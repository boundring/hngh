# Hngh Architecture Decision Record

**Status**: Accepted (Phases 1–2 complete)
**Date**: 2026-06-21
**Scope**: v0.1 (Milestone 1: "The Harness")

---

## Context

Hngh is a system harness for CachyOS/Arch Linux that orchestrates configuration, package management, GPU/runtime management, and generative AI agents. Target users are power-users and system administrators. The system must be Emacs-like in extensibility: structure for human comprehension, massively extendable, hot-patchable, with procedural-first threat detection.

---

## Locked Decisions

### D1 — Language Stack (Polyglot Hybrid)
- **Core daemon (user)**: SBCL Common Lisp — image-based, hot-reload, native compilation, CFFI.
- **System daemon (privileged)**: C — minimal, audit-friendly, no runtime.
- **AI orchestration**: Python subprocess bridge — best AI/ML ecosystem, crash-isolated.
- **GPU/hot paths**: C/C++ via CFFI.
- **Plugin languages**: Common Lisp (first-class, in-image), Python (first-class, subprocess), WASM (second-class, community knowledge packs).
- **Rationale**: Each layer uses the right tool; honors the Emacs-heritage preference for Lisp without sacrificing the AI ecosystem or performance.
- **Rejected**: Rust (user preference against), single-language monolith (would force bad tradeoffs).

### D2 — Privileged Execution Model (Split Daemon + Template Helpers)
- User daemon (`hngh.service`, runs as `$USER`) owns all intelligence, state, UI, plugins.
- System daemon (`hngh-system.service`, runs as root) is small, stateless, no AI, no plugins.
- Per-operation privileged work via `hngh-helper@.service` systemd template units.
- Communication via dbus (system bus).
- **The AI never runs as root.** This is the most important security property.
- **Rationale**: matches systemd best practices; clean audit boundary; root surface is tiny.
- **Rejected**: monolithic with polkit (no persistent privileged session), ambient capabilities (non-standard), per-op only (no event subscription), container isolation (doesn't compose with real system ops).

### D3 — Plugin Safety (Procedural-First, LLM-Strategic, Pass/Fail for AI-Generated)
Four layered defenses:
- **L1 — Procedural pre-flight** (always runs, cheap): static analysis, manifest validation, known-bad pattern DB, signature/trust tier check, hash reputation.
- **L2 — LLM semantic review** (strategic): invoked only on L1 `AMBIGUOUS` or for all AI-generated plugins. Produces structured pass/fail verdict. Mandatory for AI-generated.
- **L3 — Runtime observation** (always on, procedural): syscall/file/network/subprocess tracing, rules engine validates behavior against declared capabilities. Flags → L4.
- **L4 — LLM behavioral review** (strategic): on-flag for semantic judgment, periodic for drift detection, on-demand for user-initiated queries. Adaptive schedule with 7-day max interval.
- **Sandboxing** is not a tier default — applied case-by-case when review flags residual risk that user accepts.
- **Rationale**: deterministic methods handle the known; LLM handles the novel. Cost scales with resources, not fixed budget.
- **Rejected**: always-on LLM (expensive, probabilistic, redundant for known patterns), strict default-deny (incompatible with Emacs spirit), trusted-by-default (incompatible with AI-generated plugin feature).

### D4 — Plugin Trust Tiers
- **First-party**: built into Hngh, full access, always loaded.
- **Signed community**: maintainer-signed, capability-restricted, one-time user confirmation.
- **User-written**: user-authored, capability-restricted, Layer 2 review if L1 ambiguous.
- **AI-generated**: mandatory L2 review with pass/fail verdict before loading; sandboxed if user accepts residual risk.

### D5 — v0.1 Scope
- Core: split daemons, plugin system, procedural threat detection (L1/L3).
- Features in: package management, system config, GPU/resource management, KDE integration, backups (config vs. secrets), local model spinup, hnghbeats, LLM orchestration (local + cloud), TUI dashboard.
- Features deferred: graphical buddies, speech bubbles, social network, remote instances, subagent time-travel, passive observation, procedural cost optimization.
- DE-agnostic daemon; KDE integration is an optional plugin.
- Single-user per machine; multi-tenant is v0.3+.
- Cloud AI integrated in v0.1 (Claude, Gemini, Codex).
- Headless-capable (SSH-only servers without DE supported).

### D6 — Distribution & Self-Update
- Split AUR packages: `hngh-core`, `hngh-system`, `hngh-python`, `hngh-kde`, `hngh-dev`.
- AUR submission closed currently; ship via custom repo initially, transition when AUR reopens.
- Self-update via package manager: Hngh detects update, notifies user, on approval calls system daemon to run `pacman -Syu hngh-*`. Notify-only mode as configurable fallback.

### D7 — Extensibility Contract
- Declarative plugin manifest (YAML): name, version, trust-tier, language, capabilities (filesystem/network/subprocess/dbus/ai/knowledge-base), lifecycle hooks.
- Plugin lifecycle: DISCOVER → PARSE → L1 STATIC → LOAD | REJECT | L2 → USER REVIEW.
- CL plugins: first-class, in-image, hot-reload, package-level isolation.
- Python plugins: first-class, subprocess, JSON-RPC or socket, crash-isolated.
- WASM plugins: second-class, wasmtime, limited API, strong isolation.
- Review verdicts (for AI-generated plugins) are structured YAML: pass, confidence, concerns, suggested-fixes, reasoning. Stored alongside plugin, shown to user with diff before loading, logged to KB.

### D8 — Architecture Pattern (Image + Bus + Supervisor)
Hybrid of Microkernel + Event Bus + Actor Supervisor:
- **Image** (SBCL core, small): plugin host, event bus, state store, resource manager, scheduler, supervisor, built-in L1/L3 threat detection.
- **Bus** (custom internal event bus): all components communicate via pub/sub. dbus bridge plugin connects to external systemd session bus. External events (journald, udev, pacman hooks) normalized through bridge.
- **Supervisor** (single-level, actor discipline borrowed from OTP): every plugin and agent has declared restart policy, max-restarts-per-window, health checks, graceful shutdown contract.
- Not a full OTP tree — bounded complexity. Supervisor governs lifecycle, not isolation.
- Everything outside the image is a plugin or external process.
- **Rationale**: matches Emacs model most directly (small core, modes do everything); supervisor closes the lifecycle gap; bus gives universal observation for free; distribution-ready (remote instances = remote bus peers in v0.3).
- **Rejected**: pure Hexagonal (weak extensibility), Layered (doesn't fit autonomous work or live redefinition), pure Actor/OTP (actors can't redefine each other live).

### D9 — State Authority (Hybrid File Tree + Single SQLite)
- **Journal/event log**: append-only files in `journal/`.
- **Knowledge base**: files in `knowledge-base/`, lisp-readable, git-versioned.
- **Configuration**: files in `config/`, git-versioned, human-readable.
- **Plugin state**: `plugins/<name>/state/`, plugin-defined format.
- **Agent conversation history**: `agents/<id>/`, append-only transcripts.
- **Runtime/cache**: in-memory only, rehydrated on startup.
- **Cross-component locks**: single small SQLite DB (`state/locks.db`) — the only opaque store.
- The whole tree under `~/.hngh/` is git-initialized by default; user can push to remote. Secrets never enter this tree (handled by Secrets Manager plugin via password manager integration).

### D10 — Event Bus Substrate (Custom Internal + dbus Bridge)
- Internal event bus implemented in CL: in-process pub/sub for CL plugins, JSON-RPC over Unix socket for Python subprocesses, WASM host bindings for WASM plugins.
- dbus bridge plugin translates between internal bus and systemd session bus.
- System daemon appears on internal bus via the bridge.
- External events (journald, udev, KDE) come through the bridge, normalized into Hngh's event format.
- **Rationale**: fast in-process delivery for CL↔CL; clear security boundary (internal = user-trust, dbus = system-trust); distribution-ready.
- **Rejected**: dbus only (verbose, wrong security boundary, no in-image hooks), two separate worlds (plugins subscribe to both — bad UX).

### D11 — CL Plugin Isolation (Package-Level)
- Each CL plugin loads into its own package (`hngh.plugins.<name>.*`).
- Packages declare `:use` dependencies — explicit imports only.
- `hngh.*` core packages are locked — plugins cannot intern symbols there.
- Plugins can subscribe to events and call published core APIs, but cannot redefine core functions.
- Hot-patchable within own package; core is protected from accidental redefinition.
- Package locks are a CL language feature, not custom machinery.
- Determined malicious behavior (FFI out) falls to L3+L4.
- **Rationale**: preserves 95% of Emacs experience (hot-patch your own code) while protecting core from the 99% accident case.
- **Rejected**: full Emacs trust (no protection from accidents), full process isolation (kills hot-patch).

---

## Consequences

**Positive**:
- Small core, auditable; everything else is a plugin.
- Live extensibility preserved for CL plugins.
- Privilege boundary is clean and small.
- Threat detection is layered, cost scales with resources.
- Distribution-ready architecture for v0.3 remote instances.
- Polyglot — each layer uses the right tool.

**Negative / Tradeoffs**:
- Polyglot cost: cross-language FFI, packaging, debugging across boundaries.
- Two services to package and update atomically.
- Custom event bus is a design burden (bounded by bridge-as-plugin).
- SBCL is less common than Python/Rust — smaller hiring/contribution pool.
- Package-level isolation is not bulletproof against determined malicious code (mitigated by L3+L4).

**Mitigations**:
- Polyglot cost accepted (matches Emacs, game engines, pro audio tools).
- Atomic update via single PKGBUILD with split packages.
- Event bus design is bounded — bridge is one plugin, pub/sub is well-understood.
- SBCL fringe-ness offset by Python bridge (most contributors can work on Python side).
- Package isolation gap closed by runtime observation (L3) and LLM review (L4).

---

## Open Items for Phase 3+

- Component-by-component interface specifications (Phase 3 deliverable).
- Data flow diagrams for critical flows (Phase 4).
- Plugin manifest schema details (Phase 3, in Plugin Host component spec).
- Knowledge base structure (Phase 3, in Knowledge Base component spec).
- Remote instance protocol (Phase 4 sketch, full design in v0.3 cycle).
- Cost optimization routing algorithm (Phase 3 sketch, full design in v0.2 cycle).
