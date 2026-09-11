# Why does the oversight system-network-down flag fire nightly while push/ping/GitHub keep working — what does the headroom predicate actually measure, and which probe makes it honest?

Status: crystallized 2026-09-11 from research line `fail-20260911-system-network-down`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260911-system-network-down.md.

# Research Line Crystallization: The Nightly `network-down` Flag

_line: Why does the oversight system-network-down flag fire nightly while push/ping/GitHub keep working — what does the headroom predicate actually measure, and which probe makes it honest?_
_state: contracting → crystallized (final record)_
_lifecycle note: this is the terminal transition of a continuous line; the summary below is the lasting record. Where the record depends on repository facts I could not re-read in this session, that is stated inline rather than smoothed over._

---

## Verification Status (read first)

This finalization inherits the prior beat's caveat, unchanged: I could not obtain live read access to `research-lines.tsv`, the working repository, or the hngh kernel tree during this transition. Therefore:

- **Grounded claims** are limited to the line framing itself and the prior-art pointers enumerated in the line record.
- **No hngh kernel file paths are cited**, because I cannot confirm any of them exist. Naming one anyway would corrupt the lasting record — the failure mode this line is nominally about (a label asserting more than its measurement supports).
- All mechanism-level claims are marked as hypotheses with their falsification criteria attached, so the next transition can kill or confirm each one cheaply.

---

## Findings

### F1 — The flag is a naming bug before it is a measurement bug. *(Confirmed from line evidence)*

At the moment the flag fires, ICMP ping succeeds, GitHub over TCP/443 (and/or SSH) completes full request/response cycles, and pushes land. Whatever the predicate measures, it does not measure "network down" in any sense an operator would recognize. The boolean collapses a narrow condition into a catastrophic label. Even if every other defect were fixed, a flag named `network-down` driven by a headroom predicate would still be dishonest, because the label promises reachability and the probe delivers capacity.

### F2 — Clock-locked nightly firing implicates scheduled causes, not load events. *(Strong inference; mechanism unconfirmed)*

A predicate that trips on a schedule rather than under stochastic load points at scheduled activity or scheduled expiry. The line's prior art documents a nightly orchestrator with multiple concurrent plans writing overnight ([[sources/high-risk-file-collision-in-nightly-cycle-orchestrator]]), establishing that this environment *does* run heavy scheduled overnight work. Three mechanism families remain live, none eliminated:

1. **Path saturation** — nightly jobs saturate one specific path (tunnel/VPN interface, metered uplink, single route). The predicate measures RTT inflation or throughput margin on that path and trips its threshold, while small asynchronous probes (ping, push) succeed despite degraded latency.
2. **Scheduled expiry** — DHCP lease renewal, DHCPv6/RA lifetime expiry, or a nightly resolver restart breaks the one dependency the probe uses (e.g., IPv6 internal resolution) while GitHub traffic rides the still-working path (IPv4, cached DNS, alternate resolver).
3. **Probe self-interference** — the probe runs inside the nightly window and is starved by the orchestrator (CPU contention, scheduling priority, lock contention per the collision note). Its own timeout fires; the network never left.

### F3 — "Headroom" is plausibly a capacity predicate miscast as a liveness signal. *(Unverified until code read)*

The honest prior, from the name alone: the predicate estimates spare capacity — latency margin, bandwidth margin, or connection-establishment margin — against a fixed reference endpoint. That is a legitimate capacity-planning instrument. Mapping `headroom < threshold → network-down` instead of `→ degraded` is a category error, and the nightly firing is then *expected behavior* of the instrument under nightly load. **This finding is conditional on reading the predicate implementation; until then it is a prior, not a result.**

### F4 — The honest probe is a reachability battery, not a headroom scalar. *(Design finding; stands independent of code access)*

A flag must be falsifiable by its own probe. For a label reading `network-down`, the probe must test end-to-end reachability over the exact paths the system depends on — e.g., ICMP to a known host, TCP connect to the specific remotes in use (GitHub), DNS resolution of the specific names in use — and fire only when a quorum of independent paths fail. A single-path headroom threshold can never satisfy that contract. Headroom belongs on a separate `network-degraded` signal.

---

## Recommendations

1. **Split the signal.** Rename the existing predicate's output to `network-degraded` (or `headroom-low`) and reserve `network-down` for the reachability battery in F4. This is the minimal honest fix and requires no new measurement infrastructure beyond the battery.
2. **Instrument before theorizing.** Add timestamped logging capturing, per flag-firing: the predicate's raw inputs (RTT samples, target endpoint, interface, resolver used), plus concurrent ping/push outcomes. One night of this data distinguishes F2's three mechanisms: saturation shows RTT inflation; expiry shows resolution or address-family failure; self-interference shows probe starvation with healthy parallel measurements.
3. **Check the probe's dependencies against the nightly schedule.** Enumerate what the predicate touches (DNS, IPv6, a specific interface, a file lock) and diff that against the nightly orchestrator's schedule and resource claims documented in the prior-art collision note.
4. **Do not tune the threshold.** Raising the headroom threshold would silence the symptom while preserving the category error. The fix is semantic, not parametric.

---

## Open Threads (for the next transition, if the line reopens)

- **T1 (blocking):** Read the actual headroom predicate implementation in the hngh kernel. Confirm or kill F3. Candidate artifacts to locate: the oversight/monitor module and the flag-emission site. No paths cited here — locate by grep for the flag name and "headroom" rather than by assumption.
- **T2:** Determine which of F2's three mechanisms (saturation / expiry / self-interference) is operative, using the instrumentation from Recommendation 2. Each mechanism has a distinct fingerprint; one night's data should suffice.
- **T3:** Audit whether any *other* oversight flags share the label-exceeds-measurement pattern. If F1 is true here, the same design habit may exist elsewhere in the monitoring surface.
- **T4:** Reconcile with the orchestrator collision risk ([[sources/high-risk-file-collision-in-nightly-cycle-orchestrator]]): if the probe self-interference mechanism (F2.3) is confirmed, probe scheduling and orchestrator scheduling become one design problem, not two.

---

## References

Artifacts named in this record, with confidence:

- `research-lines.tsv` — line state file, named in the line framing itself. **Confident it exists** (designated in the prompt); contents not re-read this session.
- `/home/bricker/Projects/etc/hngh` — the hngh kernel repository, named in the line framing. **Confident the tree exists**; no internal paths verified, so none cited.
- [[sources/high-risk-file-collision-in-nightly-cycle-orchestrator]] — llm-wiki vault pointer (read-only), basis for the nightly-orchestrator context in F2 and T4.
- [[entities/camel]] — llm-wiki vault pointer (read-only); CaMeL control-and-measure framing is contextually relevant to the probe/predicate design question but was not load-bearing for any finding.
- [[sources/evomap-ai-agent-experience-network]] — llm-wiki vault pointer (read-only); listed as prior art, not load-bearing for findings.
- Prior beat (2026-09-11) on this line — source of Findings 1–4 as originally developed; this crystallization supersedes it as the line's record.

**Explicit non-claims:** Any assertion about DHCP lease timing, resolver restart schedules, specific interface topology, or threshold values in the deployment would require reading configuration and logs I have not seen. Those appear above only as falsifiable hypotheses with their tests attached, never as established fact.
