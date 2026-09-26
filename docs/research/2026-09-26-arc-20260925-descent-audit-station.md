# descent: what weekly beat shape runs the five falsifiable checks and the write-only artifact count (design/descent.md), and where does its row land?

Status: crystallized 2026-09-26 from research line `arc-20260925-descent-audit-station`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260925-descent-audit-station.md.

# Research Line: descent — Final Structured Summary

**Line:** `descent`  
**State:** `contracting` → `in-progress`  
**Question:** What weekly beat shape runs the five falsifiable checks and the write-only artifact count (`design/descent.md`), and where does its row land?  
**Model:** `unsloth:unsloth/Ornith-1.0-9B-GGUF`  
**Wall clock:** 30.0s → 22.0s  
**Date:** 2026-09-26  

---

## Findings

### 1. Five Falsifiable Checks — Structural Requirements

The five checks must satisfy three structural constraints to be genuinely falsifiable:

| Constraint | Requirement | Violation Mode |
|---|---|---|
| **Exact input** | Deterministic data/state consumed by the check | External oracle dependency |
| **Exact command** | Reproducible script/command with no human judgment | Interactive or ambiguous invocation |
| **Exact expected output** | Binary pass/fail criterion | Fuzzy or subjective threshold |

**Finding:** Any check that fails this three-part audit is not truly falsifiable and must be reworked before the beat can run autonomously. This is grounded in the `[[concepts/moment-of-action-freshness]]` attestation freshness recheck pattern, which requires that every attested state be re-verified at the moment of action without deferred judgment.

**Repository grounding:** The `design/descent.md` file is the spec for this line. The five checks are defined within it as the operational contract for the weekly beat.

### 2. Write-Only Artifact Count — Ledger Contract

The artifact count is write-only from the beat's perspective:

- **One row per beat** — the beat produces exactly one row per execution
- **Row is committed** — no downstream process may mutate it
- **Mutation is a separate failure mode** — if a downstream process mutates it, the beat must detect this as a distinct error

**Finding:** The artifact store must be append-only at the filesystem level. If the row lives in a git commit, the commit hash becomes the artifact identifier and the contract is that no one rewrites history. If the row lives in a separate store, the filesystem must enforce append-only semantics.

**Repository grounding:** This contract is defined in `design/descent.md` as the write-only artifact count specification. The prior art reference `[[sources/SRC-2026-08-24-021]]` (Autonomous Development Control — Evidence Ledger Design) provides the conceptual foundation for append-only evidence ledgers in autonomous development systems.

### 3. Row Landing — Trace from Production to Consumption

The row lands somewhere — `design/descent.md` is the spec, but the actual row lives elsewhere:

- **Production:** The beat produces the row
- **Consumption:** The next beat or external consumer reads the row
- **Discoverability:** The row must be discoverable by the next beat without human intervention

**Finding:** The row's landing location must be deterministic and predictable. If it lives in a git commit, the commit message and hash must be deterministic. If it lives in a separate store, the path must be predictable and the store must be append-only.

**Repository grounding:** The row landing trace is defined in `design/descent.md` as the row landing specification. The prior art reference `[[sources/async-proof-pattern-for-long-drop-ins]]` provides the pattern for proving long-running drop-ins with background verification, which is relevant to ensuring the row is consumed correctly.

### 4. Beat Shape — Weekly Cadence

The beat is weekly, not daily or monthly:

- **Weekly cadence** matches the cadence of prior art on autonomous development control and attestation freshness recheck
- **Appropriate for** supply-chain and prompt-injection integrity signals
- **Should be maintained** unless evidence suggests otherwise

**Repository grounding:** The weekly cadence is defined in `design/descent.md` as the beat shape specification. The prior art reference `[[sources/SRC-2026-08-24-021]]` (Autonomous Development Control — Evidence Ledger Design) provides the conceptual foundation for weekly cadence in autonomous development systems.

---

## Recommendations

### Immediate Actions for hngh/hngh-automation

#### 1. Audit the Five Checks Against the Three-Part Structure

For each of the five checks, verify:
- [ ] Exact input is deterministic and self-contained
- [ ] Exact command is reproducible without human judgment
- [ ] Exact expected output is binary (pass/fail)

**Action:** Any check that fails this audit must be reworked before the beat can run autonomously.

#### 2. Decide the Artifact Store Location

For the write-only artifact count, decide:
- [ ] Git commit: The commit hash becomes the artifact identifier; no one rewrites history
- [ ] Separate store: The filesystem must enforce append-only semantics

**Action:** If git, the commit message and hash must be deterministic. If separate store, the path must be predictable.

#### 3. Trace the Row from Production to Consumption

Define the exact path where the row lands:
- [ ] If git: Commit message and hash must be deterministic
- [ ] If separate store: Path must be predictable and store must be append-only

**Action:** The row must be discoverable by the next beat without human intervention.

#### 4. Configure the Weekly Beat Scheduler

Ensure the beat scheduler is configured for weekly execution:
- [ ] If external (cron, GitHub Actions): Configure accordingly
- [ ] If internal: Ensure the scheduler is set to weekly cadence

**Action:** The weekly cadence is appropriate for supply-chain and prompt-injection integrity signals.

---

## Open Threads

### 1. External Oracle Dependency

**Status:** Open  
**Description:** Some of the five checks may require external oracle data or human judgment. If any check requires external oracle data, it must be either replaced or wrapped in a freshness recheck per `[[concepts/moment-of-action-freshness]]`.  
**Action:** Audit each check for external oracle dependency and rework as needed.

### 2. Git History Rewriting

**Status:** Open  
**Description:** If the artifact row lives in a git commit, the contract is that no one rewrites history. This is a strong constraint that may conflict with other workflows.  
**Action:** Decide whether the git history rewriting constraint is acceptable for the hngh/hngh-automation workflow.

### 3. Append-Only Filesystem Semantics

**Status:** Open  
**Description:** If the artifact row lives in a separate store, the filesystem must enforce append-only semantics. This may require additional tooling or configuration.  
**Action:** Evaluate whether the append-only filesystem constraint is feasible for the hngh/hngh-automation workflow.

### 4. External Source Verification

**Status:** Open  
**Description:** Some claims in this summary reference external sources that cannot be verified at this time.  
**Action:** Verify the external sources when possible and update the summary accordingly.

---

## References

### Repository References

- `design/descent.md` — Spec for the descent research line, defining the five falsifiable checks, write-only artifact count, row landing, and beat shape
- `[[concepts/moment-of-action-freshness]]` — Attestation freshness recheck (moment-of-action)
- `[[sources/SRC-2026-08-24-006]]` — SLSA Supply Chain Levels for Software Artifacts
- `[[sources/SRC-2026-08-24-002]]` — CaMeL: Defeating Prompt Injections by Design
- `[[sources/SRC-2026-08-24-021]]` — Autonomous Development Control (Evidence Ledger Design)
- `[[sources/chartlibrary-io-developers-api]]` — chartlibrary.io free REST/MCP market-history research
- `[[sources/async-proof-pattern-for-long-drop-ins]]` — Prove long-running drop-ins with background

### hngh Kernel Repository

- `[redacted path] — hngh kernel repository (referenced for grounding claims)

### External Sources (Unverified)

- **Status:** External sources cited above cannot be verified at this time
- **Action:** Verify when possible and update accordingly

---

**End of descent research line summary.**  
**Line state:** `contracting` → `in-progress`  
**Next step:** Apply recommendations to hngh/hngh-automation and close open threads as evidence becomes available.
