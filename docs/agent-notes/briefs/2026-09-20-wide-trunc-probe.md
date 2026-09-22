# o9i wide-array/wide-object truncation probe — 2026-09-20

Node: `gap-shared-store-replay::reader-audit-o9i-wide`. Covers beads
o9b (wide-array) / o9f (wide-object) truncation variants. Harness:
`probe-o9i-wide-trunc/` (probe.lisp, gen-payloads.py, run.sh); raw
rows: `probe-o9i-wide-trunc/results.tsv` (48 cases, fresh SBCL per
case, `:hngh` loaded). Full detail: `probe-o9i-wide-trunc/REPORT.md`.

## Verdict requirement: MET

Flat 10k-element array and 10k-key object truncated at element
boundaries (10/50/90% kept + 100% drop-close-bracket): 40/40 trunc
cases fail-closed — federation REFUSED `malformed-attestation`, review
REFUSED `malformed-output`, status doc-level and kernel caller
(`%status-source`) both NIL-RETURN. No truncated payload ever parsed to
a value (zero BAD-STRUCTURE), no ERROR/CRASH/TIMEOUT, no hang (max wall
0.7 s vs 180 s timeout), RSS flat (92-103 MB, baseline band).

## Rejection latency vs well-formed 10k baseline (ms)

| shape | reader | baseline | 10% | 50% | 90% | 100-open |
|---|---|---|---|---|---|---|
| array | fed / review / status | 5 / 6 / 6 | 1 / 1 / 0 | 3 / 3 / 2 | 5 / 6 / 4 | 5 / 6 / 5 |
| object | fed / review | 401 / 396 | 5 / 6 | 97 / 108 | 325 / 351 | 402 / 441 |
| object | status / statussource | 8 / 8 | 1 / 0 | 3 / 3 | 6 / 6 | 7 / 6 |

## Key findings

1. Arrays reject cheaply and linearly (rejection cost ~ parse cost up to
   the cut; 10% cut is ~5x cheaper than a full parse).
2. Wide-object rejection in the hostile raw readers (fed/review) is
   QUADRATIC: the per-entry duplicate-key `member` scan
   (src/adapter/federation.lisp:267, src/adapter/review.lisp:339) makes
   a 90%-cut 10k-key object cost ~0.33 s CPU to reject and a last-byte
   cut cost the full ~0.4 s — rejection is not cheap for wide objects.
   Linear fix candidate: hash set or entry-count cap.
3. Status spine reader is linear on both shapes but has NO dup-key
   refusal (pushes both entries; first wins via assoc).
4. Incidental strictness asymmetry: fed/review OBJECT parsers tolerate a
   trailing comma (fed measured; review code-read) while fed ARRAY
   refuses it; status reader refuses trailing commas fail-closed.

## Follow-up candidates

- Linear wide-object dup-key handling (cost gap, o9f-adjacent).
- Separator-anomaly bead for trailing-comma object acceptance.
- Status dup-key silence if duplicate keys ever gate decisions.