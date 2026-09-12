#!/usr/bin/env python3
"""hngh companion-services registry guard: automation/config/hngh-services.tsv.

Mirrors test-hngh-packages.py (the registry+guard pattern). Every row must
parse to exactly 8 columns, carry a disposition from the services enum, and
resolve its install-path on THIS machine where the path is real (a "none-"
prefix marks a documented not-installed exception). In-use rows must carry a
start-command (the transient-lifecycle contract: lib/service-mgmt.sh execs
it) and a health-url. Sentinel: no sudo invocation and no curl|bash anywhere
in the management layer or the registry's start-commands, and the installer
services phase must render the real registry rows in --check mode.
"""

import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
TSV = ROOT / "config" / "hngh-services.tsv"
MGMT = ROOT / "lib" / "service-mgmt.sh"
INSTALLER = REPO / "install.sh"

COLUMNS = [
    "service", "role", "install-method", "install-path",
    "start-command", "health-url", "managed-by", "disposition",
]
DISPOSITIONS = {
    "in-use", "operator-run", "available", "registered-only", "absent",
}
ASKABLE = DISPOSITIONS - {"in-use", "operator-run"}


def registry_rows():
    rows = []
    for line in TSV.read_text().splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#") or line.startswith("service\t"):
            continue
        rows.append(line.split("\t"))
    return rows


def path_resolves(install_path):
    """PATH-independent: absolute path -> exists (a service install-path is
    commonly a root DIRECTORY, unlike a package binary); bare command ->
    shutil.which with fallback to any absolute path cited in the row."""
    token = install_path.split()[0]
    if "/" in token:
        p = os.path.expanduser(token)
        return os.path.exists(p)
    if shutil.which(token) is not None:
        return True
    return any(
        os.path.isfile(c) and os.access(c, os.X_OK)
        for c in re.findall(r"/[\w./+-]+", install_path)
    )


class TestHnghServices(unittest.TestCase):
    def test_registry_exists(self):
        self.assertTrue(TSV.is_file(), f"registry missing: {TSV}")

    def test_header_columns(self):
        header = next(
            ln for ln in TSV.read_text().splitlines() if ln.startswith("service\t")
        )
        self.assertEqual(header.split("\t"), COLUMNS)

    def test_rows_parse_to_eight_columns(self):
        for fields in registry_rows():
            self.assertEqual(
                len(fields), len(COLUMNS),
                f"row '{fields[0] if fields else '?'}' has {len(fields)} "
                f"columns (want {len(COLUMNS)})",
            )

    def test_service_ids_unique(self):
        ids = [r[0] for r in registry_rows()]
        self.assertEqual(len(ids), len(set(ids)), f"duplicate service ids: {ids}")

    def test_disposition_enum(self):
        for fields in registry_rows():
            self.assertIn(fields[7], DISPOSITIONS, f"{fields[0]}: bad disposition")

    def test_in_use_rows_have_start_command_and_health_url(self):
        for fields in registry_rows():
            if fields[7] == "in-use":
                self.assertTrue(fields[4], f"{fields[0]}: in-use needs a start-command")
                self.assertTrue(fields[5], f"{fields[0]}: in-use needs a health-url")

    def test_install_path_resolves_when_real(self):
        for fields in registry_rows():
            ip = fields[3]
            if ip.startswith("none-") or not ip:
                continue
            token = ip.split()[0]
            if "/" in token and not os.path.isdir(os.path.dirname(token)):
                continue  # registry cites another host's paths (CI clone)
            self.assertTrue(path_resolves(ip), f"{fields[0]}: install-path '{ip}' does not resolve")

    def test_managed_by_repo_file_exists(self):
        for fields in registry_rows():
            mb = fields[6]
            if mb.startswith("automation/"):
                self.assertTrue((REPO / mb).is_file(), f"{fields[0]}: managed-by '{mb}' missing")

    def test_mgmt_layer_exists_and_is_executable_sh(self):
        self.assertTrue(MGMT.is_file(), f"management layer missing: {MGMT}")

    def test_sentinel_no_sudo_or_curlbash(self):
        pattern = r"\bsudo\b|curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh"
        for label, path in (("service-mgmt.sh", MGMT), ("hngh-services.tsv", TSV)):
            for i, line in enumerate(path.read_text().splitlines(), 1):
                self.assertIsNone(
                    re.search(pattern, line),
                    f"{label}:{i}: sudo/curl|bash sentinel tripped: {line}",
                )

    def test_unknown_service_fails_closed(self):
        r = subprocess.run(
            ["/bin/bash", str(MGMT), "status", "no-such-service"],
            capture_output=True, text=True, env={"PATH": os.environ["PATH"]},
        )
        self.assertEqual(r.returncode, 2, "unknown service must exit 2")

    def test_installer_check_renders_registry_rows(self):
        sandbox = subprocess.run(
            ["mktemp", "-d"], capture_output=True, text=True,
        ).stdout.strip()
        out = subprocess.run(
            ["/bin/bash", str(INSTALLER), "--non-interactive", "--check"],
            capture_output=True, text=True,
            env={**os.environ, "HNGH_CHOICES_FILE": f"{sandbox}/c.json"},
        )
        self.assertEqual(out.returncode, 0, f"--check rc={out.returncode}: {out.stderr}")
        for fields in registry_rows():
            self.assertIn(
                fields[0], out.stdout,
                f"services phase did not render '{fields[0]}' in --check output",
            )
        self.assertIn("registry status", out.stdout, "services status header missing")
        self.assertIn("no installs", out.stdout, "--check must install nothing")

    def test_ask_seam_env_queue_then_default(self):
        def ask(env_extra, stdin_closed=True):
            r = subprocess.run(
                ["/bin/bash", "-c",
                 '. "' + str(MGMT) + '"; svc_ask_manage comfyservice-under-test'],
                capture_output=True, text=True,
                env={**os.environ, **env_extra},
                stdin=subprocess.DEVNULL,
            )
            return r.stdout.strip()
        self.assertEqual(
            ask({"HNGH_SERVICE_ANSWERS": "install configure"}),
            "install", "first queue entry must be consumed",
        )
        self.assertEqual(
            ask({"HNGH_SERVICE_ANSWERS": "skip"}),
            "skip", "single queue entry must be honored",
        )
        self.assertEqual(ask({}), "register-only", "no TTY -> register-only default")


if __name__ == "__main__":
    unittest.main(verbosity=2)
