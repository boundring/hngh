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


if __name__ == "__main__":
    unittest.main()
