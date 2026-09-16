#!/usr/bin/env python3
"""lib/credential-evidence.py contract, hermetic (key-rotation-freshness rung).

Contracts: check() refuses (fail-closed) a missing ledger, stale rows,
hash-mismatched evidence, missing evidence files, malformed rows,
duplicate rows, and negative or future-dated rotate epochs; record()
writes a private (0600, re-chmodded on every write) replace-by-name
digest-only row that a subsequent check verifies, and stamps the CURRENT
time when the epoch arg is 0 or absent (an unparsable clock must never
mint the epoch-0 stale row). Fresh + verified rows report `ok`. CLIs
print `<class>: <name> ...` findings and exit 0 always on check; argv
errors exit nonzero with the reason on stderr.

The production argv shapes emitted by jobs/credential-health.sh (record
NAME PATH LEDGER EPOCH and check LEDGER OLA, no --now) are first-class
regression cases (2026-09-16: the rung shipped dead — the positional
epoch was ignored (stored 0) and no --now made check crash on os.time(),
while the job discarded stderr, so the leg silently did nothing).
"""

import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args, cwd=None):
    return subprocess.run(
        [sys.executable, "-B", str(ROOT / "lib" / "credential-evidence.py"), *args],
        capture_output=True, text=True, cwd=cwd,
    )


class CredentialEvidence(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.evidence = self.tmp / "evidence.txt"
        self.evidence.write_text("scan-body\n")

    def cli(self, *args, cwd=None):
        return run(*args, cwd=cwd)

    # --- original contract tests (--now shapes) ---

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

    # --- production argv shapes (jobs/credential-health.sh:58,:182) ---

    def test_production_record_shape_stamps_real_epoch(self):
        # record NAME EVIDENCE LEDGER EPOCH  (positional epoch, no --now)
        epoch = int(time.time())
        ledger = self.tmp / "fresh.tsv"
        r = self.cli("record", "unsloth-session", str(self.evidence),
                     str(ledger), str(epoch))
        self.assertEqual(r.returncode, 0, r.stderr)
        row = ledger.read_text().splitlines()[0].split("\t")
        self.assertEqual(row[0], "unsloth-session")
        self.assertEqual(row[1], str(epoch), "rotate epoch must be the argv epoch")
        self.assertEqual(row[2], str(epoch), "scan epoch stamped at record time")
        self.assertEqual(ledger.stat().st_mode & 0o777, 0o600)
        out = self.cli("check", str(ledger), "604800", "--now", str(epoch + 60))
        self.assertIn("ok: unsloth-session", out.stdout)

    def test_production_check_shape_uses_live_time(self):
        # check LEDGER OLA  (no --now): live time, no crash, clean row = ok
        epoch = int(time.time()) - 60
        ledger = self.tmp / "fresh.tsv"
        self.cli("record", "unsloth-session", str(self.evidence),
                 str(ledger), str(epoch))
        r = self.cli("check", str(ledger), "604800")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stderr, "", "check must not traceback")
        self.assertIn("ok: unsloth-session", r.stdout)

    def test_production_check_shape_fires_stale(self):
        # the 2026-09-16 interaction: a junk epoch-0 row must yield a
        # stale finding through the exact production check shape.
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "stale.tsv"
        ledger.write_text(f"unsloth-session\t0\t0\t{digest}\t{self.evidence}\n")
        r = self.cli("check", str(ledger), "604800")
        self.assertEqual(r.returncode, 0)
        self.assertIn("stale: unsloth-session", r.stdout)

    # --- record stamps "now" on 0/absent epoch (storm-row prevention) ---

    def assert_stamps_now(self, ledger, *args):
        before = int(time.time())
        r = self.cli(*args)
        self.assertEqual(r.returncode, 0, r.stderr)
        row = ledger.read_text().splitlines()[0].split("\t")
        for field in (row[1], row[2]):
            self.assertGreaterEqual(int(field), before - 5)
            self.assertLessEqual(int(field), int(time.time()) + 5)

    def test_record_epoch_zero_stamps_now(self):
        ledger = self.tmp / "fresh.tsv"
        self.assert_stamps_now(ledger, "record", "unsloth-session",
                               str(self.evidence), str(ledger), "0")
        out = self.cli("check", str(ledger), "604800")
        self.assertIn("ok: unsloth-session", out.stdout)

    def test_record_missing_epoch_stamps_now(self):
        ledger = self.tmp / "fresh.tsv"
        self.assert_stamps_now(ledger, "record", "unsloth-session",
                               str(self.evidence), str(ledger))
        out = self.cli("check", str(ledger), "604800")
        self.assertIn("ok: unsloth-session", out.stdout)

    # --- strict epoch parsing: fail-closed, stderr visible ---

    def test_record_bad_epoch_fails_closed(self):
        ledger = self.tmp / "fresh.tsv"
        r = self.cli("record", "unsloth-session", str(self.evidence),
                     str(ledger), "not-an-epoch")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("epoch", r.stderr.lower())
        self.assertFalse(ledger.exists(), "refused record must not write a ledger")

    def test_check_bad_now_fails_closed(self):
        r = self.cli("check", str(self.tmp / "absent.tsv"), "604800",
                     "--now", "not-an-epoch")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("epoch", r.stderr.lower())

    # --- mode 600 applies to re-records too (creation-only 0600 caveat) ---

    def test_record_rechmods_preexisting_ledger(self):
        ledger = self.tmp / "fresh.tsv"
        ledger.write_text("")
        ledger.chmod(0o644)
        r = self.cli("record", "unsloth-session", str(self.evidence),
                     str(ledger), "--now", "1000")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(ledger.stat().st_mode & 0o777, 0o600)

    # --- evidence-path trust: absolute, or beside the ledger ---

    def test_record_refuses_foreign_relative_evidence(self):
        other = Path(tempfile.mkdtemp())
        ledger = self.tmp / "fresh.tsv"
        r = self.cli("record", "unsloth-session", "evidence.txt",
                     str(ledger), "--now", "1000", cwd=other)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("evidence-missing", r.stderr)
        self.assertFalse(ledger.exists())

    def test_record_accepts_relative_beside_ledger(self):
        ev = self.tmp / "rel-evidence.txt"
        ev.write_text("scan-body\n")
        r = self.cli("record", "unsloth-session", "rel-evidence.txt",
                     str(self.tmp / "fresh.tsv"), "--now", "1000",
                     cwd=tempfile.mkdtemp())
        self.assertEqual(r.returncode, 0, r.stderr)
        out = self.cli("check", str(self.tmp / "fresh.tsv"), "604800")
        self.assertIn("ok: unsloth-session", out.stdout)

    def test_check_rejects_foreign_relative_path_row(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "fresh.tsv"
        ledger.write_text(
            f"unsloth-session\t1000\t1000\t{digest}\tevidence.txt\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1000",
                       cwd=tempfile.mkdtemp())
        self.assertIn("evidence-missing: unsloth-session", out.stdout)

    # --- additional fail-closed classes ---

    def test_check_future_rotate_epoch_refuses(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "future.tsv"
        ledger.write_text(
            f"unsloth-session\t2000000\t1000\t{digest}\t{self.evidence}\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1000")
        self.assertIn("malformed-row: unsloth-session", out.stdout)

    def test_check_negative_rotate_epoch_refuses(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "negative.tsv"
        ledger.write_text(
            f"unsloth-session\t-5\t-5\t{digest}\t{self.evidence}\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1000")
        self.assertIn("malformed-row: unsloth-session", out.stdout)

    def test_check_duplicate_row_fails(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "dup.tsv"
        ledger.write_text(
            f"unsloth-session\t1000\t1000\t{digest}\t{self.evidence}\n"
            f"unsloth-session\t1000\t1000\t{digest}\t{self.evidence}\n")
        out = self.cli("check", str(ledger), "604800", "--now", "1000")
        self.assertIn("duplicate-row: unsloth-session", out.stdout)
        self.assertIn("ok: unsloth-session", out.stdout)

    def test_check_ola_zero_disables_stale_only(self):
        import hashlib
        digest = hashlib.sha256(self.evidence.read_bytes()).hexdigest()
        ledger = self.tmp / "ola0.tsv"
        ledger.write_text(
            f"unsloth-session\t0\t0\t{digest}\t{self.evidence}\n")
        out = self.cli("check", str(ledger), "0", "--now", "2000")
        self.assertNotIn("stale:", out.stdout)
        self.assertIn("ok: unsloth-session", out.stdout)


if __name__ == "__main__":
    unittest.main()
