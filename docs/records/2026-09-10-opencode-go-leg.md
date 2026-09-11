# 2026-09-10 -- OpenCode Go wired as the fourth quota leg (5h-window pacing)

Operator-directed 2026-09-10 ("needs to get set up... ASAP", naming the
OpenCode Go leg and its wiring): OpenCode Go T2 GLM subscription becomes
the fourth quota leg in lib/model.sh, balanced like the kimi leg. The
operator's direction names this exact action and target, satisfying the
provider-configuration instruction rule (docs/records/2026-09-09-budget-
governance-directive.md guardrails; AGENTS.md boundary).

## What landed

- cadence-params.tsv rows `opencode-url` / `opencode-model` /
  `opencode-cap-5h-calls` (60) / `opencode-research-share` (3); empty or
  absent = leg skipped fail-closed.
- `ocgo_chat` + `_ocgo_leg` in automation/lib/model.sh: chat-completions
  shape, Bearer auth (env OPENCODE_API_KEY -> mode-600 key file
  ~/.config/hngh/opencode-key), shared _post_chat MODEL_TIMEOUT (same
  semantics as remote_chat/kimi), calls-based pacing via the new
  `quota_pace_blocked_5h`. The Go gateway REQUIRES a stable
  `x-opencode-session` id per conversation (enforced 2026-09-06; the first
  live POST without it read 400 `MissingSessionID`) -- hngh calls are
  one-shot, so each call sends a fresh random `hngh-<hex>` id; the shared
  _post_chat grew an optional session-header parameter for this.
  Default model is glm-5.3-flash: it carries the $60/mo Go limit (=
  $12/5h bucket, matching R3's arithmetic); glm-5.3 itself is only $15/mo.
- R3 tightest-window pacing implemented (docs/research/2026-09-10-
  passthrough-and-quota-interleaving.md s4): the trailing-5h window counts
  telemetry (kind=model, source=ocgo) against the cap with a soft-pace
  line; no daily-cap pacer, no cost-tracking subsystem. Arithmetic:
  ~$0.005 per bounded glm-5.3-flash call -> 60 calls/5h ~= $0.30 vs the
  $12/5h bucket (40x margin).
- Chain position: unsloth -> remote -> ollama -> deck -> kimi -> **ocgo**
  -> lobehub -> archive-only; MODEL_PIN=ocgo supported; research beat
  rotation pins ocgo after the kimi cycle (33-research-beat.sh).
- credential-health section 6: one Bearer-authenticated /models probe
  (same resolution as the real call); test-probe-hygiene.sh extended to
  gate `ocgo_models_url`.
- Test: automation/tests/test-model-ocgo-leg.sh (hermetic, stubbed
  endpoints/keys) -- written first, red, then implementation; covers
  unarmed skip, model gate, body shape, key-file modes, 5h pace block +
  fall-through, out-of-window events ignored, hard cap, helper boundaries,
  dead endpoint, pin routing. Caught two real bugs pre-live: the 5h SQL
  threshold must be strftime T-formatted, not datetime (space-prefixed
  same-date events compare >= any same-day threshold), and the gateway's
  mandatory session header (found live, not by the stub -- the hermetic
  stubs do not check headers; the production probe-hygiene lint still
  guards the credential path).

## Verify

make test green (rc=0, includes test-model-ocgo-leg); hermetic env -i
green; probe-hygiene contract passed; one bounded live call to the real
endpoint (single POST, --max-time 30, max_tokens small, key from its real
resolution path, never printed) returned HTTP 200-completed. See
automation/docs/OPENCODE-GO.md for leg semantics and pacing math.

2026-09-10 amendment after live check: the first live POST (no session
header) read 400 MissingSessionID at 0.45s; with
`x-opencode-session: hngh-<hex>` the same bounded POST (glm-5.3-flash,
max_tokens 16) read 200 completed at 0.67s (usage 19+3 tokens), and the
Bearer-only GET /v1/models health-probe path read 200. Full `make test`
red count is 2, both in tests/test-plan-acceptance.py OmpBridge --
confirmed the sibling's in-flight scripts/omp-bridge bare-slug work
(step3-bridge), not this change.