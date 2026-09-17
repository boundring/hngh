# 2026-09-17 — routed-slug census definition pinned: "pathy" = OS path fragments; 2026-09-02 hngh-automation routed plan waived with record

Lane: machine free-commit (docs + automation CHANGELOG pointer; no
behavior change). Closes GAP D from the wiki-health-wiring-reconcile
gate (router-tick-slug-census follow-up): the challenge read the
2026-09-02 routed plan's repo-prose slug as a pathy miss against commit
6762dcfa's "zero pathy tokens" census claim.

## The challenged file

docs/project/plans/2026-09-02-routed-review-hngh-automation-P1-STATE-md-contains-absolute-.plan.md
is a router-emitted candidate (front matter line 1:
`routed-from=review:hngh-automation:P1-STATE-md-contains-absolute-`,
accepted 2026-09-02T10:01:26Z, executed 2026-09-08T02:44:00Z),
git-tracked and pushed (landed via 37051774 / 77d4a897, both reachable
from origin/main). The GAP D brief quoted the routed-from as
`review:hngh:P1-STATE-md-contains-absolute-`; the actual value carries
the repo token `hngh-automation`.

Identity decomposition: `review` (class) : `hngh-automation` (sibling
repo name) : `P1-STATE-md-contains-absolute-` (alert subject prose,
dash-mangled from "P1: `STATE.md` contains absolute ..."). No OS path
fragment anywhere: no home-/Users-stemmed token, no username, no
machine-local dot-dir. The only `~/...` text in the file is
the plan's quoted alert evidence — the finding it was routed to fix
(STATE.md absolute paths), fixed forward on 2026-09-08 (automation
commit e18630e) with the recorded precedent "historical rows left
as-is".

## Census definition (now explicit)

"pathy" = dash-mangled OS path fragments: home-/Users-stemmed tokens,
usernames (bricker), machine-local dot-dirs (.hngh, .config,
.llm-wiki), slash-derivable segments. Repo-name tokens (hngh,
hngh-automation, omp, ocgo) and alert subject prose are NOT pathy: they
are operator-intended public context — the repo is public and the alert
subject is the working signal text. Under this definition 6762dcfa's
census claim ("zero pathy tokens in routed plan filenames,
front-matter, router STATE.md rows") is correct; the GAP D challenge
misclassified repo-prose as pathy. The definition was implicit until
now; this record pins it.

Re-scan under the pinned definition (2026-09-17): zero routed plan
filenames or routed-from values contain home-/Users/username/dot-dir
fragments (grep of docs/project/plans/ = 0 matches).

## Disposition: WAIVE-WITH-RECORD (no rename, no routed-from rewrite)

- No private token is present, so back-redaction has nothing to remove.
- A rename would orphan the referencing surfaces for zero privacy
  gain: docs/project/reports.md:661,666,1404, three
  docs/project/report-bodies/2026-09-02T10:00:45Z / 10:01:26Z /
  2026-09-08T02:42:16Z progress files, and
  automation/dashboard/plans.json:834 — historical ledger rows of an
  executed ceremony artifact. docs/project/plans/README.md and
  automation/scripts/accept-plans.py / plan-dispose.py reference
  nothing by this filename.
- Precedent: the plan's own 2026-09-08 execution record left
  historical rows as-is; the 2026-09-16 cred-argv dispositions record
  fixed forward-only. Renaming executed ceremony artifacts is a
  history rewrite in spirit.

## Re-fire check (requested conditionally; recorded since the waiver forecloses the rename)

The router dedup regexes live at automation/scripts/router-tick.py:182
(expire_stale_candidates) and :250 (live_duplicate) — both
`^\d{4}-\d{2}-\d{2}-routed-<ident>(-\d+)?.plan.md$` with ident = the
colon-sanitized identity. (The :157/:225 anchors in the challenge text
have drifted.) Executable check (see Verification): (a)
scrub_pathy_identity (:69) leaves this identity unchanged — no
home/Users stems; (b) the regex built from the identity matches the
existing filename, so a hypothetical future identical alert WOULD
name-match this file; but (c) status=executed is in TERMINAL_STATUS
(:103), skipped by expiry (:203) and live-dup (:262), so the file can
never be expired, re-drafted, or mutated — at most a fresh candidate
would be minted for a new day. That is impossible anyway: the
underlying finding was fixed 2026-09-08 and the STATE.md writer guards
(tests/test-breadcrumbs.sh) prevent recurrence. A rename would not
change any of this: dedup keys on identity, not the historical
filename.

Verification: importlib module check on
automation/scripts/router-tick.py — scrub_pathy_identity returns the
identity unchanged; both dedup regexes match the existing filename;
"executed" in TERMINAL_STATUS; automation/tests/test-router-tick.py
green.
