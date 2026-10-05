# What closed-vocabulary read-only probe manifest plus first captured probe output from the Omarchy node (systemctl status, list-timers, read-only journal) unblocks the parked os-adapter open thread OT1, where no probe output has ever been captured?

Status: crystallized 2026-10-05 from research line `os-probe-tier-manifest`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-os-probe-tier-manifest.md.

# Research Line Final Summary (Contracting)

**Line:** What closed-vocabulary read-only probe manifest plus first captured probe output from the Omarchy node (`systemctl status`, `list-timers`, read-only journal) unblocks the parked os-adapter open thread OT1, where no probe output has ever been captured?

**State:** contracting → archived
**Date:** 2026-10-05
**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF
**Wall Clock:** 34.0s

---

## Findings

### 1. The Gap Is Structural, Not Technical
The core problem is not that the probes (`systemctl status`, `systemctl list-timers`, `journalctl` read-only) are unavailable or unknown. The gap is that **no probe output has ever been captured from the Omarchy node**. This is a pipeline/automation gap, not a knowledge gap. The commands are standard systemd primitives; the missing piece is the execution-and-persist step in the automation loop.

### 2. Closed-Vocabulary Constraint Is Enforceable
The line explicitly constrains the probe vocabulary to a closed set. This means the manifest is deterministic and auditable. Any deviation (adding custom probes) requires explicit approval. This constraint aligns with the hngh ceremony loop's closed-vocabulary principle (see prior art `[[sources/hngh-ceremony-loop-mechanics]]`).

### 3. OT1's Unblock Condition Remains Undocumented
The line states OT1 is parked waiting on probe output, but **the specific evidence format OT1 requires has not been documented**. We do not know whether OT1 needs:
- `systemctl status` to show a specific unit as "active (running)"
- A specific timer entry from `list-timers`
- A specific journal line from `journalctl`
- A combination of the above

This is the critical unknown. Without it, the manifest can be executed but the output cannot be validated against OT1's unblock condition.

### 4. The Capture Pipeline Does Not Exist in hngh Automation
The prior distillation beat identified that `hngh/hngh-automation` lacks a capture step that executes the manifest against the Omarchy node and persists output to a timestamped artifact. This is the actionable gap.

---

## Recommendations

### 1. Define the Probe Manifest as a Deterministic Set
Create an explicit `probe-manifest` definition in `hngh/hngh-automation` configuration. The manifest should list exactly:
- `systemctl status <omarchy-unit>`
- `systemctl list-timers`
- `journalctl --no-pager -n 50` (or equivalent read-only flag)

No custom probes. No open-ended queries. This is the closed-vocabulary constraint made concrete.

### 2. Add the Capture-and-Persist Step
Add a step to the `hngh/hngh-automation` loop that:
1. Executes the manifest against the Omarchy node
2. Persists output to a timestamped artifact (e.g., `probe-output-YYYYMMDD-HHMMSS.log`)
3. Archives the artifact for later analysis

This is the single step that transforms "no probe output has ever been captured" into "probe output exists and is available."

### 3. Document OT1's Minimum Unblock Evidence
Before executing the manifest, document what OT1 actually needs to unblock. Ask:
- What is the minimum viable output?
- Is one probe sufficient, or are multiple required?
- What format must the output be in?

This prevents running the full manifest when only one piece of evidence is needed.

### 4. Execute the Manifest (If Access Is Available)
If the Omarchy node is accessible, execute the manifest now to produce the first captured output. This is the highest-leverage action: it converts zero evidence into one data point.

---

## Open Threads

### 1. OT1's Unblock Condition Is Unknown
The most critical open thread. Without knowing what OT1 needs, the manifest can be captured but not validated. This thread should be resolved before the manifest is executed.

### 2. Omarchy Node Accessibility
If the Omarchy node is not accessible from the hosts running `hngh/hngh-automation`, the capture pipeline cannot be implemented without network or access changes. This is a dependency that may block the entire line.

### 3. Probe Output Format Standardization
Once captured, the output needs to be in a format that OT1 can consume. If OT1 expects a specific schema or structure, the capture pipeline must produce that. This is an open design question.

---

## References

### Verified (from prior material and line description)
- **hngh kernel repository:** `[redacted path] — referenced in line description and prior material; contents cannot be verified from this session
- **hngh automation:** `hngh/hngh-automation` — referenced in prior distillation beat as the target for capture pipeline changes
- **Prior art:** `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — research lesson on R1 probes (systemctl status, list-timers, journal)
- **Prior art:** `[[sources/hngh-ceremony-loop-mechanics]]` — hngh dogfood ceremony on closed vocabularies and path positioning
- **Prior art:** `[[sources/ainglish-org-evidence-lifecycle]]` — ainglish.org evidence-first proposal lifecycle

### Not Verified (external, cannot confirm)
- **systemd documentation:** `man systemctl`, `man journalctl` — standard Linux tools; behavior is well-documented but not verifiable from this session
- **Omarchy node:** No file path or access method is documented in prior material; existence and accessibility are unverified

### Explicit Uncertainties
- I do not have access to the local filesystem at `[redacted path] and cannot verify the existence of specific files within it.
- I cannot confirm whether the Omarchy node is currently accessible or whether `hngh/hngh-automation` has been updated since the prior distillation beat.
- OT1's unblock condition is not documented in prior material; this is an open question, not a known fact.

---

## Final State

This line is contracting to its final record. The core finding is that the gap is a missing capture pipeline, not missing knowledge. The highest-leverage next action is to document OT1's unblock condition and execute the manifest if access is available. If access is not available, the line remains parked until that dependency is resolved.

**Line archived.** No further beats scheduled.
