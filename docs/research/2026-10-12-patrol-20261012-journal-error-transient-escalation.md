# patrol: surface journal-error filed transient-escalation on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-10-12 from research line `patrol-20261012-journal-error-transient-escalation`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20261012-journal-error-transient-escalation.md.

# Final Structured Summary — Research Line Crystallization

**Line:** `patrol: surface journal-error filed transient-escalation on two consecutive runs -- why does it keep failing and which guardrail closes it?`  
**Lifecycle State:** `contracting` → **final record**  
**Date:** 2026-10-11  
**Prior State Transition:** `expanding` → `contracting` (2026-10-12)  

---

## 1. Findings

### 1.1 Root Cause: Structural, Not Technical

The line's repeated failure is a **process failure**, not a technical one. Three hypotheses were generated during the expanding phase (systemd timer retry boundaries, resource-exhaustion cascade, upstream guardrail-bug fallout), but **zero were confirmed by evidence**.

**Why the escalation persisted across two consecutive runs:**

| # | Failure Mode | Evidence Status |
|---|---|---|
| 1 | Hypotheses generated without instrumentation at failure time | Not captured |
| 2 | Two-consecutive-failures demotion rule did not fire | Guardrail failed to close |
| 3 | Verdict-rule drift across surfaces prevented rule application | Known adjacent hazard |

### 1.2 The Guardrail That Failed to Close

The documented cancellation condition is **two consecutive failed runs** (`[[sources/outcome-demotion-at-two-consecutive-failures]]`). This line remained in `expanding` across both failures. The guardrail did not fire.

**Plausible explanation:** Verdict-rule drift — if the demotion rule exists in one surface (e.g., the wiki) but not in the patrol runner, the patrol surface will keep re-running the line while the wiki surface would have cancelled it (`[[sources/verdict-rule-drift-two-surfaces]]`).

### 1.3 Unrecoverable Context

The prior beat (2026-10-12) was **truncated at 4000 bytes mid-sentence** ("Cross-reference findings with hngh ke..."). Its full next-steps list is unrecoverable. I do not reconstruct it; I note it as lost context.

### 1.4 What This Line Actually Teaches

The line's real output is a set of **procedural corrections for hngh/hngh-automation**, not a root cause for the journal-error escalation. The lesson is about instrumentation and guardrail reliability, not about the patrol surface itself.

---

## 2. Recommendations

These are framed as **what to build/check**, since I cannot verify which files currently exist (see §4).

### 2.1 Close This Line Under the Existing Demotion Rule

- Apply the two-consecutive-failures cancellation condition to this line now.
- Audit that the rule text lives in **exactly one place** and is imported (not copied) by every surface that consumes it.
- The drift failure mode in `[[sources/verdict-rule-drift-two-surfaces]]` is the plausible reason it didn't fire.

### 2.2 Capture Failure Evidence at Failure Time

- Whatever automation runs the patrol should snapshot the journal slice, timer states, and basic resource stats into the run's artifact **before exiting non-zero**.
- A transient escalation not captured in the run where it occurs is unrecoverable afterward — this is the lesson this line teaches.

### 2.3 Gate `expanding` State on Captured Primary Evidence

- A line may not enter `expanding` without at least one piece of captured primary evidence.
- Otherwise, it stays in observation with an instrumentation TODO.
- This line moved `planned` → `expanding` on the strength of a symptom alone — that gate should exist.

### 2.4 Verify Upstream Guardrail Bug Before Citing It

- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` records that a bug was *filed*; nothing in the prior material confirms its current status or that its behavior matches the observed escalation.
- Until the upstream issue state is verified, it should not be cited as a cause.

---

## 3. Open Threads

| Thread | Status | Notes |
|---|---|---|
| Root cause of journal-error escalation | **Open** | No confirming evidence; line closed under demotion rule |
| Verdict-rule drift audit | **Open** | Known hazard; needs surface-by-surface rule inventory |
| Failure evidence capture at automation layer | **Open** | Instrumentation TODO; not yet built |
| `expanding` gate on primary evidence | **Open** | Process recommendation; not yet implemented |
| Upstream guardrail bug state | **Open** | Filed but status unverified; cannot cite as cause |
| Prior beat truncation recovery | **Closed** | Lost context; not reconstructed |

---

## 4. Unverifiable Claims

The following claims are grounded in prior material I was given, but I **cannot verify** which files currently exist in either repository:

- `[redacted path] — the hngh kernel repository path is provided in the prompt but I have not inspected it.
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — referenced in prior material; existence unverified.
- `[[sources/verdict-rule-drift-two-surfaces]]` — referenced in prior material; existence unverified.
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` — referenced in prior material; existence unverified.
- `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — referenced in prior material; existence unverified.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — referenced in prior material; existence unverified.
- `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]` — referenced in prior material; existence unverified.

**I do not assert these files exist.** They are cited as prior material pointers from the research vault.

---

## 5. References

### 5.1 Prior Material (llm-wiki vault; read-only pointers)

- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — Consecutive bad-execution cancellation condition
- `[[sources/verdict-rule-drift-two-surfaces]]` — Shared verdict rule drifted across two surfaces
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` — Upstream guardrail bug filed (status unverified)
- `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — Research Lesson: Has R1 (systemctl status list timers journal)
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson: Does the obs-2026-08-25-hngh-automation...
- `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]` — pi-llm-wiki guardrail blocked all apply-patch edits

### 5.2 Repository Paths (unverified)

- `[redacted path] — hngh kernel repository (prompt-provided path; not inspected)

### 5.3 External Sources

- **None cited.** All claims are grounded in prior material or process reasoning. No external sources were invoked.

---

## 6. Line Closure Statement

This line is **closed under the demotion rule** (two consecutive failed runs). The root cause of the journal-error escalation remains unconfirmed; the line's actual output is procedural: a set of instrumentation and guardrail reliability corrections for hngh/hngh-automation.

**Final verdict:** The line generated speculation, not findings. Its lasting record is the set of recommendations in §2 and the open threads in §3.

---

*End of line record. No further beats scheduled.*
