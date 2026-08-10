# Next — Current Work

**Last updated**: 2026-08-10

## 2026-08-10 reorientation

K3 sanity review artifact 95 is now consumed into the development method:
evidence-gated state claims, completion-to-reorientation, bounded authority
completions, and coupled 5h/7d/30d quota admission. Design:
`docs/design/k3-bounded-completions.md`.

Immediate ordered work:
1. ~~Card 125: migrate workbench roots.~~ **DONE** at `2de5875`; live trees
   now reside at `~/.hngh/.hngh-night` + `.hngh-day`, old roots are
   compatibility links, manifests and watcher health verified. Follow-up:
   work-root seam/referencer sweep + bounded backup-manager capture.
2. Card 128: harden K3 quota truth (5h bucket, amount-aware admission,
   authoritative ledger rollup, call reservation, fail-closed UNKNOWN).
3. Card 131: procedural context budget lifecycle (12/18/25% stages) over a
   component ledger, replacing fixed 256K-only pressure reporting.
4. Card 132: prompt component budgets and compact handoff generator.
5. Card 130: audit/apply minimal Hermes/OpenCode capability profiles; then
   remove non-purposeful MCP/tool schemas from worker sessions.
6. Card 127: wire the planner/router to the hardened predicate; automatic K3
   remains refused until quota observation/config supplies the cap.
7. Build completion packet/fingerprint and manual quota observation gate.
8. Resume cards 120/122/124: meaningful seat reorientation and TUI health.

## Current Status

**M0–M9 + ACP waves + L2/L3 design + L2/L3 build (steps 1–5) — 837/837 fast, 2559 full suite green** (FiveAM; `make test` / `make test-full` verified
2026-08-08 on main). Session detail in `docs/project/work-sessions.md` (M3–M7/M9) and
`docs/journal/` (M0–M1). Detailed roadmap at `docs/project/roadmap.md`.

## Handoff brief (new sessions start here)

Starting work on Hngh from a fresh session: read this, then
`docs/project/work-sessions.md` M9.17–M9.22 for the session-level detail.

**What shipped this block (2026-08-07/08/09, all committed + green):**
- **Wave C items 2+4 — bwrap sandbox + hash-chained log** (`6441e0a`): **94 hash-chain** (Luna-delegated): safety-boundary log-action now SHA-256 hash-chains every entry (additive :hash, zero root, backward-compatible skip of pre-chain entries) + verify-action-log fail-closed. **96 bwrap sandbox** (attended): `src/core/sandbox.lisp` — run-sandboxed (default-deny FS/net via bwrap, writable task dir only, fail-closed no-bwrap=>error), tool-hub `sandboxed-p` flag routes agentic CLI execution through it (default off = no dev-loop break), Makefile test-fast includes :hngh.sandbox. **Procedural paren fixer hardened** (`6441e0a`): `lint-parens --fix` now runs BEFORE the check in the test gate (auto-appends EOF closes — LLM never hand-counts parens), + regression tests tests/scripts/test-lint-parens.py (4 tests, uv-hosted pytest) wired as lint-parens-test. 858/858 fast green.
- **Wave C items 8+100 — :operation human gate + ACP pipe-flake fix (TANDEM, `c657071`/`51ebf47`)**: seat A (deepseek-v4-flash) spec `docs/design/operation-gate.md` (`8933f89` + seam trap `f343128` + deploy note `1ca1edf`); seat B (gpt-5.6-luna-max) implemented — `submit-task operation-spec` forces `:type :operation` + `:authority :approval` (re-set after the v3 flatten), `approve-task` human-only (config-seeded `:operation-approvals`), `operation-gate-check` exact-match + lint-deps composition, driver pre-delegate gate, package-manager gate pre-daemon; 8 tests/38 checks. **All Wave C gate items 1–4 + 8 now land; only the canary/scan tail remains before C6 can be unparked.** Card 100 fixed the M9.34 ACP reading-thread flake (stream-error→EOF + bt:destroy-thread leak fix, 0 leaked threads verified). 19 suites, **956/956 fast, 0 fail-suites** (two consecutive runs).
- **Wave C item 3 — native least-agency tool scoping, TANDEM-DELIVERED** (`dccad77`): seat B (gpt-5.6-luna, ACP) implemented deny-by-default `*tool-grants*` in the AI tool hub from seat A's (deepseek-v4-flash) spec `2244281` — grants registry + `tool-granted-p` + `grant-tool`/`revoke-tool`, read-only tools auto-granted, denials journaled + `tool.denied` bus event, `select-tool` filter; 46 new checks. **The two-Hermes ACP tandem experiment produced and verified a full Wave C gate item unattended** (~35 min launch→commit→FINAL), with flash-as-review-counterpoint STEER: notes folded in mid-flight.
- **Wave C item 1 — qlot dep pin + CI policy decision** (`cb7b82f`/`b9c966b`): `qlfile`+`qlfile.lock` (Quicklisp 2026-01-01 + bordeaux-threads/cl-ppcre/babel/jsonrpc/alexandria/yason/jsown/fiveam/ironclad); Makefile `SBCL_FLAGS` loads `.qlot/setup.lisp` when present (no-op without qlot); `.qlot/` gitignored. **CI**: after the long-failing build CI was diagnosed (no Quicklisp on runner) and the email-spam `mirror.yml` deleted, the per-push **build/test CI was dropped by owner decision** — the local `make test` gate (lint-parens + lint-deps + 837 checks) is the quality source of truth and runs on every commit; server CI is now **lint-only** (deterministic `lint-parens` + `lint-deps`, pure python, seconds) as a future public health signal. GitHub CI green.
- **Wave C security baseline — immutable safety layer (part 1)** (`fd5bc82`): `src/core/safety-boundary.lisp` — protected-path registry (config/hngh.lisp + sentry/sandbox configs, frozen at init), fail-closed mutation guard (`allow-mutation-p` → NIL for protected, denial journaled), append-only action log (`journal/actions.lisp`), best-effort mode-lock (0444). Lives in core so plugins can't edit their own protection list. 19 new checks.
- **Wave B governance guardrails — rule base** (`make lint-deps`): `scripts/lint-deps.py`, 4 deterministic fitness checks (no plugin→plugin `:use`; core never calls plugin symbols except main.lisp `:init`/`:shutdown`; no circular deps; production never depends on tests). Fixture-verified; wired into `test-suite` before tests. 837/837 fast.
- **M8 routing data seed** (`ba77639`): `src/plugins/model-routes.lisp` — route table (id/backend/model/price/class) + the 2026-08 two-role primary split (agentic→deepseek-v4-flash, coding→gpt-5.6-luna), read-only parse test (design doc verification task #2). Accessors `route-model`/`role-model`. 63 new checks.
- **L2/L3 case-base + review pass (step 5)** (`6e6ddcb`): `src/plugins/situation-casebase.lisp` — persistent case-base (every scored situation + action + outcome appended to a journal, alongside human /steer as high-weight ground truth, with attribution), plus a scheduled cheap-local review pass that re-runs the judge offline to recalibrate/tune/surface emerging classes (open taxonomy; `accuracy-improving-p` = the §8 step 5 gate). 25 new checks; 837/837 fast.
- **L2/L3 judge model (step 4)** (`be14779`): `src/plugins/situation-judge.lisp` — cheap/local semantic judge for what Tier-0 can't see (faulty logic, hallucination, instruction-misread, risky-approach, wasted work). Pluggable backend (`:http` → ollama/unsloth/**vllm** direct; `:agentic` seam via `*judge-responder*` for opencode/Hermes one-offs), watchdog budget (bounded calls/run), bounded prompt (recent N obs), fail-closed verdict parsing (JSON score+confidence+reason; malformed/low-confidence never escalates), offline calibration harness (precision/recall/conf vs case-base; live gate only after calibration). 37 new checks; **`scripts/lint-parens.py` + `make lint-parens`** gate (detect + auto-fix unbalanced parens before every test run).
- **L2/L3 build — Tier-0 detectors + L3 scorer** (`0c62fa9`): `src/plugins/situation-detectors.lisp` (observation model + 8 deterministic detectors: identical-call loop, retry-without-progress, zero-progress, token-sink, failing-verification, excessive-waits, cost-exceedance, chatter-loop; emit `situation.detected` on the bus) + `src/plugins/situation-scoring.lisp` (impact×urgency×spread×confidence score, recovery-stage tracker, progressive gate-lowering → A3 actuator via `acp-steer-command`). 60 new checks.
- **A1** ACP client (`c9d6f5c`): initialize/new/prompt/update/cancel/permission over stdio JSON-RPC.
- **A2** ACP dispatch driver (`b7c5635`): run a task through an ACP agent subprocess; fail-closed.
- **A3** ACP steering primitive (`d6328b3`): `acp-steer-command` (scored situation → :none/:steer/:interrupt) + `acp-steer` on a live session; fail-closed on non-numeric scores.
- **A4** ACP server + framing fix (`95d61e2`): `hngh acp` exposes Hngh as an ACP agent; NEW `src/plugins/acp-transport.lisp` = JSON-RPC mode `:acp` with **newline-delimited framing** (ACP's wire format; the stock cxxxr/jsonrpc stdio transport uses LSP Content-Length and does NOT interoperate with real ACP peers — do not switch back to `:mode :stdio`). INTEROP-verified driving `bin/hngh acp` with plain newline JSON.
- **L2/L3 design capture** (`b01a0ac`, +research `aa2e88e`): `docs/design/situation-scoring.md` — the auto-steering brain behind A3 (recognition + scoring; recovery-stage model; steer-don't-interrupt; Tier-0 procedural first; cheap/local calibrated judge; progressive gate-lowering; self-improvement loop). Evidence in `docs/research/`.
- **Cost policy** (`ff61698`, superseded threshold): remote input above $0.20/M
  or UNKNOWN price is strategic reserve; local/known-price workhorses primary.
  PM/Designer defaults are DeepSeek Flash in `~/.hngh-night/squad-seats.conf`.
- **cogmem dropped** (`0dc36a0`, ADR-042): Anthropic-key dependency conflicts with cost policy; uninstalled everywhere, notes already in optmem. Cross-session memory = optmem + hngh beans + AGENTS.md breadcrumbs.

**Immediate next work (in order — full build order in situation-scoring.md §8):**
1. ~~L2 Tier-0 procedural detectors~~ — **DONE** (`0c62fa9`): all 8 detectors on the sentry/observation stream, model-free, unit-tested against /steer-derived fixtures.
2. ~~L3 scoring + recovery-stage tracker~~ — **DONE** (`0c62fa9`): impact×urgency×spread×confidence, stage tracker, fail-closed.
3. ~~Progressive gate-lowering + steer/interrupt mapping → A3~~ — **DONE** (`0c62fa9`): ladder + acp-steer-command mapping with lowered thresholds.
4. ~~Judge model (cheap/local) on suspicious windows, offline-calibrated first~~ — **DONE** (`be14779`): situation-judge.lisp with pluggable backend, budget, fail-closed parsing, calibration harness; live gate only after offline calibration against the case-base.
5. ~~Case-base + review pass (self-improvement loop)~~ — **DONE** (`6e6ddcb`): situation-casebase.lisp — persistent append-journal case-base (situation+action+outcome, human /steer high-weight ground truth, attribution) + review pass (recalibrate/tune/emergent-class probe) + `accuracy-improving-p` gate.
6. **Cross-agent normalization** — Hermes + OpenCode traces through the same scorer; dogfood on live squads.
7. **Session economy** — cards 131 → 132 → 140 → 141: context lifecycle,
   compact factual handoff, procedural reset packet, then fail-closed retirement
   and fresh successor control. Agents retire by default; Hngh state persists.

**Launch context (squads):** `squad-up` launches seats; PM/Designer default to
deepseek flash (cost policy). Task cards live in `~/.hngh-night/tasks/`; task 92
(L2/L3 steps 1–4) is DONE — archived to .done/. Next-wave cards: L2/L3 step 6
(cross-agent normalization), C6 emit-cron (schedule Hngh's own roadmap from the
case-base), C4/C10.

**Wave C + backup/sync deck (2026-08-08, composed granular for dogfooding):**
task cards 93–99 in `~/.hngh-night/tasks/` — 93 qlot pin → 94 hash-chain →
95 backup observe (Phase A) → 96 bwrap sandbox → 97 native least-agency
scoping → 98 canary/scan sidecar → 99 `:operation` gate. Gate items are
93/94/96/97 (no core self-modification until those land). Delegation:
model-tier per card; **GPT-5.6 Luna (`gpt-5.6-luna(-max)`, openai provider,
verified live 2026-08-08)** available for delegated code completions on the
cards; cheap/mechanical tail may go to deepseek-v4-flash via the pinned
delegation route. 93 (qlot) + 94 (hash-chain, Luna) + 96 (bwrap) DONE —
Wave C gate 3 of 4; item 3 (97, scoping) is the remaining gate block.

**Tandem experiment live (2026-08-09 ~01:15 → wind-down ~06:00):**
two Hermes seats on card 97 (item 3) — Seat A deepseek-v4-flash-0731
(DESIGN lane, docs only), Seat B gpt-5.6-luna (IMPLEMENT lane, code+tests),
each in its own Konsole window (`tandem-up` launcher), free-form
collaboration via `~/.hngh-night/tandem-20260809/` inbox/outbox/worklog,
lane separation by file scope (no overlapping files), time-aware gentle
halt if not done by 06:00. Test of the mutual-steering / tandem-coding
idea: both seats expose `hermes acp`; lap-level steering available from
the session or between seats.

Recent sessions (see work-sessions.md for full per-session artifacts):
- **M6.3** Emacs daemon: lifecycle (start/stop/health), policy-explicit start, outlives hngh.
- **M-sentry / M7** Procedural safeguards (secret-guard, context-watch); client-server daemon (SEXP-over-UDS, client CLI, systemd units).
- **MC-2** Six-panel emacs dashboard (status, events, llmtrim, opencode log, task queue, night-ralph log).
- **M8 model routing** Free-tier refresh: fallback chains moved to live OpenRouter catalog IDs across a mixed-vendor set (nvidia/google/openai/poolside/cohere/inclusionai), Qwen-AgentWorld-35B promoted to primary local fallback, VRAM/select-system/mapping updated.
- **M9 W1–5 squad autonomy** AGENTS.md discovery/merge, questionnaire-from-AGENTS.md, resource-gate preflight, PM-first-prompt generator, file-watcher/squad-dispatch/beans/squad-resources wiring; prompt matrix (`generate-prompt`, 36 skeletons, bones/flesh pass, D-040 model selection, prompt cache).
- **M9.34/M9.35 Wave C gate items** qlot pin (item 1, `cb7b82f`), hash-chained action log (item 4, M9.35) — the first two of the no-core-self-modification gate.
- **Benchmark sourcing + probe runner** Design brief (`docs/design/benchmark-sourcing.md`); `scripts/fetch-model-benchmarks.sh` (OpenRouter catalog + LM Arena PPE + Aider); `data/model-probes.lisp` runner (12 procedural probes, ollama/OpenRouter, tokens/sec, prefill timing, VRAM, snapshot writer).

## Up Next

| Priority | Item | Where |
|---|---|---|
| P0 | **L2/L3 build step 6** — cross-agent normalization (Hermes + OpenCode, same scorer) (steps 1–5 done `6e6ddcb`) | `docs/design/situation-scoring.md` §8; hngh |
| P0 | **M9 C4** start-now/pause-on-cause; **C10** MisakaNet failure shield (design-only now) | hngh; `docs/design/squad-autonomy.md` |
| P0 | **Wave C security baseline** — immutable safety layer (part 1 shipped `fd5bc82`); **item 1 qlot pin DONE** (`cb7b82f`), **item 4 hash-chain DONE** (Luna-delegated, 6441e0a), **item 2 bwrap sandbox DONE** (6441e0a, run-sandboxed default-deny + tool-hub `sandboxed-p` flag), **item 3 least-agency scoping DONE** (`dccad77`, deny-by-default `*tool-grants*` + `tool.denied`), **item 8 :operation gate DONE** (`c657071`, spec `docs/design/operation-gate.md`, human approval for core-file commits + dep installs, lint-deps composition); adoption research done + reviewed (OPA shelved ADR-044; Canarytokens, LLM Guard to adopt); **remaining: canary+scan sidecars (98), untrusted-content tagging (6), sandboxing (8)** — no core self-modification until the wave fully ships; core gate items 1–4, 8 land | hngh; `docs/design/autonomy-strategy.md` §7 |
| P0 | **M9 C6** planner cycle (roadmap → task queue → squad dispatch) — **PARKED pending Waves B/C** per 2026-08-08 owner decision (guardrails/security before launching automatic sessions) | hngh |
| P0 | **M9 C8/C9** benchmark-runner strategy + nightly benchmark cron — strategy exists (`docs/design/benchmark-sourcing.md`), runner + cron unbuilt; add `--run` wrapper to the probe runner | hngh |
| P1 | **M8 routing data seed** — `src/plugins/model-routes.lisp` (route table + two-role split: agentic→deepseek-v4-flash, coding→gpt-5.6-luna) + read-only parse test. **DONE** (`ba77639`); full routing selectors (M8) still unbuilt | hngh; `docs/design/model-routing.md` |
| P1 | **Backup/sync accommodation — Syncthing flagship** — design at `docs/design/backup-sync-integration.md` (ADR-043): observe → reconcile → tune over the Syncthing REST API, `:operation`-gated; three-job split (gbd=dotfiles, backup-manager=state tree, Syncthing=mirror). Phase A (observe/status + Tier-0 detector) is the first build | hngh; `docs/design/backup-sync-integration.md` |
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
