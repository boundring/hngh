#!/usr/bin/env python3
"""The narrative daily ledger + public dispatch edition, hermetic.

Fixture kernel repo + fixture automation feeds (nothing real touched,
no network): the journal writer emits "The day's story" AFTER the
machine-checked ledger with the ledger intact; jobs/digest-public.py
renders a masthead whose THE LEDGER numbers match the fixture telemetry;
the README dispatch sentinels stay byte-identical outside the sentinel
block; and the full --daily path writes journal + dispatch edition.
"""
import importlib.machinery
import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent  # kernel repo root

DAY = "2026-09-11"


def _load_kernel_writer():
    """Load scripts/generate-publication (no .py suffix) with ROOT pinned
    to the fixture via HNGH_PUB_ROOT."""
    loader = importlib.machinery.SourceFileLoader(
        "genpub", str(REPO / "scripts" / "generate-publication"))
    spec = importlib.util.spec_from_loader("genpub", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_digest_public(repo):
    """Load the renderer CODE from the real repo; the fixture is only
    the data root passed to its functions."""
    loader = importlib.machinery.SourceFileLoader(
        "digest_public", str(REPO / "automation" / "jobs" / "digest-public.py"))
    spec = importlib.util.spec_from_loader("digest_public", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
FIXTURE_DIGEST = """\
## 0300 {day}
_sources: hn-topstories,phoronix | model: fixture-model_
CRITICAL: Fixture routerOS privilege escalation (https://example.test/cve).
NOTABLE: Fixture linker rewritten in Rust (https://example.test/rust).

### NEWS FROM THE MEGASTRUCTURE {day}

<!-- feeds: logs/budget.md -->
- sessions: 2 launched today across 1 plan lane(s); newest: lane-a at 03:00.
""".format(day=DAY)


class Fixture:
    """A tmp kernel repo with fixture automation feeds for DAY."""

    def __enter__(self):
        self.tmp = Path(tempfile.mkdtemp())
        auto = self.tmp / "automation"
        for sub in ("logs", "dashboard", "state", "digest"):
            (auto / sub).mkdir(parents=True)
        for sub in ("docs/journal", "docs/project", "docs/dispatch"):
            (self.tmp / sub).mkdir(parents=True)
        (auto / "logs" / "budget.md").write_text(
            "%s | lane-a | session-run\n%s | lane-b | session-run\n"
            "%s | other | cron\n" % (DAY, DAY, DAY))
        db = auto / "dashboard" / "telemetry.db"
        con = sqlite3.connect(db)
        con.execute("CREATE TABLE events(ts TEXT, source TEXT, kind TEXT,"
                    " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
                    " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
                    " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        con.executemany(
            "INSERT INTO events(ts, kind, tokens_in, cost_usd) VALUES(?,?,?,?)",
            [("2026-09-11T03:00:00Z", "session-cost", 1000, 0.50),
             ("2026-09-11T09:15:00Z", "session-cost", 4000, 0.75)])
        con.commit()
        con.close()
        (auto / "dashboard" / "plans.json").write_text(json.dumps(
            {"plans": [{"accepted": DAY + "T01:00:00Z", "status": "executed"},
                       {"accepted": DAY + "T02:00:00Z", "status": "armed"}],
             "queue_next": "wake-mutation-lane"}))
        (auto / "dashboard" / "operator-items.json").write_text(json.dumps(
            {"items": [{"status": "open"}, {"status": "handled"}]}))
        (auto / "research-lines.tsv").write_text(
            "l1\tplanned\tx\tx\nl2\treviewed\tx\tx\n")
        (auto / "state" / "beat-blockers.tsv").write_text(
            "blk-20260911-overnight\tovernight\tbad-execution\t"
            "2026-09-11T20:00:48Z\t1\tactive\n")
        (auto / "state" / "ocgo-agent-lessons.md").write_text(
            "2026-09-11T03:34:05Z | unknown | lesson one\n"
            "2026-09-11T13:45:25Z | unknown | lesson two\n")
        (self.tmp / "docs" / "project" / ("lessons-" + DAY + ".md")).write_text(
            "# Lessons\n- 2026-09-10-opencode-go-leg.md\n"
            "- 2026-09-11-omp-integration.md\n")
        (auto / "digest" / (DAY + ".md")).write_text(FIXTURE_DIGEST)
        subprocess.run(["git", "init", "-q", str(self.tmp)], check=True)
        for k, v in (("user.email", "t@t"), ("user.name", "t")):
            subprocess.run(["git", "-C", str(self.tmp), "config", k, v],
                           check=True)
        (self.tmp / "docs" / "project" / "checkin.md").write_text("")
        (self.tmp / "docs" / "project" / "timeline.md").write_text("")
        subprocess.run(["git", "-C", str(self.tmp), "add", "-A"], check=True)
        env = dict(os.environ, GIT_AUTHOR_DATE=DAY + "T12:00:00",
                   GIT_COMMITTER_DATE=DAY + "T12:00:00")
        subprocess.run(["git", "-C", str(self.tmp), "commit", "-qm",
                        "test: fixture"], env=env, check=True)
        return self.tmp

    def __exit__(self, *exc):
        subprocess.run(["rm", "-rf", str(self.tmp)], check=True)
        return False


class TestJournalNarrative(unittest.TestCase):
    def setUp(self):
        self.fix = Fixture().__enter__()
        os.environ["HNGH_PUB_ROOT"] = str(self.fix)
        self.genpub = _load_kernel_writer()

    def tearDown(self):
        del os.environ["HNGH_PUB_ROOT"]
        subprocess.run(["rm", "-rf", str(self.fix)], check=True)

    def test_story_after_ledger_with_ledger_intact(self):
        text = self.genpub.build_journal(DAY)
        ledger = text.index("## The ledger (machine-checked)")
        story = text.index("## The day's story")
        book = text.index("## The book of the day")
        self.assertLess(ledger, story)
        self.assertLess(story, book)
        self.assertIn("- **1** commits; **0** candidate-bound.", text)
        self.assertIn("- **0** check-ins (none).", text)
        self.assertIn("- Public edition: docs/dispatch/%s.md" % DAY, text)

    def test_story_paragraphs_grounded(self):
        text = self.genpub.story_section(DAY)
        # budget.md date-prefix lines (the megastructure block's count):
        # 2 session-run + 1 cron row = 3 across 3 lanes
        self.assertIn("The hall fired 3 session(s) across 3 plan lane(s)",
                      text)
        self.assertIn("$1.25", text)
        self.assertIn("tokens in 5,000", text)
        self.assertIn("queue points at 'wake-mutation-lane'", text)
        self.assertIn("Fixture routerOS privilege escalation", text)
        self.assertIn("overnight stalled (bad-execution, x1) and now "
                      "sits active", text)
        self.assertIn("2 session lesson(s)", text)
        self.assertIn("2 new lesson-bearing record(s)", text)
        self.assertIn("Verdict: advancing", text)
        self.assertIn("<!-- feeds: automation/state/beat-blockers.tsv -->",
                      text)

    def test_story_skips_when_feeds_missing(self):
        # all feeds gone: no telemetry, no digest, no blockers, no
        # lessons -> the story still renders, structured and honest
        (self.fix / "automation" / "dashboard" / "telemetry.db").unlink()
        (self.fix / "automation" / "digest" / (DAY + ".md")).unlink()
        (self.fix / "automation" / "state" / "beat-blockers.tsv").unlink()
        (self.fix / "automation" / "state" / "ocgo-agent-lessons.md").unlink()
        text = self.genpub.story_section(DAY)
        self.assertIn("stall ledger is quiet", text)
        self.assertIn("Verdict:", text)


class TestDigestPublic(unittest.TestCase):
    def test_masthead_numbers_match_fixture_telemetry(self):
        with Fixture() as fix:
            dp = _load_digest_public(fix)
            page = dp.render_page(DAY, str(fix))
            self.assertIn("Edition no. 1 | %s" % DAY, page)
            self.assertIn("- metered spend: $1.25 across 2 model calls (24h).",
                          page)
            self.assertIn("- tokens in: 5,000.", page)
            self.assertIn("- research beats: 0;", page)
            self.assertIn("Fixture routerOS privilege escalation", page)
            self.assertIn("sessions: 2 launched today", page)

    def test_write_publication_writes_file(self):
        with Fixture() as fix:
            dp = _load_digest_public(fix)
            target = dp.write_publication(DAY, str(fix))
            self.assertEqual(
                target, str(fix / "docs" / "dispatch" / (DAY + ".md")))
            text = Path(target).read_text()
            self.assertIn("## THE LEDGER", text)
            self.assertIn("docs/journal/%s.md" % DAY, text)

    def test_write_publication_fails_open(self):
        with Fixture() as fix:
            (fix / "automation" / "digest" / (DAY + ".md")).unlink()
            dp = _load_digest_public(fix)
            self.assertIsNone(dp.write_publication(DAY, str(fix)))


class TestSentinelsAndDaily(unittest.TestCase):
    def test_readme_sentinels_byte_identical_outside(self):
        with Fixture() as fix:
            readme = fix / "README.md"
            readme.write_text(
                "# Fixture\n\n<!-- dispatch:begin -->\n| old row |\n"
                "<!-- dispatch:end -->\n\ntail text stays\n")
            os.environ["HNGH_PUB_ROOT"] = str(fix)
            genpub = _load_kernel_writer()
            rc = genpub.readme_dispatch(DAY, str(readme))
            os.environ.pop("HNGH_PUB_ROOT", None)
            self.assertEqual(rc, 0)
            text = readme.read_text()
            self.assertIn("# Fixture\n\n<!-- dispatch:begin -->", text)
            self.assertIn("tail text stays\n", text)
            self.assertIn("| %s | 2 | $1.25 | 1 | 1 |" % DAY, text)

    def test_readme_without_sentinels_refused(self):
        with Fixture() as fix:
            readme = fix / "README.md"
            readme.write_text("# no sentinels\n")
            os.environ["HNGH_PUB_ROOT"] = str(fix)
            genpub = _load_kernel_writer()
            self.assertEqual(genpub.readme_dispatch(DAY, str(readme)), 1)
            os.environ.pop("HNGH_PUB_ROOT", None)
            self.assertIn("no sentinels", readme.read_text())

    def test_daily_writes_journal_and_dispatch(self):
        with Fixture() as fix:
            env = dict(os.environ, HNGH_PUB_ROOT=str(fix))
            out = subprocess.run(
                [str(REPO / "scripts" / "generate-publication"),
                 "--daily", "--force", DAY],
                env=env, capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)
            journal = (fix / "docs" / "journal" / (DAY + ".md")).read_text()
            self.assertIn("## The day's story", journal)
            dispatch = (fix / "docs" / "dispatch" / (DAY + ".md")).read_text()
            self.assertIn("## THE LEDGER", dispatch)
            # --check still verifies the machine ledger
            chk = subprocess.run(
                [str(REPO / "scripts" / "generate-publication"),
                 "--check", DAY], env=env, capture_output=True, text=True)
            self.assertEqual(chk.returncode, 0, chk.stdout + chk.stderr)




class TestSaga(unittest.TestCase):
    def test_saga_renders_blocker_and_lessons_with_footnotes(self):
        with Fixture() as fix:
            dp = _load_digest_public(fix)
            page = dp.render_page(DAY, str(fix))
            self.assertIn("## The Saga", page)
            self.assertIn("symbolic register; facts are the cited ledgers",
                          page)
            self.assertIn("a creature that knew the shape and stumbled at "
                          "the gate", page)
            self.assertIn("it paces the hall still, watched", page)
            self.assertIn("[^bblk-20260911-overnight]: state/"
                          "beat-blockers.tsv | lane overnight | cause "
                          "bad-execution | x1 | active", page)
            self.assertIn("The night-watch filed 2 lesson(s) before the "
                          "dawn (unknown x2); the dream pass keeps the "
                          "watch awake. [^l2026-09-11]", page)
            self.assertIn("[^l2026-09-11]: automation/state/"
                          "ocgo-agent-lessons.md | classes unknown.", page)
            # the cap: under 8 content lines a day
            saga = page[page.index("## The Saga"):
                        page.index("## Reading room")]
            body = [ln for ln in saga.splitlines()
                    if ln and not ln.startswith("#")
                    and "symbolic register" not in ln]
            self.assertLessEqual(len(body), 8)

    def test_saga_parked_is_sealed_wing_and_absent_when_quiet(self):
        with Fixture() as fix:
            dp = _load_digest_public(fix)
            rows = (fix / "automation" / "state" /
                    "beat-blockers.tsv").read_text()
            rows = rows.replace("active", "parked")
            (fix / "automation" / "state" / "beat-blockers.tsv") \
                .write_text(rows)
            saga = dp.saga_md(DAY, str(fix))
            self.assertIn("the park sealed it in a quiet wing",
                          " ".join(saga))
            (fix / "automation" / "state" / "beat-blockers.tsv").unlink()
            (fix / "automation" / "state" / "ocgo-agent-lessons.md").unlink()
            self.assertEqual(dp.saga_md(DAY, str(fix)), [])
            page = dp.render_page(DAY, str(fix))
            self.assertNotIn("## The Saga", page)


if __name__ == "__main__":
    unittest.main(verbosity=2)
