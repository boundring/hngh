#!/usr/bin/env python3
"""hngh collected-repositories registry guard: automation/config/hngh-packages.tsv.

Every row must parse to exactly 8 columns, cite an https upstream, carry a
disposition from the enum, and reference only feeds actually registered in
automation/config.env SOURCES. In-use rows must resolve their official
install-path on this machine PATH-independently (absolute path -> isfile
+ executable bit; bare command -> shutil.which with fallback to any
absolute path cited in the row; "none-" prefix marks the documented
not-installed-standalone exception).
"""

import os
import re
import shutil
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TSV = ROOT / "config" / "hngh-packages.tsv"
CONFIG_ENV = ROOT / "config.env"

COLUMNS = [
    "package", "upstream", "role", "install-path",
    "config-surface", "update-mechanism", "follow-feed", "disposition",
]
DISPOSITIONS = {
    "in-use", "use-later", "watch", "backlog-study", "study", "caution", "skip",
}


def registry_rows():
    rows = []
    for line in TSV.read_text().splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#") or line.startswith("package\t"):
            continue
        rows.append(line.split("\t"))
    return rows


def sources_feed_names():
    """Feed names registered in config.env SOURCES (name:url lines)."""
    text = CONFIG_ENV.read_text()
    m = re.search(r'SOURCES="\$\{SOURCES:-(.*?)\}"', text, re.S)
    if not m:
        return set()
    names = set()
    for line in m.group(1).splitlines():
        line = line.strip()
        if line and not line.startswith("#") and ":" in line:
            names.add(line.split(":", 1)[0])
    return names


def path_resolves(install_path):
    """PATH-independent: absolute path -> isfile + X_OK; bare command ->
    shutil.which with fallback to any absolute path cited in the row."""
    token = install_path.split()[0]
    if "/" in token:
        p = os.path.expanduser(token)
        return os.path.isfile(p) and os.access(p, os.X_OK)
    if shutil.which(token) is not None:
        return True
    return any(
        os.path.isfile(c) and os.access(c, os.X_OK)
        for c in re.findall(r"/[\w./+-]+", install_path)
    )


class TestHnghPackages(unittest.TestCase):
    def test_registry_exists(self):
        self.assertTrue(TSV.exists(), f"missing registry {TSV}")

    def test_rows_parse_to_8_columns(self):
        for i, parts in enumerate(registry_rows()):
            self.assertEqual(
                len(parts), len(COLUMNS),
                f"row {i}: expected {len(COLUMNS)} tab-separated columns, "
                f"got {len(parts)}",
            )

    def test_no_duplicate_packages(self):
        ids = [p[0] for p in registry_rows()]
        dupes = {i for i in ids if ids.count(i) > 1}
        self.assertEqual(dupes, set(), f"duplicate registry rows: {sorted(dupes)}")

    def test_upstream_is_https(self):
        for p in registry_rows():
            self.assertTrue(
                p[1].startswith("https://"),
                f"{p[0]}: upstream must be an https URL",
            )

    def test_disposition_in_enum(self):
        for p in registry_rows():
            self.assertIn(
                p[7], DISPOSITIONS,
                f"{p[0]}: disposition '{p[7]}' not in {sorted(DISPOSITIONS)}",
            )

    def test_follow_feed_registered_and_atom(self):
        feeds = sources_feed_names()
        for p in registry_rows():
            name = p[6]
            if not name:
                continue
            self.assertIn(name, feeds, f"{p[0]}: feed '{name}' missing from config.env SOURCES")
            url_line = next(
                l.strip() for l in CONFIG_ENV.read_text().splitlines()
                if l.strip().startswith(name + ":")
            )
            url = url_line.split(":", 1)[1]
            self.assertRegex(url, r"^https://\S+\.atom$", f"{p[0]}: feed {name} url not an atom URL")

    def test_in_use_install_paths_resolve(self):
        # the registry cites absolute paths on the operator's machine; on
        # a foreign checkout (CI runner) there is nothing to resolve --
        # but a missing install on the registry's own home still fails
        for p in registry_rows():
            if p[7] != "in-use":
                continue
            ip = p[3]
            if ip.startswith("none-"):
                self.assertNotEqual(ip, "none-", f"{p[0]}: bare 'none' lacks a reason")
                continue
            if os.environ.get("CI") == "true" and not os.path.isdir(
                    os.path.expanduser("~/.bun/bin")):
                self.skipTest("foreign host (CI clone): machine paths cited")
            self.assertTrue(
                path_resolves(ip),
                f"{p[0]}: official install-path '{ip}' does not resolve on this machine",
            )

    def test_known_in_use_packages_present(self):
        ids = {p[0] for p in registry_rows()}
        for pkg in ("omp", "bili", "pi", "opencode", "acp-kernel"):
            self.assertIn(pkg, ids, f"in-use package '{pkg}' missing from registry")


if __name__ == "__main__":
    unittest.main(verbosity=2)