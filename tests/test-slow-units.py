#!/usr/bin/env python3
"""slow-units contract (oversight probe_time_ledger): a unit is flagged
when its last wall exceeds max(2x trailing p50, 10s floor) — unless the
wall is inside the unit's design envelope. The workbeat is bimodal BY
DESIGN (skip-exit ~0.2s / bounded beat ~150-240s / timeout-capped
session up to 1800s in overnight-cycle.sh), so plan-session walls
within the cap are NOT slow — the median rule alone fired on every
legitimate mode transition (44 false rows 2026-08-27..09-01, the
routed alert 2026-09-01-routed-slow-unit-dropin-20-workbeat.sh). Over
the envelope both rules flag. Fail-closed: missing/unparsable ledger
prints nothing and exits nonzero (caller skips silently).
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "jobs" / "slow-units.py"
CAP = 1800.0
ENVELOPE = CAP + 60.0


class SlowUnits(unittest.TestCase):
    def run_probe(self, units, text=None):
        with tempfile.NamedTemporaryFile("w", suffix=".json",
                                         delete=False) as f:
            f.write(text if text is not None
                    else json.dumps({"units": units}))
            path = f.name
        return subprocess.run(
            [sys.executable, "-B", str(PROBE), path],
            capture_output=True, text=True)

    def test_workbeat_in_envelope_never_flagged(self):
        # observed real walls: routed alert 657.7s, timeout-killed 1800.6s,
        # session-after-skip-window 229.4s, quick exit 0.06s
        for last, p50 in [(657.7, 150.0), (1800.6, 150.0),
                          (229.4, 0.2), (0.06, 18.04)]:
            r = self.run_probe([{"unit": "dropin:20-workbeat.sh",
                                 "last_wall_s": last, "p50_s": p50}])
            self.assertEqual((r.returncode, r.stdout.strip()),
                             (0, ""), (last, p50))

    def test_workbeat_over_envelope_flagged(self):
        r = self.run_probe([{"unit": "dropin:20-workbeat.sh",
                             "last_wall_s": ENVELOPE + 1.0,
                             "p50_s": 150.0}])
        self.assertEqual(r.stdout.strip(),
                         "dropin:20-workbeat.sh wall=1861.0s median=150.0s")

    def test_systemd_overnight_service_enveloped_too(self):
        # same overnight-cycle.sh behind systemd ExecStart
        r = self.run_probe([{"unit": "hngh-overnight.service",
                             "last_wall_s": 1799.0, "p50_s": 150.0}])
        self.assertEqual(r.stdout.strip(), "")

    def test_plain_unit_median_rule_still_fires(self):
        r = self.run_probe([{"unit": "dropin:01-system.sh",
                             "last_wall_s": 60.0, "p50_s": 1.8}])
        self.assertEqual(r.stdout.strip(),
                         "dropin:01-system.sh wall=60.0s median=1.8s")

    def test_plain_unit_within_median_rule_silent(self):
        r = self.run_probe([{"unit": "dropin:05-readout.sh",
                             "last_wall_s": 0.7, "p50_s": 0.7}])
        self.assertEqual(r.stdout.strip(), "")

    def test_bad_ledger_fail_closed(self):
        r = self.run_probe([], text="{not json")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "")

    def test_missing_ledger_fail_closed(self):
        r = subprocess.run(
            [sys.executable, "-B", str(PROBE), "/nonexistent/ledger.json"],
            capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
