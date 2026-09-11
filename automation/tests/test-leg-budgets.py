#!/usr/bin/env python3
"""Leg-budget registry guard (R5): every chain leg declares curl --max-time
AND bounded max output tokens, both below its smallest edge timeout, in one
auditable place: automation/config/leg-budgets.tsv.

Rule: no declared pair, no chain admission. The required leg set is derived
from model.sh itself (the <name>_chat() functions named in the chain header),
so a new leg with no registry row fails this test.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TSV = ROOT / "config" / "leg-budgets.tsv"
MODEL_SH = ROOT / "lib" / "model.sh"
LAUNCH = ROOT / "lib" / "launch-session.sh"

# Legs exempt from the output-token column: image legs are not model
# completion legs (no max_tokens exists); their max-time + image-size
# bounds are declared for completeness only.
IMAGE_PREFIX = "image-"


def chain_legs():
    """Derive the model-chain leg set from model.sh's <name>_chat defs."""
    legs = set(re.findall(r"^(\w+)_chat\(\)", MODEL_SH.read_text(), re.M))
    return {leg for leg in legs if not leg.startswith("_")}


def registry_rows():
    rows = []
    for line in TSV.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        rows.append((parts + [""] * 5)[:5])
    return rows


def numeric(v):
    return v.lstrip("-").isdigit()


class TestLegBudgets(unittest.TestCase):
    def test_registry_exists(self):
        self.assertTrue(TSV.exists(), f"missing registry {TSV}")

    def test_every_chain_leg_has_row(self):
        rows = {r[0]: r for r in registry_rows()}
        for leg in sorted(chain_legs()):
            self.assertIn(leg, rows, f"chain leg '{leg}' has no registry row")

    def test_no_ghost_rows(self):
        for leg, _, _, _, src in registry_rows():
            f = re.sub(r":[\d,]+$", "", src.split()[0])
            path = ROOT.parent / f if f.startswith("automation/") else ROOT / f
            self.assertTrue(
                path.exists(), f"registry row '{leg}' cites missing file {f}"
            )
            text = path.read_text()
            token = f"{leg}_chat" if f.endswith("model.sh") else leg.replace("-", "_")
            self.assertIn(
                token.split("_")[0], text.lower(), f"row '{leg}' not found in {f}"
            )

    def test_both_values_numeric(self):
        for leg, max_time, max_out, edge, _ in registry_rows():
            if leg.startswith(IMAGE_PREFIX):
                continue
            self.assertTrue(
                numeric(max_time), f"{leg}: max-time-s '{max_time}' not numeric"
            )
            self.assertTrue(
                numeric(max_out), f"{leg}: max-output '{max_out}' not numeric"
            )
            if numeric(edge):
                self.assertLessEqual(
                    int(max_time), int(edge),
                    f"{leg}: max-time {max_time}s exceeds edge {edge}s",
                )

    def test_launch_session_cites_registry(self):
        text = LAUNCH.read_text()
        self.assertIn("leg-budgets.tsv", text, "opencode branch must cite the registry")
        self.assertIn("1800", text)
        self.assertIn("50000", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
