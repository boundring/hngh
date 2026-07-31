# hngh — agent notes (all agent CLIs working in this repo)

## Coordination contract (machine-wide)

- Shared memory: `~/.optmem/memo` — run `wake` at session start, `note "..."` for durable
  facts, `recall <regex>` to search. Top-level sessions only; subagents must NEVER run memo.
- Sign memo notes with your agent name. Memo = signposts/status (<280 bytes); files = payloads
  (write-then-rename for atomicity). Never use memo for task claiming — no claim/ack semantics.
- Summon a sibling agent headlessly: `agent-call hermes|opencode "prompt" [model]`
  (auto-logs to shared memory). Default opencode model is free local gemma-4-12b.
- Never print secret VALUES from `~/.hermes/.env`, `auth.json`, `*.pem`, `*.key`.
  By-NAME scripted access only (grep/sed/python, no value echo).

## Local-model policy

Daily driver: `unsloth/gemma-4-12b-it-qat-GGUF` via http://127.0.0.1:8888/v1 (219904 ctx).
Heavy/long-context: Qwythos-9B 1M variants. Avoid Qwen3.6-27B. Remote API spend < $1/day;
prefer local models for any loop or automated work.

## Repo notes

Common Lisp (SBCL) agent-orchestration system. Build: `make build`. Test: `make test`.
Docs: `docs/` — roadmap at `docs/project/roadmap.md` (M1.x active). Runtime state: `~/.hngh/`.
Plugin sources: `src/plugins/`. Do not commit without the owner's explicit go-ahead.
