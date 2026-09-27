#!/usr/bin/env python3
"""Hermetic tests for typesafe-docs-ingest.py + ts-kb-probe.py (slice 3).

Feeds a fixture llms.txt + pages through --source-dir (no network),
asserts node/edge construction, FTS recall, idempotent refresh, the
--limit cap, the all-failed exit code, and the catalog row in a
sandboxed HNGH_HOME_DIR.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent
INGEST = AUTO / "scripts" / "typesafe-docs-ingest.py"
PROBE = AUTO / "scripts" / "ts-kb-probe.py"

LLMS = """# TypeSafe AI

- [Alpha page](https://docs.typesafe.ai/alpha.md): the alpha concept page
- [Beta page](https://docs.typesafe.ai/beta.md): the beta recipe page
- [Gamma page](https://docs.typesafe.ai/gamma.md): never present (404)
"""

ALPHA = """# Alpha
See [the beta page](https://docs.typesafe.ai/beta.md) for the recipe.
Relative link: [beta again](/beta.md).
Untracked link: [nope](https://example.com/other.md).
"""

BETA = """# Beta
Score levels are ordered. Confidence gates whether code acts.
Back to [alpha](/alpha.md) — relative link resolution check.
<a href="/introduction">MDX link</a>
"""


def run(*argv, **env):
    e = dict(os.environ, **env)
    return subprocess.run([sys.executable, *map(str, argv)],
                          capture_output=True, text=True, env=e, timeout=60)


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ts-kb-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(
            self.tmp, True))
        self.src = self.tmp / "src"
        self.src.mkdir()
        (self.src / "llms.txt").write_text(LLMS)
        (self.src / "alpha.md").write_text(ALPHA)
        (self.src / "beta.md").write_text(BETA)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.env = {
            "HNGH_HOME_DIR": str(self.home),
            "HNGH_KNOWLEDGE_DB": str(self.tmp / "kb.db"),
        }

    def ingest(self, *extra):
        return run(INGEST, "--llms", "https://docs.typesafe.ai/llms.txt",
                   "--source-dir", str(self.src),
                   "--db", self.env["HNGH_KNOWLEDGE_DB"],
                   "--cache", str(self.tmp / "cache"), *extra,
                   **self.env)


class TestIngest(Base):
    def test_nodes_edges_fts_and_idempotent_refresh(self):
        r = self.ingest()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("nodes=2", r.stdout)
        self.assertIn("edges=2", r.stdout)
        self.assertIn("ingested=2 failed=1", r.stdout)
        # cached markdown exists for fetched pages only
        cache = sorted(p.name for p in (self.tmp / "cache").iterdir())
        self.assertEqual(cache, ["docs.typesafe.ai__alpha.md",
                                 "docs.typesafe.ai__beta.md"])
        # idempotent refresh: same counts, refreshed rows, still 1 edge
        r2 = self.ingest()
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertIn("nodes=2 edges=2", r2.stdout)
        self.assertIn("ingested=2 failed=1", r2.stdout)

    def test_limit_caps_pages(self):
        r = self.ingest("--limit", "1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("ingested=1 failed=0", r.stdout)

    def test_all_failed_exits_nonzero(self):
        (self.src / "alpha.md").unlink()
        (self.src / "beta.md").unlink()
        r = self.ingest()
        self.assertEqual(r.returncode, 1)
        self.assertIn("failed=3", r.stdout + r.stderr)

    def test_catalog_row_in_sandbox_home(self):
        self.ingest()
        tsv = (self.home / "catalog.tsv")
        self.assertTrue(tsv.is_file())
        rows = [l for l in tsv.read_text().splitlines()
                if "typesafe-docs-db" in l]
        self.assertEqual(len(rows), 1)


class TestProbe(Base):
    def test_query_related_stats(self):
        self.ingest()
        db = self.env["HNGH_KNOWLEDGE_DB"]
        r = run(PROBE, "--query", "confidence", **self.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Beta page", r.stdout)
        r = run(PROBE, "--related", "alpha.md", **self.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("docs.typesafe.ai/beta.md", r.stdout)
        r = run(PROBE, **self.env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertRegex(r.stdout, r"nodes=2 edges=2 stale\(>8d\)=\d+")

    def test_missing_db_fails_closed(self):
        env = dict(self.env, HNGH_KNOWLEDGE_DB=str(self.tmp / "absent.db"))
        r = run(PROBE, **env)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
