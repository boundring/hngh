#!/usr/bin/env python3
"""email-qa scorer contract, hermetic — fixture digests and the
HNGH_NOTIFY_EMAIL_CONF seam only; no real digests, logs, or secrets.
"""

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QA = ROOT / "scripts" / "email-qa.py"

_spec = importlib.util.spec_from_file_location("email_qa", QA)
email_qa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(email_qa)

GOOD = """# hngh daily digest 2026-09-03

status: OK
changed: 1 commit(s), +2 plan steps in 24h, 0 research doc(s) crystallized
spend: no cost data in telemetry (target $10/day)
action needed: no

## Operator items awaiting you
(nothing awaiting the operator)

## Progress (plans + queue, 24h)
  (all plans executed/rejected)
kernel queue: 0 queued rows
plan-supply: 0 accepted plans with unchecked steps
pace: steady (0 steps in 24h)

## Research
crystallized (kernel docs/research, 24h):
  (none in the last 24h)
untracked pending crystallization (automation):
  (none)
lessons harvested: (no lesson harvest found)

## Commits (24h)
1 commit(s) across both repos — kernel 1, automation 0.
kernel:
  abc1234 a commit subject
automation:
  (none)

## Alerts (last 24h)
none — quiet window

## Budget (telemetry)
telemetry fixture text

--
full digest: logs/email-digest-2026-09-03.md | dashboard: http://127.0.0.1:8890
"""


class EmailQa(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        os.environ.pop("HNGH_NOTIFY_EMAIL_CONF", None)

    def score(self, text):
        return email_qa.findings(text, secret=None)

    def test_well_formed_digest_passes(self):
        self.assertEqual(self.score(GOOD), [])

    def test_missing_digest_is_a_finding(self):
        self.assertEqual(self.score(""), ["digest file missing or empty"])

    def test_missing_tldr_head(self):
        bad = GOOD.replace("status: OK\n", "", 1)
        f = self.score(bad)
        self.assertTrue(any("TL;DR" in x for x in f), f)

    def test_empty_section(self):
        bad = GOOD.replace(
            "## Alerts (last 24h)\nnone — quiet window\n",
            "## Alerts (last 24h)\n", 1)
        f = self.score(bad)
        self.assertTrue(any("empty: Alerts" in x for x in f), f)

    def test_too_long(self):
        bad = GOOD + "\n".join("filler %d" % i for i in range(120))
        f = self.score(bad)
        self.assertTrue(any("too long" in x for x in f), f)

    def test_attention_vs_quiet_inconsistency(self):
        bad = GOOD.replace("status: OK", "status: ATTENTION: 2 alert(s) in 24h")
        f = self.score(bad)
        self.assertTrue(any("alerts section is quiet" in x for x in f), f)

    def test_listed_alerts_with_ok_headline(self):
        bad = GOOD.replace("## Alerts (last 24h)\nnone — quiet window\n",
                           "## Alerts (last 24h)\n  gate red: make test failed\n")
        f = self.score(bad)
        self.assertTrue(any("headline says OK" in x for x in f), f)

    def test_secret_leak_finding_never_echoes_the_value(self):
        f = email_qa.findings(GOOD, secret="sekret-pw-1234")
        self.assertEqual(f, [])  # no leak in GOOD: no finding
        leaked = GOOD.replace("telemetry fixture text",
                              "text with sekret-pw-1234 inside")
        f = email_qa.findings(leaked, secret="sekret-pw-1234")
        self.assertEqual(len(f), 1)
        self.assertIn("SECRET LEAK", f[0])
        self.assertNotIn("sekret-pw-1234", f[0])  # the value is never echoed

    def test_no_section_summary_prefix(self):
        self.assertNotIn("Section summary", GOOD)

    def test_banned_adjectives_fire_and_clean_passes(self):
        hourly = self.tmp / "hourly.md"
        clean = ("## 1000 2026-09-06\n"
                 "CRITICAL: RCE in WidgetServer 2.3 allows unauthenticated takeover\n")
        hourly.write_text(clean)
        self.assertEqual(self.score(GOOD), [])
        f = email_qa.voice_findings(GOOD)  # no path, no env: skipped
        self.assertEqual(f, [])
        dirty = clean + (
            "## 1100 2026-09-06\n"
            "NOTABLE: a historic major significant groundbreaking release\n")
        hourly.write_text(dirty)
        f = email_qa.voice_findings(GOOD, str(hourly))
        self.assertEqual(len(f), 1, f)
        self.assertIn("significance adjectives x4", f[0])

    def test_chatter_repeated_item_fires(self):
        hourly = self.tmp / "hourly.md"
        item = "CRITICAL: RCE in WidgetServer 2.3 allows unauthenticated takeover"
        hourly.write_text("".join("## %d00 2026-09-06\n%s\n" % (h, item)
                                  for h in (10, 11, 12)))
        f = email_qa.voice_findings(GOOD, str(hourly))
        self.assertEqual(len(f), 1, f)
        self.assertIn("chatter:", f[0])
        self.assertIn("repeated 3 times", f[0])

    def test_cli_prints_one_verdict_line(self):
        digest = self.tmp / "digest.md"
        digest.write_text(GOOD)
        p = subprocess.run(
            [sys.executable, str(QA), "--digest", str(digest)],
            capture_output=True, text=True, timeout=30,
            env=dict(os.environ,
                     HNGH_NOTIFY_EMAIL_CONF=str(self.tmp / "absent"),
                     HNGH_AUTOMATION_ROOT=str(self.tmp)))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertRegex(p.stdout.strip(), r"^email-qa \d{4}-\d{2}-\d{2}: PASS$")

    def test_cli_finding_verdict_line(self):
        digest = self.tmp / "digest.md"
        digest.write_text("# hngh daily digest\n\nno head here\n")
        p = subprocess.run(
            [sys.executable, str(QA), "--digest", str(digest)],
            capture_output=True, text=True, timeout=30,
            env=dict(os.environ,
                     HNGH_NOTIFY_EMAIL_CONF=str(self.tmp / "absent"),
                     HNGH_AUTOMATION_ROOT=str(self.tmp)))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertRegex(p.stdout, r"^email-qa \d{4}-\d{2}-\d{2}: FINDINGS \d+: ")


if __name__ == "__main__":
    unittest.main()
