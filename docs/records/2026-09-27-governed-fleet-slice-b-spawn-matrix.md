# Governed-fleet slice B: spawn-path matrix promoted + tokens_cached backfill

Date: 2026-09-27. Plan:
docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md
(slice B; governed-fleet.md section 6 item B). Free-commit automation
surface; kernel src untouched.

## What landed

### 1. Spawn-path matrix promoted (governed-fleet.md section 2)

The design doc's section-2 registry row now carries the matrix itself
(promoted 2026-09-27), five rows each with its code anchor:

1. **Interactive omp/pi** — the operator's fish wrapper
   (`command bili omp -- $argv`): cert-MITM, operator surface.
2. **Machine-launch omp** — `launch_session` default branch
   (automation/lib/launch-session.sh:488-493): `bili omp -- -p
   --model` through `bctx_bin` when bili is on PATH, plain omp
   fail-open with a `bctx-absent` breadcrumb otherwise.
3. **opencode executor** — executor=opencode branch
   (launch-session.sh:174-408): env-only MITM redirect
   (HTTPS_PROXY + NODE_EXTRA_CA_CERTS at 349-355); the hngh config
   layer is never written (the `bili opencode` temp-config path would
   strict-parse away the secret-deny block, docs/records/
   2026-09-11-bili-opencode.md). Fail-open direct at 343-347/352-359.
4. **jcode executor stdio** — executor=jcode branch
   (launch-session.sh:409-487): SDK worker shim -> `jcode run` CLI ->
   omp ladder; proxy envs dropped for the child (env -u, 474-481).
   Direct by design; upstream `bili jcode` (v0.1.110) adoption is an
   operator surface, not a machine lane.
5. **Chain beats + local legs** — every model.sh chat leg: direct
   curl; unsloth rides the local llama-server
   (hngh-services.tsv:127.0.0.1:8888).

Two invariants over the matrix, now named in the doc: fail-open
everywhere (bili absent/unreachable = uncompressed/direct with a
visible breadcrumb, never a failed launch), and one telemetry schema
(every lane's spend lands in telemetry.db; tokens_cached is
read-side-only everywhere).

### 2. tokens_cached backfill across legs

Slice A (commit 6764d00b, 2026-09-27) proved the emit path
(telemetry.py column + model.sh _post_chat/unsloth_attempt extraction
+ _model_emit forward). Slice B completes the remaining legs:

- **jobs/session-cost.py** (omp transcript leg) — the omp usage shape
  carries `cacheRead`/`cacheWrite` (verified live on host); the parser
  now sums `usage.cacheRead` only (cacheWrite is a write, not a cached
  hit) and the emitted kind=session-cost row carries `tokens_cached`
  when nonzero.
- **jobs/jcode-session-cost.py** (jcode leg) — API-call lines carry an
  optional `cache_read=N` tail; capture it into `tokens_cached`
  (field absent -> no field, old shape keeps parsing).
- **jobs/ocgo-attribution.py** (opencode stream leg) — step_finish
  `tokens.cache.read` / `cacheRead` / `cache_read` shapes (whichever
  the stream presents) land as `tokens_cached` on the SAME
  ocgo-agent row; legs that declare no cache miss all three and the
  row carries no field. The opencode.db fallback scrape is unchanged:
  cache tokens are not reconstructible there, and the stream is the
  primary attribution surface.

### 3. Hermetic proof

- tests/test-session-cost-cache.py (NEW, 2 checks, wired into the
  automation Makefile): cacheRead sums in, cacheWrite excluded,
  no-cache-field legs backfill to zero (no field emitted).
- tests/test-ocgo-launch.py: new emitter test
  (test_opencode_emitter_carries_cache_tokens) — a stream carrying
  `tokens: {input:10, output:4, cache:{read:777}}` emits exactly one
  ocgo-agent row with tokens_cached=777.
- Suite states at landing: test-ocgo-launch.py 37/37 green,
  test-jcode-session-cost.py 4/4 green, test-session-cost-cache.py
  2/2 green; full automation `make test` green before commit.

## What this slice deliberately does NOT do

- jcode-session-cost's live-log format drift: today's
  ~/.jcode/logs/jcode-2026-09-27.log carries no "API call complete"
  lines at all (the parser therefore emits nothing for fresh jcode
  traffic). That is a capture-gap backlog lane, not slice-B scope —
  the slice only extends what the parser already reads.
- opencode.db fallback cache scrape: refused (not reconstructible
  without opencode schema assumptions; the stream leg already
  covers the live window).
- `bili jcode` adoption for the machine jcode lane: upstream feature
  exists (hngh's own #755); adopting it changes the compression
  posture of a machine lane and is an operator surface decision.
