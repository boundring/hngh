# Does the path-collision bug in the scratch store lead to incorrect computational values being recorded in audit logs, thereby compromising data integrity despite storage separation?

Status: crystallized 2026-09-18 from research line `fail-20260918-Does-the-path-collision-bug-in-the-scrat`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260918-Does-the-path-collision-bug-in-the-scrat.md.

## Final Structured Summary: Path-Collision Audit-Integrity Line

**Line**: Does the path-collision bug in the scratch store lead to incorrect computational values being recorded in audit logs, thereby compromising data integrity despite storage separation?  
**State**: contracted → **sealed**. This line is closed; no further beats are pending. The core finding is that storage isolation does not equal logical isolation when namespace reuse crosses execution boundaries.

---

### Findings

1. **The defect is one of logical identity, not physical storage.**  
   Two distinct executions (wakes or plans) may share a scratch path if the orchestrator reuses a prior directory name without mutating its contents under the new plan's context. When an audit log captures a computational value *after* that overwrite—or records a value while attributing it to the wrong execution—the audit trail loses provenance fidelity. Storage separation alone cannot prevent this because the file system namespace is the logical identifier used by downstream readers, not just by the kernel's mount table.

2. **The risk materializes when scratch paths are reusable across wakes or plans.**  
   If a worker-wake writes `scratch/<plan-id>/intermediate` and a later wake reuses that same directory (or its parent) for new computations, an audit record referencing the earlier value may now point to overwritten content. The audit log's claim of "value X came from execution Y" becomes false if the underlying path has been repurposed.

3. **Provenance-bearing paths are the only reliable defense.**  
   Paths that encode a unique, non-reusable identifier per execution (e.g., `<host>:<uuid4>:<timestamp>`) cannot collide even under namespace reuse. Such paths inherently fail-open when collisions would occur, because the new computation lands in a fresh location rather than overwriting old data.

---

### Recommendations for `hngh/hngh-automation`

1. **Make scratch-store paths execution-scoped and non-reusable.**  
   Every worker-wake, plan, run, or orchestrated job must generate a scratch path that includes a unique per-execution identifier (UUID4 + monotonic timestamp). The path must never be recycled across executions on the same host without explicit deletion by the orchestrator's cleanup cycle.

2. **Capture audit values at computation time, not at log-write time.**  
   Audit records should snapshot computational outputs immediately after they are produced and bind them to the producing execution's identity in the record itself—not rely on later file-system lookups of the path that may have been overwritten. This decouples audit fidelity from storage layout.

3. **Fail closed: treat any detected collision as a data-integrity event.**  
   If two distinct executions attempt to write to the same scratch path, the orchestrator must raise an error rather than silently overwrite or merge. A collision is evidence of a logic bug in the scheduling layer and must be logged, not tolerated.

4. **Add a liveness check for the cleanup cycle.**  
   Even with non-reusable paths, stale directories from previous runs accumulate if the cleanup job misses them (e.g., during power loss or crash). A periodic verification that all scratch roots older than `max_wake_lifetime` are gone should run as part of the heartbeat cycle.

---

### Open Threads

- **Cleanup-cycle robustness under failure**: The current assumption is that cleanup runs reliably between wakes. If a wake crashes mid-cleanup, stale paths may persist and be reused by future wakes. A "cleanup-on-failure" state machine would mitigate this but requires re-examination of the worker's lifecycle hooks.
- **Cross-host path collisions in distributed setups**: If multiple hosts share a scratch store (e.g., via NFS or object storage), UUID4 alone is not collision-proof at scale. A globally unique namespace (e.g., combining host-id + execution-id) would be required, but this is out of scope for single-host analysis.
- **Audit-log tamper evidence**: Even with perfect path isolation, an adversary could still alter audit records post-hoc if the log storage itself lacks integrity constraints (checksums, append-only journals). This is a separate threat model from the scratch-store collision but compounds the same root concern: trust in logical identifiers over physical separation.

---

### References

- `[redacted path] — primary repository for `hngh/hngh-automation`; contains worker-wake orchestration, scratch-store layout logic, and audit logging code paths relevant to this line.
- `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]` — original observation that a scratch path was reused across wakes; provides the concrete reproduction context for this analysis.
- `[[sources/high-rigit-history-redacted-2026-09-20]]` — prior work on file collisions in nightly orchestration cycles; confirms that namespace reuse under scheduling is an established failure mode.

**Unverified external claims**: None asserted. All technical conclusions are grounded in the known behavior of hierarchical file-system namespaces and standard provenance principles; no external literature was cited because the findings derive from internal system architecture rather than general theory.
