#!/usr/bin/env python3
"""Doc-secrets guard: no credential-shaped strings in tracked files.

Standing gate born from the 2026-09-11 push-protection incident
(sk-or-v1 key committed to docs/research/, caught by GH013 at push).
Scans every git-tracked file in the working tree (git ls-files) for
known key prefixes plus long tokens sitting next to KEY/TOKEN/SECRET
context. Sanctioned placeholder forms ($$CREDENTIAL_...$$, <redacted,
<KEY>) are allowed. Fails naming file:line — never prints the value.
"""

import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

PREFIX_RE = re.compile(
    r"sk-or-v1-[A-Za-z0-9]{8,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{16,}"
    r"|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[bap]-[A-Za-z0-9]{10,}"
)
ALLOW_RE = re.compile(r"\$\$CREDENTIAL_[A-Z0-9]+(:[A-Z]+)?\$\$|<redacted|<KEY>")
# credential assignment: <something KEY/TOKEN/SECRET> = "token"  (env, JSON, yaml, header)
ASSIGN_RE = re.compile(
    r"[A-Za-z_][A-Za-z0-9_]*[._-]?(?:KEY|TOKEN|SECRET)\s*[:=]\s*['\"]?[A-Za-z0-9_-]{32,}")


PLACEHOLDER = "$$" + "CREDENTIAL_ABCDEFGHIJK" + ":M" + "$$"


def scan_text(text):
    """Yield (line_number, kind) hits; never the values themselves.

    Sanctioned placeholder forms are masked out of the line before the
    key/assignment patterns run, so a raw key sharing a line with a
    placeholder (e.g. a redaction note on the same line) is still caught.
    """
    for n, line in enumerate(text.splitlines(), 1):
        residual = ALLOW_RE.sub(" ", line)
        if PREFIX_RE.search(residual):
            yield n, "known-key-prefix"
        elif ASSIGN_RE.search(residual):
            yield n, "credential-assignment"


class SelfTest(unittest.TestCase):
    def test_fixture_key_is_caught(self):
        hits = list(scan_text("OPENROUTER_API_KEY=" + "a" * 40 + "\n"))
        self.assertEqual(hits, [(1, "credential-assignment")])

    def test_prefixes_are_caught(self):
        for prefix in ("sk-or-v1-" + "a" * 20, "sk-ant-" + "a" * 25,
                       "AKIA0123456789ABCDEFGH", "ghp_" + "a" * 25,
                       "xoxb-" + "a" * 15, "sk-" + "a" * 20):
            self.assertEqual(len(list(scan_text(prefix + "\n"))), 1)

    def test_bare_prefix_mentions_are_allowed(self):
        # prose enumerating prefix names must not trip the gate
        self.assertEqual(list(scan_text(
            "(sk-or-v1-, sk-ant-, AKIA, ghp_, xox) plus assignment shapes\n")),
            [])

    def test_shared_line_with_placeholder_is_caught(self):
        # 2026-09-19 evasion: a raw key sharing a line with a <redacted
        # note was blanket-allowed. Masking (not skipping) must catch it.
        line = ("OPENCODE_API_KEY=sk-" + "a" * 20
                + " (separate from OPENROUTER_API_KEY=<redacted>)\n")
        self.assertEqual(list(scan_text(line)), [(1, "known-key-prefix")])

    def test_short_sk_words_are_allowed(self):
        # prose must not trip the generic sk- rule (sk-ant-/sk-or-v1-
        # remain explicit known prefixes)
        self.assertEqual(list(scan_text(
            "uses sk-learn wrappers and scikit-learn fixtures\n")), [])

    def test_placeholders_are_allowed(self):
        self.assertEqual(list(scan_text(
            "OPENROUTER_API_KEY=<redacted 2026-09-11; value lives in "
            "env_vars.sh / 1Password>\n"
            "OPENCODE_API_KEY=" + PLACEHOLDER + "\n")), [])

    def test_plain_prose_is_allowed(self):
        self.assertEqual(list(scan_text(
            "The orchestrator collision risk is high; scheduling wins.\n")), [])


class RepoScan(unittest.TestCase):
    def test_no_secrets_in_tracked_files(self):
        files = subprocess.run(
            ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True,
            check=True).stdout.splitlines()
        bad = []
        self_path = Path(__file__).resolve()
        for rel in files:
            path = ROOT / rel
            if not path.is_file() or path.resolve() == self_path:
                continue  # skip this scanner: its own regex literals are fixture-shaped
            try:
                text = path.read_text(errors="replace")
            except OSError:
                continue
            for n, kind in scan_text(text):
                bad.append("%s:%d (%s)" % (rel, n, kind))
        self.assertEqual(bad, [], "credential-shaped strings found:\n" + "\n".join(bad))


if __name__ == "__main__":
    unittest.main(verbosity=2)
