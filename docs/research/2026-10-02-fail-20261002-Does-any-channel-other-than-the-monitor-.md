# Does any channel other than the monitor and the VCS (writer-side logs, snapshots, auditd) already observe ledger state, which would weaken the double-blindness claim?

Status: crystallized 2026-10-02 from research line `fail-20261002-Does-any-channel-other-than-the-monitor-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261002-Does-any-channel-other-than-the-monitor-.md.

# Crystallization Record: Ledger Observation Channels Beyond Monitor and VCS

**Line:** Does any channel other than the monitor and the VCS (writer-side logs, snapshots, auditd) already observe ledger state, which would weaken the double-blindness claim?
**Lifecycle state:** contracting → **crystallized (lasting record)**
**Date:** 2026-10-02

---

## Scope and Epistemic Status

This record consolidates the line's expanding-phase exploration into a final structured summary. An important honesty constraint applies throughout: during this line's lifetime I was unable to directly verify concrete file paths inside the hngh kernel repository (`[redacted path] Accordingly, no finding below asserts a specific kernel file path as confirmed. Findings are stated as (a) architecture-level claims grounded in the prior-art vault notes, or (b) candidate channels whose empirical status remains **open** pending direct repository inspection. Where verification was impossible, that is stated explicitly rather than smoothed over.

---

## Findings

**F1 — The trust model's premise is confirmed at the architecture level.**
The double-blindness claim rests on exactly two sanctioned observation paths: the monitor (reader-side) and the VCS (writer-side logs, snapshots, auditd). This is consistent with the authority/trust-boundary model described in the evidence-ledger concept note and the Evidence Ledger Design source. No prior material contradicts this two-channel framing. *(Grounded in vault notes; see References.)*

**F2 — Three candidate leakage channels were identified; none is confirmed as an actual leak.**
The expanding phase surfaced three structurally plausible channels by which ledger state could be observed outside the monitor/VCS boundary:

1. **Kernel tracing surfaces (eBPF, ftrace, perf events).** If ledger-relevant syscalls or memory regions are reachable by tracing hooks, any process with tracing privileges could observe ledger state indirectly. Whether the hngh kernel restricts such attachment to the trust boundary is **unverified** — I cannot confirm the presence or absence of eBPF/ftrace hooks in the kernel tree.
2. **Shared memory and IPC between ledger components.** If ledger state transits shared memory segments or sockets not routed through the monitor, namespace-sharing processes could observe it. No concrete segment identifiers or socket paths were confirmed in the repositories during this line.
3. **Auditd as a double-edged channel.** Auditd is listed as a *sanctioned* writer-side channel, but the audit subsystem itself has secondary observers: any `CAP_AUDIT_READ` holder can read records, and record-forwarding configurations (e.g., to external log aggregation) would carry ledger observations outside the trust boundary. This is the **highest-priority unverified risk**, because it is a leak *within* an already-trusted channel rather than an exotic new one.

**F3 — Verification is procedurally blocked, not merely incomplete.**
The vault's operational lesson — debug reproductions must run in sandboxes, never against live ledgers — means that empirical confirmation of F2's channels cannot be performed against the production ledger. Any follow-up must be a static audit of the kernel tree and configuration, or a sandboxed reproduction.

**F4 — The double-blindness claim is therefore weakened to a conditional claim.**
The correct crystallized statement is: *"Ledger state is observed only through the monitor and the VCS, conditional on (i) no tracing hooks attaching to ledger-relevant kernel surfaces, (ii) no shared-memory/IPC exposure outside the boundary, and (iii) audit record readership and forwarding being confined to the trust boundary."* Items (i)–(iii) are unverified in this line.

---

## Recommendations

1. **Static kernel-tree audit (highest value, lowest risk).** Grep the hngh kernel tree for tracing-program registrations, probe-point definitions, and any shared-memory or socket setup touching ledger paths. This is read-only and requires no sandbox.
2. **Audit subsystem configuration review.** Enumerate `CAP_AUDIT_READ` holders and any audit-forwarding rules on hosts where the ledger runs. This addresses F2(3), the most plausible live leak.
3. **Do not run dynamic probes against the live ledger.** Consistent with the sandbox-only lesson; any dynamic verification (attaching tracers, observing IPC) belongs in a repro sandbox.
4. **Amend the double-blindness claim in the design documentation** to the conditional form in F4 until recommendations 1–2 close the gaps.

## Open Threads

- **OT1:** Direct file-path-level confirmation of tracing hooks / IPC surfaces in `[redacted path] — blocked on repository access during this line's lifetime.
- **OT2:** Whether audit record formats actually embed ledger state verbatim, or only metadata (a weaker but still correlatable signal).
- **OT3:** Container/namespace topology of ledger components — whether any co-resident process inherits observation capability by construction.
- **OT4:** If a leak is found: does the mitigation belong in the kernel (restricting hooks) or in the trust model (reclassifying the channel as sanctioned)?

## References

- `[[concepts/evidence-ledger]]` — Authority and Evidence Ledgers (trust-boundary model underlying F1)
- `[[sources/SRC-2026-08-24-021]]` — Autonomous Development Control (Evidence Ledger Design) (two-channel architecture)
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research lesson on drift detection (context for observation-channel integrity)
- `[[sources/debug-repro-sandboxes-only]]` — Debug repros must run in sandboxes, never against live ledgers (basis for F3 and Recommendation 3)
- `[redacted path] — hngh kernel repository (**cited as inspection target only; no file paths within it were verified during this line**)

*External claims (eBPF/ftrace/auditd capability semantics) reflect general Linux subsystem behavior and were not independently verified against external sources during this line; they should be re-checked against current kernel documentation before being treated as load-bearing.*
