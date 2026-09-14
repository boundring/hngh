#!/usr/bin/env python3
"""Hermetic unit tests for POST /delegate (plan 2026-09-14 step 1).

Import-safe: dashboard-server.py only starts its HTTP server under
`if __name__ == "__main__"`, so the module can be imported directly and
the module-level validator plus route dispatch dict tested without any
network or subprocess activity.

Run: cd automation && python3 -B tests/test-delegate-route.py
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_MODULE_PATH = os.path.join(_HERE, "..", "dashboard-server.py")

_spec = importlib.util.spec_from_file_location(
    "dashboard_server_under_test", _MODULE_PATH)
ds = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ds)


def good_body():
    return {"slug": "test-slug", "objective": "do the thing",
            "provider": "zai", "minutes": 10}


class TestValidateDelegateBody(unittest.TestCase):
    def test_valid_body(self):
        ok, params = ds.validate_delegate_body(good_body())
        self.assertTrue(ok)
        self.assertEqual(params, good_body())

    def test_bad_slug(self):
        for bad in ("", "a" * 65, "has space", "has/slash", "has.dot",
                    None, 42):
            body = good_body()
            body["slug"] = bad
            ok, err = ds.validate_delegate_body(body)
            self.assertFalse(ok, "slug=%r accepted" % (bad,))
            self.assertIn("slug", err)

    def test_empty_objective(self):
        for bad in ("", "   ", None, 7):
            body = good_body()
            body["objective"] = bad
            ok, err = ds.validate_delegate_body(body)
            self.assertFalse(ok, "objective=%r accepted" % (bad,))
            self.assertIn("objective", err)

    def test_oversized_objective(self):
        body = good_body()
        body["objective"] = "x" * 2001
        ok, err = ds.validate_delegate_body(body)
        self.assertFalse(ok)
        self.assertIn("objective", err)
        body["objective"] = "x" * 2000
        ok, _ = ds.validate_delegate_body(body)
        self.assertTrue(ok)

    def test_unknown_provider(self):
        for bad in ("gpt", "ZAI", "", None, 1):
            body = good_body()
            body["provider"] = bad
            ok, err = ds.validate_delegate_body(body)
            self.assertFalse(ok, "provider=%r accepted" % (bad,))
            self.assertIn("provider", err)

    def test_minutes_out_of_range_and_wrong_type(self):
        for bad in (0, 31, -5, "10", 10.0, None, True):
            body = good_body()
            body["minutes"] = bad
            ok, err = ds.validate_delegate_body(body)
            self.assertFalse(ok, "minutes=%r accepted" % (bad,))
            self.assertIn("minutes", err)

    def test_boundary_minutes_accepted(self):
        for m in (1, 30):
            body = good_body()
            body["minutes"] = m
            ok, params = ds.validate_delegate_body(body)
            self.assertTrue(ok)
            self.assertEqual(params["minutes"], m)

    def test_objective_control_characters_rejected(self):
        body = good_body()
        body["objective"] = "line one\nline two"
        ok, err = ds.validate_delegate_body(body)
        self.assertFalse(ok)
        self.assertIn("objective", err)

    def test_non_dict_body(self):
        ok, _err = ds.validate_delegate_body(None)
        self.assertFalse(ok)


class TestRouteDispatch(unittest.TestCase):
    def test_delegate_route_registered(self):
        # The dispatch dict is built inline inside do_POST; assert the
        # handler method exists and the source wires "delegate" beside
        # "spawn" in the dispatch dict.
        self.assertTrue(callable(getattr(ds.Handler, "_delegate", None)))
        with open(_MODULE_PATH, encoding="utf-8") as f:
            src = f.read()
        self.assertRegex(src, r'"delegate"\s*:\s*self\._delegate')


class TestDelegateExec(unittest.TestCase):
    """Drive Handler._delegate with stubs: fixed argv, 202/400/500 shapes."""

    def _run(self, body, popen):
        captured = {"argv": None}
        handler = ds.Handler.__new__(ds.Handler)
        handler._body = lambda: body

        def fake_popen(argv, **kw):
            captured["argv"] = argv

        def fail_popen(argv, **kw):
            raise OSError("boom")

        real_popen = ds.subprocess.Popen
        impl = fake_popen if popen == "ok" else fail_popen
        ds.subprocess.Popen = impl
        try:
            handler._json = lambda code, obj: captured.update(code=code, obj=obj)
            handler._delegate()
        finally:
            ds.subprocess.Popen = real_popen
        return captured

    def test_fixed_argv_and_202(self):
        cap = self._run(good_body(), popen="ok")
        self.assertEqual(
            cap["argv"],
            ["bash", os.path.normpath(os.path.join(_HERE, "..", "lib",
                                   "jcode-delegate.sh")),
             "test-slug", "do the thing", "10", "zai"])
        self.assertEqual(cap["code"], 202)
        self.assertEqual(cap["obj"], {"ok": True, "slug": "test-slug"})

    def test_exec_failure_is_500(self):
        cap = self._run(good_body(), popen="fail")
        self.assertEqual(cap["code"], 500)
        self.assertFalse(cap["obj"]["ok"])

    def test_invalid_body_is_400_shape(self):
        bad = good_body()
        bad["provider"] = "gpt"
        cap = self._run(bad, popen="fail")
        self.assertEqual(cap["code"], 400)
        self.assertFalse(cap["obj"]["ok"])
        self.assertIn("provider", cap["obj"]["error"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
    unittest.main(verbosity=2)
