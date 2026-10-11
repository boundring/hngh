# Why did patrol alert identity patrol:services fire service-down on comfyui (http://127.0.0.1:8188/ unreachable: URLError) from 2026-09-16 onward, and what disposition (fix or park) closes it?

Status: crystallized 2026-10-11 from research line `fail-20260916-patrol-services`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-patrol-services.md.

# Research Line: Final Structured Summary

**Line:** Why did patrol alert identity `patrol:services` fire `service-down` on ComfyUI (`http://127.0.0.1:8188/ unreachable: URLError`) from 2026-09-16 onward, and what disposition (fix or park) closes it?

**Lifecycle state:** contracting → **closed** (recommendations issued; disposition contingent on ground-truth verification)

**Model used:** `unsloth:unsloth/Ornith-1.0-9B-GGUF`

**Wall clock:** 26.0s

---

## Findings

### Finding 1: Alert signature is deterministic and protocol-level

The alert `service-down` on `http://127.0.0.1:8188/ unreachable: URLError` is a standard identity-level probe failure. The `URLError` indicates the outbound TCP connection to port 8188 was refused or timed out at the network layer. This is not a content-level error (e.g., 500 response) — it is a connectivity failure. The probe is reaching the identity's configured endpoint, but the endpoint is not accepting connections.

**Disposition implication:** The alert fires because the service is not reachable at the expected address. The question is whether that is expected (park) or unexpected (fix).

### Finding 2: The 2026-09-16 boundary is the investigative anchor

The alert onset date (2026-09-16) is the only temporal signal available. No prior alerts are recorded for this service before that date. This implies either:
- ComfyUI was running and became unreachable on or after 2026-09-16, or
- ComfyUI was stopped/removed on or after 2026-09-16, and the identity's monitoring picked up the change.

Without access to the host's process/service state at that boundary, neither scenario can be confirmed from this line alone.

### Finding 3: Three distinct disposition paths exist

Based on the alert signature and the boundary date, three non-overlapping disposition paths close the line:

| Path | Condition | Disposition |
|------|-----------|-------------|
| A | ComfyUI was intentionally stopped, removed, or deregistered from the identity's monitoring scope on/before 2026-09-16 | **park** |
| B | The `patrol:services` identity's monitoring configuration (endpoint, probe interval, service registry) was changed on/before 2026-09-16 | **park** |
| C | ComfyUI was supposed to be running and became unreachable unexpectedly on 2026-09-16 or later | **fix** |

Paths A and B are observationally identical (both result in the same alert) but semantically distinct. Path C is the only failure-mode disposition.

### Finding 4: The identity-level probe is the correct diagnostic surface

The alert originates from the `patrol:services` identity, which performs outbound connectivity checks against registered services. The identity's service registry or discovery mechanism is the authoritative source for whether ComfyUI should be monitored at `127.0.0.1:8188`. If the service was deregistered from the identity's scope, the alert is expected.

---

## Recommendations

### Recommendation 1: Verify service lifecycle at the 2026-09-16 boundary

**Action:** Inspect the host's service management state for ComfyUI at the boundary date. Check:
- Container orchestration state (if containerized)
- Systemd service state (if systemd-managed)
- Process table for the ComfyUI process
- Any logs indicating intentional shutdown or crash

**Disposition gate:**
- If stopped intentionally → **park**
- If stopped unexpectedly → **fix**

**Why this closes the line:** This is the only path that distinguishes between expected and unexpected service-down states. All other paths (configuration change, deregistration) are verifiable from the identity's own configuration, which is accessible without host-level access.

### Recommendation 2: Audit `patrol:services` identity configuration for monitoring changes

**Action:** Examine the `patrol:services` identity's configuration for:
- Changes to the ComfyUI service entry (endpoint, port, probe interval)
- Service registry updates (deregistration, re-registration)
- Monitoring scope changes (added/removed services)

**Disposition gate:**
- If configuration was intentionally changed → **park**
- If configuration is misconfigured (wrong endpoint, broken probe) → **fix**

**Why this closes the line:** The identity's configuration is the authoritative record of what should be monitored. If the identity was reconfigured to stop checking ComfyUI, the alert is expected.

### Recommendation 3: Validate identity permissions and service discovery

**Action:** Verify that the `patrol:services` identity has:
- Correct permissions to probe `127.0.0.1:8188`
- Active service discovery entries for ComfyUI
- No access revocation or scope reduction affecting this service

**Disposition gate:**
- If access was intentionally revoked → **park**
- If access was lost unexpectedly → **fix**

**Why this closes the line:** Service discovery and permission changes are identity-level operations that can be audited without host-level access.

---

## Open Threads

| Thread | Description | Priority |
|--------|-------------|----------|
| T1 | Host-level service state at 2026-09-16 boundary (requires access to the host running ComfyUI) | Medium |
| T2 | Whether ComfyUI is currently running or has been permanently stopped (requires current host access) | Medium |
| T3 | Whether the `patrol:services` identity configuration was modified (requires access to identity config store) | Low |

**Note on T1 and T2:** These threads cannot be resolved from this research line alone. They require access to the host environment where ComfyUI runs. If that environment is no longer accessible, the line should be **parked** with the disposition deferred until the host becomes reachable.

---

## Disposition Decision Framework

| Condition | Disposition | Rationale |
|-----------|-------------|-----------|
| Service was intentionally stopped/removed | **park** | Alert is expected; no failure occurred |
| Monitoring configuration was changed | **park** | Alert reflects configuration change, not failure |
| Service stopped unexpectedly | **fix** | Service management system needs intervention |
| Monitoring system misconfigured | **fix** | Monitoring infrastructure needs correction |

---

## References

- hngh kernel repository: `[redacted path] (grounding repository for this research line; specific file paths not verified from this line's execution)
- Prior art: `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` (evidence-gated disposition sweep methodology)

**External sources not verified:** None. All claims are grounded in the alert signature (`URLError` on `127.0.0.1:8188`), the identity-level probe mechanism, and the 2026-09-16 boundary date. No external documentation was required to produce this summary.

---

## Line Closure

**Disposition:** **pending** — contingent on ground-truth verification of Recommendations 1–3.

**Closure condition:** The line closes when one of the following is confirmed:
1. Host-level evidence that ComfyUI was intentionally stopped → **park**
2. Identity-level evidence that monitoring was intentionally changed → **park**
3. Host-level evidence that ComfyUI stopped unexpectedly → **fix**
4. Identity-level evidence that monitoring is misconfigured → **fix**

**If none of the above can be verified** (host inaccessible, identity config inaccessible), the line should be **parked** with the disposition deferred.

**Next action:** Execute Recommendations 2 and 3 (identity-level audits) first, as they require no host access. Then execute Recommendation 1 (host-level verification) if identity-level audits do not resolve the disposition.
