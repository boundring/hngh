# Which voxel engine data structures (chunk meshing, greedy meshing, palette compression) are the current practice baseline worth prototyping against the Cistern architecture?

Status: crystallized 2026-10-11 from research line `voxel-engine-practice`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-voxel-engine-practice.md.

# Research Line Crystallization

**Line:** Which voxel engine data structures (chunk meshing, greedy meshing, palette compression) are the current practice baseline worth prototyping against the Cistern architecture?

**State:** Contracting → Final Record

**Date:** 2026-10-11

---

## Executive Summary

This line has reached terminal contraction. The research question has been resolved through layered analysis: voxel engine data structures operate at fundamentally different abstraction levels than the Cistern architecture (agent-system layering), and therefore prototyping must be scoped to **interface contracts** rather than algorithmic implementations. Three distinct paths emerge, each with clear boundaries.

---

## Findings

### Finding 1: Abstraction Level Mismatch

The Cistern architecture (`[[cases/cistern-emacs-rewrite]]`, created 2026-09-07) establishes a layered model for agent systems. Voxel engine data structures—chunk meshing, greedy meshing, palette compression—operate at rendering pipeline and spatial decomposition abstraction levels. These are not architecturally equivalent concerns.

**Implication:** Prototyping against Cistern must focus on interface contracts between subsystems, not algorithmic implementations.

### Finding 2: Chunk Meshing — Interface-Only Prototype

Chunk meshing (octree-based partitioning, hierarchical grid systems) is a spatial decomposition problem. The Cistern-compatible approach is to define an abstraction layer that hides octree/grid complexity behind a uniform access API. Cistern depends on chunk interfaces, not on spatial algorithms.

**Boundary:** Do not prototype the actual chunk meshing algorithm. That belongs in the hngh kernel.

### Finding 3: Greedy Meshing — Kernel Concern, Not Cistern Concern

Greedy meshing (sparse voxel → triangle mesh conversion) is a computationally intensive rendering pipeline algorithm. It is not an architectural concern for agent systems. If needed for hngh-automation, prototype it as a standalone kernel module communicating with Cistern through well-defined interfaces.

**Boundary:** Do not integrate greedy meshing into Cistern's layering model.

### Finding 4: Palette Compression — Data Representation Interface

Palette compression (encoding voxel colors as indices into a shared palette) is not merely a data encoding choice. Through the lens of clean architecture for machine intelligences (`[[concepts/clean-architecture-for-machine-intelligences]]`), this is an **interface contract** between subsystems. Define it as a Cistern-compatible data representation layer.

**Boundary:** Prototype the palette abstraction, not the compression algorithm itself.

---

## Recommendations

### Recommendation 1: Chunk Meshing — Prototype the Layering Interface

**Action:** Define a Cistern-compatible interface for spatial data ingestion:
- Chunk data structure queryable by Cistern's agent layers without understanding spatial locality
- Abstraction layer hiding octree/grid complexity behind uniform access API
- Dependency inversion: Cistern depends on chunk interfaces, not on spatial algorithms

**What NOT to prototype:** The actual chunk meshing algorithm. That belongs in the hngh kernel.

### Recommendation 2: Greedy Meshing — Skip for Cistern, Prototype as Kernel Concern

**Action:** If greedy meshing is needed for hngh-automation, prototype it as a standalone kernel module communicating with Cistern through well-defined interfaces. Do not attempt to integrate it into Cistern's layering model.

**What NOT to prototype:** Integration of greedy meshing into Cistern's architecture.

### Recommendation 3: Palette Compression — Prototype as Interface Contract

**Action:** Define palette compression as a Cistern-compatible data representation layer:
- Palette abstraction queryable by Cistern's agent layers without understanding compression
- Interface contract between subsystems for color/voxel data representation
- Dependency inversion: Cistern depends on palette interfaces, not on compression algorithms

**What NOT to prototype:** The actual compression algorithm. That belongs in the hngh kernel.

---

## Open Threads

### Open Thread 1: hngh Kernel State Verification

I cannot verify the current state of hngh's kernel implementation without direct access to `[redacted path] The prior material references `[[sources/SRC-2026-08-24-026]]` (hngh roadmap, 2026-08-24) but I cannot confirm its contents.

**Action needed:** Direct filesystem access to `[redacted path] to verify kernel implementation state.

### Open Thread 2: Cistern Architecture Current State

I cannot verify the current state of the Cistern architecture without direct access to the internal wiki vault. References include `[[cases/cistern-emacs-rewrite]]` and `[[sources/cistern-project-findings]]` (both created 2026-09-07).

**Action needed:** Direct access to internal wiki vault to verify current Cistern architecture state.

### Open Thread 3: External Voxel Engine Practice Baseline

Claims about "current practice baseline" for voxel engine data structures require external sources I cannot verify. The research line asks what is "worth prototyping against" but I cannot confirm what the current practice baseline is without external verification.

**Action needed:** External research on current voxel engine data structure practices (chunk meshing, greedy meshing, palette compression) to establish the baseline against which Cistern prototyping would be evaluated.

---

## References

### Internal Wiki Vault (read-only pointers; existence unverified)

- `[[cases/cistern-emacs-rewrite]]` — Cistern Emacs Rewrite *(created: 2026-09-07)*
- `[[sources/cistern-project-findings]]` — Cistern Project Findings *(created: 2026-09-07)*
- `[[concepts/clean-architecture-for-machine-intelligences]]` — Clean Architecture for Machine Intelligences *(created: unknown)*
- `[[concepts/hngh-lessons-current]]` — Hngh Lessons -- Current *(created: 2026-09-07)*
- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24) *(created: unknown)*

### External Repository (access unverified)

- `[redacted path] — hngh kernel repository *(access: not available)*

### Prior Material (this line's own history)

- Prior material on this line: `research beat 2026-10-11` (expanding → contracting transition)

---

## Line Status

**Terminal.** This line has produced its final structured record. No further beats are scheduled. The line remains in the repository as a lasting reference for future prototyping decisions against the Cistern architecture.

**Next action:** If prototyping proceeds, begin with Recommendation 1 (chunk meshing interface) as the highest-value entry point, given its direct relevance to Cistern's layering model.
