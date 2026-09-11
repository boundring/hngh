#!/usr/bin/env python3
"""Feedback auto-apply pipeline, hermetic.

Operator interactivity directive (2026-09-11), apply slice: [quick]
css-theme/data-format items map to whitelisted one-line property edits on
dashboard/style.css; correction items get an inspection report row, never
an edit; anything not parseable to the whitelist stays unapplied. All
paths are seamed to a tmp fixture (style.css, operator-items.json, state
tsv, APPLIED.md, report-queue root); the named check runs a fake test
script under the fixture. No real dashboard files, no network.
"""
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


FIXTURE_CSS = """\
/* fixture */
:root { --bg: #0d1117; --ink: #e6edf3; }
html, body { margin: 0; color: var(--ink);
  font: 14px/1.45 -apple-system, sans-serif; }
header { display: flex; gap: 12px; padding: 5px 8px;
  border-bottom: 1px solid var(--line); }
.sub { color: var(--muted); font-size: 10.5px; margin-left: 4px; }
"""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="fbapply-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.dash = self.tmp / "dashboard"
        (self.dash / "feedback").mkdir(parents=True)
        (self.tmp / "state").mkdir()
        (self.dash / "style.css").write_text(FIXTURE_CSS)
        self.items = self.dash / "operator-items.json"
        self.applied = self.dash / "feedback" / "APPLIED.md"
        fa = _load("feedback_apply", "jobs/feedback-apply.py")
        self.fa = fa
        fa.AUTOMATION_ROOT = str(self.tmp)
        fa.STATE_MD = str(self.tmp / "STATE.md")
        fa.STYLE = str(self.dash / "style.css")
        fa.STATE_TSV = str(self.tmp / "state" / "feedback-applied.tsv")
        fa.APPLIED_MD = str(self.applied)
        fa.ITEMS_JSON = str(self.items)
        fa.REPORT_KERNEL = str(ROOT.parent)  # real scripts/report-queue
        os.environ["HNGH_REPORT_ROOT"] = str(self.tmp / "report-root")

    def load_items(self, rows):
        self.items.write_text(json.dumps(
            {"items": [{"id": k, "text": v} for k, v in rows]}))

    def css(self):
        return (self.dash / "style.css").read_text()


class ApplyTest(Base):
    def test_font_plus_applies_clamped_edit_and_records_history(self):
        self.load_items([(
            "f1", "feedback-ingest | alert | "
            "[feedback:css-theme][quick] header: increase base font size")])
        self.assertEqual(self.fa.main([]), 0)
        css = self.css()
        self.assertIn("font: 16px/1.45", css)  # 14px + 2px, once
        self.assertEqual(css.count("16px/1.45"), 1)
        line = self.applied.read_text().strip().splitlines()[-1]
        self.assertIn("f1", line)
        self.assertIn("14px", line)  # previous value carried on the line
        row = (self.tmp / "state" / "feedback-applied.tsv"
               ).read_text().strip().splitlines()[-1].split("\t")
        self.assertIn("f1", row[0])
        self.assertEqual(row[3], "14px")  # old value in durable state
        self.assertEqual(len(row[-1]), 64)  # sha256 of the edited file

    def test_color_value_applies_to_matched_rule(self):
        self.load_items([(
            "f4", "feedback-ingest | alert | "
            "[feedback:css-theme][quick] .sub: use color #ff0000")])
        self.fa.main([])
        self.assertIn(".sub { color: #ff0000;", self.css())

    def test_non_whitelisted_request_stays_unapplied(self):
        css_before = self.css()
        self.load_items([(
            "f2", "feedback-ingest | alert | "
            "[feedback:css-theme][quick] header: make it pop")])
        self.assertEqual(self.fa.main([]), 0)
        self.assertEqual(self.css(), css_before)
        self.assertFalse(self.applied.exists())
        self.assertFalse((self.tmp / "state" / "feedback-applied.tsv")
                         .exists())

    def test_no_matching_element_appends_rule_within_cap(self):
        self.load_items([(
            "f5-%d" % i, "feedback-ingest | alert | "
            "[feedback:css-theme][quick] widget%d: increase panel gap"
            % i) for i in range(6)])
        self.fa.main([])
        # cap: 5 appended rules per beat, the 6th refused with a note
        self.assertEqual(self.css().count("gap: 14px; }"), 5)
        self.assertIn("append cap (5) reached",
                      self.applied.read_text())

    def test_baseline_clamp_stops_runaway_growth(self):
        for i in range(9):  # 2px x 8 = 16px total drift, 9th refused
            self.fa.apply_change(
                "font-size", +1, "html, body", "clamp-%d" % i)
        css = self.css()
        self.assertIn("font: 30px/1.45", css)  # 14 + 16 clamp ceiling
        self.assertNotIn("font: 32px", css)
        self.assertIn("baseline clamp refused", self.applied.read_text())

    def test_revert_last_restores_previous_value(self):
        self.fa.apply_change("font-size", +1, "html, body", "rv1")
        self.fa.apply_change("gap", +1, "header", "rv2")
        self.assertIn("font: 16px/1.45", self.css())
        self.assertIn("gap: 14px", self.css())
        self.assertEqual(self.fa.revert_last(), 0)  # reverts rv2
        self.assertIn("gap: 12px", self.css())
        self.assertIn("font: 16px/1.45", self.css())  # rv1 untouched
        self.assertEqual(self.fa.revert_last(), 0)  # reverts rv1
        self.assertIn("font: 14px/1.45", self.css())
        self.assertNotIn("font: 16px/1.45", self.css())

    def test_revert_last_on_empty_history_is_a_clean_noop(self):
        self.assertEqual(self.fa.revert_last(), 0)


class CorrectionTest(Base):
    def test_correction_item_runs_named_check_and_files_report(self):
        check = self.tmp / "tests"
        check.mkdir()
        (check / "test-fake.sh").write_text("#!/usr/bin/env bash\necho ok\n")
        os.chmod(check / "test-fake.sh", 0o755)
        self.load_items([(
            "f3", "feedback-ingest | alert | "
            "[feedback:correction] tests: check tests/test-fake.sh")])
        self.assertEqual(self.fa.main([]), 0)
        reports = (self.tmp / "report-root" / "docs" / "project")
        self.assertTrue((reports / "reports.md").exists())
        # never an edit: style.css unchanged by a correction item
        self.assertEqual(self.css(), FIXTURE_CSS)

    def test_correction_without_named_check_reports_no_check(self):
        self.load_items([(
            "f6", "feedback-ingest | alert | "
            "[feedback:correction] layout: something looks off")])
        self.assertEqual(self.fa.main([]), 0)
        body = (self.tmp / "report-root" / "docs" / "project" /
                "report-bodies")
        self.assertTrue(any(b.exists() for b in body.glob("*.md")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
