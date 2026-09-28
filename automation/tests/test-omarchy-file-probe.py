#!/usr/bin/env python3
"""omarchy-file-probe contract tests (hermetic: no network, no pacman).

Fixture mini .files tarball + file:// mirror + PATH-stub `pacman -Qlq`
+ sandboxed HNGH home (env seams: OMARCHY_MANIFEST, HNGH_PROBE_*).
The CLI is subprocessed end-to-end for exit codes and report shape;
the sudoers/boot backup aborts are exercised in-process with the
_lexists/_copy2 seams monkeypatched (never touching real /etc or
/boot).
"""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parents[1]
JOB = AUTO / "jobs" / "omarchy-file-probe.py"

ENV_KEYS = ("HNGH_HOME", "OMARCHY_MANIFEST", "HNGH_PROBE_PACMAN_CONF",
            "HNGH_PROBE_MIRRORS", "HNGH_PROBE_CACHE", "PACMAN_QLQ",
            "PATH")


def _rel(p):
    """Absolute path -> pacman .files relative form (no leading /)."""
    return str(p).lstrip("/")


def _restore_environ(old):
    def _do():
        for k, v in old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    return _do


def make_files_db(path, pkgs):
    """Mini pacman .files DB tarball: pkgs = {name: [relative paths]}."""
    with tarfile.open(path, "w:gz") as tf:
        for name, files in sorted(pkgs.items()):
            d = "%s-1.0-1" % name

            def add(member, data):
                info = tarfile.TarInfo(member)
                info.size = len(data)
                tf.addfile(info, io.BytesIO(data))

            add(d + "/desc", ("%%NAME%%\n%s\n%%VERSION%%\n1.0-1\n"
                              % name).encode())
            add(d + "/files",
                ("%FILES%\n" + "\n".join(files) + "\n").encode())


class Fixture:
    """Sandbox: file:// mirror with a fixture .files DB, pacman.conf,
    stub pacman, canned `pacman -Qlq` output, hngh home."""

    def __init__(self, root, pkgs=None, manifest=None, installed=None):
        self.root = Path(root)
        self.home = self.root / "home"
        self.cache = self.home / "db" / "omarchy" / "filedb"
        self.mirror = self.root / "mirror"
        self.mirror.mkdir(parents=True)
        exists = self.root / "exists.txt"
        exists.write_text("probe-keep\n")
        exists.chmod(0o640)
        self.exists = exists
        db_pkgs = {
            "probea": ["usr/bin/probea", "usr/share/doc/probea/README"],
            "probeb": ["etc/vimrc", _rel(exists),
                       "etc/hngh-probe-fixture/protected.conf"],
        }
        make_files_db(self.mirror / "fixture.files",
                      pkgs if pkgs is not None else db_pkgs)
        self.manifest = self.root / "manifest.packages"
        self.manifest.write_text(manifest if manifest is not None else
                                 "# fixture manifest\nprobea\nprobeb\n"
                                 "aurpkg # aur\n")
        self.conf = self.root / "pacman.conf"
        self.conf.write_text("[options]\nArchitecture = x86_64\n\n"
                             "[fixture]\n"
                             "Include = /etc/pacman.d/mirrorlist\n")
        self.mirrorlist = self.root / "mirrorlist"
        self.mirrorlist.write_text("Server = file://%s\n" % self.mirror)
        self.qlq = self.root / "qlq.txt"
        self.qlq.write_text("/etc/vimrc\n/usr/bin/other-pkg-file\n")
        self.qq = self.root / "qq.txt"
        self.qq.write_text("".join(n + "\n" for n in (installed or [])))
        self.bin = self.root / "bin"
        self.bin.mkdir(exist_ok=True)
        stub = self.bin / "pacman"
        stub.write_text('#!/bin/sh\n'
                        '[ "$1" = -Qlq ] && { cat "$PACMAN_QLQ"; exit 0; }\n'
                        '[ "$1" = -Qq ] && { cat "$PACMAN_QQ"; exit 0; }\n'
                        'echo "stub pacman: unsupported: $*" >&2\nexit 1\n')
        stub.chmod(0o755)

    def env(self):
        e = os.environ.copy()
        e["PATH"] = str(self.bin) + os.pathsep + e.get("PATH", "")
        e["PACMAN_QLQ"] = str(self.qlq)
        e["PACMAN_QQ"] = str(self.qq)
        e["HNGH_HOME"] = str(self.home)
        e["OMARCHY_MANIFEST"] = str(self.manifest)
        e["HNGH_PROBE_PACMAN_CONF"] = str(self.conf)
        e["HNGH_PROBE_MIRRORS"] = str(self.mirrorlist)
        e["HNGH_PROBE_CACHE"] = str(self.cache)
        return e

    def run(self, *args):
        return subprocess.run([sys.executable, "-B", str(JOB), *args],
                              capture_output=True, text=True,
                              env=self.env(), timeout=120)

    def report(self):
        with open(self.home / "db" / "omarchy" / "file-probe.json") as f:
            return json.load(f)


def load_probe():
    spec = importlib.util.spec_from_file_location("omarchy_file_probe", JOB)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class OmarchyFileProbe(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="omarchy-probe-test-")
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def test_clean_exit_0(self):
        fx = Fixture(self.tmp, manifest="probea\n")
        r = fx.run()
        self.assertEqual(r.returncode, 0, r.stderr)
        rep = fx.report()
        self.assertTrue(rep["clean"])
        self.assertEqual(rep["conflicts"], [])
        self.assertEqual(rep["manifest_counts"], {"repo": 1, "aur": 0})
        self.assertEqual(rep["repos"][0]["name"], "fixture")
        self.assertIn("file://", rep["repos"][0]["url"])
        self.assertEqual(rep["repos"][0]["packages"], ["probea"])
        self.assertIn("generated", rep)

    def test_manifest_counts_and_classes(self):
        fx = Fixture(self.tmp)
        r = fx.run()
        self.assertEqual(r.returncode, 1, r.stderr)
        rep = fx.report()
        self.assertEqual(rep["manifest_counts"], {"repo": 2, "aur": 1})
        self.assertFalse(rep["clean"])
        got = {(c["path"], c["cls"]) for c in rep["conflicts"]}
        self.assertEqual(got, {
            ("/etc/vimrc", "owned-elsewhere"),
            (str(fx.exists), "on-disk-unowned"),
            ("/etc/hngh-probe-fixture/protected.conf", "protected-prefix"),
        })
        pkg = {c["path"]: c["pkg"] for c in rep["conflicts"]}
        self.assertEqual(pkg["/etc/vimrc"], "probeb")

    def test_backup_manifest_tsv(self):
        fx = Fixture(self.tmp)
        r = fx.run()
        self.assertEqual(r.returncode, 1, r.stderr)
        broot = fx.home / "db" / "omarchy" / "preinstall-backup"
        tsdirs = list(broot.iterdir())
        self.assertEqual(len(tsdirs), 1)
        dest = tsdirs[0] / _rel(fx.exists)
        self.assertTrue(dest.is_file())
        self.assertEqual(dest.stat().st_mode & 0o777, 0o640)  # mode kept
        rows = (tsdirs[0] / "manifest.tsv").read_text().splitlines()
        self.assertEqual(rows, ["%s\t%s\ton-disk-unowned" % (
            fx.exists, hashlib.sha256(b"probe-keep\n").hexdigest())])
        backed = {c["path"]: c["backed_up"]
                  for c in fx.report()["conflicts"]}
        self.assertTrue(backed[str(fx.exists)])
        self.assertFalse(backed["/etc/hngh-probe-fixture/protected.conf"])
        self.assertFalse(backed["/etc/vimrc"])

    def test_exit_2_manifest_errors(self):
        fx = Fixture(self.tmp, manifest="aurpkg # aur\n# only comments\n")
        r = fx.run()
        self.assertEqual(r.returncode, 2)
        self.assertIn("zero repo names", r.stderr)
        e = fx.env()
        e["OMARCHY_MANIFEST"] = str(fx.root / "nope.packages")
        r = subprocess.run([sys.executable, "-B", str(JOB)],
                           capture_output=True, text=True, env=e)
        self.assertEqual(r.returncode, 2)
        self.assertIn("unreadable", r.stderr)

    def test_exit_2_fetch_failure_names_repo(self):
        fx = Fixture(self.tmp)
        (fx.mirror / "fixture.files").unlink()
        r = fx.run()
        self.assertEqual(r.returncode, 2)
        self.assertIn("fixture", r.stderr)
        self.assertIn("failed", r.stderr)

    def test_cached_db_offline_rerun(self):
        fx = Fixture(self.tmp)
        first = fx.run()
        self.assertEqual(first.returncode, 1, first.stderr)
        db = fx.cache / "fixture.files"
        self.assertTrue(db.is_file())
        mtime = db.stat().st_mtime_ns
        # break the mirror: any fetch attempt now exits 2
        fx.mirrorlist.write_text("Server = file://%s/missing\n" % fx.mirror)
        second = fx.run()
        self.assertEqual(second.returncode, 1, second.stderr)
        self.assertNotIn("fetch failed", second.stderr)
        self.assertEqual(db.stat().st_mtime_ns, mtime)

    def test_architecture_auto_resolves_machine_arch(self):
        fx = Fixture(self.tmp)
        v4 = fx.mirror / "x86_64_v4"
        v4.mkdir()
        (v4 / "fixture.files").write_bytes(
            (fx.mirror / "fixture.files").read_bytes())
        fx.conf.write_text("[options]\nArchitecture = auto\n\n"
                           "[fixture]\n"
                           "Include = /etc/pacman.d/mirrorlist\n")
        fx.mirrorlist.write_text("Server = file://%s/$arch_v4\n" % fx.mirror)
        r = fx.run()
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertIn("x86_64_v4", json.dumps(fx.report()))

    def test_installed_target_satisfied_never_conflict(self):
        """An installed target owns its own files: every one of its
        paths is skipped (no owned-elsewhere, no on-disk backup), the
        report names it under 'satisfied', and it cannot manufacture a
        conflict or an exit 1 by being pre-installed."""
        fx = Fixture(self.tmp, installed=["probeb"])
        r = fx.run()
        self.assertEqual(r.returncode, 0, r.stderr)
        rep = fx.report()
        self.assertEqual(rep["satisfied"], ["probeb"])
        self.assertEqual(rep["conflicts"], [])
        self.assertTrue(rep["clean"])

    def test_files_directory_entries_never_conflict(self):
        """.files DB directory entries (trailing /) are shared dirs:
        pacman deliberately allows co-ownership, so they are counted
        under 'shared_dirs' and never classified as conflicts -- even
        in a run that has a genuine on-disk conflict."""
        exists = Path(self.tmp) / "exists.txt"
        fx = Fixture(self.tmp,
                     pkgs={"probea": [_rel(exists),
                                      "usr/share/probe-dir/"]})
        r = fx.run()
        self.assertEqual(r.returncode, 1, r.stderr)
        rep = fx.report()
        self.assertEqual(rep["shared_dirs"], 1)
        self.assertEqual({(c["path"], c["cls"]) for c in rep["conflicts"]},
                         {(str(exists), "on-disk-unowned")})
        self.assertNotIn("usr/share/probe-dir/",
                         {c["path"] for c in rep["conflicts"]})

    def test_unknown_arg_exit_2(self):
        fx = Fixture(self.tmp)
        r = fx.run("--frobnicate")
        self.assertEqual(r.returncode, 2)
        self.assertIn("usage", r.stderr)

    def _abort_case(self, relpath, target):
        fx = Fixture(self.tmp, pkgs={"probec": [relpath]},
                     manifest="probec\n")
        old = {k: os.environ.get(k) for k in ENV_KEYS}
        for k in ENV_KEYS:
            os.environ[k] = fx.env()[k]
        self.addCleanup(_restore_environ(old))
        mod = load_probe()
        orig_lex, orig_copy = mod._lexists, mod._copy2
        mod._lexists = lambda p, o=orig_lex, t=target: \
            True if p == t else o(p)

        def boom(src, dst):
            raise OSError("backup denied")
        mod._copy2 = boom
        self.addCleanup(setattr, mod, "_lexists", orig_lex)
        self.addCleanup(setattr, mod, "_copy2", orig_copy)
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            rc = mod.main([])
        self.assertEqual(rc, 2)
        self.assertIn(target, err.getvalue())
        self.assertIn("abort", err.getvalue())

    def test_sudoers_backup_failure_aborts(self):
        self._abort_case("etc/sudoers", "/etc/sudoers")

    def test_boot_backup_failure_aborts(self):
        self._abort_case("boot/vmlinuz-probe", "/boot/vmlinuz-probe")


if __name__ == "__main__":
    unittest.main()
