<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=vision-reviewer-gap-jcode-20260914 -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `vision-reviewer-gap-jcode-20260914`
at 2026-09-14T22:00:13Z. Alert text: jcode-delegate-controls step 3 remaining loop blocked: reviewer endpoint 127.0.0.1:8888/v1/models serves zero models (probed 2026-09-14T21:1xZ) - no vision-capable model exists to regrade sessions-delegate-after.png; adding one is provider/serving configuration (missing-authority boundary parked 18:56/19:25) - needs operator to add a vl/vision model, then rerun a grade-interface-style grade on the after capture

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

      Landed 2026-10-05: reviewer endpoint now serves 13 models (the
      2026-09-14 "zero models" premise is stale); unsloth/Qwen3.8-27B-GGUF
      proven image-capable by a live round-trip probe (solid-red PNG →
      "Red") after unsloth/gemma-4-12b-it-qat-GGUF returned empty/400-class
      results; one-shot grade-interface-style regrade of the existing
      automation/dashboard/shots/sessions-delegate-after.png appended one
      vision row to docs/project/ui-grades.md: 5/10 (honest vision grade,
      old 3/10 fallback row untouched; grade truncated at 2048 tokens on
      the first pass, landed parseable at 4096).
