#!/usr/bin/env python3
"""hngh-bridge plugin pure helpers (plan step 8, context-seeding).

The plugin lives outside the repo (~/.omp/plugins/hngh-bridge); only its
pure helpers are testable without omp. src/orient.ts exports repoRoot
(cwd gate) and hasOriented (dedup state check); both run under bun, which
strips the type-only import. The full session_start behavior is verified
by the omp print-mode probe recorded in the integration plan.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORIENT_TS = Path.home() / ".omp" / "plugins" / "hngh-bridge" / "src" / "orient.ts"
OCODE_TS = Path.home() / ".omp" / "plugins" / "hngh-bridge" / "src" / "opencode.ts"

RUNNER = """
const m = await import(FILE);
console.log(JSON.stringify([
  m.repoRoot(CWD),
  m.hasOriented(ENTRIES),
]));
"""


class HnghBridgePlugin(unittest.TestCase):
    def run_helpers(self, cwd, entries):
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
            f.write(
                RUNNER.replace("FILE", json.dumps(str(ORIENT_TS)))
                .replace("CWD", json.dumps(cwd))
                .replace("ENTRIES", json.dumps(entries))
            )
            script = f.name
        r = subprocess.run(
            ["bun", "run", script],
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout.strip().splitlines()[-1])

    def test_repo_root_gates_on_bridge_presence(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            # foreign cwd -> null
            self.assertEqual(self.run_helpers(str(root), [])[0], None)
            # cwd with scripts/omp-bridge -> root
            (root / "scripts").mkdir()
            (root / "scripts" / "omp-bridge").touch()
            self.assertEqual(self.run_helpers(str(root), [])[0], str(root))

    def test_has_oriented_keys_on_custom_entry_type(self):
        no = [{"type": "message"}, {"type": "custom", "customType": "com.other.state"}]
        yes = no + [{"type": "custom", "customType": "com.hngh.orient"}]
        self.assertFalse(self.run_helpers(".", no)[1])
        self.assertTrue(self.run_helpers(".", yes)[1])


OCODE_RUNNER = """
const m = await import(FILE);
console.log(JSON.stringify({
  clamp: [m.clampMaxMinutes(), m.clampMaxMinutes(0), m.clampMaxMinutes(-5),
          m.clampMaxMinutes(999), m.clampMaxMinutes(3), m.clampMaxMinutes(7.9),
          m.clampMaxMinutes("nonsense")],
  candidates: m.delegateCandidates(CWD),
  parsed: m.parseResult("session=dslug\\nrc=1\\ndisposition=dead\\nlog=logs/x.log\\n"),
}));
"""


class HnghOpencodeTool(unittest.TestCase):
    """The hngh_opencode tool file: registered in the plugin manifest,
    parses under bun, and its pure helpers behave (bounded timeout clamp,
    wrapper discovery gated on ocgo-delegate.sh, key=value result parse)."""

    def run_helpers(self, cwd):
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
            f.write(OCODE_RUNNER
                    .replace("FILE", json.dumps(str(OCODE_TS)))
                    .replace("CWD", json.dumps(cwd)))
            script = f.name
        r = subprocess.run(["bun", "run", script],
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout.strip().splitlines()[-1])

    def test_tool_registered_and_parses(self):
        self.assertTrue(OCODE_TS.exists())
        pkg = json.loads((OCODE_TS.parent.parent / "package.json").read_text())
        for key in ("pi", "omp"):
            self.assertIn("./src/opencode.ts", pkg[key]["tools"])

    def test_helpers_clamp_discover_parse(self):
        with tempfile.TemporaryDirectory() as td:
            out = self.run_helpers(td)
        # bounded defaults: 10 min default, 1..30 clamp (the opencode-agent
        # leg budget max-time 1800s), garbage -> default
        self.assertEqual(out["clamp"], [10, 1, 1, 30, 3, 7, 10])
        # foreign cwd -> the repo fallback still answers (same shape as
        # hngh_propose's bridgeCandidates); a cwd that carries the wrapper
        # wins first
        self.assertEqual(out["candidates"],
                         [str(Path.home() / "Projects/etc/hngh"
                              / "automation/lib/ocgo-delegate.sh")])
        (Path(td) / "automation" / "lib").mkdir(parents=True)
        (Path(td) / "automation" / "lib" / "ocgo-delegate.sh").touch()
        out = self.run_helpers(td)
        self.assertEqual(out["candidates"][0],
                         str(Path(td) / "automation/lib/ocgo-delegate.sh"))
        self.assertEqual(out["parsed"],
                         {"session": "dslug", "rc": "1",
                          "disposition": "dead", "log": "logs/x.log"})


if __name__ == "__main__":
    unittest.main()
