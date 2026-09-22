# 2026-09-20 — gemini burst cap enforcement landed (burst-remediation)

## Assignment

Deep-graph node burst-remediation (part c of the DRIFT
spend-verify-default-path goal), gated on two explore children:

- burst-provenance: verdict intended-but-unlanded. The gemini burst cap
  exists only as configuration (automation/cadence-params.tsv:29-30 rows
  `gemini-burst-max-calls=20` / `gemini-burst-window-s=3600`, landed in
  93af701b1 2026-09-19 15:53; automation/config.env:41-42
  GEMINI_BURST_MAX_CALLS/GEMINI_BURST_WINDOW_S) with zero enforcement
  code: `git log --all -S GEMINI_BURST` touches only that config commit
  and omp snapshot mirrors, and automation/lib/model.sh had no
  reference. The rows name lib/model.sh MODEL_PIN=remote as the
  consumption site; nothing records a deliberate drop.
- burst-cash-ceiling: the remote leg is dormant (no key file, 0
  source=remote telemetry rows) but unguarded on shape: 200/day bounds
  calls, not tokens, and the burst rows were declared as the
  spend-shape control. Recommendation (a): enforce the burst gate in
  the pin=remote path.

## What landed

automation/lib/model.sh:

- New `gemini_burst_blocked()` pacer beside the quota_pace_* family:
  counts telemetry events `kind='model' source='remote'` inside a
  rolling `strftime('now','-N seconds')` window and blocks when
  `used >= cap`. Caps resolve env-first
  (GEMINI_BURST_MAX_CALLS/GEMINI_BURST_WINDOW_S) with
  cadence-params `gemini-burst-max-calls`/`gemini-burst-window-s`
  fallback and hardcoded defaults 20/3600 (same precedence as every
  leg's env-override rule *inside the pacer*). CORRECTION 2026-09-20
  (burst-params-shadowing): that precedence held only inside the pacer
  function. In production, automation/config.env:41-42 pre-set
  GEMINI_BURST_MAX_CALLS=20 / GEMINI_BURST_WINDOW_S=3600 and
  model.sh sources common.sh (which sources config.env) before the
  pacer runs, so the params rows were dead config: editing them had no
  effect, and the true production precedence was env-or-config.env-default
  > (rows unreachable) > default. FIX: the config.env pre-sets were
  dropped (comment-only pointer at the rows, kimi-daily-cap pattern),
  so the rows are authoritative again and the documented env > row >
  default precedence holds end to end. Regression: test 5j (sandbox
  copies the real config.env; tightened rows 5/60 block, env
  override 20/3600 admits). Hard cap only, no soft pace: a burst lane
  has no even-spend contract. Malformed cap or window fails open to
  the rest of the chain (same posture as quota_pace_*'s bad-cap rule).
- The pin=remote branch of `_model_call_impl()` calls the gate BEFORE
  entering remote_chat: block -> breadcrumb -> skip the remote leg ->
  fall through to the local chain inside model_call, so research never
  blocks on quota state (existing pin-miss contract, unchanged).
  `remote_chat()` itself does NOT call the gate (narrowed 2026-09-20,
  blast-radius fix -- see below): it keeps only the key-file gates
  and the shared REMOTE_DAILY_CAP_CALLS daily cap, which all remote
  lanes share.

Counting the shared `source='remote'` stream (not a gemini-only tag)
is deliberate, WITH the 2026-09-20 blast-radius narrowing: the gate is
called ONLY from the pin=remote branch, so muse/feedback remote calls
count toward the gemini window (they can only block the burst lane
EARLY, never admit past the cap - the safe direction for a
spend-shape gate) but the gate NEVER blocks the feedback pin or the
unpinned chain. Those lanes have no 20/hour cap per the routing
policy (docs/design/value-add-routing.md: feedback "allowed within
the shared remote cap", burst rule 1 "only the coding-completions
class has a burst lane", burst rule 3 "paid fallback for blocked T2
is muse-spark-contributor, never the gemini burst lane"); they share
only the 200/day REMOTE_DAILY_CAP_CALLS. This matches the
cash-ceiling recommendation (a) verbatim: "enforce the burst gate in
the pin=remote path". A per-model split (gemini-only telemetry tag)
would need a new telemetry source or model-column filter; not taken
in this slice (see open questions).

BLAST-RADIUS FIX 2026-09-20 (gate audit): as first landed, the gate
was called inside `remote_chat()`, which serves THREE lanes --
pin=remote coding, pin=feedback muse, and the unpinned chain muse
fallback -- so 20 muse/feedback calls in an hour blocked call 21 of
ANY remote lane, throttling the sanctioned volume-judgment lane to
20/hour against its documented 200/day cap, with no test and no
header documentation. Reproduced empirically: 20 seeded
source=remote events made MODEL_PIN=feedback fall to unsloth
(remote stub 0 hits) and the unpinned chain fall to archive-only
(remote stub 0 hits). Fixed by moving the gate call out of
remote_chat into the pin_remote branch; regression tests 5k
(feedback ignores a full burst window) and 5l (unpinned chain
ignores a full burst window) prove the scoping, run red on the old
code (5 failures: feedback fell to unsloth, unpinned fell to
archive-only) and green after.

automation/tests/test-model-pin-routing.sh: cases 5f-5i (fixture-backed,
hermetic, sandbox telemetry):

- 5f window full (20 events at now-2s, cap 20/3600) -> local unsloth
  answers, remote stub never hit.
- 5g below cap (19 events) -> gemini answers.
- 5h window expiry (20 events at now-12s, window 10s) -> gemini
  answers: proves rolling-window, not per-day semantics.
- 5i env unset + sandbox cadence-params rows 20/3600 -> blocked: proves
  the params-file resolution path named by the rows.
- 5k pin=feedback + full burst window (20 events) -> feedback STILL
  answers (remote stub hit): proves the burst gate never throttles the
  feedback lane.
- 5l unpinned chain + full burst window -> remote fallback STILL
  answers (remote stub hit, unsloth never hit): proves the unpinned
  leg never sees the burst gate.

TDD order held: 5f/5i were run red (exact failures: remote stub hit
where "never hit" asserted) before the model.sh change; green after.
5k/5l were run red against the pre-narrowing model.sh (5 failures:
feedback fell to unsloth with 0 remote hits; unpinned fell to
archive-only with 0 remote hits) and green after the narrowing.

## Deliberately not in this slice

- Remote-leg input token guard (ceiling recommendation (b)): separate
  concern, separate slice; the burst cap already bounds call rate.
- The racy count->call->emit TOCTOU on both the daily and burst gates:
  pre-existing shape shared with the kimi/ocgo pacers; fixing it means
  an atomic counter seam for all pacers at once, not a remote-only
  patch.
- Post-intro (2027-01-01) pricing re-rating of the caps: config
  values, operator steering.

## Open questions

- RESOLVED 2026-09-20 (blast-radius fix): muse/feedback traffic still
  COUNTS toward the gemini window (shared source=remote count, the
  safe direction), but the gate no longer BLOCKS muse/feedback lanes --
  it is called only from the pin=remote branch. The remaining question
  (gemini-only telemetry tag to stop muse/feedback from counting at
  all) stays open; current rows say "max gemini coding-pin calls",
  which a strict reading would split, and the shared count implements
  the tighter reading for the gemini lane only.
- Input-token guard threshold for the coding leg (ceiling rec (b)),
  pending a real caller (leg is still dormant).

## Validation

- bash tests/test-model-pin-routing.sh: green, 0 FAIL, including the
  four new cases and the pre-existing rotation/review-transition cases.
- make test (automation gate): full suite green on the committed tree.

## Provenance note

The 2026-09-20 value-add-routing policy record
(docs/records/2026-09-20-value-add-routing-policy.md) states
"automation/cadence-params.tsv and automation/lib/model.sh already
enforce every rung"; that statement was true only after this slice -
the burst rung it cites (gemini 20/3600) had no consuming code before
this landing. This record supersedes that claim retroactively for the
burst rung.
