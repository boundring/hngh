#!/usr/bin/env python3
"""manga-vision token-file 0600 gate (the f809a05f ProbeTokenMode class):
a token file not exactly 0600 must be refused fail-closed BEFORE its
value is read or sent; a 0600 file still rides the Bearer header.
Hermetic: urlopen stood in, no network, no images, no magick."""
import builtins
import importlib.util
import tempfile
import unittest
import unittest.mock
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load():
    spec = importlib.util.spec_from_file_location(
        "manga_vision_gate", str(ROOT / "jobs" / "manga-vision.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mv = _load()


class _Sent(Exception):
    """urlopen stood in: the request (and its Authorization) got here."""


class TokenFileMode(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tok = Path(self.tmp.name) / "unsloth.token"
        self.tok.write_text("tok-secret-1234\n")
        self._old = mv.TOKEN_FILE
        mv.TOKEN_FILE = str(self.tok)
        self.addCleanup(setattr, mv, "TOKEN_FILE", self._old)

    def _one_call_under_stub(self, guard_reads=False):
        def fake_urlopen(req, timeout=None):
            raise _Sent(req.headers.get("Authorization"))

        patches = [unittest.mock.patch.object(
            mv.urllib.request, "urlopen", fake_urlopen)]
        if guard_reads:
            real_open = builtins.open

            def guarded(file, *a, **k):
                if str(file) == str(self.tok):
                    raise AssertionError(
                        "token file was read despite the too-open refusal")
                return real_open(file, *a, **k)

            patches.append(unittest.mock.patch("builtins.open", guarded))
        with patches[0], patches[-1] if guard_reads else unittest.mock.patch(
                "builtins.open", builtins.open):
            return mv._one_call("p", [], 8, False, 5)

    def test_too_open_token_refused_before_read_or_send(self):
        self.tok.chmod(0o644)
        with self.assertRaises(mv.TokenFileModeError) as cm:
            self._one_call_under_stub(guard_reads=True)
        self.assertIn("0600", str(cm.exception))
        self.assertIn(str(self.tok), str(cm.exception))

    def test_tight_token_rides_bearer_header(self):
        self.tok.chmod(0o600)
        with self.assertRaises(_Sent) as cm:
            self._one_call_under_stub()
        self.assertEqual("Bearer tok-secret-1234", cm.exception.args[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
