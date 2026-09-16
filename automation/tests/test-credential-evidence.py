#!/usr/bin/env python3
"""lib/credential-evidence.py contract, hermetic (key-rotation-freshness rung).

Contracts: check() refuses (fail-closed) a missing ledger, stale rows,
hash-mismatched evidence, missing evidence files, and malformed rows;
record() writes a private (0600) replace-by-name digest-only row that a
subsequent check verifies. Fresh + verified rows report `ok`. CLIs print
`<class>: <name> ...` findings and exit 0 always.
"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    return subprocess.run(
        [sys.executable, "-B", str(ROOT / "lib" / "credential-evidence.py"), *args],
        capture_output=True, text=True,
    )


class CredentialEvidence(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.evidence = self.tmp / "evidence.txt"
        self.evidence.write_text("scan-body\n")

    def cli(self, *args):
        return run(*args)

    def test_missing_ledger_refuses(self):
        out = self.cli("check", str(self.tmp / "absent.tsv"), "604800", "--now", "1000")
        self.assertIn("ledger-missing:", out.stdout)

    def test_record_makes_private_verified_row(self):
        ledger = self.tmp / "fresh.tsv"
        r = self.cli("record", "unsloth-session", str(self.evidence),
                     str(ledger), "--now", "1000")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(ledger.stat().st_mode & 0o777, 0o600)
        out = self.cli("check", str(ledger), "604800", "--now", "1000")
        self.assertIn("ok: unsloth-session", out.stdout)

    def test_stale_row_refuses(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "stale.tsv"
        ledger.write_text(
            f"unsloth-session\t0\t0\t{digest}\t{self.evidence}\n")
        out = self.cli("check", str(ledger), "600", "--now", "2000")
        self.assertIn("stale: unsloth-session", out.stdout)

    def test_hash_mismatch_refuses(self):
        ledger = self.tmp / "fresh.tsv"
        self.cli("record", "unsloth-session", str(self.evidence),
                 str(ledger), "--now", "1000")
        self.evidence.write_text("tampered\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1100")
        self.assertIn("hash-mismatch: unsloth-session", out.stdout)

    def test_missing_evidence_refuses(self):
        ledger = self.tmp / "fresh.tsv"
        self.cli("record", "unsloth-session", str(self.evidence),
                 str(ledger), "--now", "1000")
        self.evidence.unlink()
        out = self.cli("check", str(ledger), "604800", "--now", "1100")
        self.assertIn("evidence-missing: unsloth-session", out.stdout)

    def test_malformed_row_refuses(self):
        ledger = self.tmp / "bad.tsv"
        ledger.write_text("garbage-line-not-tables\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1000")
        self.assertIn("malformed-row:", out.stdout)


if __name__ == "__main__":
    unittest.main()
