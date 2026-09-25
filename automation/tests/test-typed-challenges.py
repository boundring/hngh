#!/usr/bin/env python3
"""typed-challenges pin (unresolved-matters pass B2, 2026-09-24).

Contract pinned (automation/scripts/typed-challenges.py):
- TWO batched ask_nouls calls: the refusal-condition batch, then the
  disconfirming-question counter batch.
- Rows fire at p >= 0.7 only; risk text "risk p=N.NN: <condition>",
  counter text "counter p=N.NN: plausible disconfirming reading of
  <condition>"; the principle column keeps the matrix name.
- Combined output is capped at 20 rows (ROW_CAP).
- Fail-open: first-batch exception or empty -> no rows; second-batch
  exception -> risk rows still ride out.
- Wire shape stays `<principle>\t<text>\t<cite>`.

Hermetic: ask_nouls and _diff are monkeypatched; no model calls, no
git, no repo-state writes.
"""

import sys
import unittest
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib"))

_spec = importlib.util.spec_from_file_location(
    "typed_challenges", ROOT / "scripts" / "typed-challenges.py")
typed_challenges = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(typed_challenges)  # noqa: E402

CA = "closed-authority"
CA_COND = typed_challenges.PRINCIPLES[CA]


class ScriptedNouls:
    """ask_nouls stand-in: scripted per-call returns, calls recorded."""

    def __init__(self, returns):
        self.returns = list(returns)
        self.calls = []

    def __call__(self, state, questions):
        self.calls.append(questions)
        step = self.returns.pop(0)
        if isinstance(step, Exception):
            raise step
        return step


def run_findings(returns):
    stub = ScriptedNouls(returns)
    orig_nouls, orig_diff = typed_challenges.ask_nouls, typed_challenges._diff
    typed_challenges.ask_nouls = stub
    typed_challenges._diff = lambda files: ""
    try:
        rows = typed_challenges.findings("obj", ["a.diff"])
    finally:
        typed_challenges.ask_nouls, typed_challenges._diff = orig_nouls, orig_diff
    return rows, stub


def same(cond):
    return {name: cond for name in typed_challenges.PRINCIPLES}


def only(name, cond, rest=0.1):
    out = {n: rest for n in typed_challenges.PRINCIPLES}
    out[name] = cond
    return out


class TypedChallengesPin(unittest.TestCase):
    def test_two_batched_calls_and_row_shape(self):
        rows, stub = run_findings([only(CA, 0.9), only(CA, 0.9)])
        self.assertEqual(len(stub.calls), 2)
        self.assertIn("Is there a real risk this candidate trips it?",
                      stub.calls[0][CA])
        self.assertIn("Is there a plausible disconfirming reading",
                      stub.calls[1][CA])
        self.assertEqual(rows, [
            "%s\trisk p=0.90: %s\ta.diff" % (CA, CA_COND),
            "%s\tcounter p=0.90: plausible disconfirming reading of %s"
            "\ta.diff" % (CA, CA_COND),
        ])

    def test_bar_is_inclusive_point_seven(self):
        below, _ = run_findings([same(0.69), same(0.69)])
        self.assertEqual(below, [])
        rows, _ = run_findings([same(0.70), same(0.0)])
        self.assertEqual(len(rows), 10)
        self.assertTrue(all("risk p=0.70:" in r for r in rows))

    def test_cap_twenty_rows(self):
        rows, _ = run_findings([same(0.9), same(0.9)])
        self.assertEqual(len(rows), typed_challenges.ROW_CAP)
        self.assertEqual(len(rows), 20)

    def test_counter_failure_fails_open_but_keeps_risk_rows(self):
        rows, _ = run_findings([only(CA, 0.8), RuntimeError("nouls down")])
        self.assertEqual(len(rows), 1)
        self.assertTrue(all("risk p=0.80:" in r for r in rows))

    def test_first_batch_failure_emits_nothing(self):
        rows, stub = run_findings([RuntimeError("no key"), same(0.9)])
        self.assertEqual(rows, [])
        self.assertEqual(len(stub.calls), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
