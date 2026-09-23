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
import os
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
        text = f"see https://example.com{os.path.expanduser("~")}/page"
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


class PathyStems(unittest.TestCase):
    """Dash-mangled path fragments (the GAP audit shape: a slug arriving
    pre-mangled as `Where-exactly-in-home-bricker-Projects-e` passes
    PATH_TOKEN_RE unchanged and bakes the username into a public id).
    The dash-form family must stay one single-source mechanism with
    router-tick's PATHY_STEMS: home/users/tmp/root case-insensitive +
    the HNGH_ROUTER_PATHY_STEMS deployment-username seam. 2026-09-17
    gate-spec redesign (gap-g2-predicate-false-positives): the bare-
    stem cut was empirically unusable as a gate predicate on real repo
    content (291 committed research lines flagged, every one a prose
    false positive). A stem segment now cuts only when the NEXT dash
    segment is path-shaped (another stem, the deployment username, or
    a PATHY_COMPONENTS vocabulary entry) -- the two-segment shape every
    measured payload id carries (home-bricker-Projects...). A leading
    pathy stem with a path-shaped successor still refuses the whole
    input (""); leading prose ("Users should ...") survives."""

    def setUp(self):
        # capture once in setUp, restore once in tearDown: a
        # self-re-registering addCleanup here would flip-flop forever
        self._orig_stems = os.environ.get("HNGH_ROUTER_PATHY_STEMS")

    def tearDown(self):
        if self._orig_stems is None:
            os.environ.pop("HNGH_ROUTER_PATHY_STEMS", None)
        else:
            os.environ["HNGH_ROUTER_PATHY_STEMS"] = self._orig_stems

    def stem_env(self, val):
        # plain setter; tearDown restores the captured value
        if val is None:
            os.environ.pop("HNGH_ROUTER_PATHY_STEMS", None)
        else:
            os.environ["HNGH_ROUTER_PATHY_STEMS"] = val

    def test_family_is_the_documented_four(self):
        self.assertEqual(scrub.PATHY_STEMS, ("home", "users", "tmp", "root"))

    def test_truncate_cuts_at_first_pathy_dash_segment(self):
        # the exact leaked id stem: cut at the token, prefix survives
        self.assertEqual(
            scrub.scrub_truncate_pathy(
                "Where-exactly-in-home-bricker-Projects-e"),
            "Where-exactly-in-")

    def test_truncate_leading_stem_refuses_to_empty(self):
        # whole-token path-derived: "" is the refuse signal, fail closed
        self.assertEqual(scrub.scrub_truncate_pathy(
            "home-bricker-Projects-etc-hngh"), "")

    def test_truncate_username_stem_via_seam(self):
        self.stem_env("hermituser")
        self.assertEqual(
            scrub.scrub_truncate_pathy("Where-in-hermituser-Dropbox-x"),
            "Where-in-")

    def test_stems_case_insensitive_and_seam_casefolded(self):
        # stems and the seam casefold; the SUCCESSOR must be path-shaped
        # (stem, seam username, or component) -- "bricker" here would be
        # inert under a different pinned username, so successors use the
        # seam username / a component
        self.stem_env("HermitUser")
        for tok, want in (("Where-in-Home-hermituser-x", "Where-in-"),
                          ("review-in-USERS-hermituser-x", "review-in-"),
                          ("x-TMP-Documents-cache", "x-")):
            self.assertEqual(scrub.scrub_truncate_pathy(tok), want)

    def test_innocuous_word_kept_when_not_seam_backed(self):
        # exact segment match only: a plain word that merely CONTAINS a
        # stem ("homework" in "the-homework-question") is kept whole,
        # and the username stem does not widen to prefix words either
        self.stem_env("hermituser")
        self.assertEqual(
            scrub.scrub_truncate_pathy("the-homework-question"),
            "the-homework-question")
        self.assertEqual(
            scrub.scrub_truncate_pathy("hermituserish-thing"),
            "hermituserish-thing")

    def test_plain_token_unchanged(self):
        self.assertEqual(scrub.scrub_truncate_pathy("Which-gate-eats-rc"),
                         "Which-gate-eats-rc")

    def test_multi_token_dash_input_keeps_earlier_tokens(self):
        self.assertEqual(
            scrub.scrub_truncate_pathy(
                "Where-exactly-in-home-bricker-Projects-e do gates die"),
            "Where-exactly-in-")

    # --- 2026-09-17 gate-spec redesign (gap-g2-predicate-false-
    # positives): the sweep gate needs a DISCRIMINATING dash-leak
    # predicate. Positive controls are the three real committed payload
    # ids; negative controls are the top false-positive classes the old
    # bare-stem rule produced when run over the real 278-file sweep
    # domain (291 lines). Measured contract: 0 corpus false positives,
    # 3/3 payload ids caught.

    def test_payload_class_cut_real_ids(self):
        # the real leak class: stem followed by the deployment username
        # / a capitalized path component (username pinned: the real
        # committed payload ids embed this deployment's username)
        self.stem_env("bricker")
        for line, want in (
            ("fail-20260914-Where-exactly-in-home-bricker-Projects-e",
             "fail-20260914-Where-exactly-in-"),
            ("fail-20260916-Do-any-files-in-home-bricker-Projects-et",
             "fail-20260916-Do-any-files-in-"),
            ("fail-20260915-Does-the-file-structure-at-home-bricker-",
             "fail-20260915-Does-the-file-structure-at-"),
        ):
            self.assertEqual(scrub.scrub_truncate_pathy(line), want)

    def test_prose_false_positive_classes_survive(self):
        # the measured false-positive classes: bare stems in English
        # prose and path-component words inside prose; none carries the
        # stem-then-path-shape pair, so none is path-derived. Runs with
        # the config-default username stem active (the gate's env-less
        # condition); the classes must survive under ANY stem set
        self.stem_env(None)
        for line in (
            "adopted -- root cause: the network-down headroom predicate",
            "fixed -- dashboard-server.py now serves the jailed /hngh-docs route",
            "the root cause is rc",
            "use tmp dir for fixtures",
            "users table grows",
            "root-cause-analysis-of-leaks",
            "Users should be able to jump to meaningful landmarks",
        ):
            self.assertEqual(scrub.scrub_truncate_pathy(line), line)

    def test_config_default_username_stem_reaches_gate(self):
        # the sweep gate runs env-less under make test: the deployment
        # username stem must come from the committed config.env default
        # line (whatever it says on this checkout), env unset
        self.stem_env(None)
        default = scrub._config_env_default("HNGH_ROUTER_PATHY_STEMS")
        self.assertTrue(default, "config.env default line missing")
        self.assertIn(default.lower(), scrub.pathy_leak_vocab())
        # the real corpus shape must cut under the config default stem
        payload = ("fail-20260915-Does-the-file-structure-at-home-%s-"
                   % default)
        self.assertNotEqual(scrub.scrub_truncate_pathy(payload), payload)

    def test_stem_needs_path_shaped_successor(self):
        # the discriminating core: a stem without a path-shaped
        # successor is English prose, leading or not; a leading stem
        # WITH a path-shaped successor still refuses the whole input
        self.assertEqual(
            scrub.scrub_truncate_pathy("home-advantage-was-confirmed"),
            "home-advantage-was-confirmed")
        self.assertEqual(scrub.scrub_truncate_pathy(
            "users-bricker-shared-notes"), "")

    def test_component_vocabulary_and_seam(self):
        # the path-shape vocabulary mirrors router-tick's grammar data;
        # HNGH_ROUTER_PATHY_COMPONENTS extends it without code edits
        self.assertIn("projects", scrub.PATHY_COMPONENTS)
        self.assertIn("dropbox", scrub.PATHY_COMPONENTS)
        old = os.environ.get("HNGH_ROUTER_PATHY_COMPONENTS")
        try:
            os.environ["HNGH_ROUTER_PATHY_COMPONENTS"] = "Vault"
            self.assertEqual(
                scrub.scrub_truncate_pathy("in-tmp-Vault-x"), "in-")
            self.assertEqual(
                scrub.scrub_truncate_pathy("in-tmp-Cache-x"),
                "in-tmp-Cache-x")
        finally:
            if old is None:
                os.environ.pop("HNGH_ROUTER_PATHY_COMPONENTS", None)
            else:
                os.environ["HNGH_ROUTER_PATHY_COMPONENTS"] = old

    def test_router_tick_shares_the_mechanism(self):
        # single-source contract: router-tick binds its stem family from
        # lib/scrub.py instead of redefining it. Module identity cannot
        # be asserted across separately-executed copies, so the guard
        # is the binding line itself plus value equality (a reverted
        # re-point resurfaces as either assertion failing).
        src = (ROOT / "scripts" / "router-tick.py").read_text()
        self.assertIn("PATHY_STEMS = _scrub_mod.PATHY_STEMS", src)
        spec = importlib.util.spec_from_file_location(
            "hngh_router_tick_scrubcheck",
            str(ROOT / "scripts" / "router-tick.py"))
        tick = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tick)
        self.assertEqual(tick.PATHY_STEMS, scrub.PATHY_STEMS)
        # functions compare by identity across module copies; compare
        # behavior on the audited leak shape instead
        self.assertEqual(
            tick.scrub_truncate_pathy("Where-exactly-in-home-bricker-x"),
            scrub.scrub_truncate_pathy("Where-exactly-in-home-bricker-x"))

    def test_module_has_stem_constant_for_reuse(self):
        self.assertTrue(hasattr(scrub, "PATHY_STEMS"))
        self.assertTrue(hasattr(scrub, "scrub_truncate_pathy"))


if __name__ == "__main__":
    unittest.main()
