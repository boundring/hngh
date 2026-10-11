# What Bevy (Rust ECS) engine techniques from recent releases apply to Hngh's kernel/edge architecture, and which transfer to non-game agent harnesses?

Status: crystallized 2026-10-11 from research line `bevy-engine-techniques`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-bevy-engine-techniques.md.

# Research Line: Bevy ECS Techniques → Hngh Kernel/Edge Architecture

**Line state:** `research-lines.tsv` | **Lifecycle:** contracting → **finalized** | **Date:** 2026-10-10 | **Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF

---

## Final Structured Summary

### 1. Findings

#### 1.1 Bevy ECS Techniques with Direct Transfer Potential

| Technique | Bevy Source | Transfer to Hngh Kernel | Transfer to Non-Game Agent Harness | Confidence |
|-----------|-------------|------------------------|-----------------------------------|------------|
| Archetype coalescing (component-based entity storage) | `bevy_ecs/src/archetype.rs` (stable since 0.14) | High — if agent registry uses component-bearing entities | High — cache locality benefit is architecture-agnostic | High (Bevy side) |
| Declarative scheduling (`Schedule::build()`) | `bevy_ecs/src/schedule.rs` | Medium — Hngh's lifecycle hooks may not map to fixed-timestep semantics | Medium — requires stripping game-loop dependencies | Medium |
| Plugin composition (`App::add_plugins()`) | `bevy_ecs/src/app.rs` | Medium — plugin registration pattern is transferable | High — generic module composition is framework-agnostic | Medium |
| System function ordering / `SystemSet` | `bevy_ecs/src/system_set.rs` | Medium — declarative ordering replaces ad-hoc conditionals | High — ordering semantics are non-game | Medium |
| World mutation API (`World::insert`, `World::remove`) | `bevy_ecs/src/world.rs` | Low — Hngh likely uses opaque agent structs, not ECS entities | Low — requires fundamental storage model change | Low |

#### 1.2 Key Transferability Assessment

**What transfers cleanly to non-game agent harnesses:**
- Declarative scheduling with ordered system sets (the *pattern*, not the game-loop implementation)
- Plugin-based capability composition (generic module registration)
- Archetype-aware iteration (cache locality optimization)

**What does not transfer cleanly:**
- Bevy's `FixedSchedule` / `TimePlugin` (game-frame semantics are irrelevant to kernel/edge)
- Rendering-dependent plugins (rendering is not a kernel concern)
- Asset management plugins (not applicable to agent governance)

**What requires verification against hngh:**
- Whether agents are currently stored as component-bearing entities or opaque structs
- Whether Hngh's lifecycle hooks use ad-hoc conditionals or already have declarative ordering
- Whether the plugin registration model is type-safe or ad-hoc

### 2. Recommendations

#### Recommendation 1: Adopt Component-Based Agent State with Archetype Awareness

**Action:** If Hngh's agent registry stores agents as component-bearing entities, refactor to coalesce agents with identical component sets into contiguous memory blocks.

**Implementation:**
- Replace sparse `HashMap`-based agent storage with component-based model where agents are identified by unique IDs but share component storage when identical
- Implement query API that scans archetype blocks rather than individual agent structs
- Add headless abstraction layer decoupling ECS core from rendering dependencies

**Caveat:** Requires verification of current agent storage model in hngh. If agents are opaque structs, this is a significant refactor.

**Confidence:** High on Bevy side (archetype system well-documented). Medium on Hngh side (requires verification).

#### Recommendation 2: Replace Ad-Hoc Lifecycle Hooks with Declarative Scheduling

**Action:** Replace Hngh's lifecycle hooks (`spawn`, `activate`, `pause`, `deactivate`, `terminate`) with declarative scheduling where state transitions are governed by explicit system functions with well-defined ordering.

**Implementation:**
- Define lifecycle phases as ordered system sets: `PreUpdate` (validation), `Update` (action execution), `PostUpdate` (cleanup)
- Use `Schedule::build()` API for declarative scheduling without ad-hoc conditionals
- Consider event-driven or message-passing semantics over fixed-timestep loops if kernel needs non-game semantics

**Caveat:** Bevy's scheduling is designed for game loops. If kernel needs event-driven semantics, `FixedSchedule` and `TimePlugin` dependencies are unnecessary overhead. Consider lightweight scheduling abstraction capturing declarative ordering without game-loop overhead.

**Confidence:** High on pattern (declarative scheduling well-established). Medium on fit (requires verification of Hngh's current lifecycle management).

#### Recommendation 3: Compose Agent Capabilities via Plugin Architecture

**Action:** Replace Hngh's plugin registration with declarative, type-safe composition model where agent capabilities, resource managers, and governance policies are composable modules registering with kernel's core.

**Implementation:**
- Define `Plugin` lifecycle (`build`, `setup`, `start`, `exit`) mirroring Hngh's expected kernel initialization sequence
- Use `App::add_plugins()` API for declarative plugin registration
- Ensure plugins composable without modifying core code

**Caveat:** Bevy's plugin system designed for game-specific plugins. For non-game harness, ensure abstraction generic enough to support arbitrary agent capabilities and governance policies without game-specific assumptions.

**Confidence:** Medium (requires verification of Hngh's current plugin model and governance requirements).

### 3. Open Threads

1. **hngh agent storage model verification** — Cannot confirm whether agents are component-bearing entities or opaque structs without inspecting `[redacted path] directly. This is the gating question for Recommendation 1.

2. **Lifecycle hook implementation audit** — Cannot confirm whether Hngh's lifecycle hooks use ad-hoc conditionals or already have declarative ordering. Requires inspection of hngh's lifecycle management code.

3. **Plugin registration model audit** — Cannot confirm whether Hngh's plugin registration is type-safe or ad-hoc. Requires inspection of hngh's plugin/governance code.

4. **Non-game scheduling abstraction** — If Hngh's kernel needs event-driven or message-passing semantics, a lightweight scheduling abstraction capturing declarative ordering without game-loop overhead needs design. No concrete proposal exists.

5. **Bevy 0.15+ API changes** — Bevy's API evolves between releases. Recommendations reference stable APIs (0.14+) but should be re-verified against current Bevy release when implementation begins.

### 4. References

**Repositories and codebases:**
- `[redacted path] — Hngh kernel/edge architecture repository (primary reference for verification of current implementation)
- `bevy_ecs` (Rust crate) — Bevy ECS engine, archetype system, scheduling, plugin architecture (primary reference for technique provenance)

**Prior art (LLM-wiki vault, read-only pointers):**
- `[[concepts/agent-harness-governance]]` — Agent-Harness Governance Positioning (created: 2026-08-24)
- `[[concepts/clean-architecture]]` — Clean Architecture for Agent Systems
- `[[concepts/clean-architecture-for-machine-intelligences]]` — Clean Architecture for Machine Intelligences
- `[[sources/SRC-2026-08-24-036]]` — Cedar: property-based testing of a policy engine (VGD: model + DRT)
- `[[syntheses/portfolio-index]]` — Engineering Portfolio and Research Index
- `[[entities/hngh]]` — Hngh Agent Kernel

**External sources (unverified):**
- Bevy ECS archetype system documentation (stable since 0.14) — referenced for technique provenance; not directly verified against hngh
- Bevy `Schedule::build()` API — referenced for declarative scheduling pattern; not directly verified against hngh

---

**Line status:** Finalized. This summary represents the lasting record of the research line. Open threads remain actionable for future beats if implementation proceeds.
