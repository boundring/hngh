# 2026-09-16 — chain-wide reply-side path scrub at the model_call chokepoint

## Problem

The llc-model-hygiene-law follow-up (named in
docs/records/2026-09-16-model-reply-path-scrub.md): the news-lane closed
the reply-side no-echo seam ONLY inside jobs/news-articles.py, while
lib/model.sh is sourced by 20+ lanes (research beat, review prep, ux
review, night research, ping, morning digest, overnight cycle, model
bench, the delegation libs). Every one of those lanes feeds
hngh-internal text (research lines with live ~ tokens,
alert identities, lessons tails) into model_call and persists replies
verbatim — the research beat writes $supportive/$response into
digest/RESEARCH-REVIEW-*.md and $body into RESEARCH-BEAT/crystallized
docs that research_commit pushes to the public repo. The local
unsloth/ollama legs contain the blast radius today, but
MODEL_PIN/fall-through reaches the remote opencode/zai/kimi legs.

## Decision: output-side chokepoint, not per-lane scrubs

model_call is the ONE consumer entry every leg answers through, so the
scrub lives there once and every lane inherits it. Two consequences,
both pinned by test:

- Consumers stay untouched (no second regex to drift; same four-branch
  token law news-articles.py scrubs both directions with, ported to a
  single-pass jq gsub: URL-shaped tokens match first and are preserved
  verbatim, /home //tmp ~/ tokens redact to the fixed [redacted path]
  marker, prose kept, bare /home //tmp die too).
- Input hygiene stays with the caller: archive_only still archives the
  raw prompt unmutated, and the research-lines.tsv live paths are a
  prompt-input question (the news lane's house-law wording), not an
  output-seam one.

Boundary check (AGENTS.md): automation/lib/model.sh is automation
free-commit surface, not kernel (kernel = src/, tests/, root Makefile,
hngh.asd), so no ceremony needed. JSON-mode callers: none exist
(_json_body is request-side only), so wrapping model_call breaks
nothing. No consumer reads $MODEL_USED as a shell variable (the wrapper
pipelines the impl in a subshell); all read the file or
last_model_used(). model-bench writes leg replies directly through
unsloth_chat, but its stats/ output is gitignored (no egress); the leg
functions stay unwrapped by design.

## What landed

Landing note: while this slice was being gated, sibling lanes'
`git add -A` sweeps absorbed this slice's uncommitted hunks twice: the
model.sh implementation (whole _scrub_paths + model_call/
_model_call_impl wrapper) rode into the token-mode commit f8b0fe7f,
and the CHANGELOG entry rode into the render-layer commit 1959e2e5
(which also left the duplicated same-day changelog header). This
commit carries the rest of the slice — the red-first suite, its
Makefile registration, and this record — and documents the
attribution so the history is honest.

- automation/lib/model.sh (landed via f8b0fe7f)
  - _scrub_paths(): the PATH_TOKEN_RE port (jq -Rsr single-pass gsub);
    fail-closed: jq absent or failing yields EMPTY output, never leaky
    identity.
  - model_call() becomes the public wrapper: runs the chain
    (_model_call_impl) and scrubs the winning reply; archive-only
    (empty stdout) passes through unchanged; scrub failure yields
    empty with MODEL_USED still naming the leg that answered.
- automation/tests/test-model-reply-scrub.sh (red-first): stub deck leg
  AND stub ollama leg each echo ~, /tmp, ~/.hngh, bare
  /home //tmp, and a URL through model_call — both must come back
  exactly scrubbed (markers in, URL verbatim, prose kept, truncation
  flag preserved); archive-only contract intact (empty stdout, raw
  prompt archived unmutated).
- Research-beat spot-audit (deliverable): reply persistence paths are
  $body (RESEARCH-BEAT + crystallized docs) and $supportive/$response
  (RESEARCH-REVIEW docs + dispositions columns) — ALL flow from
  model_call captures, so the chokepoint covers them; no per-file scrub
  pinned there. Residual known inputs (caller-side "Line: $line"
  headers echoing research-lines.tsv verbatim) are input-side and
  already published verbatim in the committed TSV — left for the
  input-hygiene follow-up, not silently absorbed here.

## Validation

- Red first: the new suite reported exactly 2 output-side FAILs (deck +
  ollama legs, pathy echo verbatim) with all contract pins green.
- One real catch during green-up: -Rs vs -Rsr jq flags (slurp alone
  JSON-parses the raw input -> parse error); the fail-closed posture
  surfaced it as empty output instead of a leak.
- Neighbor suites green: model deck/kimi/ocgo legs, pin routing,
  demote, unsloth context guard, news articles (its section-8 reply
  pins unaffected: the caller-side scrub now redacts nothing new on
  that lane since model_call already did).
- Full automation gate green on an isolated HEAD+this-slice worktree
  (two UNRELATED dirty lanes in the shared tree are not this slice's:
  test-dashboard-p0 timer-hygiene on a sibling's sessions-view.js hunk
  -- mechanical HnghPoll.start fix applied in their file, uncommitted;
  and llc-gate-render-layer-scrub's own red-first digest-html work,
  left exactly as found, one test red mid-flight in their lane).
