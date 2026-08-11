# Hngh crystallization implementation plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Recast Hngh as a small, profile-driven local operating-system harness whose core is cheap to load, whose state is bounded and legible, and whose optional capabilities do not become permanent code, process, context, or storage obligations.

**Architecture:** Replace the current “load every first-party plugin, then initialize nearly all of them” model with an image composed from a small kernel plus explicit operating modes. A profile selects modes and adapters before boot; no runtime component starts merely because its source was compiled. Durable state becomes a small number of named records with one owner, while volatile data, raw transcripts, caches, and runtime sockets stay separate, bounded, and disposable.

**Tech stack:** SBCL/Common Lisp, ASDF systems, FiveAM, small C privileged daemon, systemd user/system units, ACP/MCP adapters, Lisp configuration, SQLite only if selected at the storage decision gate.

---

## 1. Why this refactor is needed

Hngh already has the right base principles: local-first coordination, explicit authority, disposable agent sessions, evidence instead of model assertions, and use of existing agent harnesses rather than reimplementation. Its implementation has grown beyond those principles.

### Observed repository inventory — 2026-08-10

| Surface | Observed state | Consequence |
|---|---:|---|
| Tracked source | 23,210 lines across 56 `src/` files | The implementation is broad before a profile selects any job. |
| Tests | 12,315 lines across 59 test files | Good coverage exists, but every test system currently depends on the full image. |
| Packages | 53 Common Lisp packages | Package names expose a larger control surface than a small kernel needs. |
| Load graph | one serial `hngh` ASDF system with 15 core files and 36 plugin files | Loading the package means loading every feature. |
| Startup | `src/core/main.lisp` directly initializes the kernel plus roughly 30 first-party components | The plugin host is not the startup authority; a profile cannot make a component absent. |
| State tree | `*state-tree-dirs*` eagerly creates 21 directories | Empty features leave filesystem surface even when unused. |
| State paths | many component-specific `config/plugins/`, `state/plugins/`, journals, agent directories, and per-resource lock files | Retention, backup, migration, and file-count control are distributed rather than governed. |
| Build output | ignored `bin/` is 106 MiB; ignored `.qlot/` is 11 MiB | The repository ignores the material, but the local package footprint remains unmeasured and unbudgeted. |

Specific seams worth preserving but correcting:

- `src/core/plugin-host.lisp` provides a plugin lifecycle concept, while `src/core/main.lisp` bypasses it with direct init/shutdown calls.
- `src/core/state-store.lisp` is readable and conservative (`*read-eval*` is disabled), but it mixes durable configuration, mutable records, journals, and lock files under one broad file tree.
- `src/core/event-bus.lisp` journals every published event by default; its declared queue/backpressure structure is broader than the actual direct-callback delivery path.
- `Makefile` runs `scripts/lint-parens.py --fix` as part of `make test`. A verification command that edits its inputs is not a pure acceptance gate.
- `hngh.asd` is serial and includes every implementation module. `hngh/client` depends on the complete `hngh` system even though it is intended to be thin.
- `src/plugins/hngh-up.lisp` (2,271 lines) and `src/plugins/ai-orchestrator.lisp` (1,607 lines) have multiple distinct concerns each. They should be decomposed by contract, not merely renamed.

The just-completed documentation consolidation is a useful precedent: one compact current surface, an archive for historical detail, one fact in one home, and compatibility paths only where needed.

## 2. Non-negotiable invariants

1. **Hngh is a coordinator, not a replacement agent harness.** ACP, MCP, Hermes, OpenCode, systemd, Git, Syncthing, and local runtimes remain external substrates behind bounded adapters.
2. **No model receives broad ambient state by default.** A profile and a work package define the packet, capabilities, route class, and context cap before launch.
3. **Every durable record has one owner, schema, retention class, and migration path.** Unknown state is not silently recreated or discarded.
4. **A process, adapter, watcher, database connection, or journal exists only when the selected profile needs it.** Feature source presence does not authorize startup.
5. **The privileged C daemon stays narrow, stateless, typed, and free of model logic.** It remains a separate trust boundary.
6. **The ordinary path is procedural.** Models may classify ambiguity or produce bounded decision packets; they do not decide their own authority, persistence, retention, or continuation.
7. **Compatibility is explicit and temporary.** Every compatibility path names its removal condition and has a read/write audit. No silent dual-write period.
8. **The planner-fixture review hold remains intact.** This program does not edit `tests/unit/test-hngh-planner.lisp`, reinterpret its evidence, or bypass the current delivery frontier.
9. **A refactor must lower or justify measured surface.** New code, directory, process, table, record type, or configuration key needs a declared replacement or measured value.

## 3. Architecture options

### Option A — Prune-first monolith

Keep one ASDF system and the current `src/core/` plus `src/plugins/` layout. Remove or archive components judged unused, add a few config toggles, and stop initializing some components.

**Benefits**

- Lowest immediate migration risk.
- Preserves existing package and test topology.
- Can quickly stop obvious unused processes.

**Costs**

- The complete image still loads every feature and dependency.
- Config toggles become a second, weak startup mechanism beside direct calls.
- State ownership and event retention remain distributed.
- It cannot make the small/default Hngh materially small.

**Use only if:** the operator wants a short stabilization pass before a larger design decision. It is not sufficient as the crystallized architecture.

### Option B — Profiled image with internal modes and narrow adapters

Create a small kernel and compose explicit modes—`work`, `agents`, `machine`, and `observe`—through named profiles. Replace “plugin” as the internal unit with an in-repo mode/subsystem contract. Keep ACP, systemd/dbus, Hermes/OpenCode, and Emacs as adapters. Build only the systems the selected profile needs.

**Benefits**

- Matches the requested Emacs-style model: a small image, selected modes, explicit hooks, and user-readable configuration.
- Separates policy and records from external tools and UI.
- Makes a local procedural profile genuinely small and fail-closed.
- Lets Hngh ship a usable operator profile without starting dashboards, watchers, model management, or agent control by default.
- Offers a clean later boundary for a network node without turning all of Hngh into a distributed system now.

**Costs**

- Requires a disciplined mode contract and an ASDF split before source moves.
- Existing direct package references must be inventoried and converted deliberately.
- Requires a real profile and storage migration fixture set.

**Recommendation: choose Option B.** It is the smallest architecture that realizes the product’s own doctrine without an all-at-once rewrite.

### Option C — Network-first microkernel

Immediately make every capability a separate process or remotely addressable service, with durable queues and node synchronization as the default.

**Benefits**

- Strongest isolation and a clear future multi-machine story.
- Potentially smallest resident processes per host.

**Costs**

- Introduces service discovery, authentication, versioning, distributed failure handling, and operator burden before local contracts are stable.
- Makes local dogfooding and dynamic Common Lisp iteration slower.
- Expands rather than shrinks the package, file, process, and operational surface.

**Reject for this iteration.** A node boundary may follow only after the local mode contracts, data model, and migration receipts are proven.

## 4. Recommended target shape

### 4.1 Product shape

```text
operator / Emacs / CLI
          |
          v
       Hngh image
          |
  +-------+--------+------------------+
  | kernel | mode registry | policy   |
  +-------+--------+------------------+
          |              |
          |              +-- durable record service
          |
  +-------+---------+----------+--------+
  | work mode | agent mode | machine | observe |
  +-------+---------+----------+--------+
          |
          +-- adapters: ACP, systemd/dbus, tool process, local runtime, Emacs
```

The kernel is a library and boot coordinator, not a hidden all-feature daemon. It owns only:

- boot/profile resolution;
- typed command and event envelopes;
- authority/policy admission;
- mode lifecycle and dependency order;
- durable-record API and migration gate;
- process supervision primitives;
- observability necessary to prove the above.

The modes own vertical product behavior:

| Mode | Owns | Explicit exclusions |
|---|---|---|
| `work` | work packages, claims, handoffs, retirement, afterlife reduction, case records | provider launch mechanics, package actions, UI rendering |
| `agents` | route admission, ACP sessions, adapter capability truth, receipts, context packets | durable task authority, agent-harness reimplementation |
| `machine` | approved user-space maintenance, local runtime leases, backup/sync coordination, system adapter requests | root execution policy, autonomous privileged action |
| `observe` | measurements, situation classification, bounded summaries, dashboard feeds | retention policy, agent lifecycle authority |

An adapter translates an outside protocol into a typed Hngh command/event. It must not contain work policy, planner rules, storage layout, or independent lifecycle truth.

### 4.2 Source and ASDF shape

Target the following logical systems first. Do not physically move all files until the compatibility systems and focused fixtures pass.

```text
hngh/kernel       boot, profile, command/event schema, policy, lifecycle
hngh/store        durable record API, migrations, retention and export
hngh/node         Unix socket daemon and thin CLI protocol
hngh/work         work, claims, receipts, handoff, retirement, case records
hngh/agents       routes, ACP, tool process adapter, local runtime admission
hngh/machine      systemd/dbus, package/config, backup/sync adapters
hngh/observe      procedural observers, bounded summaries, optional dashboard feed
hngh/emacs        Emacs client integration
hngh/operator     default selected operator profile
hngh/tests-*      focused test systems matching the systems above
```

The final source placement should be:

```text
src/
  kernel/       # only shared boot, contract, policy, lifecycle primitives
  store/        # one durable-record boundary
  node/         # socket server and client protocol
  modes/        # work, agents, machine, observe
  adapters/     # ACP, tool process, systemd/dbus, local runtime, Emacs
  ui/           # thin CLI/TUI renderers; never policy or persistence
  system-daemon/# existing narrow C privilege boundary
```

This creates fewer *loadable units* and fewer runtime responsibilities. It does not require turning healthy focused files into one large file. The file-count reduction goal applies most strongly to state/configuration, generated artifacts, and package distribution—not to destroying readable source boundaries.

### 4.3 Profiles

Profiles are data with a strict schema, not arbitrary executable configuration. The initial set:

| Profile | Modes | Default posture |
|---|---|---|
| `minimal` | kernel, store, node | local/procedural only; no remote routes, MCP, watcher, dashboard, or automatic adapter launch |
| `operator` | kernel, store, node, work, selected observe | normal interactive local control; agents and machine actions are opt-in commands |
| `agent-control` | `operator` plus agents | ACP/tool adapters after route and authority admission |
| `maintenance` | `operator` plus machine | operator-declared maintenance window only |
| `observer` | kernel, store, observe | read-only status/measurement; no launch, write, or privileged path |

The final default must be `operator`, not an implied full image. Profile changes take effect only at a clean restart, except for a separately designed, fixture-tested hot-swap contract.

### 4.4 Runtime and storage shape

Use four explicit classes under `~/.hngh/`:

```text
config.lisp        operator-owned, versioned configuration
state.sqlite       durable ledgers, indexes, migrations, and compact current state
run/               socket, locks, PID and ephemeral transport state; removed at stop
objects/           bounded attachments only when a durable record points to one
secrets/           separate existing secret boundary; never included in the database/export
```

`state.sqlite` is a proposed storage decision, not an implementation authorization. The decision gate must compare it against a compacted Lisp-record store using the same fixtures. SQLite is preferred if it provides a materially lower file count, atomic migration/transactions, queryable receipts, and bounded retention without weakening inspectability or backup recovery.

Rules regardless of engine:

- configuration remains human-editable declarative Lisp data with read evaluation disabled;
- each record has `(kind id schema-version owner created-at expires-at retention-class)`;
- raw model transcripts, tool streams, screenshots, and large outputs are attachments, not default ledger rows;
- a session’s durable end state is a receipt plus a compact handoff/afterlife record, not its full transcript;
- no global event stream is retained by default merely because an event was emitted;
- `run/` is never backed up or mirrored;
- export/backup derives a reviewable snapshot from the durable store; it does not duplicate every transient file.

### 4.5 Event and process policy

Events divide into three classes:

1. **volatile signals**: in-memory only; dropped on restart without pretending otherwise;
2. **durable decisions/receipts**: compact, schema-validated, append-only ledger records;
3. **bounded observations**: sampled/reduced records with an expiry/compaction rule.

A profile starts zero child processes until a selected mode invokes a declared adapter. Process and service declarations carry an owner, reason, restart policy, capability set, evidence source, and stop action. An unavailable adapter fails closed; no alternative provider, tool, or daemon starts by implication.

## 5. Ordered implementation plan

The current delivery frontier remains authoritative. These tasks become active only after the operator accepts the crystallization decision and the existing card 147 review hold is cleared or explicitly scoped around. Until then, the permitted output is design, inventory, and fixtures that do not alter the held surface.

### Task 1: Establish a reproducible footprint baseline

**Objective:** Make surface reduction measurable before any refactor claims.

**Files:**
- Create: `scripts/audit-footprint.py`
- Create: `tests/fixtures/footprint/known-minimal/`
- Create: `tests/scripts/test-audit-footprint.py`
- Modify: `Makefile`
- Modify: `docs/core/system-design.md`
- Modify: `docs/core/records-and-governance.md`
- Modify: `docs/records/backlog.md`

**Steps:**

1. Define a machine-readable footprint receipt with source file count, ASDF component count, packages loaded by profile, startup wall time, RSS, process count, open file count, durable-store byte count, runtime-file count, and archive/attachment byte count.
2. Add fixtures that run against a temporary `HNGH_HOME`; never measure the operator’s live state tree in tests.
3. Make the audit command read-only. It must label unavailable measurements `UNKNOWN`, not zero.
4. Split `make lint-parens` into a check-only target and an explicit formatting/fixing target. `make test` must not modify a tracked source file.
5. Add a test that snapshots `git diff --exit-code` before and after the fast suite, proving test purity.
6. Record the initial receipt in a dated `docs/records/` entry and link only the summary/definition from the core docs.

**Acceptance:** `make test` leaves a clean fixture worktree unchanged; `make audit-footprint PROFILE=minimal HOME=<temp>` creates a schema-valid receipt; a missing metric remains `UNKNOWN`.

### Task 2: Lock the mode, profile, storage, and plugin-authority decisions

**Objective:** Replace contradictory legacy design assumptions with one accepted current architecture contract.

**Files:**
- Modify: `docs/core/system-design.md`
- Modify: `docs/core/session-operations.md`
- Modify: `docs/core/delivery.md`
- Modify: `docs/core/records-and-governance.md`
- Create: `docs/records/YYYY-MM-DD-crystallization-decision.md`
- Modify: `CHANGELOG.md`

**Steps:**

1. Record the chosen option, specifically whether internal first-party code is governed as modes rather than dynamically discovered plugins.
2. Define the profile schema, the mode lifecycle contract, and the fail-closed behavior for unavailable/unknown adapters.
3. Decide the durable-store engine after comparing the two fixture implementations. Record migration, backup, recovery, and inspection consequences.
4. Set retention classes and operator-approved ceilings for raw transcripts, observations, receipts, attachments, archives, and backup snapshots. Do not invent retention durations.
5. List every compatibility API/path, its sole reader/writer, verification fixture, removal condition, and expected deletion release.

**Acceptance:** current core documentation names one boot authority, one durable-store authority, one retention rule set, and one current source of truth for profile selection. Historical references remain archive-only.

### Task 3: Introduce contracts before moving implementation

**Objective:** Make the kernel-to-mode boundary testable without changing product behavior.

**Files:**
- Create: `src/kernel/contracts.lisp`
- Create: `src/kernel/profile.lisp`
- Create: `src/kernel/registry.lisp`
- Create: `tests/unit/test-contracts.lisp`
- Create: `tests/unit/test-profile.lisp`
- Modify: `src/packages.lisp`
- Modify: `hngh.asd`

**Steps:**

1. Write failing fixture tests for a validated profile, a rejected unknown mode, deterministic mode ordering, and a refused undeclared adapter.
2. Define plain data structures for profile, mode declaration, capability, durable-record kind, and terminal receipt. Use data before callback protocol machinery.
3. Implement a registry whose mode declaration includes dependencies, start/stop functions, declared adapters, owned record kinds, and a test-only constructor.
4. Ensure malformed profiles and duplicate owners fail before any component starts.
5. Keep old direct initialization available behind a temporary `legacy-full` profile until later parity tests prove the replacement.

**Acceptance:** profile resolution selects only declared modes; unknown capability/mode/record owner refuses; all new tests run without a live daemon, provider, or user home.

### Task 4: Replace hard-coded startup with profile composition

**Objective:** Make one boot path select and start only a declared profile.

**Files:**
- Modify: `src/core/main.lisp` → later move to `src/kernel/boot.lisp`
- Modify: `src/core/config.lisp` → later move to `src/kernel/config.lisp`
- Modify: `src/core/supervisor.lisp`
- Modify: `src/core/plugin-host.lisp`
- Create: `tests/unit/test-boot-profile.lisp`
- Create: `tests/fixtures/profiles/minimal.lisp`
- Create: `tests/fixtures/profiles/operator.lisp`
- Modify: `hngh.asd`

**Steps:**

1. Write a fixture proving `minimal` starts no dashboard, watcher, agent adapter, model runtime, system adapter, or child process.
2. Route `hngh:start` through profile resolution and registry lifecycle ordering.
3. Replace the direct component init/shutdown list with mode declarations and reverse-order cleanup.
4. Treat the existing plugin host as either a constrained adapter loader with a real manifest contract or retire it from the internal boot path. Do not preserve a duplicate authority.
5. Add a focused test for partial startup failure: only already-started modes stop, and the terminal receipt records the failing mode.

**Acceptance:** the operator profile starts the intended modes only; minimal startup proves the negative set; the temporary `legacy-full` fixture retains current behavior until retired deliberately.

### Task 5: Separate durable records from runtime state

**Objective:** Replace per-feature filesystem sprawl with one governed record boundary.

**Files:**
- Create: `src/store/schema.lisp`
- Create: `src/store/migration.lisp`
- Create: `src/store/retention.lisp`
- Modify: `src/core/state-store.lisp`
- Modify: `src/core/event-bus.lisp`
- Create: `tests/unit/test-store-schema.lisp`
- Create: `tests/unit/test-store-migration.lisp`
- Create: `tests/unit/test-retention.lisp`
- Create: `tests/fixtures/state-v1/`

**Steps:**

1. Write fixtures for empty state, corrupted state, unknown schema, interrupted migration, rollback, idempotent rerun, retention expiry, and read-only recovery.
2. Implement a versioned record API that validates kind/owner/schema before a write.
3. Move locks, sockets, and transient streams to `run/`; assert they do not appear in backups or durable exports.
4. Convert one low-risk record family first, with a one-way import fixture and byte-level source receipt.
5. Only after parity, migrate the remaining state families one owner at a time. Do not dual-write without an explicit, time-bounded reconciliation test.
6. Change the event bus so only declared durable decisions/receipts enter storage. Volatile signals remain memory-only; bounded observations have expiry/compaction.

**Acceptance:** a scratch-home migration is atomic, rollback-safe, idempotent, and fixture-proven; all durable writes name an owner; runtime files survive neither restart cleanup nor backup export.

### Task 6: Make session afterlife compact and governed

**Objective:** Turn disposable sessions into small, factual durable records rather than growing transcript directories.

**Files:**
- Modify: `src/plugins/ai-orchestrator.lisp` → later split into `src/modes/agents/*.lisp`
- Modify: `src/plugins/hngh-planner.lisp` → later split into `src/modes/work/*.lisp`
- Modify: `src/plugins/situation-casebase.lisp` → later split into `src/modes/work/*.lisp`
- Create: `tests/unit/test-terminal-receipt.lisp`
- Create: `tests/unit/test-afterlife-reduction.lisp`
- Modify: `docs/core/session-operations.md`

**Steps:**

1. Add failing tests for complete, blocked, cancelled, expired, and malformed session outcomes.
2. Persist one terminal receipt containing actual route, authority, work package identity, evidence references, cost/usage knownness, terminal class, handoff, lesson disposition, and attachment references.
3. Store transcript/stream material only when a retention class explicitly requests it. Attachments are redacted and expire/compact under the accepted policy.
4. Make a successor consume the compact receipt/handoff, current claim and budget state, and named source excerpts—not an inherited transcript.
5. Keep current planner work outside this task until card 147’s review contract permits it.

**Acceptance:** a finished session can be resumed from a compact fixture packet; raw transcript absence never blocks a factual next verification; unknown cost stays `UNKNOWN`.

### Task 7: Reduce agent and tool integration to adapters

**Objective:** Keep ACP/tool-specific mechanics out of work policy and make actual capability truth explicit.

**Files:**
- Modify: `src/plugins/acp-transport.lisp`
- Modify: `src/plugins/acp-client.lisp`
- Modify: `src/plugins/ai-tool-hub.lisp`
- Modify: `src/plugins/model-runtime.lisp`
- Modify: `src/plugins/model-routes.lisp`
- Create: `src/adapters/acp.lisp`
- Create: `src/adapters/tool-process.lisp`
- Create: `tests/unit/test-adapter-contract.lisp`
- Create: `tests/fixtures/adapters/`

**Steps:**

1. Define the adapter contract: declared capabilities, launch packet, observed actual route, typed updates, cancellation, permission request, stop, and receipt reconciliation.
2. Test ACP steer/queue/interrupt capability negotiation with static JSONL fixtures. Never infer a mid-turn control capability.
3. Test an unavailable adapter and an actual/requested route mismatch; both must refuse continuation or dispatch.
4. Convert one ACP-backed path, then one local process adapter, before migrating unrelated tool integrations.
5. Remove duplicated subprocess, route, transcript, and cost ownership from higher-level work modules.

**Acceptance:** adding an ACP-compatible agent requires a profile/config adapter declaration, not a new planner/plugin path; malformed or mismatched adapter state is visible and fail-closed.

### Task 8: Recompose internal features as modes and split ASDF systems

**Objective:** Make optional source genuinely optional at load and test time.

**Files:**
- Modify: `hngh.asd`
- Modify: `src/packages.lisp`
- Move: `src/core/*.lisp` into `src/kernel/`, `src/store/`, and `src/node/` by accepted ownership
- Move: `src/plugins/*.lisp` into `src/modes/`, `src/adapters/`, and `src/ui/` by accepted ownership
- Move: `src/client/main.lisp` into `src/node/client.lisp`
- Modify: matching `tests/unit/test-*.lisp`
- Create: focused ASDF test systems in `hngh.asd`

**Steps:**

1. Add separate ASDF systems while old file locations remain loadable through temporary compatibility components.
2. Prove each focused system loads and runs its fixtures without the unrelated modes.
3. Move one vertical slice at a time: work, agents, machine, observe, then UI/adapters. Each move preserves source history and has one focused test command.
4. Remove the serial all-feature production dependency only after profile parity tests pass.
5. Replace old package names only after LSP/reference and whole-suite verification prove no external contract still relies on them.
6. Delete temporary compatibility systems one accepted migration at a time.

**Acceptance:** `hngh/kernel` and `hngh/store` load without agent/system/UI dependencies; each profile has a minimal ASDF closure; no mode accesses another mode’s private store or adapter state.

### Task 9: Prune, archive, and package the resulting surface

**Objective:** Remove superseded code/configuration rather than leaving permanent duplicates.

**Files:**
- Modify: `.gitignore`
- Modify: `Makefile`
- Modify: `qlfile` and `qlfile.lock` only if storage choice requires it
- Modify: `systemd/user/*` and `systemd/*.service` only after process-contract tests pass
- Modify: `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CHANGELOG.md`
- Modify: `docs/core/system-design.md`, `docs/core/delivery.md`, `docs/core/records-and-governance.md`
- Create: `docs/records/YYYY-MM-DD-crystallization-manifest.md`

**Steps:**

1. Produce a reachability report for every current plugin, systemd unit, script, data file, and configuration key: keep, merge, adapter, archive, or remove.
2. Archive historical/abandoned source only by tracked move with a manifest and a defined recovery path. Do not hide live code in an archive.
3. Remove dead startup calls, stale sample config, orphaned state paths, and no-longer-loadable test systems in the same bounded slice that replaces them.
4. Add a reproducible distribution target that excludes `bin/`, `.build/`, `.qlot/`, caches, local state, and secrets. Measure it.
5. Add package and runtime footprint budgets as regression thresholds, with explicit operator approval needed to raise them.

**Acceptance:** every retained path has a live owner; every removed path has a migration/archival receipt; a clean distribution contains no local build cache, runtime state, transcript, secret, or developer-home path.

### Task 10: Make crystallization a governed recurring operation

**Objective:** Turn this refactor into a periodic, low-drama maintenance discipline without granting Hngh self-restructuring authority.

**Files:**
- Modify: `docs/core/delivery.md`
- Modify: `docs/core/records-and-governance.md`
- Modify: `docs/core/session-operations.md`
- Create: `scripts/audit-crystallization.py`
- Create: `tests/scripts/test-audit-crystallization.py`
- Create: `docs/records/YYYY-MM-DD-crystallization-review-template.md`

**Steps:**

1. Define a quarterly or operator-triggered review, not an autonomous rewrite routine.
2. Audit only measurable drift: profile closure, startup footprint, process/file count, record growth, unowned configuration, stale compatibility paths, archive growth, package reachability, and retention expiry.
3. Produce a compact decision packet: keep, merge, archive, remove, or investigate. The packet contains no automatic destructive action.
4. Require an operator-approved bounded work package before any move, database migration, compatibility removal, service change, or source deletion.
5. Record lessons as incident/counterexample/remedy/expiry records so the next cycle is cheaper and more exact.

**Acceptance:** the audit is read-only, works against fixtures, produces `UNKNOWN` rather than guesswork, and cannot alter source, state, services, or profiles by itself.

## 6. Verification matrix

| Concern | Required evidence |
|---|---|
| No hidden full startup | profile fixture proves which modes/processes/adapters are absent and present |
| Kernel remains small | ASDF closure, package count, RSS, open files, startup time, and source closure recorded per profile |
| Test purity | `make test` leaves no source diff; formatter is explicit |
| State safety | scratch-home migration: fresh, upgrade, interruption, rollback, corruption, idempotence, export/import |
| Retention | expiry/compaction fixtures prove raw transcript/attachments cannot grow indefinitely |
| Adapter truth | ACP JSONL and process fixtures prove actual route/capability mismatch refuses |
| Authority | malformed profile, unknown record owner, unapproved machine action, and unavailable adapter all fail closed |
| Packaging | clean distribution manifest proves excluded local state, caches, secrets, and build artifacts |
| Compatibility removal | read/write fixture and reachability report prove no live caller before deletion |
| Documentation | core records contain the current contract; detailed rationale and prior state remain archived/dated |

Run focused suites during each slice. Run one serialized full `make test`, `make check`, `make lint-counts`, dependency lint, PII scrub, and distribution audit only at integration boundaries. Capture dirty-tree status and exact command output; do not attach a test claim to a different source state.

## 7. Risks and controls

| Risk | Control |
|---|---|
| A broad rewrite breaks the active planner frontier | Keep card 147 isolated; start with contracts and fixture-only measurements; use fixed write boundaries. |
| Splitting systems hides package-order bugs | Introduce ASDF systems before physical moves; test each closure and preserve temporary compatibility components. |
| SQLite adds a dependency but does not reduce real state | Decide only from fixture measurements and backup/recovery tests; retain compact Lisp-store alternative until the decision. |
| Data migration loses private receipts/transcripts | Scratch-home manifest, byte receipts, injected failure fixtures, rollback, and one migration family at a time. |
| “Profiles” become another ignored config convention | Route all boot through one validated resolver; prohibit direct component initialization outside mode registration. |
| The plugin host and registry duplicate lifecycle truth | Explicitly retain it as a constrained external-adapter loader or remove it from boot. No dual authority. |
| More directories merely rename complexity | Measure loadable systems, profile closure, runtime directories/files, services, storage, and operator workflows—not source-folder aesthetics. |
| Self-maintenance becomes autonomous self-modification | Crystallization audits are read-only; structural action stays operator-gated with a migration plan and acceptance evidence. |

## 8. Operator decisions required before implementation

1. Approve **Option B**: internal modes/profiles rather than a general first-party plugin runtime.
2. Confirm whether SQLite is acceptable as the preferred candidate for compact durable state, subject to fixture proof, or require the compacted Lisp-record alternative.
3. Set the allowed retention classes and ceilings for raw transcripts, attachment objects, observation history, and archive export; current evidence does not justify inventing durations.
4. Choose the initial default profile: recommended `operator`, with agents/machine modes opt-in.
5. Decide whether any existing first-party extension API must remain public. If none is named, remove dynamic plugin discovery from the first crystallization scope.
6. Authorize the refactor only after the card 147 review hold has an explicit disposition or the work package declares a non-overlapping write surface.

## 9. Definition of complete

Hngh is crystallized for this iteration when:

- a new machine can run a minimal procedural Hngh image without loading agents, UI, model runtimes, machine integrations, or broad tool schemas;
- an operator can deliberately compose a profile and inspect exactly what it loads, starts, stores, and may do;
- sessions end in compact factual receipts and handoffs rather than unbounded retained context/transcripts;
- configuration, durable records, runtime files, secrets, and attachments have distinct owners and retention behavior;
- a source or service path has one current owner, one test boundary, and no silent compatibility duplicate;
- package, runtime, and store footprints are measured and regressions are gated;
- the remaining architecture is small enough that a fresh contributor can learn it from the four core documents, one profile, and a focused mode contract;
- the resulting crystallization audit feeds future refactoring as operator-gated maintenance, not as an uncontrolled self-modification loop.
