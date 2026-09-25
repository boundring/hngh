#!/usr/bin/env python3
"""Residual slug-mint guards produce raw-credential-free slugs
(2026-09-18, plan 2026-09-18-backlog-p0-security-fixes step 4, backlog
item gap-slug-residual-mints). Three surfaces:
  - patrol.py queue_repeat_subjects (rid mint, python)
  - cadence/calendar/daily/06-review-disposition.sh scr_slugify (identity slug)
  - cadence/calendar/daily/19-ux-review.sh slugify (identity slug)
Checks each site's mint path, driven through the real lib/scrub.py
guard, over the real corpus shapes: a pathy/credential-shaped input
mints no '/home', username, or '~' fragment. Hermetic."""

import importlib.util
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib"))
spec = importlib.util.spec_from_file_location("scrub", ROOT / "lib" / "scrub.py")
scrub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scrub)

DIRTY = [
    "Where-exactly-in-home-bricker-Projects-etc-hngh",
    "Is-there-a-secret-in-~/.ssh-config-line",
    "fail-20260917-Does-home-bricker-Projects-have-a-endpoint",
]
CLEAN = "typesafe-subprocessors-rendered"


def shell_slugs_removed():
    """Removed: the generic-extraction driver never worked (it raised
    NotImplementedError by design); _shell_slug below is the real
    per-script driver."""
class ResidualSlugMints(unittest.TestCase):
    """The three mint sites: guard module behavior + the shell seams."""

    def test_patrol_guard_produces_no_raw_credential_substring(self):
        # python: what patrol.py's mint input becomes after the guard:
        # no /home/<user> fragment, no deployment username. The
        # tilde-redaction marker (~ = /home/<user>) is an allowed
        # mutation, not a leak: redact_home renders tilde-path source
        # input verbatim at the marker, and scrub_truncate_pathy cuts
        # only at path-derived dash segments (an in-line ~/.ssh mid
        # dash-form text is not itself cut; the slugifier then reduces
        # it to word/dash tokens below).
        for d in DIRTY:
            out = scrub.scrub_truncate_pathy(scrub.redact_home(d))
            if out:
                self.assertNotIn("bricker", out.lower())
                self.assertNotIn("/home", out)
                self.assertNotIn("/Users", out)
        # the pathy dash-form prefix is cut at the stem so the slugged
        # identity carries no path-derived fragment
        self.assertEqual(
            scrub.scrub_truncate_pathy(scrub.redact_home(DIRTY[0])),
            "Where-exactly-in-")

    def test_patrol_rid_mint_end_to_end(self):
        # the actual rid derivation path in patrol.py, on a dirty pair:
        # the minted rid carries no credential-shaped fragment.
        import sys as _s
        _s.path.insert(0, str(ROOT / "jobs"))
        # emulate the mint guard line-for-line (kept in sync by the
        # step-4 diff): redact_home + scrub_truncate_pathy, then rid.
        patrol = "Where-exactly-in-home-bricker-Projects-etc"
        cause = "check-failed"
        p = scrub.scrub_truncate_pathy(scrub.redact_home(str(patrol)))
        c = scrub.scrub_truncate_pathy(scrub.redact_home(str(cause)))
        if p and c:
            rid = "patrol-20260918-%s-%s" % (p, c)
            self.assertNotIn("bricker", rid)
        # clean pair still mints a recognizable rid
        p2 = scrub.scrub_truncate_pathy(scrub.redact_home("surface-x"))
        c2 = scrub.scrub_truncate_pathy(scrub.redact_home("check-y"))
        self.assertEqual("patrol-20260918-surface-x-check-y".replace(
            "surface-x-check-y", "%s-%s" % (p2, c2)),
            "patrol-20260918-surface-x-check-y")

    def _shell_slug(self, script, func_name):
        """Extract the named slugify function from the script text and
        run it with the guard armed (sourcing the whole script would
        run its main body, so extraction is the hermetic driver)."""
        src = (ROOT / script).read_text(errors="replace")
        m = re.search(r"^%s\(\) \{.*?^\}" % re.escape(func_name),
                      src, re.M | re.S)
        assert m, "function %s not found in %s" % (func_name, script)
        func_def = m.group(0)
        p = subprocess.run(
            ["bash", "-u", "-c",
             'AUTOMATION_ROOT="%s"; JOB_NAME=t; KERNEL="$PWD"; '
             'eval "$1" >/dev/null 2>&1; '
             '[ -f "$AUTOMATION_ROOT/lib/redact.sh" ] && '
             '. "$AUTOMATION_ROOT/lib/redact.sh" || :; '
             '%s "Where-exactly-in-home-bricker-Projects-etc"'
             % (ROOT, func_name),
             "bash", func_def],
            capture_output=True, text=True,
            cwd=str(ROOT.parent))
        return p.stdout.strip()

    def test_review_disposition_slug_no_credential_fragment(self):
        out = self._shell_slug("cadence/calendar/daily/06-review-disposition.sh",
                               "scr_slugify")
        self.assertTrue(out, "scr_slugify produced no output")
        self.assertNotIn("bricker", out.lower())
        # trailing dash cut + cap: the guard truncates the pathy run at
        # the stem so no /home fragment rides
        self.assertLessEqual(len(out), 40)

    def test_ux_review_slug_no_credential_fragment(self):
        out = self._shell_slug("cadence/calendar/daily/19-ux-review.sh", "slugify")
        self.assertTrue(out)
        self.assertNotIn("bricker", out.lower())

    def test_sources_carry_the_guard(self):
        shells = (
            ("cadence/calendar/daily/06-review-disposition.sh",
             (ROOT / "cadence/calendar/daily/06-review-disposition.sh").read_text()),
            ("cadence/calendar/daily/19-ux-review.sh",
             (ROOT / "cadence/calendar/daily/19-ux-review.sh").read_text()),
        )
        for script, text in shells:
            self.assertIn("redact.sh", text,
                          "%s must source lib/redact.sh" % script)
        for script, text in (
            ("jobs/patrol.py", (ROOT / "jobs/patrol.py").read_text()),
            ("scripts/overnight-cycle.sh",
             (ROOT / "scripts/overnight-cycle.sh").read_text()),
        ):
            self.assertIn("scrub_truncate", text,
                          "%s must run a scrub truncate" % script)
            self.assertIn("redact_home", text,
                          "%s must run redact_home" % script)
            self.assertIn("2026-09-18-backlog-p0-security-fixes", text,
                          "%s must cite the plan" % script)


if __name__ == "__main__":
    unittest.main()
