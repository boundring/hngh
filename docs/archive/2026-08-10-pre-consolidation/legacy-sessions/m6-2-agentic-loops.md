# Wave: M6.2 — agentic file-editing loops (as-completed record)

> Written after completion (2026-07-31) — the debugging arc WAS the work; recorded for the convention.

## Context

M3's driver ran text tasks only (direct-api completions can't edit files). M6.2 makes the driver run tasks that WRITE code: the `:opencode` agentic-CLI path (opencode 1.18 headless on the free local model).

## What was broken (dogfood catch, task #5)

1. `agentic-cli-args` used stale `--task` syntax → opencode 1.18 wants `run [flags] <prompt>`. Fixed: `(list "run" "--auto" "-m" "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF" task)` — `--auto` for headless permission approval (opencode's secret-path denies still enforced), `-m` pins the free model.
2. Deeper: `log-cost-entry` called `default-model` unconditionally; its `ecase` covered only the 4 API tool-ids. **Every agentic invocation crashed at cost-logging** — success got marked `:failed`, and the masking error hid the true outcome. Reproduction showed opencode actually wrote the file while the queue said failed. Fixed: `default-model` is now total (agentic CLIs report their tool id).

## Verification (all met)

- `make test` 888/888 (new: args-shape + default-model-total tests).
- Task #6 ("write /tmp/hngh-agentic-proof.txt with 'ok'") ran queue → driver → `opencode run --auto -m <local-12b>` → file exists with "ok"; queue `:done`, cost 0.0.

## Follow-ups (not this wave)

- `execute-agentic-cli` has **no timeout** — a hung agentic task blocks the tick. Add timeout before unattended long agentic tasks.
- Agentic runs inherit the submitter's env (UNSLOTH_API_KEY for the local provider); document in operator docs.
- mc daemon needs a restart to pick up post-17:44 code (done manually this session).
