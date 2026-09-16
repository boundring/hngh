#!/usr/bin/env python3
"""Tests for jobs/render-blocks-feed.py — the HNGH-RENDER side-channel
feed builder (viz-render consumer slice). Hermetic: fixtures only."""

import importlib.util
import json
import os
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location(
    "rbfeed", os.path.join(ROOT, "jobs", "render-blocks-feed.py"))
rbf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rbf)


class BuildTests(unittest.TestCase):
    def test_build_empty_when_no_captures_exist(self):
        data = rbf.build(["/nonexistent/path.jsonl"], 50)
        self.assertEqual(data["count"], 0)
        self.assertEqual(data["envelopes"], [])
        self.assertIn("generated_at", data)

    def test_valid_envelope_parsed(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            with open(cap, "w") as f:
                f.write(json.dumps({
                    "v": 1, "id": "e1", "ts": "2026-09-16T10:00:00Z",
                    "kind": "turn-render",
                    "blocks": [{"kind": "summary", "payload": "hi"}],
                    "tools": [], "usage": {"in": 5},
                }) + "\n")
            data = rbf.build([cap], 50)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["envelopes"][0]["id"], "e1")
        self.assertEqual(data["envelopes"][0]["blocks"][0]["kind"],
                         "summary")

    def test_bad_lines_skipped_never_fatal(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            with open(cap, "w") as f:
                f.write("not json\n")
                f.write(json.dumps({"v": 2, "id": "wrong-version"}) + "\n")
                f.write(json.dumps({"no-v": True}) + "\n")
                f.write(json.dumps({
                    "v": 1, "id": "e2", "ts": "2026-09-16T11:00:00Z"}) + "\n")
            data = rbf.build([cap], 50)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["envelopes"][0]["id"], "e2")

    def test_duplicate_ids_keep_first(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            with open(cap, "w") as f:
                for ts in ("2026-09-16T10:00:00Z", "2026-09-16T11:00:00Z"):
                    f.write(json.dumps({
                        "v": 1, "id": "dup", "ts": ts}) + "\n")
            data = rbf.build([cap], 50)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["envelopes"][0]["ts"], "2026-09-16T10:00:00Z")

    def test_sorted_newest_last_and_max_keeps_newest(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            with open(cap, "w") as f:
                for n, ts in enumerate((
                        "2026-09-16T09:00:00Z", "2026-09-16T12:00:00Z",
                        "2026-09-16T10:00:00Z", "2026-09-16T11:00:00Z")):
                    f.write(json.dumps({
                        "v": 1, "id": f"e{n}", "ts": ts}) + "\n")
            data = rbf.build([cap], 2)
        self.assertEqual(data["count"], 2)
        # 12:00 (e1) is newest, then 11:00 (e3)
        self.assertEqual([e["id"] for e in data["envelopes"]],
                         ["e3", "e1"])  # 10:00 then 11:00

    def test_malformed_blocks_list_normalized(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            with open(cap, "w") as f:
                f.write(json.dumps({
                    "v": 1, "id": "e3", "ts": "2026-09-16T10:00:00Z",
                    "blocks": "not-a-list", "tools": 7, "usage": []}) + "\n")
            data = rbf.build([cap], 50)
        self.assertEqual(data["envelopes"][0]["blocks"], [])
        self.assertEqual(data["envelopes"][0]["tools"], [])
        self.assertEqual(data["envelopes"][0]["usage"], {})


class MainTests(unittest.TestCase):
    def test_main_writes_out_atomically(self):
        with tempfile.TemporaryDirectory() as td:
            cap = os.path.join(td, "cap.jsonl")
            out = os.path.join(td, "out", "render-blocks.json")
            with open(cap, "w") as f:
                f.write(json.dumps({
                    "v": 1, "id": "e9", "ts": "2026-09-16T10:00:00Z"}) + "\n")
            rc = rbf.main(["--capture", cap, "--out", out])
            self.assertEqual(rc, 0)
            with open(out) as f:
                data = json.load(f)
            self.assertEqual(data["count"], 1)
            self.assertFalse(os.path.exists(out + ".tmp"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
