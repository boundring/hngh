#!/usr/bin/env python3
"""omp-bridge roguelike-delegation smoke: run-start/run-end, hermetic.

The real script resolves scripts/hngh from its own package location, so we
stub it via the HNGH_BIN env override (which defaults to that real path): a
recording stub echoes argv per invocation to a log and exits a configurable
code. No sbcl, no network, no real hngh is touched.

Contract: run-start happy path creates run+admit argv in order and prints
the run line; a create-run refusal (exit 1/2) maps straight through before
any admit fires; run-end validates dispositions client-side (bogus -> exit
2 with no subprocess fired); run-end valid path relays hngh's rendered
close-run and exit code; AUTOMATION_ROOT defaults to ROOT/automation and
HNGH_AUTOMATION_ROOT still wins.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "omp-bridge"

HNGH_STUB = """#!{python}
import os, sys
with open(os.environ["STUB_ARGV_LOG"], "a") as fh:
    fh.write("|".join(sys.argv[1:]) + "\\n")
raise SystemExit(int(os.environ.get("STUB_EXIT", "0")))
"""


class OmpBridgeDelegation(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.argv_log = self.root / "hngh-argv.txt"
        hngh = self.root / "hngh-stub"
        hngh.write_text(HNGH_STUB.replace("{python}", sys.executable))
        os.chmod(hngh, 0o755)
        self.hngh = hngh

    def tearDown(self):
        self._td.cleanup()

    def bridge(self, *args, exit_code=0, env=None):
        overrides = dict(env or {})
        e = dict(os.environ)
        e["HNGH_BIN"] = str(self.hngh)
        e["OMP_BRIDGE_STORE"] = str(self.root / "bridge-store")
        e["STUB_ARGV_LOG"] = str(self.argv_log)
        e["STUB_EXIT"] = str(exit_code)
        for key, value in overrides.items():
            if value is None:
                e.pop(key, None)
            else:
                e[key] = value
        return subprocess.run([sys.executable, str(SCRIPT), *args],
                              capture_output=True, text=True, env=e)

    def argv_lines(self):
        return (self.argv_log.read_text().splitlines()
                if self.argv_log.exists() else [])

    # --- run-start ---------------------------------------------------------

    def test_run_start_happy_creates_run_then_admits(self):
        out = self.bridge("--run-start", "sx", "do the thing")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("run run-1 session sx", out.stdout)
        lines = self.argv_lines()
        self.assertEqual(len(lines), 2)
        self.assertIn("|create-run|do the thing|builder|", lines[0])
        self.assertIn("--store=", lines[0])
        self.assertIn("loadout-route-label=model", lines[0])
        self.assertIn("loadout-context-limit=8000", lines[0])
        self.assertIn("loadout-token-limit=8000", lines[0])
        self.assertIn("loadout-cost-limit=2000", lines[0])
        self.assertIn("loadout-time-limit=3600", lines[0])
        self.assertIn("loadout-tool-labels=worker-task/mutation", lines[0])
        self.assertIn("loadout-network-labels=model-review", lines[0])
        self.assertIn("loadout-writable-scopes=repository", lines[0])
        # admit-transport run-1 worker runs second, same store
        self.assertIn("|admit-transport|run-1|worker", lines[1])
        self.assertIn("--store=", lines[1])

    def test_run_start_task_label_sets_route_label(self):
        out = self.bridge("--run-start", "sx", "obj", "--task", "reviewer")
        self.assertEqual(out.returncode, 0, out.stderr)
        line = self.argv_lines()[0]
        self.assertIn("loadout-route-label=reviewer", line)
        self.assertNotIn("loadout-route-label=model", line)

    def test_run_start_create_refusal_propagates_no_admit(self):
        out = self.bridge("--run-start", "sx", "obj", exit_code=1)
        self.assertEqual(out.returncode, 1, out.stdout)
        self.assertIn("create-run refused", out.stderr)
        lines = self.argv_lines()
        self.assertEqual(len(lines), 1)  # admit never fired
        self.assertIn("|create-run|", lines[0])

    def test_run_start_malformed_create_propagates_2(self):
        out = self.bridge("--run-start", "sx", "obj", exit_code=2)
        self.assertEqual(out.returncode, 2, out.stdout)
        self.assertEqual(len(self.argv_lines()), 1)

    def test_run_start_empty_session_refused(self):
        out = self.bridge("--run-start", "", "obj")
        self.assertEqual(out.returncode, 2)
        self.assertIn("empty SESSION", out.stderr)
        self.assertEqual(self.argv_lines(), [])

    # --- run-end -----------------------------------------------------------

    def test_run_end_bogus_disposition_fails_local(self):
        out = self.bridge("--run-end", "run-1", "banana")
        self.assertEqual(out.returncode, 2)
        self.assertIn("cancelled|evacuated|dead", out.stderr)
        self.assertEqual(self.argv_lines(), [])  # no subprocess fired

    def test_run_end_valid_closes_run(self):
        out = self.bridge("--run-end", "run-1", "dead", exit_code=0)
        self.assertEqual(out.returncode, 0, out.stderr)
        lines = self.argv_lines()
        self.assertEqual(len(lines), 1)
        self.assertIn("|close-run|run-1|dead", lines[0])
        self.assertIn("--store=", lines[0])

    def test_run_end_propagates_refusal(self):
        out = self.bridge("--run-end", "run-1", "evacuated", exit_code=1)
        self.assertEqual(out.returncode, 1)
        self.assertIn("close-run refused", out.stderr)

    # --- automation root ----------------------------------------------------

    def test_automation_root_default_and_override(self):
        fake_root = self.root / "repo"
        (fake_root / "automation").mkdir(parents=True)
        out = self.bridge("--run-start", "sx", "obj",
                          env={"HNGH_BRIDGE_ROOT": str(fake_root),
                               "OMP_BRIDGE_STORE": None})
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn(f"--store={fake_root / 'automation' / 'bridge'}",
                      self.argv_lines()[0])
        alt = self.root / "alt-automation"
        out = self.bridge("--run-start", "sy", "obj",
                          env={"HNGH_BRIDGE_ROOT": str(fake_root),
                               "OMP_BRIDGE_STORE": None,
                               "HNGH_AUTOMATION_ROOT": str(alt)})
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn(f"--store={alt / 'bridge'}", self.argv_lines()[2])


if __name__ == "__main__":
    unittest.main(verbosity=2)
