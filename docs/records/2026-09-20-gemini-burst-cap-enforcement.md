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
  leg's env-override rule). Hard cap only, no soft pace: a burst lane
  has no even-spend contract. Malformed cap or window fails open to
  the rest of the chain (same posture as quota_pace_*'s bad-cap rule).
- `remote_chat()` calls the gate after the key-file gates and before
  the daily cap: block -> breadcrumb + return 1 -> the pin falls
  through to the local chain inside model_call, so research never
  blocks on quota state (existing pin-miss contract, unchanged).

Counting the shared `source='remote'` stream (not a gemini-only tag)
is deliberate: muse/feedback remote calls count toward the gemini
window, which can only block the burst lane EARLY, never admit past
the cap - the safe direction for a spend-shape gate. A per-model split
would need either a new telemetry source or a model column filter; not
taken in this slice (see open questions).

automation/tests/test-model-pin-routing.sh: cases 5f-5i (fixture-backed,
hermetic, sandbox telemetry):

- 5f window full (20 events at now-2s, cap 20/3600) -> local unsloth
  answers, remote stub never hit.
- 5g below cap (19 events) -> gemini answers.
- 5h window expiry (20 events at now-12s, window 10s) -> gemini
  answers: proves rolling-window, not per-day semantics.
- 5i env unset + sandbox cadence-params rows 20/3600 -> blocked: proves
  the params-file resolution path named by the rows.

TDD order held: 5f/5i were run red (exact failures: remote stub hit
where "never hit" asserted) before the model.sh change; green after.

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

- Should muse/feedback stop counting toward the gemini window (a
  gemini-only telemetry tag), or is the conservative shared count the
  intended semantics? Current rows say "max gemini coding-pin calls",
  which a strict reading would split; the shared count implements the
  tighter reading.
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
