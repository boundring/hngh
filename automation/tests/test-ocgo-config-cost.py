#!/usr/bin/env python3
"""ocgo cost reducers, hermetic (no real sessions, no spend).

2026-09-11 burn attribution (logs/overnight-ocgo-selfsteer2-
20260911T093738.log.json): session 2 billed 144,495 fresh-input tokens
(~86% of cost at $0.15/M in vs $0.50/M out). Four near-total cache misses
re-billed 117k of already-seen content; the top tool outputs were the
scout result (32.8k chars), a whole-file lessons read (29.2k chars) and a
whole-file launch-session.sh read (12.3k chars). Reducers: small_model
pins to the free local llama-server leg (titles/summaries only; the
primary agent keeps opencode-go/glm-5.3-flash), agent prompts carry an
input-budget section, and the emitter tees a per-session top-burner TSV.
"""

import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent
EMITTER = AUTO / "jobs" / "ocgo-attribution.py"


def _load_jsonc(path):
    """Parse JSONC (line comments) — same tiny parser as test-ocgo-launch."""
    out = []
    for line in Path(path).read_text().splitlines():
        res, in_str, esc = [], False, False
        i = 0
        while i < len(line):
            c = line[i]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
                res.append(c)
            elif c == '"':
                in_str = True
                res.append(c)
            elif c == "/" and line[i:i + 2] == "//":
                break
            else:
                res.append(c)
            i += 1
        out.append("".join(res))
    return json.loads("\n".join(out))


NOW_MS = int(time.time() * 1000)


def tool_use(sid, call, tool, chars, desc="x"):
    return json.dumps({
        "type": "tool_use", "timestamp": NOW_MS, "sessionID": sid,
        "part": {"type": "tool", "tool": tool, "callID": call,
                 "state": {"status": "completed",
                           "input": {"filePath" if tool == "read" else "command": desc},
                           "output": "x" * chars}}})


class OcgoConfigCost(unittest.TestCase):
    def test_small_model_pins_to_free_local_leg(self):
        cfg = _load_jsonc(AUTO / "config" / "opencode" / "opencode.jsonc")
        # primary agent stays on the paid Go-quota model (operator rule)
        self.assertEqual(cfg["model"], "opencode-go/glm-5.3-flash")
        self.assertEqual(cfg["agent"]["executor"]["model"],
                         "opencode-go/glm-5.3-flash")
        # small_model (title/summary/compaction) rides the local llama-server
        self.assertTrue(cfg["small_model"].startswith("unsloth-local/"),
                        cfg["small_model"])
        prov = cfg["provider"]["unsloth-local"]
        # credentials ride env-var references, never literals
        self.assertEqual(prov["options"]["baseURL"], "{env:UNSLOTH_BASE_URL}")
        self.assertEqual(prov["options"]["apiKey"], "{env:UNSLOTH_API_KEY}")
        self.assertTrue(prov["models"])

    def test_agent_prompts_carry_input_budget(self):
        for role in ("executor", "scout"):
            text = (AUTO / "config" / "opencode" / "agents"
                    / (role + ".md")).read_text()
            self.assertIn("## Input budget", text, role)
            # known-large files named so the agent never whole-file reads them
            self.assertIn("src/main.lisp", text, role)
            self.assertIn("ocgo-agent-lessons.md", text, role)
            self.assertIn("-m", text, role)  # grep -m bounded searches

    def test_emitter_appends_top_burn_from_fixture_stream(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            stream = td / "events.jsonl"
            burn = td / "ocgo-agent-burn.tsv"
            stream.write_text("\n".join([
                tool_use("ses_b1", "c1", "read", 30000,
                         "/repo/automation/state/ocgo-agent-lessons.md"),
                tool_use("ses_b1", "c2", "read", 3000, "/repo/src/main.lisp"),
                tool_use("ses_b1", "c3", "bash", 1500, "git status"),
                tool_use("ses_b1", "c4", "grep", 800, "lesson"),
            ]))
            r = subprocess.run(
                [sys.executable, "-B", str(EMITTER), str(stream),
                 "--db", str(td / "none.db"), "--telemetry",
                 str(td / "telemetry.db"), "--burn", str(burn)],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = burn.read_text().splitlines()
            # header + top-3, largest first; the 4th tool call is dropped
            self.assertEqual(len(lines), 4, lines)
            row = lines[1].split("\t")
            self.assertEqual(row[2], "read")
            self.assertEqual(row[3], "30000")
            self.assertIn("ocgo-agent-lessons.md", row[4])
            self.assertNotIn("grep", burn.read_text())

    def test_emitter_survives_stream_without_tool_events(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            stream = td / "events.jsonl"
            stream.write_text("")
            r = subprocess.run(
                [sys.executable, "-B", str(EMITTER), str(stream),
                 "--db", str(td / "none.db"), "--telemetry",
                 str(td / "telemetry.db"), "--burn", str(td / "b.tsv")],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()