# Does grepping cadence/hour/33-research-beat.sh for `timeout|max_tokens|SECONDS|date +%s` close OT1 affirmatively and reveal where wall_s is assigned relative to the model invocation?

Status: crystallized 2026-09-14 from research line `fail-20260914-Does-grepping-cadence-hour-33-research-b`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-grepping-cadence-hour-33-research-b.md.

# Research line — FINAL record (contracted)

**Line:** Does grepping `cadence/hour/33-research-beat.sh` for `timeout|max_tokens|SECONDS|date +%s` close OT1 affirmatively and reveal where `wall_s` is assigned relative to the model invocation?
**State:** contracting → **record closed; OT1 remains open**

## Verdict

**No — OT1 is not closed affirmatively.** No prior beat produced grep output from the actual file. The expanding beat inferred the script's structure (timeout-wrapping, `SECONDS`/`date +%s` capture, `max_tokens` in the payload) from shell conventions and flagged it as inference. An affirmative closure requires observed output; none exists. The question stays open until the command is run.

## Findings

1. **No evidence was ever gathered.** The only prior substance is a hypothesis, explicitly self-labelled as such. Reasoning about what such scripts "usually" do is not evidence of what *this* script does.
2. **The `wall_s` bracketing question is unanswered and load-bearing.** Whether `wall_s` is assigned before or after the model invocation determines whether it measures the model call, the whole beat, or pre-prompt work (acceptance parsing, vault reads, prompt assembly). If it under-brackets, every ledger line systematically under-reports beat duration — a failure mode that compounds with the stall lessons in prior art.
3. **The line has now consumed ≥2 model beats without the one-line evidence.** The expanding beat deduced; this contraction crystallizes. Neither ran the grep. This transition's own header records `wall_s: 47.0` — a model wall-time cost a sub-second grep would have avoided, and which is *itself* ambiguous pending finding #2. The line's documented failure mode (spending a model beat on what a

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
