#!/usr/bin/env python3
"""omarchy-preflight contracts (hermetic).

jobs/omarchy-preflight.py snapshots machine state BEFORE an omarchy
install/adopt. This suite proves, in a sandbox (HOME / HNGH_HOME_DIR /
OMARCHY_ETC_DIR env + PATH-stub pacman driven by a fixture file -- the
test-pins-drift.sh technique):

  m1) capture + manifest sha256 correctness: every archive member except
      manifest.tsv is listed with the right sha256; an unreadable dir
      (sudoers.d stand-in) falls back to a stat-metadata blob;
  m2) missing dirs tolerated: only present sources are captured;
  m3) 60s re-run refusal + --force bypass;
  m4) --dry-run prints the plan, writes nothing;
  m5) --strict exit 2 on empty capture (non-strict still exits 0 with a
      manifest-only archive);
  m6) config/omarchy-defaults.tsv schema: live rows all exactly 4-field;
      a deliberately broken fixture row fails closed (research-lines
      _read_tsv fail-closed style).

Boundary: grammar + archive shape only. No live pacman, no /etc reads,
no ~/.hngh writes.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

AUTO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOB = os.path.join(AUTO_ROOT, "jobs", "omarchy-preflight.py")
DEFAULTS = os.path.join(AUTO_ROOT, "config", "omarchy-defaults.tsv")
DEFAULTS_FIELDS = ("key", "value", "source", "note")
EXPECTED_KEYS = frozenset((
    "palette.scheme", "palette.accent", "palette.window_bg",
    "palette.view_bg", "palette.positive", "palette.negative",
    "font.ui", "font.mono", "terminal.default", "terminal.alt",
    "browser.default", "browser.alt", "editor.default",
    "wallpaper.engine", "session.target", "session.host_type"))

# deterministic pacman stub FIRST ON PATH: -Qqe cats the fixture file;
# PACMAN_FAIL=1 forces the fail-closed path.
STUB_PACMAN = """#!/usr/bin/env bash
if [ -n "${PACMAN_FAIL:-}" ]; then
  echo "stub pacman: forced failure" >&2
  exit 1
fi
cat "$PACMAN_QQE_FIXTURE"
"""


def read_defaults(path):
    """4-field fail-closed parse (research-lines _read_tsv headerless
    style): '#' comments and blank lines skipped, every data row exactly
    4 fields, anything else raises."""
    rows = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, start=1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 4:
                raise ValueError("%s:%d: row has %d fields, expected 4"
                                 % (path, n, len(fields)))
            rows.append(dict(zip(DEFAULTS_FIELDS, fields)))
    return rows


class Sandbox(unittest.TestCase):
    """Fresh HOME + hngh home + etc + pacman stub per test (umask 022 is
    the caller's job; fixtures are 0644/0755 by default)."""

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="omarchy-preflight-test-")
        self.home = os.path.join(self.td, "home")
        self.hngh = os.path.join(self.td, "hngh")
        self.etc = os.path.join(self.td, "etc")
        self.stub = os.path.join(self.td, "bin")
        self.fx = os.path.join(self.td, "fx")
        for d in (self.home, self.hngh, self.etc, self.stub, self.fx):
            os.mkdir(d)
        self.pacman = os.path.join(self.stub, "pacman")
        with open(self.pacman, "w") as fh:
            fh.write(STUB_PACMAN)
        os.chmod(self.pacman, 0o755)
        self.qqe = os.path.join(self.fx, "qqe.txt")
        with open(self.qqe, "w") as fh:
            fh.write("linux\nfirefox-developer-edition\n")
        self.addCleanup(self._cleanup)

    def _cleanup(self):
        for base, dirs, _files in os.walk(self.td):
            for d in dirs:
                try:
                    os.chmod(os.path.join(base, d), 0o755)
                except OSError:
                    pass
        shutil.rmtree(self.td, ignore_errors=True)

    def cfg(self, *parts):
        return os.path.join(self.home, ".config", *parts)

    def put(self, path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(text)
        return path

    def seed_sources(self):
        self.put(self.cfg("hypr", "hyprland.conf"),
                 "monitor=eDP-1,preferred,auto,1\n")
        self.put(self.cfg("foot", "foot.ini"), "font=Iosevka:size=11\n")
        self.put(self.cfg("omarchy", "bin", "default"), "echo omarchy\n")
        self.put(self.cfg("gtk-3.0", "gtk.css"), "# nothing yet\n")
        self.put(os.path.join(self.etc, "nsswitch.conf"),
                 "passwd: files systemd\n")
        self.put(os.path.join(self.etc, "security", "faillock.conf"),
                 "deny = 5\n")
        self.put(os.path.join(self.etc, "sddm.conf.d", "sddm.conf"),
                 "[General]\nDisplayServer=wayland\n")
        self.put(os.path.join(self.etc, "sudoers.d", "README"), "secret\n")
        os.chmod(os.path.join(self.etc, "sudoers.d"), 0o000)

    def run_job(self, *flags, fail_pacman=False):
        env = os.environ.copy()
        env.update({
            "HOME": self.home,
            "HNGH_HOME_DIR": self.hngh,
            "OMARCHY_ETC_DIR": self.etc,
            "PACMAN_QQE_FIXTURE": self.qqe,
            "PATH": self.stub + os.pathsep + env["PATH"],
        })
        env.pop("PACMAN_FAIL", None)
        if fail_pacman:
            env["PACMAN_FAIL"] = "1"
        return subprocess.run([sys.executable, "-B", JOB, *flags],
                              capture_output=True, text=True, env=env)


class Capture(Sandbox):

    def archive(self):
        arcs = os.listdir(os.path.join(self.hngh, "db", "omarchy"))
        tars = [a for a in arcs if a.endswith(".tar.zst")]
        self.assertEqual(len(tars), 1, arcs)
        return tarfile.open(
            os.path.join(self.hngh, "db", "omarchy", tars[0]), "r:zst")

    def manifest_rows(self, tf):
        rows = {}
        for line in tf.extractfile("manifest.tsv").read().decode().splitlines()[1:]:
            arc, sha = line.split("\t")
            rows[arc] = sha
        return rows

    def test_m1_capture_and_manifest_sha256(self):
        self.seed_sources()
        r = self.run_job()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("captured=", r.stdout)
        with self.archive() as tf:
            members = tf.getnames()
            rows = self.manifest_rows(tf)
            self.assertEqual(sorted(members),
                             sorted(rows.keys() | {"manifest.tsv"}))
            for arc, sha in rows.items():
                data = tf.extractfile(arc).read()
                self.assertEqual(hashlib.sha256(data).hexdigest(), sha, arc)
            for src in ("hypr/hyprland.conf", "foot/foot.ini",
                        "omarchy/bin/default", "gtk-3.0/gtk.css"):
                with open(self.cfg(*src.split("/")), "rb") as fh:
                    self.assertEqual(
                        tf.extractfile(
                            self.cfg(*src.split("/")).lstrip("/")).read(),
                        fh.read(), src)
            pkg = tf.extractfile("sys-meta/pacman-Qqe.txt").read().decode()
            self.assertEqual(pkg, "linux\nfirefox-developer-edition\n")
        meta = [a for a in rows if a.startswith("sys-meta/")
                and a.endswith("sudoers.d.stat")]
        self.assertEqual(len(meta), 1, rows)
        with self.archive() as tf:
            blob = tf.extractfile(meta[0]).read().decode()
        self.assertIn("path=%s" % os.path.join(self.etc, "sudoers.d"), blob)
        self.assertIn("mode=0000", blob)

    def test_m2_missing_dirs_tolerated(self):
        self.put(self.cfg("gtk-3.0", "gtk.css"), "# only this\n")
        r = self.run_job()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("captured=2", r.stdout)
        self.assertIn("failed=0", r.stdout)
        with self.archive() as tf:
            rows = self.manifest_rows(tf)
        self.assertEqual(sorted(rows),
                         sorted([self.cfg("gtk-3.0", "gtk.css").lstrip("/"),
                                 "sys-meta/pacman-Qqe.txt"]))


class Guards(Sandbox):

    def arcdir(self):
        return os.path.join(self.hngh, "db", "omarchy")

    def archives(self):
        return sorted(a for a in os.listdir(self.arcdir())
                      if a.endswith(".tar.zst"))

    def test_m3_refuse_within_60s_then_force(self):
        self.seed_sources()
        self.assertEqual(self.run_job().returncode, 0)
        self.assertEqual(len(self.archives()), 1)
        r2 = self.run_job()
        self.assertEqual(r2.returncode, 2)
        self.assertIn("--force", r2.stderr)
        self.assertEqual(len(self.archives()), 1)  # nothing new written
        self.assertEqual(self.run_job("--force").returncode, 0)
        self.assertEqual(len(self.archives()), 2)

    def test_m4_dry_run_writes_nothing(self):
        self.seed_sources()
        r = self.run_job("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("dry-run", r.stdout)
        self.assertIn("archive:", r.stdout)
        for src in ("hypr", "omarchy"):
            self.assertIn(self.cfg(src), r.stdout)
        self.assertIn(os.path.join(self.etc, "nsswitch.conf"), r.stdout)
        self.assertIn("pacman -Qqe: yes", r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.hngh, "db")))

    def test_m5_strict_exit2_on_empty_capture(self):
        r = self.run_job("--strict", fail_pacman=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("nothing capturable", r.stderr)
        self.assertFalse(os.path.exists(os.path.join(self.hngh, "db")))

    def test_m5b_non_strict_empty_capture_writes_manifest_only(self):
        r = self.run_job(fail_pacman=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("captured=0", r.stdout)
        self.assertIn("failed=1", r.stdout)
        with tarfile.open(os.path.join(
                self.arcdir(), self.archives()[0]), "r:zst") as tf:
            self.assertEqual(tf.getnames(), ["manifest.tsv"])


class DefaultsSchema(unittest.TestCase):
    """config/omarchy-defaults.tsv: 4-field fail-closed gate in the
    research-lines style -- the real parser over hermetic tmpdir TSVs,
    plus live contracts on the actual data file."""

    def write(self, text):
        fd, path = tempfile.mkstemp(suffix=".tsv")
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        self.addCleanup(os.unlink, path)
        return path

    def test_m6_live_rows_are_4_field_with_expected_keys(self):
        rows = read_defaults(DEFAULTS)
        self.assertEqual(frozenset(r["key"] for r in rows), EXPECTED_KEYS)
        self.assertEqual(rows[0]["value"], "Blueprints")
        self.assertEqual(rows[0]["source"],
                         "~/.local/share/color-schemes/Blueprints.colors")

    def test_m6_well_formed_fixture_parses(self):
        good = "# key\tvalue\tsource\tnote\n\n# comment\n"
        good += "a.b\tc\td\tnote\n"
        self.assertEqual(read_defaults(self.write(good))[0]["key"], "a.b")

    def test_m6_short_row_fails_closed(self):
        broken = "# key\tvalue\tsource\tnote\nshort\trow\there\n"
        with self.assertRaises(ValueError):
            read_defaults(self.write(broken))

    def test_m6_overwide_row_fails_closed(self):
        broken = "# key\tvalue\tsource\tnote\nk\tv\ts\tn\textra\n"
        with self.assertRaises(ValueError):
            read_defaults(self.write(broken))


if __name__ == "__main__":
    unittest.main()
