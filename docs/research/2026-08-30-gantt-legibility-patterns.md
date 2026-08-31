# gantt legibility patterns

Status: crystallized 2026-08-30 from research line `gantt-legibility-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gantt-legibility-patterns.md.

Correction (2026-08-31, landing session): this line's beat material was
written without repo access and misread the domain — hngh is a Common
Lisp governance kernel (ASDF + Makefile, `~/Projects/etc/hngh/Makefile`),
not a compiled OS kernel with a build pipeline. There is no CMake, no
Kbuild, no CI workflow set: none of the "Verification Required" build-
system paths below are established. Read this document as generic gantt-
legibility prior art only; every repository-specific claim in it is
**not established**.

# Research Line: Gantt Legibility Patterns
**Lifecycle State:** Contracting (Final Summary)
**Repository Context:** `~/Projects/etc/hngh` (Kernel), `hngh-automation` (Visualization/Orchestration)

## Executive Summary
This research line investigates how to render complex, high-density kernel dependency graphs as legible Gantt charts. The "expanding" phase identified that standard linear Gantt visualization fails for kernel builds due to non-linear dependencies and semantic ambiguity in task states. This contraction phase crystallizes those findings into a final structured record, providing actionable implementation directives for `hngh-automation` while explicitly marking where local verification against the `hngh` repository is required.

**Key Constraint:** I cannot directly access `~/Projects/etc/hngh` to verify specific file paths or build system configurations. All recommendations are framed as **implementation directives** that must be validated against the kernel’s actual build system artifacts. Where external sources are needed but unverifiable, this is explicitly stated.

---

## Findings

1.  **Standard Gantt Visualization is Insufficient for Kernel Builds:**
    *   Kernel build pipelines exhibit deep, non-linear dependency trees with high temporal density.
    *   Standard Gantt charts treat tasks as linear/parallel blocks, leading to visual clutter when >5 tasks overlap in a single time unit.
    *   *Source:* Inferred from standard kernel build patterns (e.g., Linux Kbuild, CMake) and prior research beats. *Verification Required:* Confirm `hngh`’s build system exposes dependency graphs via machine-readable formats (JSON/YAML).

2.  **Semantic Ambiguity in Task States:**
    *   Standard Gantt colors (blue=active, red=blocked) are insufficient for kernel tasks.
    *   "Blocked" has nuanced meanings: waiting on upstream patch, hardware dependency, license conflict, etc.
    *   *Source:* Inferred from kernel development workflows. *Verification Required:* Review `hngh`’s CI/CD logs or task tracker to identify distinct "blocked" states and confirm if they are explicitly tagged in build output.

3.  **Legibility is Zoom-Dependent:**
    *   At macro levels, individual task bars become noise.
    *   At micro levels, dependency arrows create visual clutter.
    *   Legibility requires adaptive filtering based on zoom level and context.
    *   *Source:* General visualization principles applied to high-density graphs. *Verification Required:* Analyze `hngh`’s commit history and build logs to determine typical task durations and critical path lengths.

---

## Recommendations for `hngh-automation`

### 1. Implement "Aggregated Gantt" Rendering (Dependency Graph Simplification)
*   **Problem:** Deep, non-linear dependency trees cause visual clutter in standard Gantt charts.
*   **Recommendation:** Implement an **adaptive aggregation layer** for Gantt rendering:
    *   **Macro View (Project-Wide):** Collapse sub-tasks into single bars representing top-level phases (e.g., "Kernel Build," "Module Compilation"). Hide individual file dependencies unless expanded.
    *   **Micro View (Debugging):** Only reveal dependency arrows when the user zooms into a specific phase. Use **edge bundling** to reduce arrow clutter.
*   **Verification Required:** Inspect `~/Projects/etc/hngh` for build system files (`Makefile`, `CMakeLists.txt`, or custom scripts) to identify critical path dependencies. Confirm whether the build system exposes dependency graphs via JSON/YAML that can be ingested by `hngh-automation`.

### 2. Define Kernel-Specific Semantic Color Mapping
*   **Problem:** Standard Gantt colors are insufficient for nuanced kernel task states.
*   **Recommendation:** Implement a **custom semantic color palette** in `hngh-automation`’s visualization engine:
    *   **Green:** Active compilation.
    *   **Yellow:** Waiting on external dependency (e.g., upstream kernel patch).
    *   **Orange:** Hardware-specific task (e.g., driver testing).
    *   **Red:** Failed build or critical error.
    *   **Purple:** License/compliance check pending.
*   **Verification Required:** Review `hngh`’s CI/CD logs or task tracker to identify the distinct states of "blocked" tasks. Confirm whether these states are explicitly tagged in the build system output.

### 3. Adaptive Filtering for Temporal Density
*   **Problem:** Legibility is highly dependent on zoom level; static views fail at both macro and micro scales.
*   **Recommendation:** Implement **zoom-level-dependent filtering** in `hngh-automation`:
    *   **Zoom > 1 week:** Hide all dependency arrows. Show only phase-level bars.
    *   **Zoom < 1 day:** Show individual task bars but hide non-critical dependencies (e.g., optional module builds).
    *   **Critical Path Highlighting:** Always highlight the longest chain of dependencies in a distinct color (e.g., bold black) regardless of zoom level.
*   **Verification Required:** Analyze `hngh`’s commit history and build logs to determine typical task durations. Confirm critical path lengths to calibrate zoom thresholds.

---

## Open Threads

1.  **Build System Integration:**
    *   Does `hngh` expose a machine-readable dependency graph (e.g., JSON, YAML, or custom format)? If not, what parsing strategy is required for `Makefile`/`CMakeLists.txt`?
    *   *Action:* Verify file paths and formats in `~/Projects/etc/hngh`.

2.  **State Tagging:**
    *   Are task states (e.g., "waiting on upstream patch") explicitly tagged in `hngh`’s build output or CI logs? If not, how can these states be inferred from log patterns?
    *   *Action:* Review CI/CD logs and task tracker definitions.

3.  **Performance Constraints:**
    *   What is the maximum number of tasks/dependencies that `hngh-automation` must handle without performance degradation?
    *   *Action:* Benchmark against `hngh`’s largest build scenarios.

4.  **User Interaction Model:**
    *   How should users interact with the aggregated view (e.g., click to expand, hover for details)?
    *   *Action:* Define UI/UX specifications for `hngh-automation`.

---

## References

*Note: The following file paths are cited as targets for verification. I cannot confirm their existence or contents without direct access to `~/Projects/etc/hngh`.*

1.  **Build System Configuration:**
    *   `~/Projects/etc/hngh/Makefile` (or equivalent)
    *   `~/Projects/etc/hngh/CMakeLists.txt` (if applicable)
    *   `~/Projects/etc/hngh/build-scripts/` (custom build scripts, if any)

2.  **CI/CD Logs and Task Definitions:**
    *   `~/Projects/etc/hngh/.github/workflows/` (or equivalent CI configuration)
    *   `~/Projects/etc/hngh/task-tracker/` (if a custom task tracker exists)

3.  **Build Output Artifacts:**
    *   `~/Projects/etc/hngh/build-logs/` (sample logs for state tagging analysis)
    *   `~/Projects/etc/hngh/dependency-graph.json` (or equivalent, if exposed by build system)

*External Sources:* None cited. All claims are grounded in inferred kernel development patterns and prior research beats. Where specific `hngh` details are required, explicit verification steps are provided.
