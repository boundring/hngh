# Decisions — Lightweight Decision Log

**Last updated**: 2026-06-22

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

### D-005: Custom test harness instead of FiveAM
**Context**: Need a test framework for M0. Could use FiveAM (popular CL test framework) or write a minimal custom harness.
**Decision**: Custom test harness for M0. Can migrate to FiveAM later if needed.
**Rationale**: Keeping external dependencies minimal for the skeleton. The custom harness (define-test, assert-true, assert-equal, assert-condition) is ~80 lines and sufficient for M0 unit tests. FiveAM migration is straightforward if the custom harness becomes limiting.

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

### D-014: M1 batch reordering — secrets moved up, backup moved down
**Context**: Original M1 batch plan had secrets manager (M1.11) in Batch 5, but AI tool hub (M1.6, Batch 3) needs API keys from the secrets manager. Backup manager (M1.10) was in Batch 5 but isn't a blocker for any other component.
**Decision**: Move M1.11 (secrets) to Batch 2 (before AI infrastructure). Move M1.10 (backup) to Batch 5 (polish). Merge old Batches 5+6 into a single Batch 5.
**Rationale**: Secrets manager must exist before AI tool hub can retrieve API keys for cloud providers. Backup manager is needed before packaging (M1.14) but doesn't block any feature development. Reordering eliminates a dependency gap that would have caused integration problems in Batch 3.

### D-009: Scheduler action functions passed as objects
**Context**: Scheduler actions can be (:event topic payload) or (:function fn). Initially tried passing quoted lambda forms and eval-ing them.
**Decision**: Pass actual function objects via (list :function (lambda () ...)) instead of quoted forms.
**Rationale**: eval of lambda forms doesnt capture local variables (null lexical environment). Passing function objects directly avoids eval entirely and correctly captures closures.