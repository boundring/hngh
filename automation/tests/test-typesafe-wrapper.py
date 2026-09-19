#!/usr/bin/env python3
"""test-typesafe-wrapper.py — session-layer tests for lib/typesafe.py.

Hermetic except one optional live call: without TYPESAFE_API_KEY (or
without the SDK) every helper returns None fail-closed and the live test
self-skips. With key + SDK the live Noul call must return a float in
[0,1]. No kernel src/ touched.
"""
import os
import sys
import unittest
import unittest.mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))

import typesafe


class FailClosed(unittest.TestCase):
    def test_no_key_noul_none(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertIsNone(
                typesafe.ask_noul({"s": "t"}, "q", "Is this a test?"))

    def test_no_key_choice_none(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertIsNone(
                typesafe.ask_choice({"s": "t"}, "q", "Pick one.", ["a", "b"]))

    def test_no_key_score_none(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertIsNone(
                typesafe.ask_score({"s": "t"}, "q", "Rate it.", ["clarity"]))

    def test_no_key_fanout_triple_none(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(
                typesafe.triage_fanout({"s": "t"}, ["a", "b"]),
                (None, None, None))

    def test_no_key_closeout_none(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertIsNone(
                typesafe.closeout_evidence_noul({"s": "t"}, "did the thing"))


class FanoutSingleCall(unittest.TestCase):
    """Speculative fan-out: one system_one round trip, branch on result."""

    def _fake_client(self, noul=0.8, choice="b", scores=(0.2, 0.9)):
        calls = []

        class FakeNouls(dict):
            pass

        class V:
            def __init__(self, v):
                self.noul = v

        class C:
            def __init__(self, v):
                self.choice = v

        class S:
            def __init__(self, v):
                self.score = v

        class R:
            pass

        class FakeClient:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def system_one(self, state, questions):
                calls.append(set(questions))
                r = R()
                r.nouls = {"collapse_ready": V(noul),
                           "close_evidence": V(noul),
                           "operator_busy": V(noul)}
                r.choices = {"hottest": C(choice)}
                r.scores = {"urgency": S(scores[0])}
                return r

        return FakeClient(), calls

    def test_fanout_one_call_all_variants(self):
        fake, calls = self._fake_client()
        with unittest.mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "_client", return_value=fake):
                hot, col, scores = typesafe.triage_fanout(
                    {"s": "t"}, ["a", "b"])
        self.assertEqual(hot, "b")
        self.assertTrue(col)
        self.assertEqual(scores, 0.2)
        self.assertEqual(len(calls), 1)  # one round trip
        self.assertEqual(calls[0], {"hottest", "collapse_ready", "urgency"})

    def test_fanout_collapse_false_below_half(self):
        fake, _ = self._fake_client(noul=0.3)
        with unittest.mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "_client", return_value=fake):
                _, col, _ = typesafe.triage_fanout({"s": "t"}, ["a", "b"])
        self.assertFalse(col)

    def test_closeout_true_above_half(self):
        fake, _ = self._fake_client(noul=0.9)
        with unittest.mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "_client", return_value=fake):
                self.assertTrue(typesafe.closeout_evidence_noul(
                    {"s": "t"}, "landed commit abc, tests green"))

    def test_closeout_false_below_half(self):
        fake, _ = self._fake_client(noul=0.1)
        with unittest.mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "_client", return_value=fake):
                self.assertFalse(typesafe.closeout_evidence_noul(
                    {"s": "t"}, "vague claim, no cites"))

    def test_beat_skip_gate_fallback_false(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertFalse(typesafe.beat_skip_gate({"session_recent": "yes"}))

    def test_beat_skip_stale_verdict_forces_refresh(self):
        # verdict older than max age: False without any inference call.
        with unittest.mock.patch.dict(
                os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "ask_noul",
                    side_effect=AssertionError("must not infer")):
                self.assertFalse(typesafe.beat_skip_gate({
                    "session_recent": "yes",
                    "verdict_age_s": "999",
                    "verdict_max_age_s": "120"}))

    def test_beat_skip_fresh_verdict_asks_noul(self):
        fake, _ = self._fake_client(noul=0.9)
        with unittest.mock.patch.dict(
                os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "_client", return_value=fake):
                self.assertTrue(typesafe.beat_skip_gate({
                    "session_recent": "no",
                    "verdict_age_s": "10",
                    "verdict_max_age_s": "120",
                    "studio_queue_depth": "0",
                    "beat_model": "m",
                    "studio_user_model": "m"}))

    def test_beat_skip_queue_depth_skips_without_inference(self):
        with unittest.mock.patch.dict(
                os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "ask_noul",
                    side_effect=AssertionError("must not infer")):
                self.assertTrue(typesafe.beat_skip_gate({
                    "session_recent": "no",
                    "verdict_age_s": "5",
                    "studio_queue_depth": "1",
                    "beat_model": "m",
                    "studio_user_model": "m"}))

    def test_beat_skip_foreign_model_skips_without_inference(self):
        with unittest.mock.patch.dict(
                os.environ, {"TYPESAFE_API_KEY": "x"}):
            with unittest.mock.patch.object(
                    typesafe, "ask_noul",
                    side_effect=AssertionError("must not infer")):
                self.assertTrue(typesafe.beat_skip_gate({
                    "session_recent": "no",
                    "verdict_age_s": "5",
                    "studio_queue_depth": "0",
                    "beat_model": "beat-weights",
                    "studio_user_model": "operator-weights"}))


class LiveCall(unittest.TestCase):
    def test_live_noul_returns_float(self):
        if not os.environ.get("TYPESAFE_API_KEY"):
            self.skipTest("no TYPESAFE_API_KEY: live call skipped")
        try:
            import typesafe_sdk  # noqa: F401
        except ImportError:
            self.skipTest("typesafe_sdk not installed")
        v = typesafe.ask_noul(
            {"subject": "wrapper self-test"},
            "working",
            "Is this a self-test?")
        self.assertIsInstance(v, float)
        self.assertGreaterEqual(v, 0.0)
        self.assertLessEqual(v, 1.0)


if __name__ == "__main__":
    unittest.main()
