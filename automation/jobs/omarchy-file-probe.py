#!/usr/bin/env python3
"""omarchy-file-probe -- user-level pre-install file-conflict probe.

Dry-run companion to the omarchy phase-1 install: before any package
is installed, answer "which files would the manifest packages
clobber?" -- without sudo, without installing, writing only under the
hngh home (HNGH_HOME / HNGH_HOME_DIR / ~/.hngh).

Pipeline:
  1. manifest  config/omarchy-base.packages (env OMARCHY_MANIFEST):
               lines `name # comment`; blank/#-only lines skipped,
               `aur`-marked names counted but not probed. Unreadable
               manifest or zero repo names -> exit 2.
  2. file DBs  every repo section of pacman.conf (env
               HNGH_PROBE_PACMAN_CONF) with servers from the section
               itself or the mirrorlist (env HNGH_PROBE_MIRRORS;
               file:// URLs work, so tests stay hermetic). The repo
               `<name>.files` tarball (%FILES% per package) is fetched
               with urllib (60s timeout) into HNGH_PROBE_CACHE
               (default <home>/db/omarchy/filedb) and reused offline
               until --refresh. A repo whose mirrors all fail -> exit
               2 naming the repo.
  3. classify  each manifest-package file path:
                 owned-elsewhere  in the `pacman -Qlq` set of every
                                  installed package (queried once)
                 on-disk-unowned  exists on disk, no owner
                 protected-prefix starts /etc/, /boot/,
                                  /usr/lib/systemd/system/,
                                  /usr/lib/modules/
               first match wins in that order.
  4. backup    every existing on-disk-unowned / protected-prefix file
               is copied (mode preserved) to
               <home>/db/omarchy/preinstall-backup/<UTC-ts>/ plus a
               path<TAB>sha256<TAB>class manifest.tsv. Per-file
               backup failures log and continue -- except /etc/sudoers*
               or /boot: those abort with exit 2.
  5. report    <home>/db/omarchy/file-probe.json:
               {generated, manifest_counts:{repo,aur},
                repos:[{name,url,packages}],
                conflicts:[{path,pkg,cls,backed_up}], clean}

Exit conventions mirror pins-drift / scripts/report-queue (2 on
malformed input, fail closed): 0 clean, 1 conflicts found, 2 error.
No sudo, no pacman write operations (auditable by grep: only -Qlq is
shelled out); the only writes are under the hngh home.
"""

import datetime
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request

AUTOMATION_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(AUTOMATION_ROOT, "lib"))
import hngh_home  # userspace-home paths (HNGH_HOME_DIR / ~/.hngh)

MANIFEST_PATH = os.path.join(AUTOMATION_ROOT, "config",
                             "omarchy-base.packages")
PACMAN_CONF = "/etc/pacman.conf"
FETCH_TIMEOUT = 60  # seconds, mirrors curl --max-time 60
PROTECTED_PREFIXES = ("/etc/", "/boot/",
                      "/usr/lib/systemd/system/", "/usr/lib/modules/")
ABORT_PREFIXES = ("/etc/sudoers", "/boot/")
OWNED, ONDISK, PROTECTED = ("owned-elsewhere", "on-disk-unowned",
                            "protected-prefix")


class CheckError(Exception):
    """Fail-closed input error (exit 2): never reads as 'no conflict'."""


# test seams (sudoers/boot abort cases monkeypatch these)
_lexists = os.path.lexists
_copy2 = shutil.copy2


def home_root():
    """hngh userspace home: HNGH_HOME wins, else lib/hngh_home."""
    return os.environ.get("HNGH_HOME") or hngh_home.home()


def load_manifest(path):
    """-> ([repo names], aur count). Exit 2 unreadable / zero names."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except OSError as e:
        raise CheckError("manifest unreadable %s: %r" % (path, e))
    names, aur = [], 0
    for line in lines:
        name, _, comment = line.partition("#")
        name = name.strip()
        if not name:
            continue
        if comment.strip().lower().startswith("aur"):
            aur += 1
            continue
        names.append(name)
    if not names:
        raise CheckError("manifest has zero repo names: %s" % path)
    return names, aur


def _expand(url, repo, arch):
    return url.replace("$repo", repo).replace("$arch", arch)


def _mirrors(path, repo, arch):
    """Server URLs from a mirrorlist (env override applies to all)."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except OSError as e:
        raise CheckError("mirrorlist unreadable %s: %r" % (path, e))
    urls = []
    for raw in lines:
        line = raw.strip()
        if line.startswith("Server"):
            _, _, val = line.partition("=")
            if val.strip():
                urls.append(_expand(val.strip(), repo, arch))
    return urls


def load_repos(conf_path, mirror_override=None):
    """-> {repo: [server urls]}; pacman.conf order == priority order."""
    try:
        with open(conf_path, encoding="utf-8") as f:
            conf = f.readlines()
    except OSError as e:
        raise CheckError("pacman.conf unreadable %s: %r" % (conf_path, e))
    arch = "x86_64"
    repos = {}
    current = None  # repo name, or None for the global options area
    for raw in conf:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1]
            current = None if name == "options" else name
            if current:
                repos.setdefault(current, [])
            continue
        key, sep, val = line.partition("=")
        if not sep:
            continue
        key, val = key.strip(), val.strip()
        if current is None:
            if key == "Architecture" and val:
                arch = platform.machine() if val == "auto" else val
        elif key == "Server":
            repos[current].append(_expand(val, current, arch))
        elif key == "Include":
            repos[current].extend(
                _mirrors(mirror_override or val, current, arch))
    return {r: urls for r, urls in repos.items() if urls}


def _download(url, dest):
    tmp = dest + ".part"
    try:
        with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT) as resp, \
                open(tmp, "wb") as f:
            shutil.copyfileobj(resp, f)
        os.replace(tmp, dest)
        return True
    except OSError as e:  # urllib.error.URLError subclasses OSError
        sys.stderr.write("omarchy-file-probe: fetch failed %s: %r\n"
                         % (url, e))
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def fetch_dbs(repos, cache_dir, refresh=False):
    """-> {repo: (db path, url)}; cache hits reused until --refresh."""
    os.makedirs(cache_dir, exist_ok=True)
    out = {}
    for name, urls in repos.items():
        dest = os.path.join(cache_dir, name + ".files")
        if os.path.isfile(dest) and not refresh:
            out[name] = (dest, urls[0])
            continue
        last = None
        for url in urls:
            if _download(url.rstrip("/") + "/" + name + ".files", dest):
                out[name] = (dest, url)
                break
            last = url
        else:
            raise CheckError("repo %s: all %d server(s) failed (last %s)"
                             % (name, len(urls), last))
    return out


def _desc_name(text):
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == "%NAME%" and i + 1 < len(lines):
            return lines[i + 1].strip()
    return None


def _files_list(text):
    out, on = [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("%"):
            on = s == "%FILES%"
        elif on and s:
            out.append(s)
    return out


def parse_files_db(db_path, wanted):
    """-> {package: [absolute paths]} for wanted packages in a .files
    DB tarball (%NAME%/desc + %FILES%/files per <pkg>-<ver> dir)."""
    dirs = {}
    with tarfile.open(db_path, "r:*") as tf:
        for member in tf.getmembers():
            parts = member.name.split("/")
            if len(parts) != 2 or not member.isfile():
                continue
            fobj = tf.extractfile(member)
            if fobj is None:
                continue
            text = fobj.read().decode("utf-8", "replace")
            info = dirs.setdefault(parts[0], {"name": None, "files": []})
            if parts[1] == "desc":
                info["name"] = _desc_name(text)
            elif parts[1] == "files":
                info["files"] = _files_list(text)
    found = {}
    for info in dirs.values():
        if info["name"] in wanted:
            found[info["name"]] = ["/" + p for p in info["files"] if p]
    return found


def installed_files():
    """Every file path of every installed package, queried once."""
    try:
        cp = subprocess.run(["pacman", "-Qlq"], capture_output=True,
                            text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise CheckError("pacman -Qlq unavailable: %r" % e)
    if cp.returncode != 0:
        raise CheckError("pacman -Qlq failed rc=%d: %s"
                         % (cp.returncode, cp.stderr.strip()[:200]))
    return {ln for ln in cp.stdout.splitlines() if ln}


def classify(abspath, owned):
    """-> conflict class token or None; owned beats disk beats prefix."""
    if abspath in owned:
        return OWNED
    if _lexists(abspath):
        return ONDISK
    if abspath.startswith(PROTECTED_PREFIXES):
        return PROTECTED
    return None


def backup_files(targets, backup_parent):
    """Copy (mode preserved) each existing target into a UTC-ts dir +
    write manifest.tsv rows `path<TAB>sha256<TAB>class`. -> (dir, set
    of backed-up paths). /etc/sudoers* or /boot failures abort (exit
    2); other per-file failures log and continue."""
    ts = datetime.datetime.now(datetime.timezone.utc)\
        .strftime("%Y%m%dT%H%M%SZ")
    root = os.path.join(backup_parent, ts)
    n = 0
    while os.path.isdir(root):  # same-second re-run: never clobber
        n += 1
        root = os.path.join(backup_parent, "%s.%d" % (ts, n))
    os.makedirs(root)
    rows, backed = [], set()
    for abspath, cls in targets:
        try:
            dest = os.path.join(root, abspath.lstrip("/"))
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            _copy2(abspath, dest)
            with open(dest, "rb") as f:
                digest = hashlib.sha256(f.read()).hexdigest()
            rows.append("%s\t%s\t%s\n" % (abspath, digest, cls))
            backed.add(abspath)
        except OSError as e:
            sys.stderr.write("omarchy-file-probe: backup failed %s: %r\n"
                             % (abspath, e))
            if abspath.startswith(ABORT_PREFIXES):
                raise CheckError("abort: backup failed for %s" % abspath)
    with open(os.path.join(root, "manifest.tsv"), "w",
              encoding="utf-8") as f:
        f.writelines(rows)
    return root, backed


def probe(refresh=False):
    """The pipeline: -> (report dict, report path). Raises CheckError
    (exit 2) on any fail-closed input problem."""
    manifest = os.environ.get("OMARCHY_MANIFEST") or MANIFEST_PATH
    names, aur = load_manifest(manifest)
    repos = load_repos(
        os.environ.get("HNGH_PROBE_PACMAN_CONF") or PACMAN_CONF,
        os.environ.get("HNGH_PROBE_MIRRORS"))
    if not repos:
        raise CheckError("no repo with servers in pacman.conf")
    cache = os.environ.get("HNGH_PROBE_CACHE") or os.path.join(
        home_root(), "db", "omarchy", "filedb")
    dbs = fetch_dbs(repos, cache, refresh)
    owned = installed_files()
    wanted = set(names)
    repo_pkgs = {name: [] for name in dbs}
    by_path = {}  # abspath -> pkg (first repo in pacman.conf order wins)
    for repo, (db_path, _url) in dbs.items():
        for pkg, paths in parse_files_db(db_path, wanted).items():
            repo_pkgs[repo].append(pkg)
            for p in paths:
                by_path.setdefault(p, pkg)
    conflicts, to_backup = [], []
    for abspath in sorted(by_path):
        cls = classify(abspath, owned)
        if cls is None:
            continue
        conflicts.append({"path": abspath, "pkg": by_path[abspath],
                          "cls": cls, "backed_up": False})
        if cls != OWNED and _lexists(abspath):
            to_backup.append((abspath, cls))
    backed = set()
    if to_backup:
        _root, backed = backup_files(
            to_backup, os.path.join(home_root(), "db", "omarchy",
                                    "preinstall-backup"))
    for c in conflicts:
        c["backed_up"] = c["path"] in backed
    report = {
        "generated": datetime.datetime.now(datetime.timezone.utc)
            .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "manifest_counts": {"repo": len(names), "aur": aur},
        "repos": [{"name": name, "url": dbs[name][1],
                   "packages": sorted(repo_pkgs[name])} for name in dbs],
        "conflicts": conflicts,
        "clean": not conflicts,
    }
    out = os.path.join(home_root(), "db", "omarchy", "file-probe.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, sort_keys=True)
        f.write("\n")
    return report, out


def main(argv):
    refresh = False
    for a in argv:
        if a == "--refresh":
            refresh = True
        else:
            sys.stderr.write("usage: omarchy-file-probe.py [--refresh]\n")
            return 2
    try:
        report, out = probe(refresh)
    except CheckError as e:
        sys.stderr.write("omarchy-file-probe: %s\n" % e)
        return 2
    except OSError as e:
        sys.stderr.write("omarchy-file-probe: %r\n" % e)
        return 2
    for c in report["conflicts"]:
        print("%s: %s (pkg %s)%s" % (
            c["cls"], c["path"], c["pkg"],
            " [backed up]" if c["backed_up"] else ""))
    print("omarchy-file-probe: %d conflict(s), report %s"
          % (len(report["conflicts"]), out))
    return 0 if report["clean"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
