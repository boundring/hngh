#!/usr/bin/env python3
"""lint-home-paths scanner contract, hermetic (no git, no repo state).

The violation string is DERIVED at runtime from
pathlib.Path.home().name: a hardcoded login here would trip the guard
itself (the guard runs over this file too). Fake-login fixtures
(/home/aubergine, /home/testuser, /home/bri) and URL wire data
(https://x.io/home/u/f) are deliberately legal - the scrubber's test
vocabulary."""

import contextlib
import importlib.util
import io
import pathlib
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


checker = _load("lint_home_paths", "scripts/lint-home-paths.py")

HOME = pathlib.Path.home().name
REAL = f"/home/{HOME}/x"  # derived at runtime, never hardcoded


def deflated_zip(files):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for member, body in files.items():
            zf.writestr(member, body, compress_type=zipfile.ZIP_DEFLATED)
    return buf.getvalue()


class CleanContent(unittest.TestCase):
    def test_prose_without_home_paths_passes(self):
        self.assertEqual(checker.scan_payload("notes.txt", b"plain prose\n"), [])


class RealLogin(unittest.TestCase):
    def test_real_home_string_is_a_violation(self):
        lines = checker.scan_payload("f.txt", REAL.encode())
        self.assertEqual(len(lines), 1, lines)
        self.assertTrue(lines[0].startswith("f.txt: line 1: "), lines)


class LegalFakes(unittest.TestCase):
    """Fixture logins and URL wire data survive by design."""

    def test_fixture_logins_pass(self):
        for text in ("/home/<user>", "/home/$HOME", "/home/aubergine"):
            self.assertEqual(checker.scan_payload("f.txt", text.encode()), [], text)

    def test_url_wire_data_passes(self):
        self.assertEqual(checker.scan_payload("f.txt", b"https://x.io/home/u/f"), [])

    def test_other_accounts_not_flagged(self):
        # boundary: [A-Za-z0-9._-] after the login means another account
        # (/home/<me>-2), never the real home
        for text in (f"/home/{HOME}-2/x", f"/home/{HOME}2/x", f"/home/{HOME}.bak"):
            self.assertEqual(checker.scan_payload("f.txt", text.encode()), [], text)


class ZipPayloads(unittest.TestCase):
    def test_deflated_member_body_leak_fails(self):
        # the memoir-epub class: deflate hides the leak from the raw
        # bytes, only the decompressed member body carries it
        data = deflated_zip({"chapter.xhtml": f"see {REAL} now".encode() + b" " * 256})
        self.assertNotIn(REAL.encode(), data,
                         "fixture must hide the leak from a raw scan")
        self.assertEqual(checker.scan_payload("book.epub", data),
                         ["book.epub:chapter.xhtml: zip-member hit"])

    def test_member_name_leak_fails(self):
        data = deflated_zip({f"leak{REAL}": b"body"})
        self.assertIn(f"book.epub:leak{REAL}: zip-member hit",
                      checker.scan_payload("book.epub", data))

    def test_clean_zip_passes(self):
        self.assertEqual(checker.scan_payload("book.epub",
                                              deflated_zip({"a.txt": b"ok"})), [])

    def test_unparseable_pk_payload_fails_closed(self):
        self.assertEqual(checker.scan_payload("junk.bin", b"PK\x03\x04not-a-zip"),
                         ["junk.bin: unparseable PK payload"])


class Report(unittest.TestCase):
    def run_lint(self, payloads):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = checker.lint(iter(payloads))
        return code, out.getvalue(), err.getvalue()

    def test_clean_reports_clean_and_exits_0(self):
        self.assertEqual(self.run_lint([("f.txt", b"ok")]),
                         (0, "lint-home-paths: clean\n", ""))

    def test_leak_reports_failure_line_and_exits_1(self):
        code, _out, err = self.run_lint([("f.txt", REAL.encode())])
        self.assertEqual(code, 1)
        self.assertEqual(err.splitlines()[-1],
                         "lint-home-paths: 1 location(s) leak the real home path")


if __name__ == "__main__":
    unittest.main(verbosity=2)
