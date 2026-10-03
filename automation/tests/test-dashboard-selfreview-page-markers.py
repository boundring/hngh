#!/usr/bin/env python3
"""PAGE_MARKERS coverage guard (plan 2026-09-14-routed-dash-served-index-5b4a1fb4).

Each dashboard-self-review.py PAGE_MARKERS entry asserts that a marker
must appear in the 200 body of its served page. When the dashboard pages
changed (f7e73c69: index.html became the broadsheet front page and the
verdict pills moved to console.html), the map kept
"index.html": "verdict-pill", so every hourly tick files an
unacceptable-now alert for a page that is healthy — the map is the
stale side, not the page.

Contract:
  every PAGE_MARKERS file exists in dashboard/ AND its marker string
  appears in that file's source; otherwise the guard fails with the
  exact (page, marker) pair, naming the stale side to fix.

No network, no secrets: PAGE_MARKERS is source-level truth; the live
served check itself is jobs/dashboard-self-review.py check_served().
"""

import unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "dashboard-self-review.py"
DASH = ROOT / "dashboard"


def load_job():
    loader = SourceFileLoader("dashboard_self_review_markers", str(JOB))
    spec = spec_from_loader(loader.name, loader)
    mod = module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class TestPageMarkers(unittest.TestCase):
    def test_every_marker_in_its_source_file(self):
        job = load_job()
        bad = []
        for name, marker in job.PAGE_MARKERS.items():
            page = DASH / name
            if not page.exists():
                bad.append((name, marker, "file missing"))
                continue
            if marker not in page.read_text(encoding="utf-8", errors="replace"):
                bad.append((name, marker, "marker absent from source"))
        self.assertEqual(
            bad, [],
            "PAGE_MARKERS names a marker its source page does not carry "
            "- fix the STALE side (map entry), not the page: " + str(bad))


if __name__ == "__main__":
    unittest.main()
