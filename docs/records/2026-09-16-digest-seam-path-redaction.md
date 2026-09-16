# 2026-09-16 — digest seam: path redaction on the mega line and the public edition

## Problem

Digest seam audit 2026-09-16: `automation/jobs/digest-ledger.py` passed
host-derived text through `_ascii()` (ASCII-forcing only, no redaction)
into the "NEWS FROM THE MEGASTRUCTURE" mega line:

- `posture()` rows — STATE.md alert crumbs with pipe-split free text;
- `operator_items()` — `dashboard/operator-items.json` item text.

A pathy crumb or item (home-rooted, `/tmp/`, or tilde path tokens)
therefore reached deck B of the digest HTML (`jobs/digest-html.py`
renders the ledger block verbatim) with the path intact. The same
unredacted pool fed `scripts/generate-publication` `story_section()`,
which quotes a deck A digest item `[:140]` into the journal/public
edition — also unscrubbed. Both surfaces are public-facing (deck B via
the dashboard, the edition via the committed dispatch), so host
filesystem layout echoed into them.

## What landed

- `automation/jobs/digest-ledger.py` — `scrub_paths()` added next to
  `_ascii()`: the same identity seam as `news-articles.py`
  (`PATH_TOKEN_RE`: home-rooted, tmp, and tilde tokens to
  `[redacted path]`, fail-closed marker, ordinary prose untouched,
  nothing dropped). Applied at the two format sites: the operator-item
  `newest[:80]` quote and the posture `crumbs[-1][3][:70]` quote, both
  inside the existing `_ascii()` call so the ASCII guarantee is
  unchanged. Automation leg, free-commit `f84a80cc` (pushed).
- `scripts/generate-publication` — the deck A "loudest line" quote
  `[:140]` now routes through `dl.scrub_paths(...)`, so the public
  edition and deck B cannot disagree about the seam (the ledger module
  is the single source of truth for the guard). Kernel leg, ceremony
  candidate `39814a59` (hash `8193f94f...`).
- Tests, written red first:
  - `automation/tests/test-digest-html.py` `BuilderTest.
    test_build_block_scrubs_path_tokens` — a pathy STATE.md crumb and
    operator item render into the mega line; asserts zero path tokens
    of the three kinds, exactly three `[redacted path]` markers (one
    per token), and that the rows are kept (`1 open of 1`,
    `1 alert crumbs today`) — redaction, not dropping. Fully hermetic:
    every feed passed through the `feeds` seam. (Before the hermetic
    fix the red run accidentally proved the live bug: the day's real
    STATE.md crumb carried a home-rooted path into the block.)
  - `tests/scripts/test-generate-publication.py` `StoryDeckAScrub.
    test_story_deck_a_quote_scrubs_paths` — a pathy CRITICAL digest
    item is quoted into `story_section()` output with all three token
    kinds redacted and the quote kept (count + `drift in` marker
    asserted). The fixture builds the home-rooted token by
    concatenation because committed kernel content may not carry the
    literal token (the verify-candidate public-content gate, the same
    gate the scrub guard serves).

## Validation

- Red: both new tests failed on the home-rooted token present in the
  rendered output before the guards landed.
- Green: `automation/tests/test-digest-html.py` 13/13 OK;
  `tests/scripts/test-generate-publication.py` 7/7 OK; the kernel gate
  (`make test`) exit 0 with both guards and both tests in the tree.
- The shared automation gate (`cd automation && make test`) carried a
  pre-existing failure in `automation/dashboard/sessions-view.js` (raw
  `setInterval(` vs the poll-hygiene rule) from a concurrent lane's
  in-flight working tree; it is unrelated to this slice, and this
  slice's automation commit was staged file-exact so the lane's
  in-flight files never entered it.

## Landing note

The kernel leg landed in two ceremony candidates: `39814a59` bound the
production guard (`scripts/generate-publication`) alone — the first
invocation crashed in the sbcl script loader on a punctuation-heavy
objective string and committed nothing; the recovery invocation used a
plain objective and bound only the guard file. This record and the
kernel-side test complete the slice in the follow-up candidate.
Lessons filed: ceremony objectives should be plain ASCII prose without
parenthetical quotes or dashes; every `--ceremony` invocation is real
(there is no dry-run mode through the bridge wrapper); kernel
candidates must satisfy the public-content gate, so path-token
fixtures are built by concatenation, never committed as literals.
