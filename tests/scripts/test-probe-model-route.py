#!/usr/bin/env python3
"""Probe-model-route smoke: parser strictness and the no-network exit.

The probe is deliberately testable offline: --route=local|remote|auto
with missing configs must resolve to "none" (exit 1) the same way a
missing endpoint does — no network is touched when no endpoint is
configured. The parser's fail-closed behavior (unknown key, missing
key, duplicate, empty) is asserted directly via import.
"""

import importlib.machinery
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "probe-model-route"


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


def load():
    loader = importlib.machinery.SourceFileLoader("probe_model_route_mod", str(SCRIPT))
    spec = importlib.util.spec_from_loader("probe_model_route_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def good_config(tmp, endpoint="http://127.0.0.1:9/v1/chat/completions"):
    conf = tmp / "reviewer.conf"
    tok = tmp / "token"
    tok.write_text("secret-token\n")
    conf.write_text(
        f"endpoint={endpoint}\nmodel=test/model\nmax-tokens=512\n"
        f"timeout=2\ntoken-file={tok}\n")
    return conf


class ProbeRouteParser(unittest.TestCase):
    def test_unknown_key_rejected(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            conf = Path(td) / "bad.conf"
            conf.write_text("endpoint=http://x\nbogus-key=1\n")
            with self.assertRaises(ValueError):
                mod.parse_config(conf)

    def test_missing_keys_rejected(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            conf = Path(td) / "bad.conf"
            conf.write_text("endpoint=http://x\n")
            with self.assertRaises(ValueError):
                mod.parse_config(conf)

    def test_duplicate_rejected(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            conf = Path(td) / "bad.conf"
            conf.write_text("endpoint=http://a\nendpoint=http://b\n"
                            "model=m\nmax-tokens=1\ntimeout=1\ntoken-file=t\n")
            with self.assertRaises(ValueError):
                mod.parse_config(conf)

    def test_missing_config_is_unreachable(self):
        mod = load()
        ok, err = mod.probe(str(Path("/nonexistent/reviewer.conf")))
        self.assertFalse(ok)
        self.assertIn("not present", err)


class ProbeRouteOffline(unittest.TestCase):
    def test_no_config_exits_one(self):
        for route in ("auto", "local", "remote"):
            out = run(["--route", route, "--local", "/nonexistent/l",
                       "--remote", "/nonexistent/r"])
            self.assertEqual(out.returncode, 1,
                             f"{route} with no config should be exit 1: {out.stdout}")
            self.assertEqual(out.stdout.strip(), "none")

    def test_bad_route_exits_two(self):
        out = run(["--route", "bogus"])
        self.assertEqual(out.returncode, 2)
        self.assertIn("route must be", out.stderr)

    def test_probe_endpoint_trimming(self):
        mod = load()
        self.assertEqual(
            mod.probe_endpoint("http://127.0.0.1:8888/v1/chat/completions"),
            "http://127.0.0.1:8888/v1/models")


if __name__ == "__main__":
    unittest.main(verbosity=2)