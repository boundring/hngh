# Does reading cadence/hour/33-research-beat.sh confirm that wall_s wraps the model call and that no timeout/max_tokens guard exists, closing OT1?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-reading-cadence-hour-33-research-be`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-reading-cadence-hour-33-research-be.md.

## Final Structured Summary: Research Line on `wall_s` Wrapping and Timeout/Max_Tokens Guards

### Findings

1. **Script Location and Header Values**: The script `cadence/hour/33-research-beat.sh` is the correct location for the research line. The header value `wall_s: 67.0` in the current state indicates the elapsed time for the beat, which is consistent with a shell-side elapsed-seconds measurement (e.g., `SECONDS` or `date +%s`).

2. **OT1 Closure**: The research line does not confirm that `wall_s` wraps the model call and that no timeout/max_tokens guard exists. The prior beat incorrectly asserted three file paths that are unverified and implausible:
   - `/home/bricker/Projects/etc/hngh/hngh/kernel/33-research-beat.sh` (script location is `cadence/hour/33-research-beat.sh`).
   - `/home/bricker/Projects/etc/hngh/hngh/kernel/wall_s.py` (implausible as `wall_s` is a shell-side measurement).
   - `/home/bricker/Projects/etc/hngh/hngh/kernel/performance_benchmarks.sh` (no evidence of its existence).

3. **External Sources**: The cited external sources (MisakaNet GOVERNANCE.md; arXiv 2305.11423) are irrelevant to OT1 and should be dropped from this line. The arXiv link is unverified.

### Recommendations

1. **Direct Inspection**:
   - **R1**: Inspect `cadence/hour/33-research-beat.sh` to confirm whether `wall_s` is assigned to bracket the model invocation specifically or the entire beat. Grep the script for `timeout`, `max_tokens`, `--max-tokens`, `-m tokens`, or equivalent parameters on the model invocation. Absence of all of these closes OT1 in the affirmative.

2. **Concrete Fixes for `hngh-automation`**:
   - **R2**: If OT1 confirms (no guards):
     - **Hard Wall-Clock Guard**: Wrap the model call in `timeout(1)` (e.g., `timeout 300 deck ...`) to prevent a hung upstream from stalling the hourly cadence indefinitely.
     - **Token Cap**: Pass an explicit max_tokens (or the deck equivalent) at the call site to bound runaway generations and keep `wall_s` interpretable.
     - **Keep `wall_s` Honest**: Record a distinct `timed_out: true` header field or a sentinel `wall_s` if the beat hits the timeout, to avoid conflating upstream hangs with slow generations.

### Open Threads

1. **Verification of Script Contents**: Since the filesystem cannot be read from this turn, direct inspection is required to confirm the script's contents.

2. **Implementation of Fixes**: The

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
