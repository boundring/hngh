# Decisions — Lightweight Decision Log

**Last updated**: 2026-06-24

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
