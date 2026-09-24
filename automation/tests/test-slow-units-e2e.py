#!/usr/bin/env python3
"""slow-units e2e wiring — the backlog "Time ledger & delay flagging"
row's named review trigger. One synthetic slow unit travels the real
seam end to end (jobs/slow-units.py row -> oversight-tick.sh
probe_time_ledger/alert() -> report-queue bump args) and the two
parse/wiring contracts around it hold:

  (i)   fixture ledger -> exactly one row; two probe runs inside one
        identity+window both file `--identity KEY --window SECONDS` —
        the args shape report-queue's add() folds into one ` ×N` row
        (scripts/report-queue bump_row);
  (ii)  alert()'s flap layer: the same row twice inside SUPPRESS_MIN
        (60s) files exactly once; past the window it re-files with the
        SAME identity (the flap-suppressed alert feeding the steer
        path), one steer-feeding breadcrumb per filing;
  (iii) time-ledger.sh's three parse seams (systemd journal walls /
        [ceremony-timing] lines / drop-in-timing.log) round-trip into
        a temp time-ledger.json with the contract fields (unit,
        last_wall_s, p50_s, max_s / step, ms, ts).

Hermetic: temp trees only (sources read via symlink, never edited),
report-queue + breadcrumb mocked, no network, no STATE.md writes, no
/tmp/hngh-* state. The max(2*p50, 10.0) rule and ENVELOPE cases live
in test-slow-units.py and are deliberately NOT duplicated here.
"""

import contextlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import types
import unittest
import warnings
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SLOW_UNITS = ROOT / "jobs" / "slow-units.py"
OVERSIGHT = ROOT / "jobs" / "oversight-tick.sh"
TIME_LEDGER = ROOT / "jobs" / "time-ledger.sh"

ROW = "dropin:test-slow.sh wall=30.0s median=1.0s"
IDENT = "slow-unit:dropin:test-slow.sh"
# the bump args report-queue's --add path requires to fold occurrences
BUMP_ARGS = re.compile(r"--identity (\S+) --window (\d+)")

# fake report-queue: log argv, exit 0 (the filing seam alert() calls)
RQ = """\
#!/usr/bin/env bash
printf '%s\\n' "$*" >>"$RQ_LOG"
exit 0
"""

# driver preamble: source the seam cut, then mock breadcrumb so no
# STATE.md (real or fixture) is ever written
DRIVER = """\
set -u
. "$SB/cut.sh"
breadcrumb() { printf '%s|%s|%s\\n' "${1:-}" "${2:-}" "${3:-}" >>"$BREAD_LOG"; }
REPORT_QUEUE="$SB/rq"
"""


class SlowUnitsE2E(unittest.TestCase):
    def setUp(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        self.sb = Path(td.name)
        # lib/ + jobs/ symlinked read-only to the real tree; every
        # writable seam (ledger fixture, logs, alert state) is temp
        (self.sb / "lib").symlink_to(ROOT / "lib")
        (self.sb / "jobs").symlink_to(ROOT / "jobs")
        (self.sb / "dashboard").mkdir()
        rq = self.sb / "rq"
        rq.write_text(RQ)
        rq.chmod(0o755)
        self.rq_log = self.sb / "rq.log"
        self.bread_log = self.sb / "bread.log"
        self.alert_last = self.sb / "alert-last"
        for f in (self.rq_log, self.bread_log, self.alert_last):
            f.touch()
        self.env = dict(os.environ, SB=str(self.sb), HNGH_REPO=str(self.sb),
                        RQ_LOG=str(self.rq_log), BREAD_LOG=str(self.bread_log),
                        ALERT_LAST=str(self.alert_last),
                        ATTENTION_FLAG=str(self.sb / "attention"))

    def run_bash(self, script):
        p = subprocess.run(["bash", "-c", script], cwd=str(self.sb),
                           env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p

    def cut(self, func):
        """Source seam: top of jobs/oversight-tick.sh through FUNC's
        closing `}` at column 0 (the cut
        test-oversight-tick-alert-redact.sh established), so only the
        named seam is defined and nothing runs. ROOT/STATE_FILE are
        rewritten to the temp tree — the real tree is never touched."""
        text, started = [], False
        for line in OVERSIGHT.read_text().splitlines():
            text.append(line)
            if line.startswith(func + "()"):
                started = True
            elif started and line == "}":
                break
        self.assertTrue(started, "seam %s() missing from %s" % (func, OVERSIGHT))
        cut_text = re.sub(r"^ROOT=.*$", 'ROOT="%s"' % self.sb,
                          "\n".join(text), count=1, flags=re.M)
        cut_text = re.sub(r"^STATE_FILE=.*$",
                          'STATE_FILE="%s"' % (self.sb / "STATE.md"),
                          cut_text, count=1, flags=re.M)
        (self.sb / "cut.sh").write_text(cut_text + "\n")

    def ledger_fixture(self):
        """One synthetic slow unit (30s wall vs 1s median: over the
        max(2*p50, 10s) floor, no ENVELOPE) plus one fast decoy."""
        ledger = self.sb / "dashboard" / "time-ledger.json"
        ledger.write_text(json.dumps({
            "generated_at": "2026-09-24T00:00:00+00:00",
            "units": [
                {"unit": "dropin:test-slow.sh", "last_wall_s": 30.0,
                 "runs_24h": 1, "p50_s": 1.0, "max_s": 30.0},
                {"unit": "dropin:test-fast.sh", "last_wall_s": 2.0,
                 "runs_24h": 3, "p50_s": 1.5, "max_s": 2.0},
            ],
            "ceremonies": []}))
        return ledger

    def test_i_row_files_identity_window_bump_args(self):
        # the probe prints exactly one row for one synthetic slow unit
        r = subprocess.run(
            [sys.executable, "-B", str(SLOW_UNITS), str(self.ledger_fixture())],
            capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), [ROW])
        # two probe runs inside one identity+window (SUPPRESS_MIN=0 pins
        # the FILING seam here; the flap layer itself is case ii): each
        # run's row must file the identity+window args report-queue's
        # add() folds into one ` ×N` row
        self.cut("probe_time_ledger")
        self.run_bash(DRIVER
                      + "SUPPRESS_MIN=0\nprobe_time_ledger\nprobe_time_ledger\n")
        calls = self.rq_log.read_text().splitlines()
        self.assertEqual(len(calls), 2, calls)
        pairs = []
        for line in calls:
            self.assertTrue(line.startswith("--add alert "), line)
            self.assertIn("[oversight] slow-unit: " + ROW, line)
            m = BUMP_ARGS.search(line)
            self.assertIsNotNone(m, line)
            pairs.append(m.groups())
        self.assertEqual(pairs[0], (IDENT, "86400"))
        # same identity inside one window on the second filing = the
        # report-queue bump (not a fresh row)
        self.assertEqual(pairs[0], pairs[1])

    def test_ii_alert_flap_suppression_window(self):
        self.cut("alert")
        self.run_bash(DRIVER + (
            'SUPPRESS_MIN=60\n'
            'alert "slow-unit" "%s" "%s" 86400\n'
            'alert "slow-unit" "%s" "%s" 86400\n' % (ROW, IDENT, ROW, IDENT)))
        # second alert inside SUPPRESS_MIN -> exactly one filing
        calls = self.rq_log.read_text().splitlines()
        self.assertEqual(len(calls), 1, calls)
        crumbs = self.bread_log.read_text().splitlines()
        self.assertEqual(len(crumbs), 1, crumbs)
        job, event, detail = crumbs[0].split("|")
        self.assertEqual((job, event, detail),
                         ("oversight-tick", "alert", "slow-unit: " + ROW))
        # advance past the window without sleeping: alert() stores its
        # suppression key as `echo "$key $now"` (oversight-tick.sh:82) —
        # rewrite the epoch to now-120s
        old = int(time.time()) - 120
        self.alert_last.write_text(
            re.sub(r" [0-9]+$", " %d" % old,
                   self.alert_last.read_text(), flags=re.M))
        self.run_bash(DRIVER + (
            'SUPPRESS_MIN=60\n'
            'alert "slow-unit" "%s" "%s" 86400\n' % (ROW, IDENT)))
        # past the window the alert re-files carrying the SAME identity
        calls = self.rq_log.read_text().splitlines()
        self.assertEqual(len(calls), 2, calls)
        first = BUMP_ARGS.search(calls[0]).groups()
        second = BUMP_ARGS.search(calls[1]).groups()
        self.assertEqual(first, (IDENT, "86400"))
        self.assertEqual(second, first)
        # one steer-feeding breadcrumb per filing: the row
        # `ts | oversight-tick | alert | detail` (lib/breadcrumbs.sh:23)
        # is what steer_leg's `grep -E "steer|alert|optimize"`
        # (oversight-tick.sh:389) feeds the typed hazard gate
        crumbs = self.bread_log.read_text().splitlines()
        self.assertEqual(len(crumbs), 2, crumbs)
        for crumb in crumbs:
            self.assertEqual(crumb.split("|")[1], "alert")
            self.assertRegex(crumb, r"steer|alert|optimize")

    def test_iii_time_ledger_parse_round_trip(self):
        # time-ledger.sh's parse "functions" are its embedded python
        # heredoc — extract and exec it against fixture command output
        src = TIME_LEDGER.read_text()
        self.assertIn("<<'PYEOF'; then", src)
        body = src.split("<<'PYEOF'; then\n", 1)[1].split("\nPYEOF\n", 1)[0]
        # fail closed on script drift: all three parse seams present
        for seam in ('" over "', '" wall clock time"',
                     "[ceremony-timing]", "drop-in-timing.log"):
            self.assertIn(seam, body,
                          "time-ledger.sh parse seam moved; re-pin extraction")
        now = datetime.now(timezone.utc)
        t1 = (now - timedelta(minutes=8)).strftime("%Y-%m-%dT%H:%M:%SZ")
        t2 = (now - timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
        (self.sb / "logs").mkdir()
        (self.sb / "logs" / "drop-in-timing.log").write_text(
            "%s|99-fixture.sh|3.5\n%s|99-fixture.sh|7.25\n" % (t1, t2))
        journal = {
            "hngh-cadence-5m.service": (
                "2026-09-24T09:00:01 host systemd[871]: hngh-cadence-5m."
                "service: Consumed 0.500s CPU time over 1.000s wall clock"
                " time, 50.0M memory peak.\n"
                "2026-09-24T09:05:01 host systemd[871]: hngh-cadence-5m."
                "service: Consumed 1.000s CPU time over 2.000s wall clock"
                " time, 50.0M memory peak.\n"
                "2026-09-24T09:10:01 host systemd[871]: hngh-cadence-5m."
                "service: Consumed 3.000s CPU time over 6.000s wall clock"
                " time, 50.0M memory peak.\n"),
            "hngh-autonomy.service": (
                "2026-09-24T09:30:00 host hngh[871]: [ceremony-timing]"
                " mutation-check-push 2266 ms\n"
                "2026-09-24T09:30:05 host hngh[871]: [ceremony-timing]"
                " bridge flock wait 5 ms\n"),
        }

        def fake_run(cmd, **kw):
            if cmd[0] == "systemctl":
                out = "NEXT LEFT ...\nhngh-cadence-5m.service" \
                      " hngh-cadence-5m.service\n"
            elif cmd[0] == "journalctl":
                out = journal.get(cmd[cmd.index("-u") + 1], "")
            else:
                out = ""
            return types.SimpleNamespace(stdout=out)

        real_run, real_argv = subprocess.run, sys.argv
        subprocess.run, sys.argv = fake_run, ["time-ledger", str(self.sb),
                                              "24", "200"]
        out = io.StringIO()
        try:
            with warnings.catch_warnings(), contextlib.redirect_stdout(out):
                # time-ledger.sh reads its drop-in log with a bare
                # open().read(); the gc-close warning is its own noise
                warnings.simplefilter("ignore", ResourceWarning)
                exec(compile(body, "time-ledger.sh:PYEOF", "exec"),
                     {"__name__": "__ledger__"})
        finally:
            subprocess.run, sys.argv = real_run, real_argv

        # round-trip through a temp time-ledger.json, then assert the
        # contract fields
        ledger = self.sb / "time-ledger.json"
        ledger.write_text(out.getvalue())
        data = json.loads(ledger.read_text())
        self.assertIn("generated_at", data)
        # journal walls [1, 2, 6]: last_wall_s=last seen, p50_s=median,
        # max_s=worst; then the drop-in log row (even-n p50 average)
        self.assertEqual(data["units"], [
            {"unit": "hngh-cadence-5m.service", "last_wall_s": 6.0,
             "runs_24h": 3, "p50_s": 2.0, "max_s": 6.0},
            {"unit": "dropin:99-fixture.sh", "last_wall_s": 7.25,
             "runs_24h": 2, "p50_s": 5.375, "max_s": 7.25},
        ])
        # [ceremony-timing] rows: step (full label), ms, ts
        self.assertEqual(data["ceremonies"], [
            {"step": "mutation-check-push", "ms": 2266.0,
             "ts": "2026-09-24T09:30:00"},
            {"step": "bridge flock wait", "ms": 5.0,
             "ts": "2026-09-24T09:30:05"},
        ])


if __name__ == "__main__":
    unittest.main()
