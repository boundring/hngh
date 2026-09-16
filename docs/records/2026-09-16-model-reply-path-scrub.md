# 2026-09-16 — model hygiene: output-side path scrub and a no-paths house law for the news lane

## Problem

Open question from the llc-news-prompt-audit (2026-09-16): does
`automation/lib/model.sh` attach any system-prompt-level hygiene law to
the MODEL_PIN local legs (unsloth/ollama) that would discourage echoing
prompt-injected host paths into article bodies, and is
`model_reply`'s fence-strip + `_ascii()` output pass sufficient given
`scrub_paths` now guards the input side?

Findings (both answered in code before editing):

- **No hygiene law exists.** Every leg of the chain builds its request
  through `_json_body()` (lib/model.sh:146-161), which sends a single
  `{"role": "user", "content": prompt}` message; there is no system
  prompt anywhere in model.sh. `automation/jobs/news-articles.py`
  `model_reply()` (then lines 295-336) shells into `model_call`
  through `NEWS_ARTICLES_MODEL_CMD` / the same seam, so the caller owns
  100% of prompt content, including any hygiene law.
- **The output side was unguarded.** `model_reply`'s reply handling was
  fence-strip + `_ascii()` (ASCII-forcing only); `PATH_TOKEN_RE` /
  `scrub_paths` ran only over prompt-side inputs (title, place, ledger
  line, source extract). The input-side scrub cannot stop a model from
  echoing a path token it saw redacted, inferred, or hallucinated, so a
  pathy completion would have shipped verbatim into the article body
  and the public edition.

## What landed

- `automation/jobs/news-articles.py`
  - `build_prompt()` gains a house law in the writing-register block:
    "No host filesystem paths in the prose: never write /home/...,
    /tmp/, or ~/... tokens, even when the data above shows them
    redacted; refer to such items generically ('a local file')." The
    law is deliberately worded WITHOUT the literal `[redacted path]`
    marker so the section-8 exact-marker-count pin stays meaningful
    (the pin counts data-scrub markers, not prompt boilerplate).
  - `model_reply()` now runs the reply through the same seam after the
    fence strip: `text = scrub_paths(_ascii(text)).strip()` — one
    fail-closed redaction pass, ordinary prose untouched, identical
    `PATH_TOKEN_RE` both directions (no second regex to drift).
- `automation/tests/test-news-articles.sh` section 8 extends the
  no-echo pins to the reply: the model seam is stubbed with a pathy
  draft (`/home/...`, `/tmp/...`, `~/.hngh/...` plus kept prose) and
  `model_reply` must return zero tokens of the three kinds, exactly
  three identity-seam markers, and the kept prose. Section header
  comment updated to state both directions and the no-system-prompt
  finding.

## Validation

- Red first: with only the test extended, the suite reported 4 new
  FAILs (`model_reply scrubs echoed /home|/tmp|~/.hngh tokens`,
  `carries the identity-seam markers`) and 1 counted failure; all
  pre-existing checks stayed ok.
- First green attempt caught a real pin regression: wording the house
  law with the literal marker moved the captured-request marker count
  1 -> 11 (`model request carries the redaction marker` FAIL). The law
  was rephrased without the literal; the pin returned to exact.
- Green: `automation/tests/test-news-articles.sh` 0 failures (38 ok),
  `tests/test-news-desk.py` 12 OK, `tests/test-newspaper-window.py`
  6 OK, `tests/test-digest-html.py` OK.
- Shared automation gate (`cd automation && make test`): single failure
  is the pre-existing `test-dashboard-p0.py` PollHygiene case on
  `dashboard/sessions-view.js` (raw `setInterval(`) from a concurrent
  lane's in-flight working tree, documented in the digest-seam record
  the same day and unrelated to this slice. This commit is staged
  file-exact so in-flight lane files never enter it.

## Scope note

The scrub is the news lane's own caller-side backstop. `lib/model.sh`
itself is untouched (it remains a generic single-user-message chain;
adding a system-prompt seam there is a kernel-surface change, out of
this automation slice's scope). Other model_call consumers (research
beat, digest legs) do not get the reply scrub from this change; if the
operator wants the guard chain-wide, that is a follow-up with its own
pins. The no-echo doctrine across seams so far: prompt side
(news-articles `scrub_paths`, 2026-09-16), mega line
(digest-ledger.py, free-commit f84a80cc), public edition
(scripts/generate-publication, ceremony 39814a59), and now the reply
side of the wire desk.
