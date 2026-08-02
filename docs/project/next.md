# Next — Current Work

**Last updated**: 2026-08-02

## Current Status

**M0–M7+Phase 2 spec complete; Agent Platoons v0 designed** — 1028/1028 tests passing (FiveAM, `make test` verified
2026-08-02 @ 106a922 on main, post queue-v3 merge). Session detail in `docs/project/work-sessions.md` (M3–M7) and
`docs/journal/` (M0–M1).

Recent sessions:
- **M3** Event loop: persistent queue + scheduler-driven task driver, $0 local
  inference default.
- **M4.1** Unsloth lifecycle: shared systemd-owned server, API-level
  management (no spawn/kill).
- **M5.1** First dogfood loop: real task queue → driver → local model, $0,
  artifact adopted by opencode as svc-dash wave-5 spec.
- **M6.1** Mission control: `mc` tiled tmux session (svc-dash | daemon |
  status | events | free agents); mission-control plugin; live tmux lifecycle
  test. Hardened later same day: `~/.tmux.conf` (mouse, vi keys,
  remain-on-exit), `mc refresh` dead-pane respawn.
- **M6.2** Agentic file-editing loops: driver runs opencode headless via tool
  hub at $0 on gemma-4-12b.
- **M6.3** Emacs daemon: daemon lifecycle (start/stop/health), policy-explicit start, daemon outlives hngh.
- **M7** Client-server daemon: wire protocol (SEXP-over-UDS), daemon core, client CLI, systemd units. 1028/1028 tests.
- **Agent Platoons v0**: declarative squad specs, bash launcher, 7 role templates, first dogfood (duo-review).

## Up Next

| Priority | Item | Where |
|---|---|---|
| P0 | **Phase 2** — atomic claim/release, verifier-gated completion, M7 wire handlers, lease expiry (spec @106a922, tasks 66-69) | hngh |
| P0 | **M8 model-management** — routing table, benchmark harness, cost/latency matrix | hngh |
| P0 | **Sentry Tier-1** — light-ralph analysis (config-tweak proposer, drift triage, secret-guard pattern review) + git pre-commit hook calling `guard-text` | hngh; `.omc/plans/sentry-safeguards.md` |
| P1 | **M8 model-management plugin** — routing table seeded (`docs/design/model-routing.md`); selection/sourcing/benchmark harness | hngh; `sysconfig_mgmt/.omc/plans/multi-model-topology.md` |
| P1 | **Night-ralph task library** — continual planning/docs/training-set/research tasks, $0 local; isolated `~/.hngh-night` | hngh; `.omc/plans/overnight-local-loop.md` |
| P1 | **svc-dash PyPI release** (wave 6 history persistence done, local) | `sysconfig_mgmt/.omc/plans/distribution-packaging.md` |
| P2 | **gbd TUI waves 1–8** | `~/Projects/etc/20260725/git-back-dots` |
| P2 | **DOC leftovers**: M1.13 KDE integration (P2), M1.14 PKGBUILD, M1.15 integration tests | hngh |

Done 2026-07-31/08-02: M6.3 emacs-daemon, M-sentry (secret-guard + context-watch), MC-2 waves 1–3 (6-panel emacs dashboard), svc-dash wave 6, night-run/night-ralph loop, M7 daemon, Agent Platoons v0.

Note: M7 feeds MC-2 (daemon clients) but MC-2 does not block M7 — both can
proceed; MC-2 wave 1 is read-only panels over existing state.

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

- **SBCL**: 2.6.5 (pacman, CachyOS); Quicklisp at `~/quicklisp/`
- **CL deps**: bordeaux-threads, cffi, cl-json, cl-ppcre, alexandria, fiveam
- **Local models**: unsloth :8888 (systemd user units; gemma-4-12b daily
  driver, Qwythos-9B 1M long-context); ollama :11434
- **Agents**: opencode 1.18.8 (`opencode/` model prefix, zen gateway);
  Hermes TUI; llmtrim interceptor :43117; `llm-budget` spend gate ($10/hr)

## Repository

- GitHub: https://github.com/boundring/hngh (primary, issues, milestones)
- Codeberg: https://codeberg.org/hngh/hngh (mirror)
- Local: ~/Projects/etc/hngh/
- Project board: https://github.com/users/boundring/projects/1

## Blocked

Nothing blocked.

## Notes

- M4.1/M5.1/M6.1/M6.2 changes were committed per-model-attribution
  convention; see work-sessions.md for per-session artifact lists.
- `docs/project/backlog.md` M2/M3 sketches remain valid long-horizon context.
