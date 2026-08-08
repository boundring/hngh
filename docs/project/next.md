# Next — Current Work

**Last updated**: 2026-08-08

## Current Status

**M0–M9 + ACP waves + L2/L3 design + L2/L3 first build — 693/693 fast, 2434/2434 full suite green** (FiveAM; `make test` / `make test-full` verified
2026-08-08 on main). Session detail in `docs/project/work-sessions.md` (M3–M7/M9) and
`docs/journal/` (M0–M1). Detailed roadmap at `docs/project/roadmap.md`.

## Handoff brief (new sessions start here)

Starting work on Hngh from a fresh session: read this, then
`docs/project/work-sessions.md` M9.17–M9.22 for the session-level detail.

**What shipped this block (2026-08-07/08, all committed + green):**
- **L2/L3 build — Tier-0 detectors + L3 scorer** (`<L2L3>`): `src/plugins/situation-detectors.lisp` (observation model + 8 deterministic detectors: identical-call loop, retry-without-progress, zero-progress, token-sink, failing-verification, excessive-waits, cost-exceedance, chatter-loop; emit `situation.detected` on the bus) + `src/plugins/situation-scoring.lisp` (impact×urgency×spread×confidence score, recovery-stage tracker, progressive gate-lowering → A3 actuator via `acp-steer-command`). 60 new checks; 693/693 fast, 2434/2434 full.
- **A1** ACP client (`c9d6f5c`): initialize/new/prompt/update/cancel/permission over stdio JSON-RPC.
- **A2** ACP dispatch driver (`b7c5635`): run a task through an ACP agent subprocess; fail-closed.
- **A3** ACP steering primitive (`d6328b3`): `acp-steer-command` (scored situation → :none/:steer/:interrupt) + `acp-steer` on a live session; fail-closed on non-numeric scores.
- **A4** ACP server + framing fix (`95d61e2`): `hngh acp` exposes Hngh as an ACP agent; NEW `src/plugins/acp-transport.lisp` = JSON-RPC mode `:acp` with **newline-delimited framing** (ACP's wire format; the stock cxxxr/jsonrpc stdio transport uses LSP Content-Length and does NOT interoperate with real ACP peers — do not switch back to `:mode :stdio`). INTEROP-verified driving `bin/hngh acp` with plain newline JSON.
- **L2/L3 design capture** (`b01a0ac`, +research `aa2e88e`): `docs/design/situation-scoring.md` — the auto-steering brain behind A3 (recognition + scoring; recovery-stage model; steer-don't-interrupt; Tier-0 procedural first; cheap/local calibrated judge; progressive gate-lowering; self-improvement loop). Evidence in `docs/research/`.
- **Cost policy** (`ff61698`): >$0.10/M tokens = strategic reserve (GLM-5.2, K3); cheap/local primary. PM/Designer seat defaults demoted to deepseek-v4-flash-0731 in ~/.hngh-night/squad-seats.conf.
- **cogmem dropped** (`0dc36a0`, ADR-042): Anthropic-key dependency conflicts with cost policy; uninstalled everywhere, notes already in optmem. Cross-session memory = optmem + hngh beans + AGENTS.md breadcrumbs.

**Immediate next work (in order — full build order in situation-scoring.md §8):**
1. ~~L2 Tier-0 procedural detectors~~ — **DONE** (`<L2L3>`): all 8 detectors on the sentry/observation stream, model-free, unit-tested against /steer-derived fixtures.
2. ~~L3 scoring + recovery-stage tracker~~ — **DONE** (`<L2L3>`): impact×urgency×spread×confidence, stage tracker, fail-closed.
3. ~~Progressive gate-lowering + steer/interrupt mapping → A3~~ — **DONE** (`<L2L3>`): ladder + acp-steer-command mapping with lowered thresholds.
4. **Judge model (cheap/local) on suspicious windows, offline-calibrated first** (NOT yet built — next wave).
5. Case-base + review pass (self-improvement loop).
6. Cross-agent normalization (Hermes + OpenCode, one scorer).

**Launch context (squads):** `squad-up` launches seats; PM/Designer default to
deepseek flash (cost policy). Task cards live in `~/.hngh-night/tasks/`; task 91
(A3+A4) is DONE — archive to .done/. A next-wave card (L2/L3 build) is staged at
`~/.hngh-night/tasks/92-l2-l3-situation-scoring-build.txt` (see next.md §Up Next).

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
| P0 | **L2/L3 build steps 4–6** — judge model (cheap/local, offline-calibrated first), case-base + review loop, cross-agent normalization (steps 1–3 done `<L2L3>`) | `docs/design/situation-scoring.md` §8; hngh |
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
