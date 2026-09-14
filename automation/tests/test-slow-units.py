#!/usr/bin/env python3
"""slow-units contract (oversight probe_time_ledger): a unit is flagged
when its last wall exceeds max(2x trailing p50, 10s floor) — unless the
wall is inside the unit's design envelope. The workbeat is bimodal BY
The workbeat is multimodal BY
DESIGN (skip-exit ~0.2s / bounded beat ~150-240s / dream leg up to 600s
+ timeout-capped session up to 1800s in overnight-cycle.sh), so plan-session
walls within the cap are NOT slow
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
DREAM = 600.0  # OVERNIGHT_DREAM_TIMEOUT, synchronous inside the same wall
ENVELOPE = CAP + DREAM + 60.0


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
        # session-after-skip-window 229.4s, quick exit 0.06s; since the
        # 2026-09-10 dream leg: routed alert 1964.6s and time-ledger max
        # 2384.771s (both dream+session work, under 2460 = 1800+600+60)
        for last, p50 in [(657.7, 150.0), (1800.6, 150.0),
                          (229.4, 0.2), (0.06, 18.04),
                          (1964.6, 40.3), (2384.771, 799.257)]:
            r = self.run_probe([{"unit": "dropin:20-workbeat.sh",
                                 "last_wall_s": last, "p50_s": p50}])
            self.assertEqual((r.returncode, r.stdout.strip()),
                             (0, ""), (last, p50))
            r = self.run_probe([{"unit": "dropin:20-workbeat.sh",
                                 "last_wall_s": last, "p50_s": p50}])
            self.assertEqual((r.returncode, r.stdout.strip()),
                             (0, ""), (last, p50))

    def test_workbeat_over_envelope_flagged(self):
        r = self.run_probe([{"unit": "dropin:20-workbeat.sh",
                             "last_wall_s": ENVELOPE + 1.0,
                             "p50_s": 150.0}])
        self.assertEqual(r.stdout.strip(),
                         "dropin:20-workbeat.sh wall=2461.0s median=150.0s")

    def test_systemd_overnight_service_enveloped_too(self):
        # same overnight-cycle.sh behind systemd ExecStart
        r = self.run_probe([{"unit": "hngh-overnight.service",
                             "last_wall_s": 1799.0, "p50_s": 150.0}])
        self.assertEqual(r.stdout.strip(), "")

    def test_remote_push_in_envelope_never_flagged(self):
        # 16-remote-push.sh is bimodal by design: skip-exit ~0.0s (median),
        # but the red/stale-gate branch re-runs the kernel gate inline under
        # `timeout 290 make test` — observed walls 28.6-40.8s while the
        # 2026-09-13 gate-red crumb stood (432 duplicate slow-unit alerts
        # through 2026-09-14). The script's own upstream cap is 290s.
        for last, p50 in [(28.6, 0.016), (40.8, 0.0), (289.0, 0.0)]:
            r = self.run_probe([{"unit": "dropin:16-remote-push.sh",
                                 "last_wall_s": last, "p50_s": p50}])
            self.assertEqual((r.returncode, r.stdout.strip()),
                             (0, ""), (last, p50))

    def test_remote_push_over_envelope_flagged(self):
        r = self.run_probe([{"unit": "dropin:16-remote-push.sh",
                             "last_wall_s": 350.1, "p50_s": 0.016}])
        self.assertEqual(r.stdout.strip(),
                         "dropin:16-remote-push.sh wall=350.1s median=0.0s")

    def test_research_beat_in_envelope_never_flagged(self):
        # 33-research-beat.sh is bimodal by design: throttled failfirst
        # skip-exit ~0.2s (the median), GO ticks run bounded model_call
        # work — observed 28.3-552.5s (time-ledger max 501.3s; p50 drifts
        # 0.2 -> 146.2s as GO ticks cluster, so the median rule alone
        # fires on every legitimate mode transition — the routed alert
        # 2026-09-12, identity re-routed 5x since 2026-09-08). 800s is
        # the parked disposition's own revisit threshold (~2x the
        # model-call ceiling), +60s margin.
        for last, p50 in [(28.3, 0.1), (137.4, 0.2), (552.5, 108.9),
                          (501.3, 146.2)]:
            r = self.run_probe([{"unit": "dropin:33-research-beat.sh",
                                 "last_wall_s": last, "p50_s": p50}])
            self.assertEqual((r.returncode, r.stdout.strip()),
                             (0, ""), (last, p50))

    def test_research_beat_over_envelope_flagged(self):
        r = self.run_probe([{"unit": "dropin:33-research-beat.sh",
                             "last_wall_s": 861.0, "p50_s": 0.2}])
        self.assertEqual(r.stdout.strip(),
                         "dropin:33-research-beat.sh wall=861.0s median=0.2s")

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
