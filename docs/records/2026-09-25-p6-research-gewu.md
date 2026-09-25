# P6 — research at the gewu boundary

Date: 2026-09-25. Plan: refoundation P6. Three gates landed in the
research beat cluster, all hermetic (zero live model calls in tests).

## (a) Cached orientation

`automation/scripts/context-pack.sh` (new): idempotent per-UTC-day pack
of the synthesizer's orientation inputs — dispositions tail, lessons
tail, backlog sections, alert identities, source tokens — under five
fixed `== name ==` headers, written atomically (tmp+mv) to
`logs/context-pack-<date>.txt`, fail-soft, exit 0 always.
`demand_synthesize` in `cadence/hour/33-research-beat.sh` now reads the
cached pack instead of re-gathering; a missing/empty pack skips
synthesis (no crash). The overflow wrapper inherits the cache through
the shared body — no third beat re-establishes structure. Live probe:
built once (47 KB, five headers), second run mtime-stable, then
deleted (logs/ is runtime data, never committed).

## (b) Question, not beat

Normalized slug (both languages): lowercase, runs of non-[a-z0-9] to
one '-', trimmed. Before any mint — `lib/causes.sh
append_research_subject`, `patrol.py queue_repeat_subjects`, the
beat's synthesizer — the normalized slug is matched against open
research-lines.tsv ids (status planned|contracting|crystallized) and
research-subjects.txt ids; a match lands the question under the
EXISTING id (full-line dedup), so `ensure_lines` never seeds a second
line — the entry gains a question, never a new beat. A synthesizer
line with no named source item is no longer discarded: it is recorded
as a `question-<sid>` row, and `ensure_lines` skips `question-*` ids —
recorded questions never beat.

## (c) Ground-truth withholds

`ground_truth_gate` in the beat, before followon queueing: an
`adopted` verdict whose supportive pass names no evidence item — a
pathed file, a `file:line` citation, a fenced block, or a `$ `-led
command line — is recorded as `withheld` with the reason prefixed
`withheld -- no named evidence item: `, followons cleared. The row
still rides the sealed append seam; parked/killed paths untouched;
both review prompts unchanged. Harvest keys on `adopted`, so withheld
rows never become lessons.

## Verification

- `tests/test-research-gewu.sh` (new, 37 assertions, 6 cases): pack
  build-once + headers + section degrade; cache consumption proven via
  a sentinel planted only in the pack reaching the model stub's
  captured prompt; question-synth recording + ensure_lines skip;
  double-mint same cause under existing open id; patrol mint under
  existing id (importlib, hermetic ctx); gate matrix — no evidence ->
  withheld, file:line / fenced / `$ ` cmd / pathed file -> adopted,
  parked reason untouched.
- Updated: test-research-accel2.sh (question-row asserts),
  test-research-review.sh (evidence fixture), test-wiki-health.sh
  (pack sandbox copy); stub-lib.sh gains a default-reply hook.
- Two live bugs found and fixed during verification:
  33-research-beat.sh:991 read `$followons` under `set -u` before
  first assignment (killed every review run) -> `${followons:-}`;
  a review-case fixture was stubbing the beat instead of the stub.
- `automation make test` exit 0 (199s); root `make test` green;
  bash -n + py_compile clean.
