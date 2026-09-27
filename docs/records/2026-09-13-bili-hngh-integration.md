# 2026-09-13 bili-hngh integration -- the decision document (Slice A S3)

Filed by the governed-fleet slice A landing (plan
`governed-fleet-consolidation`, 2026-09-27 execution). The design
surface is docs/design/governed-fleet.md (sections 1-2, 6, 10); this
record cites the decisions and evidence, it does not restate the
design.

## The decision: the context proxy joins the fleet as bili

The billion-context proxy (the operator's compression middlebox, the
"bili" context proxy of the interim stream) is admitted as a governed
companion service under the section-2 one-pattern: **declared in a
registry, enforced by a guard, watched by a patrol, mutated only
through the certificate loop.**

1. **Declared** -- automation/config/hngh-services.tsv gains the bili
   row (disposition=operator-run, managed-by=operator): the proxy is a
   transient per-launch child. The operator's interactive fish
   wrappers (`command bili omp --`, 2026-08-24
   context-budget-and-toolchain decision), the `bili-jcode` wrapper
   (~/.local/bin/bili-jcode, delegating to the native `bili jcode`
   launcher since bili >= 0.1.110, 2026-09-14), and the machine's
   automation/lib/launch-session.sh spawns (omp branch line ~489, the
   opencode-branch env-only MITM redirect per
   docs/records/2026-09-11-bili-opencode.md) each keep a
   `bili <verb>` process alive for the launch duration. There is no
   fixed health URL to poll and no start-command `service-mgmt.sh`
   would ever exec -- an empty health-url/start-command row keeps the
   service-health and service-children patrols honest instead of
   manufacturing permanent service-down/transient-left-running
   findings.
2. **Guarded** -- the install lane is guarded by
   automation/tests/test-bctx-canary.sh (billion-context@npm-global
   updates via scripts/hngh-omp-update.sh; the deprecated
   billion-context-omp/-pi installs stayed retired) and the registry
   shape by automation/tests/test-hngh-services.py. The bili-spawn
   behavior itself stays guarded by test-bctx-launch.py
   (present -> routes through bili; absent -> uncompressed launch with
   a visible breadcrumb, fail-open by design -- a launch never fails
   because compression is missing).
3. **Watched** -- the watch is the section-2 spawn-path/seam patrol
   expression: jobs/security-check.sh (4h tier) breadcrumbs
   `b_ok` (0/1: a `billion-context` binary on PATH keeping a
   `bili start|omp|opencode|jcode` process alive). It is recorded
   state, never an alert: 0 means the leg went uncompressed with its
   own visible trail, which is the designed fail-open posture, not a
   fault.

## Slice A execution (2026-09-27 session)

- **S1 -- tokens_cached capture, telemetry.py FIRST, then model.sh**
  (the fail-closed ordering of governed-fleet.md section 6: model.sh
  emit rejects unknown --data keys, so the store column and the
  validator must exist before the emitter grows the key, or every
  model row would silently vanish):
  - automation/jobs/telemetry.py -- DATA_FIELDS admits `tokens_cached`
    (the second guard still rejects unknown keys, hermetically proved),
    SCHEMA carries the column, an idempotent
    `ALTER TABLE events ADD COLUMN tokens_cached INTEGER` backfills
    live dbs, the INSERT writes it, --help documents it.
  - automation/lib/model.sh -- TOKCACHED_FILE
    (tmp-tokenscached.txt, the same subshell-escape file lane as
    TOKIN/TOKOUT); `_post_chat` extracts
    `.usage.prompt_tokens_details.cached_tokens`,
    `.usage.prompt_cache_hit_tokens` (Kimi shape / Kimi
    prompt_cache_hit_tokens), or
    `.usage.input_tokens_details.cached_tokens` (Responses shape,
    opencode-go); `unsloth_attempt` does the same for the local
    llama-server leg; `_model_emit` forwards the value and clears the
    tmp file (no stale inheritance into a later leg), including the
    lone-cached case (a cache-pure response with no in/out pair still
    yields one row with tokens_cached only).
  - **Live evidence of the column's value:** the bili session stats on
    this host show the cache doing its job (e.g. post-fix runs:
    inputTokens 3.7M with cachedTokens 3.5M, cache hit 94% on the
    2026-09-27 omp sessions; one chain sampled 100/80 prompt/cached
    tokens). Until slice A the automation model rows captured only
    in/out, so the spend-vs-cache picture was invisible to the
    dashboard telemetry feed (telemetry.json buckets + per-leg rows).
- **S2 -- registry row + patrol breadcrumb** -- the bili services row
  and the security-check b_ok breadcrumb above.
- **Verification** -- new hermetic test
  automation/tests/test-slice-a-bili-surface.sh (9 checks: accept,
  unknown-key fail-closed, old-schema ALTER backfill, emit-forward +
  tmp-clearing, lone-cached, breadcrumb presence), wired into
  automation/Makefile; the affected model-chain leg suites re-run
  green (xiaomi, kimi, ocgo, pin-routing, deck, zai-proxy,
  remote-token-mode); the services registry guard re-runs green
  (test-hngh-services.py, 13 checks). Kernel docs land via the
  certificate ceremony with kernel `make test` per the plans/README
  verification contract.

## What this decision deliberately does NOT do

- The spawn-path matrix completion (which launch paths ride bili
  compression, which legs stay direct) is slice B -- promoted there
  with the tokens_cached backfill across legs, not guessed here.
- The bili MITM policy (BILI_MITM_DOMAINS host whitelist,
  ~/.config/billion-context/billion-context.json) is operator
  configuration: never provider/credential surface for a machine
  session, and never mutated without a certificate naming it.
- Compression policy remains bili upstream's contract; this landing
  only makes the fleet SEE the proxy (registry row, patrol breadcrumb)
  and MEASURE its cache (tokens_cached) -- nothing is used that is not
  declared, nothing declared goes unwatched.
