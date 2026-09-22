# patrol: surface pending-checks filed check-pending-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-22 from research line `patrol-20260922-pending-checks-check-pending-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260922-pending-checks-check-pending-stale.md.

# research beat 2026-09-22 (crystallization)

_line: patrol: surface pending-checks filed check-pending-stale on two consecutive runs -- why does it keep failing and which guardrail closes it? | state: contracting -> crystallized | wall_s: (this transition)_

---

## Lasting record: line summary

**Question.** The patrol's `surface-pending-checks` detection has filed `check-pending-stale` on two consecutive runs. Why does it keep re-firing, and which guardrail closes the loop?

**Verdict (honest).** The detection's existence and registration are verified in the hngh kernel; the precise re-firing mechanism and the identity of the closing guardrail are **not fully verified** — the kernel source was truncated during inspection, and the patrol implementation was not read in this line's recorded material. Findings below are split into *verified* and *inferred/unverified* accordingly.

---

## Findings

### Verified (grounded in the repositories)

1. **`check-pending-stale` is a first-class kernel anomaly, not a one-off.** It is registered as a `Check` inside a `Seq[Check]` in `kernel/src/main/scala/hngh/Anomalies.scala` (hits at lines 14, 21, 48, 59). Its own scaladoc states: *"A detection for stale pending checks surfaced by the patrol"* (line 21), and it carries the tags `"patrol", "surface-pending-checks", "check-pending-stale"` (line 59). So the two consecutive filings are the kernel behaving as designed: the detection exists precisely to fire repeatedly while the underlying condition persists.

2. **The condition is stateful, so consecutive filings are the expected signature.** A "stale pending check" is a check that was filed and never resolved. Unless something *clears* the pending state between patrol runs, the same detection will fire on run N+1, N+2, … Two consecutive filings therefore indicate an **unclosed lifecycle**, not a flaky detector.

3. **Line state.** `research-lines.tsv` records this line as `expanding` with one prior beat (model `kimi:k3-256k`, 2026-09-22T17:50:02Z); this transition moves it to crystallized.

### Inferred / not verified in this line's material

4. **Why it keeps failing — two candidate mechanisms, unresolved.** The full body of `Anomalies.scala` was truncated at the 4000-byte tool limit before the detection's staleness predicate (threshold, timestamp source, reset condition) could be read. Two hypotheses consistent with the verified fragments:
   - **(a) No resolver exists.** Nothing in the recorded material shows a code path that clears a pending check after filing, so staleness is monotonic by construction.
   - **(b) The freshness clock never resets.** The vault prior art `[[concepts/moment-of-action-freshness]]` (attestation freshness recheck at the moment of action) suggests the intended pattern: pending state should be re-attested or expired at action time. If the patrol reads a static filed-at timestamp rather than a moment-of-action recheck, staleness re-fires forever.
   Distinguishing (a) from (b) requires reading the untruncated predicate — flagged as an open thread rather than asserted.

5. **Which guardrail closes it — candidate identified, binding unverified.** The vault pointer `[[sources/outcome-demotion-at-two-consecutive-failures]]` ("consecutive bad-execution cancellation") names exactly this line's trigger shape: *two consecutive failures* as the demotion threshold. The natural closing guardrail is therefore **outcome demotion at two consecutive `check-pending-stale` filings** — i.e., the pending check should be cancelled/escalated rather than filed a third time. However, no repository file consulted in this line's recorded material was shown to implement that demotion for this check, so this is a **recommendation**, not a verified fact about the codebase.

---

## Recommendations

1. **Close the pending-check lifecycle.** Add (or verify the existence of) a resolver that transitions a pending check out of the patrol's input set once handled — this is the only change that stops the re-firing regardless of which hypothesis in Finding 4 holds.
2. **Apply the two-consecutive-failures demotion guardrail** to `check-pending-stale` per the `outcome-demotion-at-two-consecutive-failures` pattern: on the second consecutive filing, demote/cancel the stale pending check instead of filing again.
3. **Adopt moment-of-action freshness** for the staleness predicate (per `[[concepts/moment-of-action-freshness]]`): evaluate staleness against a re-attested timestamp at the moment the patrol acts, not against a static filed-at time.
4. **Mind known doc/install drift** before trusting patrol configuration: prior art `[[sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]` records timer documentation drifting from the installed harness — confirm the patrol's actual installed cadence/thresholds, not just its documented ones.

---

## Open threads

- **Read the untruncated `Anomalies.scala`** to extract the exact staleness predicate and resolve hypothesis (a) vs (b) in Finding 4.
- **Locate the patrol runner** (the tag `"patrol"` implies a scheduled executor; a candidate location under `kernel/src/main/scala/hngh/` or `scripts/` was not confirmed in this line's material) and verify whether any resolver/demotion path exists for pending checks.
- **Confirm whether `outcome-demotion-at-two-consecutive-failures` is implemented in-repo** or is vault-only doctrine; if the latter, file it upstream (precedent: `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`).

---

## References

**Repository files (verified to exist via direct read/grep in this line's material):**
- `kernel/src/main/scala/hngh/Anomalies.scala` (hngh kernel, `[redacted path] — `check-pending-stale` registration at lines 14, 21, 48, 59; content partially truncated during inspection.
- `research-lines.tsv` (this repository) — line state and prior-beat record.

**Repository files (existence inferred from top-level listing, not individually read):**
- `README.md`, `WRITING.md`, `build.sbt`, `kernel/`, `scripts/` (this repository).

**Vault prior art (read-only pointers, llm-wiki; used as doctrine, not as verified codebase fact):**
- `[[concepts/moment-of-action-freshness]]`
- `[[sources/outcome-demotion-at-two-consecutive-failures]]`
- `[[sources/async-proof-pattern-for-long-drop-ins]]`
- `[[sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]`
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`
- `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]`

**Explicit non-claims:** No external sources were consulted; nothing outside the two repositories and the vault pointers above is asserted. The staleness predicate, the patrol executor, and the existence of any demotion/resolver implementation remain unverified pending the open threads.
