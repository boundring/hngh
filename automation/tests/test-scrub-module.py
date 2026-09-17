#!/usr/bin/env python3
"""Single-source scrub module contract (llc-gate-scrub-site-divergence,
red-first 2026-09-16): automation/lib/scrub.py is THE one path-token
redaction definition in the tree. Before this module existed, four
independent regex copies drifted (jobs/news-articles.py,
jobs/digest-ledger.py, lib/model.sh inline jq, lib/redact.sh sed) with
two marker conventions; the kernel ledger sink (scripts/report-queue)
is a mirrored sink-side mapping, not a definition.

Canonical decisions recorded here:

- ONE marker: "[redacted path]" (fail-closed, greppable, the python
  and shell seams' existing convention). The kernel ledger sink maps
  the SAME token family to readable tilde markers (~ = /home/<user>,
  ~tmp = /tmp) as a documented per-sink convention via redact_home();
  absolute paths die at both.
- ONE token family: URL-shaped tokens are preserved verbatim EXCEPT
  credential-bearing userinfo (user:pass@host dies to [redacted]@host);
  scheme-relative //host/home/<user>, absolute /home/<user>,
  /Users/<user>, /root, /tmp, and ~/... all die. Bare /home and /tmp
  (no trailing segment) die too. The mid-token guard keeps URL path
  components (https://x.io/home/u/f) and MACRO/home fragments intact.
- scrub_grep: exact MATCH lines only, for alert-crumbs scanning; a
  plain source URL line is not leakage and is not reported; kernel
  ~tmp/... markers are readable conventions, not leakage, and pass.
- Idempotent: scrubbing an already-scrubbed text is a no-op (markers
  and [redacted]@ userinfo survive a second pass).

Hermetic: loads the module by path; no repo or home state."""

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


scrub = _load("hngh_scrub", "lib/scrub.py")
scrub_paths = scrub.scrub_paths
scrub_grep = scrub.scrub_grep
redact_home = scrub.redact_home


class Marker(unittest.TestCase):
    def test_marker_is_the_fixed_fail_closed_marker(self):
        self.assertEqual(scrub.MARKER, "[redacted path]")

    def test_home_path_redacted_to_marker(self):
        self.assertEqual(scrub_paths("see /home/aubergine/dots/vimrc now"),
                         "see [redacted path] now")

    def test_bare_home_and_tmp_die(self):
        self.assertNotIn("/home", scrub_paths("cd /home alone"))
        self.assertNotIn("/tmp", scrub_paths("wrote /tmp then left"))

    def test_mid_token_url_path_component_untouched(self):
        text = "fetched https://x.io/home/u/f and MACRO/home/u ok"
        self.assertEqual(scrub_paths(text), text)


class UrlFamily(unittest.TestCase):
    def test_source_url_preserved_verbatim(self):
        text = "fetched https://example.com/doc and www.example.com/x"
        self.assertEqual(scrub_paths(text), text)

    def test_url_with_home_like_path_component_preserved(self):
        text = "see https://example.com/home/bricker/page"
        self.assertEqual(scrub_paths(text), text)

    def test_userinfo_credentials_die(self):
        self.assertEqual(
            scrub_paths("git https://user:s3cret@example.com/repo"),
            "git https://[redacted]@example.com/repo")

    def test_plain_url_without_userinfo_untouched(self):
        text = "https://example.com/repo"
        self.assertEqual(scrub_paths(text), text)


class AdditionalFamilies(unittest.TestCase):
    def test_users_path_dies(self):
        self.assertNotIn("/Users", scrub_paths("mac /Users/bricker/dots"))

    def test_root_path_dies(self):
        self.assertNotIn("/root", scrub_paths("check /root/.ssh/config"))
        self.assertNotIn("/root", scrub_paths("check /root alone"))

    def test_root_word_not_matched(self):
        text = "the /rooted cause"
        self.assertEqual(scrub_paths(text), text)

    def test_scheme_relative_host_home_dies(self):
        self.assertNotIn("//filesrv",
                         scrub_paths("mount //filesrv/home/aubergine/x"))
        self.assertIn(scrub.MARKER,
                      scrub_paths("mount //filesrv/home/aubergine/x"))

    def test_tilde_path_dies(self):
        self.assertNotIn("~/.hngh", scrub_paths("token at ~/.hngh/x"))

    def test_bare_tilde_and_tmp_marker_survive(self):
        text = "cost ~5, ~tmp/hngh-cer-x.store untouched, home is ~"
        self.assertEqual(scrub_paths(text), text)


class GrepMode(unittest.TestCase):
    def test_only_match_lines(self):
        text = ("ok line\n"
                "leak /home/aubergine/x here\n"
                "url https://example.com/x\n"
                "creds https://u:p@evil.example/x\n")
        self.assertEqual(scrub_grep(text),
                         ["leak /home/aubergine/x here",
                          "creds https://u:p@evil.example/x"])

    def test_kernel_tmp_marker_not_reported(self):
        text = "~tmp/hngh-cer-a.store untouched"
        self.assertEqual(scrub_grep(text), [])

    def test_tilde_path_reported(self):
        self.assertEqual(scrub_grep("see ~/.hngh/db/t.db"),
                         ["see ~/.hngh/db/t.db"])

    def test_empty_and_none(self):
        self.assertEqual(scrub_grep(""), [])
        self.assertEqual(scrub_grep(None), [])


class KernelSinkConvention(unittest.TestCase):
    """redact_home: the tilde mapping the kernel ledger sink uses; the
    family matches scrub_paths, the marker is the readable tilde form."""

    def test_home_and_tmp_tilde(self):
        self.assertEqual(redact_home("see /home/aubergine/dots/vimrc and "
                                     "/tmp/c.store"),
                         "see ~/dots/vimrc and ~tmp/c.store")

    def test_users_root_scheme_relative_tilde(self):
        self.assertEqual(redact_home("/Users/bricker/dots /root/x "
                                     "//filesrv/home/aubergine/y"),
                         "~/dots ~/x ~/y")

    def test_userinfo_redacted(self):
        self.assertEqual(redact_home("https://user:pw@e.io/x"),
                         "https://[redacted]@e.io/x")

    def test_url_home_component_untouched(self):
        self.assertEqual(redact_home("https://e.io/home/u/f"),
                         "https://e.io/home/u/f")


class Hygiene(unittest.TestCase):
    def test_idempotent(self):
        text = ("mixed /home/a/x /Users/b/y /root /tmp/t //h/home/c/d "
                "~/.e https://u:p@e.io/r https://e.io/home/f plain")
        once = scrub_paths(text)
        self.assertEqual(scrub_paths(once), once)

    def test_none_and_empty(self):
        self.assertEqual(scrub_paths(None), "")
        self.assertEqual(scrub_paths(""), "")
        self.assertEqual(redact_home(""), "")


if __name__ == "__main__":
    unittest.main()
