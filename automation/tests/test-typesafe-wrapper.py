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

    def test_beat_skip_gate_fallback_false(self):
        env = {k: v for k, v in os.environ.items() if k != "TYPESAFE_API_KEY"}
        with unittest.mock.patch.dict(os.environ, env, clear=True):
            self.assertFalse(typesafe.beat_skip_gate({"session_recent": "yes"}))


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
