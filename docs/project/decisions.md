# Decisions — Lightweight Decision Log

**Last updated**: 2026-08-02

This is a lightweight log of day-to-day decisions that don't warrant a full ADR.
Architecture-level decisions live in `docs/design/architecture-decision-record.md`.

---

## 2026-06-22

### D-001: Wipe existing GitHub repo
**Context**: GitHub boundring/hngh had a prior shell/Python implementation with 15 ADRs, working code, AUR packaging, and CI. The new SBCL CL architecture is a fundamental redesign.
**Decision**: Wipe completely, start from scratch. No preservation of prior work.
**Rationale**: The prior work was a different architecture (shell/Python vs. SBCL CL microkernel). Preserving it would create confusion. The prior ADRs, while valuable, are superseded by the new design spec's 11 locked decisions (D1–D11).

### D-002: GitHub as primary, Codeberg as push mirror
**Context**: Dual-remote setup needed. GitHub has better project management (Projects V2, issues, milestones). Codeberg provides a non-corporate mirror.
**Decision**: GitHub is the single source of truth for project management (issues, projects, milestones, PRs). Codeberg is a code mirror only — commits sync, but issues/PRs are GitHub-only.
**Rationale**: No reliable bidirectional issue sync exists between GitHub and Codeberg. Maintaining issues in two places creates drift. GitHub Projects V2 has no Codeberg equivalent.

### D-003: AGPL-3.0 license
**Context**: Need to choose a license for Hngh.
**Decision**: AGPL-3.0-or-later, matching the prior repo's choice (ADR 0004).
**Rationale**: The prior project chose AGPL-3.0 to match Unsloth Studio, which Hngh integrates with. AGPL ensures network-facing services share modifications. Preserving this decision from the prior iteration.

### D-004: Planning docs in docs/project/
**Context**: Need git-visible work state tracking alongside GitHub issues.
**Decision**: Add `next.md` (current work), `done.md` (completed log), `backlog.md` (future queue), `decisions.md` (this file) to `docs/project/`.
**Rationale**: GitHub issues are the canonical tracker, but git-visible planning files give a quick "what's happening" view without opening GitHub. Maintained by hand or by agentic tools during work sessions.

### D-005: Custom test harness instead of FiveAM — **superseded by D-013**
**Context**: Need a test framework for M0. Could use FiveAM (popular CL test framework) or write a minimal custom harness.
**Decision**: Custom test harness for M0. Can migrate to FiveAM later if needed.
**Rationale**: Keeping external dependencies minimal for the skeleton. The custom harness (define-test, assert-true, assert-equal, assert-condition) is ~80 lines and sufficient for M0 unit tests. FiveAM migration is straightforward if the custom harness becomes limiting.
**Superseded**: D-013 closed this in M1.0a.

### D-006: Build directory named bin/ (not build/)
**Context**: Makefile phony target `build` conflicted with build directory name `build/`, causing circular dependency.
**Decision**: Rename build directory to `bin/`.
**Rationale**: Avoids Makefile phony/directory name collision. `bin/` is also more conventional for compiled binaries.

### D-007: File-based locks for M0.3 (SQLite deferred)
**Context**: State Store needs cross-plugin transactional locks. cl-sqlite is not available on this system without Quicklisp setup. Design spec (D9) specifies SQLite for the locks DB.
**Decision**: Use file-based locks (one file per resource, with TTL and holder tracking) for M0.3. Migrate to SQLite when cl-sqlite is available.
**Rationale**: File-based locks work for M0's needs (single-process Hngh, low lock contention). TTL-based expiry handles crash recovery. Auto-reclamation of expired locks prevents deadlocks. SQLite migration is straightforward — the lock API (acquire-lock, release-lock, list-locks) is unchanged; only the implementation swaps from file operations to SQL queries.

### D-008: Plugin manifests use Lisp plist format
**Context**: Plugin manifests need to be readable and parseable. Options: YAML, JSON, or Lisp data.
**Decision**: Use Lisp plist format (parseable with READ).
**Rationale**: Keeps dependencies minimal (no YAML/JSON parser needed). Readable and editable by humans. Natively supports Lisp data types. Can migrate to YAML later if non-Lisp plugins need a format they can parse.

### D-010: dbus bridge uses gdbus subprocess (cl-dbus deferred)
**Context**: dbus bridge needs to monitor session bus signals and call methods. cl-dbus is not available without Quicklisp.
**Decision**: Use `gdbus monitor` subprocess to watch signals and `gdbus call` for method invocation. Migrate to cl-dbus when Quicklisp is set up.
**Rationale**: gdbus is available on CachyOS/Arch (via glib2). Subprocess approach works for M0's needs (passive monitoring). cl-dbus will provide programmatic signal subscription and method calls with proper type handling when available.

### D-011: Dashboard TUI uses raw ANSI escape codes
**Context**: Dashboard TUI needs a terminal rendering library. cl-charms and croatoan are not available without Quicklisp.
**Decision**: Use raw ANSI escape codes for minimal TUI rendering (clear screen, colors, cursor positioning).
**Rationale**: No external dependency needed. Three views (overview/events/plugins) and keyboard navigation work with basic ANSI. cl-charms/croatoan will be needed for M2's graphical buddy avatar, but M0's dashboard only needs status display and event feed.

### D-012: System daemon needs _POSIX_C_SOURCE for C11
**Context**: Compiling system daemon with `-std=c11` causes implicit declaration errors for popen, pclose, and chmod.
**Decision**: Add `#define _POSIX_C_SOURCE 200809L` at the top of main.c before any includes.
**Rationale**: C11 strict mode doesn't expose POSIX functions by default. The `_POSIX_C_SOURCE` define enables them. This is standard practice for C code using POSIX functions with strict C standards. Also added `_DEFAULT_SOURCE` for `realpath()` availability (added during M0 critical review).

### D-013: Migrate test suite to FiveAM
**Context**: Custom test harness (D-005) has no setup/teardown hooks, no fixtures, no parameterized tests. Failed tests contaminate global state for subsequent tests. Scheduler tests use `sleep` (flaky). FiveAM is now installed via pacman.
**Decision**: Migrate from custom harness to FiveAM as the first M1 session (M1.0a).
**Rationale**: FiveAM provides `def-fixture` with `before-each`/`after-each` — solves state contamination. Better test isolation, proper failure reporting, and `fiveam:run!` for CI. The migration is mechanical (78 tests, same assertions, different macro names). M1 components (threat detection, resource manager, AI orchestrator) are more complex and need better test infrastructure than M0.
**Closed**: M1.0a done 2026-06-23 (commit 8ebcbe4). Vestigial harness.lisp still in tree — cleanup pending.

### D-014: M1 batch reordering — secrets moved up, backup moved down
**Context**: Original M1 batch plan had secrets manager (M1.11) in Batch 5, but AI tool hub (M1.6, Batch 3) needs API keys from the secrets manager. Backup manager (M1.10) was in Batch 5 but isn't a blocker for any other component.
**Decision**: Move M1.11 (secrets) to Batch 2 (before AI infrastructure). Move M1.10 (backup) to Batch 5 (polish). Merge old Batches 5+6 into a single Batch 5.
**Rationale**: Secrets manager must exist before AI tool hub can retrieve API keys for cloud providers. Backup manager is needed before packaging (M1.14) but doesn't block any feature development. Reordering eliminates a dependency gap that would have caused integration problems in Batch 3.

### D-009: Scheduler action functions passed as objects
**Context**: Scheduler actions can be (:event topic payload) or (:function fn). Initially tried passing quoted lambda forms and eval-ing them.
**Decision**: Pass actual function objects via (list :function (lambda () ...)) instead of quoted forms.
**Rationale**: eval of lambda forms doesnt capture local variables (null lexical environment). Passing function objects directly avoids eval entirely and correctly captures closures.

---

## 2026-06-23

### D-015: `remove-packages` returns NIL until daemon side is implemented
**Context**: Package Manager `remove-packages` API needs the system daemon to expose `RemovePackages` on dbus. Daemon side not yet built.
**Decision**: `remove-packages` is wired in the package manager but returns NIL with no side effect. Add to M2 / next daemon release.
**Rationale**: Surface the API now so callers can be written, but don't pretend the operation works. Tests should explicitly assert NIL.

### D-016: Local-vault backend is the only fully-implemented secrets backend in M1
**Context**: Secrets Manager supports 4 backends (1Password CLI, KeePassXC, vault.age, local-vault). 1Password / KeePassXC / vault.age need external CLI / binary setup that varies by system.
**Decision**: Implement local-vault fully in M1. The other three detect presence but return `:not-implemented` for get/set.
**Rationale**: Local-vault works out of the box without external tooling. Detection gives users a clear signal that the backend exists but is stubbed. Filling out the others is M2 work.

### D-017: Managed-paths API is non-blocking with 10s timeout
**Context**: System Config `write-config` and `create-snapshot` go through the system daemon. Slow operations could block the caller.
**Decision**: Add a 10s timeout to daemon dbus calls. Longer operations should be backgrounded by the caller.
**Rationale**: Synchronous user-facing operations should not hang. Backgrounding is the caller's responsibility.

---

## 2026-06-24

### D-018: AI-generated plugins get one-notch confidence downshift in LLM threat review
**Context**: LLM Threat Detector produces a confidence level (`:high` / `:med` / `:low`) for L2 verdicts and L4 assessments. AI-generated plugins (`:trust-tier :ai-generated`) have inherently higher uncertainty than first-party plugins.
**Decision**: When reviewing an AI-generated plugin, the LLM threat detector downshifts confidence by one notch (`:high → :med`, `:med → :low`, `:low → :low`).
**Rationale**: Fail-safer posture for higher-uncertainty sources. This is a documented behavior — not a hidden downgrade — and applies uniformly across L2 and L4 reviews.

### D-019: LLM Threat Detector stores history as append-only list
**Context**: `state/plugins/llm-threat/history.lisp` records every review action.
**Decision**: History is a single list appended in chronological order, with a `*state-append-lock*` mutex around the read-modify-write cycle.
**Rationale**: Append-only with locking is sufficient for the audit trail. Per-plugin history is derived by joining `history.lisp` with `plugins/<slug>/review-verdict.lisp` and `state/plugin-observations/<slug>/assessments.lisp` via timestamp.

### D-020: Hnghbeats condensation emits exactly one `hnghbeats.beat` event per call
**Context**: `perform-condensation` produces a deterministic summary plist for a given date and persists it to `journal/hnghbeats/<date>.lisp`.
**Decision**: One condensation call emits exactly one `hnghbeats.beat` event with the full summary payload. Subscribers that want only a category (e.g., only costs) should re-condense or filter the plist client-side.
**Rationale**: Keeps the event simple. The summary is small (~50 lines plist max) so re-sending the whole thing is fine.

### D-021: Knowledge Base writes are best-effort, never error
**Context**: KB is called from many paths (LLM threat detector pattern recording, system config events, AI orchestrator handoffs). A failing KB write could cascade into a failure of the calling path.
**Decision**: KB write failures return NIL but do not signal an error. Lock-busy, missing directories, and state-store-unavailable are all silently ignored.
**Rationale**: KB is a knowledge store, not a critical path. Critical writes should be explicit `kb-write-article!` calls if they need to propagate errors. Standard `kb-write-article` is fire-and-forget for instrumentation purposes.

### D-022: Local-runtime invoke passes a model-spec plist, not a model-name string
**Context**: AI Orchestrator's local-runtime invoke path was passing `(delegate-policy-model policy)` as a model-name string. `spawn-runtime` expects a plist `(:name "model-name" ...)`.
**Decision**: Call site converts: `(list :name model-name)`. Spawn result is consumed via `runtime-info-id` and `runtime-info-status`.
**Rationale**: Plist shape matches the spawn API. Plist allows extension (e.g., adding `:context-size` or `:quantization`) without breaking the call signature.

### D-023: Agent `backend-id` is tracked separately from agent ID for completion mapping
**Context**: Tool Hub emits `agent.completed` payloads keyed by `:invocation-id` (its own internal counter). Orchestrator tracked agents by numeric `agent-info-id`. The two are sometimes the same value, sometimes not.
**Decision**: `agent-info` struct carries a `backend-id` slot. Orchestrator's `handle-agent-completed` does `find-agent-by-backend-id` lookup in addition to `find-agent`. Event payloads emit both `:id` and `:invocation-id` for robustness.
**Rationale**: Both naming schemes need to coexist. The orchestrator's `agent-info-id` is the primary key for orchestrator state; the backend-id is the primary key for tool-hub state. Mapping either direction works.

### D-024: `stop-runtime` takes a `:reason` keyword for grant-release policy
**Context**: `stop-runtimes-by-grant-id` was reimplementing stop semantics inline. The shared `stop-runtime` function needs to know whether the stop is explicit (release the grant) or preempted (don't — caller releases).
**Decision**: `stop-runtime` takes `&key (reason :explicit)`. When `reason` is `:preempted`, the grant is NOT released inside `stop-runtime` — the preemption caller does that.
**Rationale**: One path for stopping, one place to maintain. The reason lets the same code path handle both user-initiated stop and automatic preemption cleanly.

### D-025: Provider-specific auth headers (not generic `Authorization`)
**Context**: Direct API calls (Anthropic, Google, OpenAI) each have a different auth header convention. Anthropic uses `x-api-key`, Google uses `x-goog-api-key`, OpenAI uses `Authorization: Bearer`.
**Decision**: AI Tool Hub `provider-api-headers` function dispatches on tool-id and returns the correct header list. Headers + payload are written to temp files and passed to curl via `-H @file` and `--data-binary @file` to keep them out of `ps` output.
**Rationale**: Direct API integration needs correct auth per provider, and process-arg leakage is a real concern for security-sensitive credentials.

### D-026: `tests/unit/harness.lisp` is NOT orphaned after FiveAM migration
**Context**: After M1.0a migrated all tests from custom `define-test`/`assert-true` macros to FiveAM's `def-suite`/`test`/`is`, the file `tests/unit/harness.lisp` was flagged as a candidate for deletion because the original custom framework no longer exists.
**Decision**: Keep `tests/unit/harness.lisp`. The file now holds the migrated FiveAM test infrastructure: `def-suite :hngh` (root suite), `hngh.tests:run-tests` (entry point called by both `make test` and `asdf:test-system`), and shared fixture helpers (`make-tmp-home`, `cleanup-tmp-home`, `fixture-path`).
**Rationale**: Confusing file name (the original "harness" referred to the custom test framework) but the contents are essential. All 19 test files use `make-tmp-home` / `cleanup-tmp-home` from this file. Optional follow-up: rename to `tests/unit/fiveam-harness.lisp` for clarity (deferred to Batch 5).

### D-027: Wire `asdf:test-system` to actually run the test suite
**Context**: `hngh.asd` `:perform (test-op ...)` body was empty (`(declare (ignore op c))` followed by no forms). `asdf:test-system :hngh/tests` would do nothing. `make test` worked because it bypasses via direct `(hngh.tests:run-tests)` call. Any IDE or external tooling that relies on `asdf:test-system` would silently skip tests.
**Decision**: Wire the body to `(uiop:symbol-call :hngh.tests :run-tests)`. After this change, `asdf:test-system :hngh/tests` runs all 1020 checks with 100% pass.
**Rationale**: `asdf:test-system` is the standard way to invoke tests for any Common Lisp system. The `make test` target works as before; external tools now also work.

### D-028: Backup Manager secrets exclusion — hardcoded list + defense-in-depth + Oracle hardening
**Context**: B7 (M1.10) git-versions the state tree and can push to public remotes. Its primary guarantee is that secrets NEVER reach a commit. The Secrets Manager (B8) exposes no API to enumerate secret paths (confirmed during M1.10 context-gathering), and the only secret location in the system is `secrets/` (plus the `secrets/vault.lisp` vault and `config/plugins/secrets-manager/`).
**Decision**: The Backup Manager owns a hardcoded `*default-ignore-paths*` / `*forbidden-prefixes*` / `*forbidden-suffixes*` set (`secrets/`, `state/locks/`, `config/plugins/secrets-manager/`, `*.age`, `*.gpg`). Defense-in-depth: (1) a managed `.gitignore`, AND (2) a pre-commit staging guard that unstages forbidden paths and aborts the commit. An Oracle security review hardened the enforcement layer (no design change): H1 git C-quoting unquoted before the prefix check; H2 `safe-git-arg-p` validation + `--` separators against argument injection; H3 a `*git-lock*` mutex serialising commit/push/restore against the auto-commit scheduler thread; H4 auto-stash before restore; H5 forbidden-path rejection in restore.
**Rationale**: The dynamic `SecretPathDeclared` coordination from the design spec is unnecessary for v0.1 (no dynamically-declared secret paths exist). A hardcoded list is simpler and provably complete for the current system. Defense-in-depth means a single failure (e.g., `git add -f`) does not leak secrets.

### D-029: Backup Manager known limitations (documented, deferred)
**Context**: Oracle review surfaced two residual limitations that are not enforcement bugs.
**Decision**: Document and defer, not block M1.10:
- **Prior-committed secrets (M1)**: the staging guard only protects the current commit. Secrets committed before the plugin existed (or via a bypass) persist in history and would be pushed. Mitigation: add a `verify-history` command (deferred to Batch 5 follow-up) and document "audit history before first push to a public remote."
- **Case-sensitive-FS assumption (M2)**: the prefix/`.gitignore` checks are case-sensitive; a `Secrets/` directory on a case-insensitive FS would bypass both. Hngh creates `secrets/` with fixed casing, so this requires deliberate user action. Documented as an assumption.
**Rationale**: Both are narrow, require unusual conditions, and are appropriately handled by documentation + a future audit command rather than blocking the milestone.

### D-030: M1 integration hardening — close verified event-wiring gaps
**Context**: An alignment review (intent vs. built) plus a cross-plugin event-wiring audit found that the 12 plugins were built as well-tested but isolated islands, with real integration-fabric gaps that unit tests (plugins in isolation) don't catch: (1) Plugin Host published no `plugin.*` lifecycle events, so L3 threat observation received nothing; (2) hnghbeats subscribed to `"*.*"`, which matches nothing (a leading `*` is literal in `topic-match-p`); (3) ai-orchestrator re-processed its own `agent.completed` emissions; (4) dbus-bridge emitted `dbus.signal.*` but never `system.*`, orphaning resource-manager's `system.udev.*` subscription.
**Decision**: Fix all four with regression tests, before M1.15. Plugin Host now emits `plugin.loaded`/`unloaded`/`reloaded`/`load-failed`; hnghbeats subscribes to `"*"`; `handle-agent-completed` ignores its own source; dbus-bridge normalizes known interfaces to `system.*` (dual-publish, keeping `dbus.signal.*`). NOT in scope (deferred): Dashboard depth (the "all from the TUI dashboard" exit criterion — own session) and runtime plugin *behavioral* observation events (`plugin.subprocess-started`, etc. — requires instrumentation, likely M2).
**Rationale**: Cheaper to fix known wiring defects before integration tests (M1.15) so the tests validate a correct system. The fixes are surgical and restore design intent without changing the event-bus core. An event producer/consumer audit is now a recommended gate before integration testing.

---

## 2026-08-02

### D-031: M7 wire protocol — SEXP-over-UDS
**Context**: M7 transforms hngh into a daemon + client architecture. Need a wire protocol for daemon ↔ client communication over Unix domain sockets.
**Decision**: Length-prefixed S-expressions over Unix sockets. 4-byte big-endian length header followed by S-expression bytes. Message types: `:request` (client→daemon with `:id`), `:response` (daemon→client matching `:id`), `:event` (daemon→client async). Security: `*read-eval* nil` at wire-protocol.lisp:135.
**Rationale**: S-expressions are native to CL, parseable with `read` when `*read-eval*` is bound to NIL. Length-prefix framing avoids delimiter escaping. UDS is local-only, no auth needed for v0.1. TCP upgrade deferred to M3 (Network).

### D-032: M7 daemon architecture — headless SBCL + systemd
**Context**: Hngh runs as a foreground process with embedded tmux. M7 extracts daemon into a headless systemd user service.
**Decision**: `hngh-daemon` is a headless SBCL process owning event loop, scheduler, plugin host, state store, event bus. systemd user service manages lifecycle. Clients (CLI, Emacs, TUI) connect via UDS wire protocol. Daemon stays alive when clients disconnect.
**Rationale**: Emacs-style headless daemon pattern. Systemd provides restart/health/logging. Decoupling daemon from UI enables multiple concurrent clients and remote access (M3).

### D-033: Agent Platoons v0 — shell launcher + SEXP specs
**Context**: Need declarative, reproducible spin-up of attended multi-agent sessions with wake prompts, role contracts, and journaling.
**Decision**: v0 is a bash launcher (`~/.local/bin/squad`) reading SEXP specs from `hngh/squads/`. Specs declare name, layout, preflight gates, member roles (cli/model/cwd/wake-template), and journal paths. Launcher creates tmux session, injects wake prompts, writes projected journal. Lisp plugin (`agent-platoons.lisp`) deferred to M9.
**Rationale**: Shell script is fast to implement and test. SEXP is Lisp-native, parseable with `sbcl --script`. Preflight gates (MCP, systemd, model, quota, disk) abort on failure. Projected/actual journal convention provides audit trail.

### D-034: Night queue task numbering — check .done/ before renumbering
**Context**: Multiple agents staging tasks to `~/.hngh-night/tasks/` caused collisions when reusing numbers.
**Decision**: Check `.done/` directory before numbering new tasks. Consumed tasks move to `.done/` immediately. Ledger is append-only; never reuse numbers.
**Rationale**: Simple filesystem-based coordination. No locking needed. Agents sign notes in optmem with their name for attribution.

---

## 2026-08-02

### D-035: hngh-up architecture — local command with procedural questionnaire and strategy system
**Context**: Need a `hngh up <goal>` command for goal-driven squad spin-up. Must not depend on the daemon (local command), must gather context to generate adaptive questions (max 5), must derive squad specs from answers, must support strategy reuse/sharing, and must integrate with existing `squad` launcher.
**Decision**: 
- Local command (no daemon dependency) — `up` subcommand in client CLI, runs as a standalone Lisp script.
- Procedural questionnaire — max 5 adaptive questions generated from project/file/system/OptMem context.
- Spec derivation — answers transformed into squad spec with model mapping, role layouts, preflight gates, journal config.
- Strategy system — built-in strategies (duo-review, feature-sprint, design-fork, nightly-audit) + user-saved + shareable (sanitized export/import).
- Autonomous continuation — token-aware pause/resume via forward-prompt mechanism.
- Social sharing — sanitized strategy export/import for cross-instance reuse.
- Integration — launches squads via existing `~/.local/bin/squad` script (reads SEXP specs from `hngh/squads/`).
**Rationale**: Daemon-independent CLI command enables use without running hngh service. Questionnaire capped at 5 questions keeps interaction lightweight. Strategy system enables pattern reuse and team sharing. Existing squad launcher avoids duplicating tmux/session logic. Forward-prompt mechanism aligns with M2 session lifecycle design.

### D-036: Squad automation bootstrapping — C7 self-written prompts, file-change notification, journal lifecycle
**Context**: M9 W1-2 done (C1, C2, C5, partial C3). Squad startup still uses static prompts. Hngh needs to automate the PM's first-prompt generation from project/system context, generalize file watching beyond config files (gbd's systemd .path unit pattern), and wire journaling into squad lifecycle (startup, ongoing, shutdown). Test counts in docs are stale and manually maintained — need procedural lint.
**Decision**:
- C7 PM-first-prompt generator: procedurally assembles orientation prompt from AGENTS.md discovery, plans, system context, roadmap, OptMem, squad intent. Replaces static SEAT_PROMPT strings.
- File-change notification: generalize config-watcher to registered-path bus. Plugins register interest. Systemd .path units for daemon mode (gbd pattern). mtime-poll fallback for local mode. Events on the bus as squad comm-lines.
- Squad journal lifecycle: startup writes -projected.md, ongoing writes -actual.md triggered by file-change events, shutdown writes -fragment.md (C5).
- Test-count lint: `make lint-counts` runs make test, parses check count, scans docs for N/M patterns, exits 1 on stale. No LLM involved.
- Self-improvement loop: hngh reads its own roadmap, decomposes next wave, dispatches a squad to implement it. First iteration wired in Wave 5.
**Rationale**: Static prompts don't scale. Procedural generation from context makes squads self-orienting. gbd's systemd .path pattern is proven, native, and doesn't poll. Journal lifecycle makes squad work auditable and resumable. Test-count lint eliminates a recurring manual task that wastes LLM tokens.

---

## 2026-08-04

### D-037: OpenRouter quota-aware fallbacks and multi-tier model rotation
**Context**: We depleted our 7-day Moonshot Kimi K3 native API quota (resets August 8th), and we have a strict $20/week spending limit on OpenRouter. Premium models (such as GLM-5.2 or Kimi K3 via OpenRouter) must be rationed.
**Decision**: 
- Rotate PM and Designer through cheap and free models (such as `deepseek-v4-flash`, `gpt-5.6-luna`, or free models via OpenRouter).
- Establish the "Skeleton, Bones, and Flesh" development workflow: use local Gemma or free models for skeleton code/unit tests (RED); use cheap models for implementation logic; only invoke premium models (`glm-5.2`) for final validation or fixing highly complex logical bottlenecks.
- Implement parallel cheap model fan-out and voting instead of single-turn premium model debugging.
**Rationale**: Keeps operating costs strictly under budget limits while maintaining a functional squad structure. Leveraging local and free-tier resources for the majority of standard TDD loops preserves the weekly $20 budget for critical-path PM/Designer steering.

### D-038: MisakaNet integration for agent safety and error mitigation
**Context**: Cheap squads running headless loops are vulnerable to repeating identical environment/code failures (such as SQLite database locks, cronjob races, or cross-thread delivery mixing), wasting valuable context tokens.
**Decision**: 
- Integrate MisakaNet (github.com/Ikalus1988/MisakaNet), a git-backed failure-memory layer.
- Hook into the squad event bus: when `squad.seat.error` or `make test` fails, query the local or API-based MisakaNet lesson index.
- If a lesson matches the error pattern (e.g. SQLite database lock, uncommitted git locks), inject the matching "Fix Path" directly into the Coder's prompt.
- Contribute resolved lessons (such as the Lisp parenthesis mismatch) to the global MisakaNet repository using TEMPLATE.md.
**Rationale**: Injects collective failure-recovery memories directly into the agent's context, preventing endless loops of self-debugging and saving significant token costs.

### D-039: Tight scaffolding and strict goalposts for less-intelligent models
**Context**: When rotating the Designer or Coder to cheaper models (such as `gemma-4-12b` or `deepseek-v4-flash`), open-ended design specs lead to halluncinated structures or broken interfaces.
**Decision**: 
- All design sessions (D2–D9) must be tightly structured with explicit goalposts, keyword-milestones, "must-includes" (interfaces, paths, libraries), and "must-not-includes" (deprecated patterns, external binary deps, multithreading locks).
- PM must validate every spec against these criteria before dispatching to the Coder.
**Rationale**: High-scaffolding prompts enable low-intelligence/cheap models to perform high-quality, targeted work by narrowing their search space, eliminating loose design ambiguity.

---

## 2026-08-05

### D-040: Canonical model mandate — deepseek-v4-flash-0731 primary, GLM-5.2 deep tier
**Context**: oh-my-openagent.json and ~/.hermes/config.yaml now carry strictly-ordered fallback chains (deepseek-v4-flash-0731 -> deepseek-v4-flash -> gpt-5.6-luna -> mimo-v2.5 -> minimax-m3 -> gemini-3.5-flash -> hy3-preview -> glm-5.2 -> nemotron-3-ultra:free -> Qwythos-9B local -> gemma-4-12b local), GLM-5.2 primary for deep-thinking work, gpt-5.6-terra for heavy research, qwen3.7-flash for vision. Squad configs referenced older chains (kimi-k2.6, deepseek-v4-pro, gemini-3.5-flash-lite, local-first daily driver).
**Decision**:
- Align hngh runtime + docs to the mandate: squad-seats.conf, squad-seats-cheap.conf, squad-up defaults/prompts/--cheap.
- Primary for most roles: deepseek-v4-flash-0731 (openrouter). GLM-5.2 stays primary for PM/Designer. Vision looker: qwen3.7-flash. Locals are last-resort fallbacks, not the daily driver.
- Policy does not lean on GitHub Copilot; gpt-5.6-luna is openai-provided.
**Rationale**: Cheapest-capable-first beats free-faucet-first on intelligence per $; consistency across Hermes, OpenCode (oh-my-openagent), and hngh squads. K3 native API back Aug 8.
**Files touched**: ~/.hngh-night/squad-seats.conf, squad-seats-cheap.conf, ~/.local/bin/squad-up, AGENTS.md, docs/design/model-pareto.md, model-routing.md, model-strategy.md, journal/20260805-model-mandate.md.

### D-041: MCP integration — misakanet MCP replaces gh-api lookup; nothumansearch documented
**Context**: misakanet, cogmem, nothumansearch MCPs auto-start in Hermes/OpenCode.
**Decision**: model-strategy.md Misaka Guard pre-flight now queries the misakanet MCP; AGENTS.md MCP section lists nothumansearch; cogmem + misakanet are candidates to replace OptMem for PM communication (pending design review).
**Rationale**: Tools are live; the design doc referenced a pre-MCP gh api call.

