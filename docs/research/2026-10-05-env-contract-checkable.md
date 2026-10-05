# What declarative environment-contract schema is checkable on a live host (ladder rung 2: installer -> environment contract -> package registry -> cross-platform abstraction) and validates the CachyOS workstation and the Omarchy node, feeding docs/design/harness-data-plane.md / system-harness Rung D and the config-manager backlog row?

Status: crystallized 2026-10-05 from research line `env-contract-checkable`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-env-contract-checkable.md.

# Research Line Crystallization: Declarative Environment-Contract Schema (Ladder Rung 2)

**Lifecycle:** contracting → **crystallized (closing record)**

**Honesty preamble (carried forward and still binding):** This line has never been able to open the hngh kernel repository at `[redacted path] or read any file in it. No claim below asserts that a file exists unless the research line itself names it. Every repo-dependent claim is marked **[VERIFY]** and phrased as an executable check, not an assumption. External factual claims that could not be verified in-repo are flagged as **[UNVERIFIED-EXTERNAL]**.

---

## Findings

**F1 — The three sub-questions collapse into one design.**
The line asked about (a) schema formalism, (b) live-host checkability, and (c) cross-platform abstraction. The contracted answer: these are one problem with one answer pattern — **a base contract plus platform profiles, verified by a read-only probe layer, with graded (`must`/`should`) compliance.** This decomposition is the line's primary finding; it resolves the prior beat's three named risks (over-specification, strictness, fragmentation) with one mechanism each:
- Over-specification → four-section schema cap, expansion only after green runs.
- Strictness → graded compliance (hard gate vs. drift report).
- Fragmentation → base + overlay rather than per-platform schemas.

**F2 — Read-only probes are the enabling property, not a nicety.**
All four probe families (`pacman -Q`, `systemctl is-enabled/is-active`, `stat`, `lsmod` + `sysctl -n`) are read-only and non-privileged. This is what makes "checkable on a live host" continuous rather than episodic: the checker can run on idle hosts without mutating the host it verifies, which matches the always-in-motion posture of this research process. A contract system that requires root or writes state would contradict the line's own operating model.

**F3 — YAML + JSON Schema beats a custom DSL at rung 2.**
A purpose-built DSL was considered and rejected. YAML with a JSON Schema validation layer gives editor tooling, CI validation, and a trivially parseable contract document at zero invention cost. A DSL is a rung-3+ consideration at earliest, and only if the four-section schema proves insufficient — which is a claim about future evidence, not current need.

**F4 — The consumers shape the output format.**
The line names two downstream consumers: `docs/design/harness-data-plane.md` and system-harness Rung D, plus the config-manager backlog row. The finding is that the contract checker should not emit prose or exit codes alone — each probe should emit **one structured record (target, assertion, result, severity)** that Rung D can aggregate. Whether this record shape matches what Rung D currently expects is **[VERIFY]** against the hngh repo, which this line could not read.

**F5 — The two target hosts may share a package-manager axis.**
CachyOS is Arch-derived (**[UNVERIFIED-EXTERNAL]** — asserted from general knowledge, not confirmed in-repo), and Omarchy is likewise reported to be Arch-based (**[UNVERIFIED-EXTERNAL]**). If both hold, `pacman:` is the single package key across both profiles and the cross-platform abstraction at rung 2 is thin — profiles differ in *content*, not in *probe families*. This simplifies R3 considerably, but the Omarchy base must be **[VERIFY]**-ed before keying the schema.

---

## Recommendations (final form)

### R1 — Schema: one YAML document, four top-level sections, hard cap

Exactly these keys, nothing more:

| Section | Contents | Probe | Privilege |
|---|---|---|---|
| `packages:` | expected packages keyed by manager (`pacman:`) | `pacman -Q` | none |
| `services:` | systemd unit states (`enabled`/`disabled`/`active`) | `systemctl is-enabled` / `is-active` | none |
| `filesystem:` | paths with expected exists/mode/owner | `stat` | none |
| `kernel:` | module presence, sysctl values | `lsmod`, `sysctl -n` | none |

Each assertion carries a severity: `must` (hard gate) or `should` (drift report). No additional sections until the harness runs green on these four against both hosts.

### R2 — Checker: probe-per-section, graded compliance, structured records

One probe family per section; each probe emits one record of `(target, assertion, result, severity)`. `must` failures gate; `should` failures accumulate as drift reports. The checker itself is read-only end-to-end and safe to run continuously on idle hosts. **[VERIFY]** the record shape against whatever Rung D / `docs/design/harness-data-plane.md` currently consumes; if Rung D already defines an ingestion format, the probe output conforms to it rather than the reverse.

### R3 — Cross-platform: base contract + profile overlay

- One `base.yaml` — assertions true of every managed host (e.g., monitoring agent enabled, git-backed config checkout present; the git-backed dotfile/config angle is prior art in SRC-2026-08-18-007).
- One profile per host class — `cachyos-workstation.yaml`, `omarchy-node.yaml` — merging over base; profiles may add assertions and override severities but should not silently delete base `must` assertions (a deletion should itself be a lint error).
- If F5 confirms both hosts are pacman-based, the overlay mechanism ships at rung 2 but carries only content differences — the abstraction is validated early without being stressed, which is the correct cheap way to keep the ladder honest for rung 4.

### R4 — Sequencing: contract before registry

Rung 2's output (a validated environment contract for two hosts) is the input contract for rung 3 (package registry). Do not begin registry schema work until the four-section contract has run green against both hosts at least once — otherwise the registry schema will be designed against an unvalidated environment model.

---

## Open Threads

1. **[VERIFY] Omarchy distro base.** If not pacman-based, `packages:` needs a second manager key and the rung-4 abstraction arrives earlier than planned — a materially different design.
2. **[VERIFY] Rung D ingestion format.** Does `docs/design/harness-data-plane.md` already specify the probe-record schema? Repo access required; this line never had it.
3. **[VERIFY] Config-manager backlog row.** The line feeds a specific backlog row (per SRC-2026-08-24-022, Hngh Project Backlog). Whether R1–R4 close that row or merely narrow it is undetermined from here.
4. **Drift-report disposition policy.** Graded compliance says *what* a `should` failure is, not *what happens next* (auto-remediate via config-manager? file an issue? decay over time?). Deliberately deferred — it belongs to the config-manager line, not this one.
5. **Secrets and host-unique values.** Filesystem and sysctl assertions will eventually hit host-specific values (UUIDs, interface names). The overlay pattern absorbs this, but a templating/parameter mechanism was not designed here — flagged as a rung-2.5 concern.
6. **Merge semantics for profiles.** R3 asserts "add + override severity, no silent deletion of base `must`" but the actual merge algorithm (and its linter) is unspecified. Small, but it must be decided before a third host class appears.

---

## References

Named by the research line or prior art; none independently verified from this session:

- `research-lines.tsv` — line state ledger (this repository).
- `docs/design/harness-data-plane.md` — named consumer (hngh kernel repo, `[redacted path] — **[VERIFY]** existence and contents.
- system-harness Rung D — named consumer (hngh kernel repo) — **[VERIFY]**.
- config-manager backlog row — named consumer, per Hngh Project Backlog below.
- [[sources/SRC-2026-08-24-022]] — Hngh Project Backlog (llm-wiki vault, read-only pointer).
- [[sources/SRC-2026-08-18-007]] — Git Back Dots: Git-backed System Config & Dotfile Manager (vault pointer; basis for the base-contract checkout assertion).
- [[sources/SRC-2026-08-24-020]] — Hngh Run Contract (vault pointer).
- [[concepts/delegated-contract-verification]] — delegated-contract-verification (vault pointer).
- [[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]] — prior research lesson on hngh-automation observability (vault pointer).
- [[sources/SRC-2026-08-24-002]] — CaMeL: Defeating Prompt Injections by Design (vault pointer; cited in prior art, not load-bearing for the recommendations).

**Line status: crystallized.** R1–R4 are the lasting record; open threads 1–3 are the next actions and all require hngh repo read access that this line never obtained.
