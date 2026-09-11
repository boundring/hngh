# 2026-09-11 -- research-beat capture fix (corpus-loss cure)

## The two defects

1. **No capture-side filtering.**
   `automation/cadence/hour/33-research-beat.sh` captured the model
   completion (`response="$(... | model_call 4096)"`) and wrote it
   verbatim into `digest/RESEARCH-BEAT-<date>-<id>.md` and, on the
   crystallize transition, into the kernel's `docs/research/<date>-<id>.md`.
   When the model emitted tool-call syntax mid-answer (raw
   tool-call block XML), the junk became the doc body.

2. **Silent mid-syntax truncation.** The only cap on the doc is the
   model call's `max_tokens` budget (`model_call 4096`,
   33-research-beat.sh; the `marked_cut 8000/4000` calls nearby are
   prompt-input caps, not write caps). The chain never inspected
   `finish_reason` (automation/lib/model.sh `unsloth_chat` /
   `_post_chat`), so a completion cut at the token cap ended mid
   tool-call block and was written as if complete -- the docs end
   inside the junk with no findings body.

## The fix

- `automation/lib/docfilter.py`: single source of truth for the junk
  signature (now imported by `tests/test-doc-hygiene.py`) plus the
  capture filter: whole tool-call blocks removed (complete or
  unterminated), stray signature lines removed, `finalize()` adds the
  explicit truncation markers. CLI exits 1 when nothing survives the
  strip.
- `automation/cadence/hour/33-research-beat.sh`: every captured model
  output passes through the filter before the digest write and the
  kernel crystallized-doc write. Empty-after-strip files an alert row
  (`research-beat:junk-capture:<id>`), records a degraded outcome, and
  writes nothing -- line state is held for retry. `DOC_CAPTURE_CHAR_CAP`
  (default 16000 chars) with an explicit `[truncated at write: N chars
  exceeded cap M - re-run the beat]` marker (the marked_cut convention).
- `automation/lib/model.sh`: `finish_reason=length` is now recorded
  (`_mark_trunc`, `MODEL_TRUNC_FILE`, `last_model_truncated`) and the
  beat appends a `[truncated at model call: ... - re-run the beat]`
  marker when the completion hit the token cap.
- `automation/tests/test-doc-filter.py` (9 cases, wired into
  `make test`); `tests/test-doc-hygiene.py` (landed 2026-09-11,
  commit 2880b09) now imports the shared signature. Verified: digest
  capture of the actual incident passed through the filter yields clean
  prose, zero guard hits.

## What the bug silently ate

Commit 2880b09 excised the junk and marked the cistern doc; findings
bodies were lost from 8 docs (7 research lines + the publication book,
which regenerates from the corpus):

- cistern-test-coverage
- synth-2026-09-08-1
- govbench-ci-evidence
- govbench-adapter-contract
- govbench-metrics-v1
- govbench-scenario-corpus
- govbench-voting-prior-art

All seven research lines sit at `state=reviewed` in
`research-lines.tsv`; re-running them means resetting those rows to
re-seed and letting the (now filtered) beat regenerate the docs. The
corrupted `automation/digest/RESEARCH-BEAT-2026-09-08-cistern-test-coverage.md`
is left as-is -- history is not rewritten; future beats write filtered.