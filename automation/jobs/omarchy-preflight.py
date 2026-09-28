#!/usr/bin/env python3
"""omarchy-preflight -- snapshot BEFORE any omarchy install/adopt.

Read-only capture of the machine state omarchy adoption would touch, into
ONE archive under the hngh userspace home (lib/hngh_home.py paths,
HNGH_HOME_DIR overrides for tests):

  (a) user configs that exist: ~/.config/{hypr,waybar,quickshell,foot,
      alacritty,kitty,gtk-3.0,gtk-4.0}, plus ~/.config/omarchy if present;
  (b) system avoid-list files, READ-ONLY if readable: <etc>/nsswitch.conf,
      <etc>/security/faillock.conf, <etc>/sddm.conf.d, <etc>/sudoers.d --
      an unreadable entry falls back to a stat-metadata blob
      (OMARCHY_ETC_DIR overrides <etc>, default /etc, for hermetic tests);
  (c) `pacman -Qqe` explicit-package list.

Archive: db/omarchy/preflight-<UTC-ts>.tar.zst; captured files sit at
their absolute path minus the leading '/', and manifest.tsv at the
archive root lists every captured path with its sha256. Per-file
failures are logged, counted in the summary, and never stop the run. A
stamp refuses a second run within 60s (--force bypasses). Exit 0
captured / 2 fail-closed (refusals; --strict when nothing is
capturable). --dry-run prints the plan and writes nothing.

Boring by design: stdlib tarfile/hashlib only (tar.zst needs the
py3.14+ tarfile, which this host runs); no daemon; no second backup
convention -- git-backed dots stay with the gbd parity lane
(jobs/config-backup.sh).
"""

import datetime
import hashlib
import importlib.util
import io
import os
import subprocess
import sys
import tarfile
import time

AUTOMATION_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USER_CONFIG_NAMES = ("hypr", "waybar", "quickshell", "foot", "alacritty",
                     "kitty", "gtk-3.0", "gtk-4.0")
OMARCHY_CONFIG_NAME = "omarchy"
ETC_DIR = os.environ.get("OMARCHY_ETC_DIR") or "/etc"
SYS_REL = ("nsswitch.conf", "security/faillock.conf",
           "sddm.conf.d", "sudoers.d")
PACMAN_LIST_ARC = "sys-meta/pacman-Qqe.txt"
META_ARC_DIR = "sys-meta"
REFUSE_WINDOW_S = 60
STAMP_NAME = ".last-preflight"
USAGE = "usage: omarchy-preflight.py [--dry-run] [--strict] [--force]"

_HH = None


class CheckError(Exception):
    """Fail-closed condition (exit 2)."""


def log(msg):
    print("omarchy-preflight: %s" % msg, file=sys.stderr)


def hngh_home():
    """lib/hngh_home.py loaded once (userspace-home paths, honors
    HNGH_HOME_DIR; same pattern as jobs/news-articles.py)."""
    global _HH
    if _HH is None:
        spec = importlib.util.spec_from_file_location(
            "hngh_home", os.path.join(AUTOMATION_ROOT, "lib", "hngh_home.py"))
        _HH = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_HH)
    return _HH


def _kind_of(path):
    if os.path.isdir(path):
        return "dir" if os.access(path, os.R_OK | os.X_OK) else "meta"
    if os.path.isfile(path):
        return "file" if os.access(path, os.R_OK) else "meta"
    return None


def build_plan():
    """-> [(path, kind)] for every existing candidate source; kind is
    file | dir | meta (exists but unreadable -> metadata only)."""
    items = []
    config_root = os.path.join(os.path.expanduser("~"), ".config")
    for name in USER_CONFIG_NAMES + (OMARCHY_CONFIG_NAME,):
        p = os.path.join(config_root, name)
        kind = _kind_of(p)
        if kind:
            items.append((p, kind))
    for rel in SYS_REL:
        p = os.path.join(ETC_DIR, rel)
        kind = _kind_of(p)
        if kind:
            items.append((p, kind))
    return items


def explicit_packages():
    """-> `pacman -Qqe` text, or None when the call fails (logged)."""
    try:
        out = subprocess.run(["pacman", "-Qqe"], capture_output=True,
                             text=True, timeout=30, check=True)
    except Exception as exc:
        log("pacman -Qqe failed: %r" % exc)
        return None
    return out.stdout


def stat_blob(path):
    st = os.stat(path)
    return ("path=%s\nmode=%04o uid=%d gid=%d size=%d mtime=%d\n"
            % (path, st.st_mode & 0o7777, st.st_uid, st.st_gid,
               st.st_size, int(st.st_mtime))).encode()


def meta_arcname(path):
    return os.path.join(
        META_ARC_DIR, path.strip("/").replace("/", "_") + ".stat")


def collect(items, pkgs):
    """-> (entries, failed). entries = [(arcname, payload)] where payload
    is an absolute source path (read at archive time) or bytes blob."""
    entries = []
    failed = 0

    def onerr(exc, src):
        nonlocal failed
        failed += 1
        log("walk failed %s: %r" % (getattr(exc, "filename", src), exc))

    for src, kind in items:
        if kind == "file":
            entries.append((src.lstrip("/"), src))
        elif kind == "dir":
            def walk_err(exc, src=src):
                onerr(exc, src)
            for base, _dirs, files in os.walk(src, onerror=walk_err):
                for fn in sorted(files):
                    full = os.path.join(base, fn)
                    entries.append((full.lstrip("/"), full))
        else:  # meta
            entries.append((meta_arcname(src), stat_blob(src)))
    if pkgs is not None:
        entries.append((PACMAN_LIST_ARC, pkgs.encode()))
    return entries, failed


def next_archive_path(archive_dir):
    ts = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ")
    path = os.path.join(archive_dir, "preflight-%s.tar.zst" % ts)
    n = 1
    while os.path.exists(path):
        n += 1
        path = os.path.join(archive_dir, "preflight-%s-%d.tar.zst" % (ts, n))
    return path


def write_archive(archive_path, entries):
    """Write entries + manifest.tsv; -> (written, failed)."""
    written = 0
    failed = 0
    rows = []
    with tarfile.open(archive_path, "w:zst") as tf:

        def add(arcname, data):
            ti = tarfile.TarInfo(arcname)
            ti.size = len(data)
            tf.addfile(ti, io.BytesIO(data))

        for arcname, payload in entries:
            if isinstance(payload, bytes):
                data = payload
            else:
                try:
                    with open(payload, "rb") as fh:
                        data = fh.read()
                except OSError as exc:
                    failed += 1
                    log("read failed %s: %r" % (payload, exc))
                    continue
            add(arcname, data)
            rows.append((arcname, hashlib.sha256(data).hexdigest()))
            written += 1
        manifest = "# path\tsha256\n" + "".join(
            "%s\t%s\n" % (arc, sha) for arc, sha in rows)
        add("manifest.tsv", manifest.encode())
    return written, failed


def stamp_file():
    # no side effects: the refusal check must not create the db dir
    return os.path.join(hngh_home().home(), "db", "omarchy", STAMP_NAME)


def refuse_if_recent(force):
    """Refuse a second run inside REFUSE_WINDOW_S unless --force."""
    if force:
        return
    try:
        with open(stamp_file(), encoding="utf-8") as fh:
            last = int(fh.read().strip())
    except (OSError, ValueError):
        return
    delta = int(time.time()) - last
    if 0 <= delta < REFUSE_WINDOW_S:
        raise CheckError(
            "ran %ds ago; refusing to run twice within %ds (use --force)"
            % (delta, REFUSE_WINDOW_S))


def write_stamp():
    os.makedirs(os.path.dirname(stamp_file()), exist_ok=True)
    with open(stamp_file(), "w", encoding="utf-8") as fh:
        fh.write("%d\n" % int(time.time()))


def print_plan(items, pkgs):
    for src, kind in items:
        print("%-5s %s" % (kind, src))
    print("pacman -Qqe: %s" % ("yes" if pkgs is not None else "FAILED"))
    print("archive: %s" % next_archive_path(
        os.path.join(hngh_home().home(), "db", "omarchy")))


def main(argv):
    dry = strict = force = False
    for arg in argv:
        if arg == "--dry-run":
            dry = True
        elif arg == "--strict":
            strict = True
        elif arg == "--force":
            force = True
        else:
            print(USAGE, file=sys.stderr)
            return 2
    try:
        if not dry:
            refuse_if_recent(force)
        items = build_plan()
        pkgs = explicit_packages()
        entries, failed = collect(items, pkgs)
        if pkgs is None:
            failed += 1
        if not entries and strict:
            raise CheckError(
                "nothing capturable (no readable user configs, no "
                "avoid-list files, no package list) and --strict set")
        if dry:
            print("== omarchy-preflight dry-run plan")
            print_plan(items, pkgs)
            return 0
        target = next_archive_path(hngh_home().db_dir("omarchy"))
        written, write_failed = write_archive(target, entries)
        failed += write_failed
        write_stamp()
        print("preflight: ok captured=%d failed=%d archive=%s"
              % (written, failed, target))
        return 0
    except CheckError as exc:
        log(exc)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
