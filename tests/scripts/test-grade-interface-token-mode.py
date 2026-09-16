#!/usr/bin/env python3
"""grade-interface token-file 0600 gate (the f809a05f ProbeTokenMode
class): the reviewer conf's token-file must be mode exactly 0600 before
its value is read or sent; anything else exits 1 with a named error.
Mirrors tests/scripts/test-probe-model-route.py ProbeTokenMode."""
import contextlib
import importlib.machinery
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "grade-interface"


def load():
    loader = importlib.machinery.SourceFileLoader("grade_interface_mod", str(SCRIPT))
    spec = importlib.util.spec_from_loader("grade_interface_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class GradeTokenMode(unittest.TestCase):
    def test_too_open_token_file_refused(self):
        """A 0644 token file is fail-closed refused, never read or sent."""
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            tok = Path(td) / "token"
            tok.write_text("tok-secret-1234\n")
            err = io.StringIO()
            with self.assertRaises(SystemExit) as cm, \
                    contextlib.redirect_stderr(err):
                mod.read_token({"token-file": str(tok)})
            self.assertEqual(1, cm.exception.code)
            self.assertIn("0600", err.getvalue())
            self.assertIn(str(tok), err.getvalue())

    def test_tight_token_file_reads(self):
        """The 0600 control: the value comes back for the Bearer header."""
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            tok = Path(td) / "token"
            tok.write_text("tok-secret-1234\n")
            tok.chmod(0o600)
            self.assertEqual("tok-secret-1234",
                             mod.read_token({"token-file": str(tok)}))

    def test_missing_token_file_refused(self):
        """A missing token file is a loud refusal, not a fallback."""
        mod = load()
        with self.assertRaises(FileNotFoundError):
            mod.read_token({"token-file": "/nonexistent/token"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
