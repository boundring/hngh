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

## Local-model & quota policy

Daily driver: `unsloth/gemma-4-12b-it-qat-GGUF` via http://127.0.0.1:8888/v1 (219904 ctx).
Heavy/long-context: Qwythos-9B 1M variants. Avoid Qwen3.6-27B. Remote API spend < $1/day;
prefer local models for any loop or automated work.
GitHub Copilot models: Distribute non-local tasks to GitHub Copilot models (Sol / Terra / Luna) to conserve K3 quota when available. K3 is reserved for novel design forks and critical reviews.

## Repo notes

Common Lisp (SBCL) agent-orchestration system. Build: `make build`. Test: `make test`.
Docs: `docs/` — roadmap at `docs/project/roadmap.md` (M1.x active). Runtime state: `~/.hngh/`.
Plugin sources: `src/plugins/`. Do not commit without the owner's explicit go-ahead.

## Current state (2026-08-02)

- **Tests**: `make test` green — 1028/1028 @ 106a922 (main, post queue-v3 merge)
- **M7 daemon**: committed (28d92ad). Wire protocol + daemon core + client CLI + systemd units
- **Lanes merged**: lane-a3 → main (H-A2 eligibility, H-A3 pause/resume, H-B1 maintenance, H-U1 systemd fixes)
- **Security**: `*read-eval* nil` at wire-protocol.lisp:135
- **Night queue**: 58 tasks processed (artifacts in ~/.hngh-night/artifacts/)
- **Cost routing v2**: verified faucet ladder active (kimi-sub → copilot → gemini-free → or-free)
- **Role split**: hermes=queue manager, opencode=Sisyphus=M7+platoon code, other opencode=code/docs
- **Doc convention (D1)**: durable records carry `green @ <sha>`, never bare counts


## Per-model attribution (required)

Every artifact and session record names its producer: agent + model + harness
(+ cost when nonzero). Examples: "wave-5 spec — hngh task #2 via
unsloth/gemma-4-12b-it-qat-GGUF, $0"; "fix — opencode (kimi-k3, attended)";
"M2 patch — opencode (kimi-k3) reviewing hngh task #4 draft (gemma-4-12b)".
Applies to: session files, work-sessions.md, JOURNAL.md entries, commit
messages (body or trailers), memo notes, README status lines.
