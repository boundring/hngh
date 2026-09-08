#!/usr/bin/env python3
"""dashboard feed-writer tmp-isolation contract.

Two writers sharing one tmp filename can corrupt a dashboard feed even
with tmp+rename "atomic" writes: when writer A renames the shared tmp to
the target, writer B's already-open fd keeps pointing at the renamed
inode — B's subsequent dump lands INSIDE the live target, leaving
doc-B + doc-A-tail (the 2026-09-01 11:30Z collision of the 30m
05-readout.sh tier with the morning-report refresh-dashboard.sh
ExecStartPost produced exactly that: feed-valid:readout.json
"Extra data: line 331 column 1 (char 7876)", corrupt for 30 minutes
until the next solo 30m refresh).

Contract: every dashboard-JSON writer must (a) build its tmp name
per-process (shell `$$` / python os.getpid()) so no two processes ever
share an inode behind the rename, (b) keep the `.tmp` suffix so the
gitignore `*.tmp` still hides crash lingers from the artifact sweep,
and (c) publish via rename/os.replace, never an in-place rewrite.

These are textual contract checks on purpose: the writers hardcode the
live dashboard dir (no sandbox), so the honest runnable regression is
the contract itself plus the finding's own check (dashboard-self-review)
as end-to-end evidence.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SHELL_WRITERS = {
    "cadence/30m/05-readout.sh": ".readout.json.$$.tmp",
    "jobs/refresh-dashboard.sh": ".readout.json.$$.tmp",
    "jobs/time-ledger.sh": '"$LEDGER.$$.tmp"',
}

PY_WRITERS = (
    "jobs/sessions-feed.py",
    "jobs/operator-items-feed.py",
    "jobs/schedule-feed.py",
    "jobs/plan-feed.py",
    "jobs/kb-feed.py",
    "lib/common.sh",  # update_dashboard heredoc writes data.json
)


class TmpIsolation(unittest.TestCase):
    def test_shell_writers_use_per_pid_tmp(self):
        for rel, marker in SHELL_WRITERS.items():
            text = (ROOT / rel).read_text()
            self.assertIn(marker, text,
                          f"{rel}: shared fixed tmp name — a concurrent "
                          "writer's fd survives the rename and corrupts "
                          "the live file")

    def test_shell_writers_publish_by_rename(self):
        for rel in ("cadence/30m/05-readout.sh", "jobs/refresh-dashboard.sh"):
            text = (ROOT / rel).read_text()
            self.assertRegex(text, r'mv "\$tmp"')

    def test_py_writers_use_per_pid_tmp(self):
        for rel in PY_WRITERS:
            text = (ROOT / rel).read_text()
            self.assertRegex(
                text, r'tmp = .*os\.getpid\(\)',
                f"{rel}: tmp name is not per-process")

    def test_py_writers_publish_by_replace(self):
        for rel in PY_WRITERS:
            text = (ROOT / rel).read_text()
            self.assertIn("os.replace(", text, rel)

    def test_tmp_names_keep_the_gitignored_tmp_suffix(self):
        # crash lingers must stay invisible to the sweep's `git add`
        for rel, marker in SHELL_WRITERS.items():
            text = (ROOT / rel).read_text()
            for line in text.splitlines():
                if "tmp=" in line or "tmp = " in line:
                    self.assertIn(".tmp", line,
                                f"{rel}: {line.strip()!r} loses the *.tmp "
                                "gitignore cover")
        for rel in PY_WRITERS:
            text = (ROOT / rel).read_text()
            for line in text.splitlines():
                # only the feed-write tmp (the one naming its target);
                # unrelated scratch tmps (e.g. transcript parse) don't
                # land in the dashboard dir
                if "tmp = " in line and re.search(
                        r"\bOUT\b|\boutpath\b|\bKB_DIR\b", line):
                    self.assertIn(".tmp", line,
                              f"{rel}: {line.strip()!r} loses the *.tmp "
                              "gitignore cover")


if __name__ == "__main__":
    unittest.main()