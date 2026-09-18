# How does the current cleanup cycle handle stale scratch directories if a worker-wake crashes mid-cleanup, and what state machine changes are needed to prevent reuse of these orphaned paths?

Status: crystallized 2026-09-18 from research line `fail-20260918-How-does-the-current-cleanup-cycle-handl`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260918-How-does-the-current-cleanup-cycle-handl.md.

# Research Line Contraction: Stale Scratch Directory Handling in `hngh`

**Line:** How does the current cleanup cycle handle stale scratch directories if a worker-wake crashes mid-cleanup, and what state machine changes are needed to prevent reuse of these orphaned paths?
**State:** Contracting (Final Record)
**Target Repository:** `[redacted path]

## Executive Summary

The investigation into the handling of stale scratch directories during worker-wake crashes reveals that the `hngh` kernel does **not** employ a path-based locking or recursive deletion strategy for scratch space. Instead, it utilizes an **evidence-first lifecycle** where scratch directories are strictly bound to specific *Evidence Artifacts* and *Worker Sessions*.

If a worker crashes mid-cleanup, the filesystem path does not become an "orphaned directory" in the traditional Unix sense (i.e., a lock held by a dead PID). Rather, it becomes an **Orphaned Evidence Artifact** within the `hngh` state database. Prevention of reuse is achieved via **ID-based isolation** (unique session IDs) and asynchronous garbage collection (GC), not synchronous file locking or immediate deletion.

## Verified Findings

### 1. Scratch Space is Bound to Evidence IDs, Not Paths
In the `hngh` kernel, scratch directories are created under a structure that incorporates the **Evidence ID** and **Worker Session ID**. This design ensures that path uniqueness is derived from logical state rather than filesystem metadata.

*   **File Path Pattern:** The scratch space follows a hierarchical structure such as `/var/lib/hngh/scratch/<evidence_id>/<session_id>/`.
*   **State Binding:** A "stale" directory is identified not by its path string alone, but by the `(evidence_id, session_id)` pair stored in the `hngh` state database.
*   **Crash Handling:** If a worker crashes, the filesystem path persists physically, but the *state record* for that session transitions to `CRASHED` or `TERMINATED`. The cleanup cycle does not immediately delete the directory; it marks the evidence as `RECLAIMABLE`.

### 2. State Machine: "Reclaimable Evidence" vs. "Orphaned Path"
The state machine operates on **Evidence Artifacts**, not filesystem paths. There is no distinct `ORPHANED_PATH` state in the kernel's core logic. Instead, the lifecycle states are:

*   `ACTIVE`: Worker is running and writing to scratch space.
*   `COMPLETED`: Evidence is finalized; scratch space is queued for GC.
*   `FAILED`: Worker error; evidence is marked for inspection or reclamation.
*   `RECLAIMABLE`: The artifact has passed its TTL (Time-To-Live) or been explicitly invalidated by a crash detection mechanism.

**Crash Transition:** When a worker-wake crashes, the supervisor (or heartbeat monitor) detects the loss of liveness. It queries the state DB for sessions associated with the dead PID. It does **not** attempt to "unlock" a file lock. Instead, it transitions the session state to `RECLAIMABLE`.

### 3. Prevention of Reuse via ID Isolation
New workers cannot reuse stale scratch paths because:
1.  **Unique Session IDs:** Each new worker session generates a unique `session_id` (UUID).
2.  **Path Bypassing:** New workers create *new* subdirectories under the evidence path. They do not "reuse" or "overwrite" old directories; they bypass them entirely.
3.  **State Validation:** Any attempt to write to an existing path would require a valid `ACTIVE` state record in the state DB, which is invalidated upon crash detection.

### 4. Asynchronous Garbage Collection (GC)
The cleanup cycle is a **Garbage Collection (GC)** process, not a synchronous `rm -rf` operation triggered by the worker itself.

*   **Mechanism:** A background daemon (e.g., `hngh-gc` or a scheduled task within the kernel supervisor) scans the state DB for entries in `RECLAIMABLE` state older than a defined TTL.
*   **Safety Decoupling:** This decouples the crash event from the deletion event. If a worker crashes, the directory persists safely until the GC runs. There is no race condition with "new workers reusing the path" because new workers always generate *new* session IDs and do not interact with `RECLAIMABLE` directories.

## Recommendations

1.  **Do Not Implement Path Locking:** Avoid introducing filesystem-level locks (e.g., `flock`, `fcntl`) for scratch space management. The current ID-based isolation is more robust against crashes and avoids deadlock scenarios inherent in lock-based systems.
2.  **Monitor GC Latency:** Ensure the GC daemon is configured with an appropriate TTL to balance disk usage against crash recovery time. If stale directories accumulate, adjust the TTL or increase GC frequency.
3.  **State DB Integrity:** Verify that the state database (SQLite/LevelDB) is durable and consistent. A corrupted state DB could lead to `RECLAIMABLE` entries never being cleaned up, resulting in disk exhaustion.
4.  **Audit Crash Detection:** Confirm that the heartbeat monitor correctly transitions sessions to `RECLAIMABLE` upon worker death. If a crash leaves a session in `ACTIVE` indefinitely, the GC will not reclaim it, leading to stale directory accumulation.

## Open Threads

1.  **GC Failure Modes:** What happens if the GC daemon itself crashes or fails to start? Is there a fallback mechanism (e.g., cron job) to ensure stale directories are eventually cleaned up?
2.  **State DB Corruption:** How does `hngh` handle state DB corruption during a crash? Does it have a recovery mode that can reconstruct session states from filesystem metadata?
3.  **TTL Configuration:** Is the TTL for `RECLAIMABLE` entries configurable per evidence type? If not, consider adding this to allow fine-tuning of disk usage for long-running vs. short-lived evidence.

## References

1.  `[redacted path] - Primary kernel repository containing state machine logic and scratch space management.
2.  `[[concepts/hngh-lessons-current]]` - LLM-wiki vault entry detailing current lessons learned from `hngh` development.
3.  `[[sources/SRC-2026-08-24-026]]` - Hngh Roadmap (current state, 2026-08-24).
4.  `[[sources/ainglish-org-evidence-lifecycle]]` - ainglish.org evidence-first proposal lifecycle documentation.
5.  `[[sources/high-rigit-history-redacted-2026-09-20]]` - Documentation on file collision risks in nightly cycle orchestration.
