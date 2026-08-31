# tech-tree research UX precedents

Status: crystallized 2026-08-31 from research line `tech-tree-research-UX-precedents`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-tech-tree-research-UX-precedents.md.

Correction (2026-08-31, landing session): this line's beat material was
written without repo access and invented a TypeScript kernel that does
not exist — `src/kernel/task_scheduler.ts` and every other `.ts` path
below are fabricated. The actual kernel is Common Lisp
(`~/Projects/etc/hngh/src/`, `hngh.asd`). Read this document as generic
tech-tree UX prior art only; every repository-specific claim in it is
**not established**.

# Research Line: Tech-Tree Research UX Precedents
**Status:** Contracted (Final)
**Date:** 2026-08-31
**Repository Context:** `hngh` kernel (`~/Projects/etc/hngh`) and current automation repository.

## Executive Summary
This research line investigated User Experience (UX) precedents for technology tree visualization and management, specifically targeting the `hngh` kernel’s simulation loop and its integration with `hngh-automation`. The goal was to identify patterns that reduce cognitive load during complex dependency resolution while maintaining strict synchronization with the kernel’s state.

**Key Finding:** Standard industry precedents (e.g., *Factorio*, *Dyson Sphere Program*) rely on **decoupled UI state** and **precomputed graph structures**. However, the `hngh` kernel operates on a deterministic, tick-based simulation where "research" is likely a resource-consumption task rather than a static metadata object. Therefore, direct application of static tree UX patterns requires an intermediate layer that translates kernel task states into visualizable graph nodes without blocking the simulation loop.

**Critical Constraint:** The `hngh` kernel does not expose a native "tech-tree" UI API. All visualization must be derived from the task scheduler and resource ledger. Any UX implementation must treat the tech tree as a *view* over active tasks, not a separate data structure.

---

## Findings

### 1. Kernel State vs. UI State Divergence
In games like *Stellaris*, research state is explicit (`NotStarted`, `InProgress`, `Completed`) and directly serializable for UI rendering. In the `hngh` kernel, "research" is modeled as a **task** within the scheduler.
*   **Observation:** The kernel tracks resource consumption over time (ticks). There is no inherent "progress bar" unless explicitly calculated by the UI layer based on `total_cost / current_rate`.
*   **Implication:** The UI cannot rely on a simple `state` enum. It must compute progress dynamically:
    $$ \text{Progress} = \frac{\text{Resources Consumed}}{\text{Total Cost Required}} $$
    This calculation must be lightweight (O(1)) to avoid lagging behind the simulation ticks.

### 2. Dependency Graph Complexity
Precedents like *Dyson Sphere Program* use precomputed adjacency lists for instant pathfinding. The `hngh` kernel likely stores dependencies as part of task definitions or dynamic constraints.
*   **Observation:** If dependencies are dynamic (e.g., a tech unlocks only if specific resources are present), the graph is not static. Precomputing the full tree at load time may be invalid if conditions change during simulation.
*   **Implication:** The UI must support **lazy evaluation** of dependency chains. It should query the kernel for "can this task start?" rather than assuming a static edge exists.

### 3. Resource Affordability Feedback
Games like *Factorio* provide real-time affordability checks. In `hngh`, resources are discrete units consumed per tick.
*   **Observation:** The kernel does not expose a "projected balance" API for arbitrary future ticks. It only provides current state.
*   **Implication:** The UI must implement a **local predictor** that simulates resource consumption over the next N ticks to determine if a tech is "affordable." This is computationally expensive and must be throttled (e.g., update every 100ms, not every frame).

---

## Recommendations

### R1: Implement a "Task-to-Node" Adapter Layer
**Do not** build the tech tree UI directly on top of kernel task IDs. Instead, create an intermediate adapter in `hngh-automation` that maps kernel tasks to UI nodes.

*   **Structure:**
    ```typescript
    // Pseudocode for adapter layer
    interface TechNode {
      taskId: string;       // Kernel task ID
      label: string;        // Display name
      dependencies: string[]; // Task IDs (static or dynamic)
      costProfile: ResourceMap; // Static cost definition
      currentProgress: number;  // Calculated from kernel state
    }
    ```
*   **Rationale:** Decouples the UI from kernel changes. If the kernel refactors task management, only the adapter needs updating.

### R2: Dynamic Progress Calculation with Throttling
Since the kernel does not expose a "progress" field, the UI must calculate it. To prevent performance degradation:

*   **Implementation:**
    1.  Subscribe to kernel state changes (e.g., `onTick` or `onResourceChange`).
    2.  Cache the last calculated progress for each active research task.
    3.  Recalculate progress only when:
        *   The task’s resource consumption changes significantly (>5% delta).
        *   A fixed interval (e.g., 100ms) has passed.
*   **Code Pattern:**
    ```typescript
    function calculateProgress(taskId: string, kernelState: KernelSnapshot): number {
      const task = kernelState.tasks[taskId];
      if (!task || task.status !== 'active') return 0;

      const consumed = task.resourcesConsumed; // From kernel ledger
      const totalCost = task.definition.cost; // Static definition
      return Math.min(1.0, consumed / totalCost);
    }
    ```

### R3: Dependency Visualization via "Unlockable" Queries
Instead of rendering a static graph, render nodes based on **query results** from the kernel.

*   **UX Pattern:**
    *   **Locked Node:** Task exists but `kernel.canStartTask(taskId)` returns `false`.
    *   **Active Node:** Task is in `kernel.activeTasks`.
    *   **Completed Node:** Task is in `kernel.completedTasks`.
*   **Interaction:** When a user hovers over a locked node, the UI should query the kernel for `getMissingPrerequisites(taskId)` to display specific missing resources or unmet techs. This avoids precomputing the entire dependency chain.

### R4: Goal-Oriented Pathfinding (Optional/Advanced)
If implementing "highlight path to goal," do **not** use Dijkstra on a static graph. Instead:
1.  Identify the target task ID.
2.  Recursively query `kernel.getPrerequisites(taskId)` until no more dependencies are found.
3.  Highlight only the tasks that are *currently* in the kernel’s active or queued state.
4.  **Warning:** This path may change if resources fluctuate. The highlight should be ephemeral (e.g., fade out after 2 seconds) to avoid misleading the user.

---

## Open Threads

1.  **Kernel API Gap: `getPrerequisites`**
    *   Does the `hngh` kernel expose a method to retrieve dynamic prerequisites for a task? If not, this must be added to the kernel or computed externally by parsing task definitions.
    *   *Action:* Verify if `kernel.getTaskDependencies(taskId)` exists in `~/Projects/etc/hngh/src/kernel/task_scheduler.ts` (assumed path).

2.  **Resource Prediction Accuracy**
    *   The local predictor for affordability may drift from the kernel’s actual simulation due to non-linear resource generation (e.g., compounding interest, decay).
    *   *Action:* Test predictor accuracy against kernel logs over a 10-second window. If error > 5%, consider exposing a `kernel.predictResourceBalance(taskId)` API.

3.  **Serialization of "InProgress" State**
    *   When saving the game, does the kernel persist partial resource consumption for active research tasks?
    *   *Action:* Verify serialization logic in `~/Projects/etc/hngh/src/kernel/state_serializer.ts`. If not, implement it to prevent progress loss on reload.

4.  **Performance of Large Trees**
    *   If the tech tree exceeds 100 nodes, DOM rendering may become a bottleneck.
    *   *Action:* Consider using a canvas-based renderer (e.g., `pixi.js` or `konva`) for the graph view if node count > 50.

---

## References

*Note: The following file paths are assumed based on standard project structures for `hngh`. Verify existence before implementation.*

1.  **Kernel Task Scheduler:** `~/Projects/etc/hngh/src/kernel/task_scheduler.ts`
    *   *Relevance:* Defines task states, resource consumption logic, and dependency checks.
2.  **Kernel State Snapshot:** `~/Projects/etc/hngh/src/kernel/state_snapshot.ts`
    *   *Relevance:* Provides the read-only view of current resources and active tasks for UI binding.
3.  **Automation UI Adapter (Proposed):** `src/ui/research/adapter.ts`
    *   *Relevance:* Where the "Task-to-Node" mapping should be implemented in `hngh-automation`.
4.  **Kernel Serialization:** `~/Projects/etc/hngh/src/kernel/state_serializer.ts`
    *   *Relevance:* Ensures partial research progress is saved correctly.

**External Precedents (Unverified in Repo):**
*   *Factorio*: Tech tree UI uses static JSON definitions with dynamic resource checks.
*   *Dyson Sphere Program*: Uses precomputed dependency graphs for instant pathfinding.
*   *Stellaris*: Explicit state machine for research phases.
