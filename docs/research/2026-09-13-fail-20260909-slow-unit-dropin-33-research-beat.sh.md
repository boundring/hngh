# fail-20260909-slow-unit-dropin-33-research-beat.sh — slow-unit dropin on cadence/hour/33-research-beat.sh

## Question

Routed alert `slow-unit: dropin:33-research-beat.sh wall=28.3s median=0.1s ×9`
(2026-09-09T01:00:16Z): is the hour-tier research beat's slow wall a defect, or
expected model-leg work, and should the alert be fixed or parked?

## Evidence read

- `automation/cadence/hour/33-research-beat.sh:26-36,61-109` — the beat is a
  failfirst-gated research driver: `failfirst_gate` decides GO vs THROTTLE at
  the top of the tick (`FAILFIRST_OP=research`, `FAILFIRST_TICK_S=3600`).
  Throttled ticks return in ~0.1s ("research paced below its observed
  ceiling"), which is exactly the recorded median.
- Configured model chain per `automation/cadence-params.tsv` and STATE rows:
  a GO tick runs a pinned research call (unsloth `Qwen3.8-27B-GGUF` observed
  2026-09-13). Single-call latency is tens to hundreds of seconds — matching
  the alert's wall side (28.3s at route time; current recurring alert shows
  wall=387.1s median=174.6s).
- `automation/STATE.md:56659-57525` — slow walls always bracket
  `research-done`/`research-commit` rows (expanding via unsloth lane); no
  crash, hang, or retry storm rows accompany them.
- Prior art: `automation/research-dispositions.tsv:61-62` — the sister case
  `fail-20260907-slow-unit-dropin-50-research-overflow.sh` was parked with the
  identical branch structure (failfirst-throttled median vs model-call wall),
  with named escalation triggers.

## Doctrine applied

Beat design treats coverage and supply as work, not throttles
(`33-research-beat.sh:36`). The slow-unit monitor must not be dulled to hide
real regressions (prior-art park rationale). Standard disposition for
expected-latency slow-units: park, not fix.

## Findings

- Bimodal branches explain both numbers: throttled fast-return median (~0.1s
  / 174.6s depending on tick mix) vs GO-tick model-call wall (28.3s / 387.1s).
- Latency is by design: a local model call on the pinned unsloth leg. No
  structural risk at well under the 3600s failfirst interval.
- The sister case's findings transfer directly; same cause class, same fix.

## Recommended next line

Park the alert. Revisit only if GO-tick wall grows past ~2x the observed
model-call ceiling (~800s) without a GO verdict, or if the median side starts
absorbing real work. Reuse the sister case's escalation triggers.
