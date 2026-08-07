# Next — Current Work

**Last updated**: 2026-08-07

## Current Status

**M0–M9 in build; M9 squad autonomy well into W1–5 — 494/494 fast, 1687/1687 full suite green** (FiveAM; `make test` / `make test-full` verified
2026-08-07 on main). Session detail in `docs/project/work-sessions.md` (M3–M7/M9) and
`docs/journal/` (M0–M1). Detailed roadmap at `docs/project/roadmap.md`.

Recent sessions (see work-sessions.md for full per-session artifacts):
- **M6.3** Emacs daemon: lifecycle (start/stop/health), policy-explicit start, outlives hngh.
- **M-sentry / M7** Procedural safeguards (secret-guard, context-watch); client-server daemon (SEXP-over-UDS, client CLI, systemd units).
- **MC-2** Six-panel emacs dashboard (status, events, llmtrim, opencode log, task queue, night-ralph log).
- **M8 model routing** Free-tier refresh: fallback chains moved to live OpenRouter catalog IDs across a mixed-vendor set (nvidia/google/openai/poolside/cohere/inclusionai), Qwen-AgentWorld-35B promoted to primary local fallback, VRAM/select-system/mapping updated.
- **M9 W1–5 squad autonomy** AGENTS.md discovery/merge, questionnaire-from-AGENTS.md, resource-gate preflight, PM-first-prompt generator, file-watcher/squad-dispatch/beans/squad-resources wiring; prompt matrix (`generate-prompt`, 36 skeletons, bones/flesh pass, D-040 model selection, prompt cache).
- **Benchmark sourcing + probe runner** Design brief (`docs/design/benchmark-sourcing.md`); `scripts/fetch-model-benchmarks.sh` (OpenRouter catalog + LM Arena PPE + Aider); `data/model-probes.lisp` runner (12 procedural probes, ollama/OpenRouter, tokens/sec, prefill timing, VRAM, snapshot writer).

## Up Next

| Priority | Item | Where |
|---|---|---|
| P0 | **Phase 2 finish** — atomic claim/release, verifier-gated completion, M7 wire handlers, lease expiry | hngh |
| P0 | **M9 C4** start-now/pause-on-cause; **C10** MisakaNet failure shield (design-only now) | hngh; `docs/design/squad-autonomy.md` |
| P0 | **M9 C6** planner cycle (roadmap → task queue → squad dispatch) | hngh |
| P0 | **M9 C8/C9** benchmark-runner strategy + nightly benchmark cron — strategy exists (`docs/design/benchmark-sourcing.md`), runner + cron unbuilt; add `--run` wrapper to the probe runner | hngh |
| P1 | **Night-ralph task library** — continual planning/docs/training-set/research tasks, $0 local; isolated `~/.hngh-night` | hngh |
| P1 | **svc-dash PyPI release** (wave 6 history persistence done, local) | `sysconfig_mgmt/.omc/plans/distribution-packaging.md` |
| P1 | **Sentry Tier-1** — light-ralph analysis + git pre-commit hook calling `guard-text` | hngh; `.omc/plans/sentry-safeguards.md` |
| P2 | **gbd TUI waves 1–8** | `~/Projects/etc/20260725/git-back-dots` |
| P2 | **DOC leftovers**: M1.13 KDE integration (P2), M1.14 PKGBUILD, M1.15 integration tests | hngh |

Done 2026-07-31/08-07: M6.3 emacs-daemon, M-sentry (secret-guard + context-watch), MC-2 waves 1–3 (6-panel emacs dashboard), svc-dash wave 6, night-run/night-ralph loop, M7 daemon, Agent Platoons v0, M8 model routing/free-tier refresh, M9 W1–5 prompt matrix + benchmark sourcing + probe runner.

Note: M9 W1–5 shipped but C4 startup row (start-now/pause-on-cause), C6 planner, and C8/C9 benchmark loop are the remaining path to squad autonomy completion; the probe runner is the executable seed for C8/C9.

## Key Architecture Decisions (carried forward; see git history for M1-era list)

- **Language**: SBCL Common Lisp (core) + C (system daemon) + Python (AI, future) + C/C++ (GPU)
- **Architecture**: Image + Bus + Supervisor (microkernel-style)
- **State**: File tree (git-versioned); queue at `~/.hngh/tasks/queue.lisp`
- **Event bus**: Custom internal pub/sub + dbus bridge
- **Manifest format**: Lisp plist (D-008)
- **Scheduler actions**: Function objects (D-009)
- **Threat detection**: Procedural-first (L1/L3), LLM-strategic (L2/L4)
- **Privilege**: Split daemon — user daemon (CL) + system daemon (C, root)
- **Test harness**: FiveAM (D-013)
- **Thread safety**: bordeaux-threads mutexes on all shared state
- **READ safety**: *read-eval* nil for untrusted reads
- **Local inference default**: `(:prefer-tool :local-openai-api)` — driver is
  serial, one task per tick; agentic path = `opencode run --auto -m <local>`
- **License**: AGPL-3.0-or-later (D-003)

## Environment

- **SBCL**: 2.6.7 (pacman, CachyOS); Quicklisp at `~/quicklisp/`
- **CL deps**: bordeaux-threads, cffi, cl-json, cl-ppcre, alexandria, fiveam, jsown (schema validation for model probes)
- **Local models**: unsloth :8888 (systemd user units; gemma-4-12b daily
  driver, Qwythos-9B 1M long-context, Qwen-AgentWorld-35B for heavy local
  fallback); ollama :11434
- **Agents**: opencode 1.18.8 (`opencode/` model prefix, zen gateway);
  Hermes TUI; llmtrim interceptor :43117; `llm-budget` spend gate ($10/hr)

## Repository

- GitHub: https://github.com/boundring/hngh (primary, issues, milestones)
- Codeberg: https://codeberg.org/hngh/hngh (mirror)
- Local: ~/Projects/etc/hngh/
- Project board: https://github.com/users/boundring/projects/1

## Blocked

- **OpenRouter weekly spend wall** (hit 2026-08-06, ~$48/wk org cap): chat
  completions return 403 "Budget limit exceeded" and subagents surface it as
  garbled 401 "Invalid token payload". Delegation is pinned to the DeepSeek
  direct API (cheap, no markup) as the default route; OpenRouter stays a
  catalog source and optional fallback. Top up or raise the org cap before
  depending on OpenRouter for a large delegation run.
- **M9 C4 / C6 / C8 / C9**: designed but unbuilt (see Up Next) — squad
  autonomy is not yet end-to-end self-continuing.
- Nothing else blocked.

## Notes

- M4.1/M5.1/M6.1/M6.2 changes were committed per-model-attribution
  convention; see work-sessions.md for per-session artifact lists.
- `docs/project/backlog.md` M2/M3 sketches remain valid long-horizon context.
