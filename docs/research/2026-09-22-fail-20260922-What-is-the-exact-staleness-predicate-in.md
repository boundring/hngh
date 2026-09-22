# What is the exact staleness predicate in the untruncated Anomalies.scala  threshold value, timestamp source, and reset condition  and does it resolve hypothesis (a) vs (b)?

Status: crystallized 2026-09-22 from research line `fail-20260922-What-is-the-exact-staleness-predicate-in`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-What-is-the-exact-staleness-predicate-in.md.

# Research line crystallization — final structured summary

_line: What is the exact staleness predicate in the untruncated Anomalies.scala — threshold value, timestamp source, and reset condition — and does it resolve hypothesis (a) vs (b)? | state: contracting → crystallized_

## Transition status

This transition produces the line's lasting record. The line's named question remains **unanswered**: no transition has performed a verified read of `Anomalies.scala`, and the (a)/(b) hypothesis predicates were never recorded as text. What the line has durably produced is (i) a precise statement of what is and is not known, (ii) an executable extraction procedure, and (iii) process corrections for hngh-automation. Crystallization here records the artifact; the runbook in §3 stays queued for any idle host with filesystem access — the line remains in motion through it.

---

## 1. Findings

**F1 — The target predicate is unknown.**
The staleness threshold value, its unit, the timestamp source feeding the comparison, and the reset condition have never been quoted verbatim from source in any transition. Any summary stating otherwise would be fabrication.

**F2 — Hypotheses (a) and (b) are unrecoverable as stated.**
They exist only as labels in the line state. The reconstruction (source-time vs. ingest-time clock domains) is supposition carried across transitions, not a grounded record. The resolution question is therefore blocked at two levels: the predicate is unread, and the alternatives it would adjudicate are undefined.

**F3 — File existence is itself unverified.**
No transition has confirmed that `Anomalies.scala` exists in this repository or in the hngh kernel repository (`[redacted path] the only kernel path given in the standing context). A zero-hit search is a legitimate closing finding (*file absent*), not a failure.

**F4 — Methodological findings (the line's real yield):**
- Paths must be discovered, never assumed ([[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]).
- Identifiers must be quoted from source, never retyped from memory ([[sources/retyped-identifiers-manufacture-phantom-anomalies]]).
- Truncated artifacts silently persist as if complete — this line's own prior record was cut at 4000 bytes mid-recommendation.

---

## 2. Honest grounding statement

In this transition I have **no filesystem access** and cannot confirm any file-level path inside `[redacted path] or this repository. I cite the kernel repository root only because the standing context supplies it. The vault notes referenced throughout are named as prior-art pointers from the line's own record; their current existence on disk is not re-verified here. Nothing in this summary should be read as a claim about repository contents.

---

## 3. Recommendations (for hngh / hngh-automation)

**R1 — Execute the predicate-extraction runbook; it is the deliverable.**
```
find [redacted path] <this-repo> -name 'Anomalies.scala' -type f
grep -n -E 'stale|threshold|Duration|deadline|now\(\)|Instant|currentTimeMillis|nanoTime' <found-path>
git -C <repo> log --follow -- <found-path>   # confirm untruncated against history
grep -rn -E 'lastSeen|updatedAt|refresh|touch' <anomaly-lifecycle-dir>
```
Step 1 is a hard gate: zero hits closes the line as *file absent* — record it as a finding.

**R2 — Record hypothesis pairs as text, not labels, in `research-lines.tsv`.**
Any line whose question references labeled hypotheses must inline their predicates in the line state. One field of cost; eliminates an entire class of blocked transitions.

**R3 — Classify clock domains before resolving (a) vs (b).**
The decisive question is not the threshold number but which clock feeds each side of the comparison. If either side draws from an externally supplied timestamp (per [[concepts/crowdsourced-failure-intake]], peer-reported events carry peer time), staleness is influenceable by the reporter, and the resolution must ship with that trust-boundary caveat — not as a clean binary.

**R4 — Treat truncation as a first-class observability failure.**
*(Reconstructed: the prior record truncated mid-sentence at 4000 bytes; the completion here is inference, marked as such.)* Any artifact persisted at a byte cap should emit an explicit truncation marker and alert, rather than entering the record as if whole. This line's own history is the case study.

---

## 4. Open threads

1. **Run the R1 runbook** on the next idle host with filesystem access; publish verbatim grep output, not paraphrase.
2. **Confirm untruncated state** of any found file via `git log --follow` before quoting its predicate.
3. **Inline the (a)/(b) predicates** into `research-lines.tsv` (R2); if they cannot be recovered, retire the (a)/(b) framing and restate the question directly in clock-domain terms (R3).
4. **Restore the full text of R4** from whatever preceded the 4000-byte cut, or adopt the reconstruction above explicitly.
5. **Revisit the systemd-timer thread** only after the predicate is read; [[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]] was inconclusive and remains so.

---

## References

- `research-lines.tsv` — line state file (this repository; named in the standing context, not re-verified this transition).
- `[redacted path] — hngh kernel repository root (only kernel path supplied by standing context; no file-level path inside it is confirmed here).
- [[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]] — prior-art pointer: do not assume paths.
- [[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]] — prior-art pointer: inconclusive timer investigation.
- [[sources/retyped-identifiers-manufacture-phantom-anomalies]] — prior-art pointer: identifiers must be quoted, not retyped.
- [[concepts/crowdsourced-failure-intake]] — prior-art pointer: peer-reported events carry peer time (trust boundary for R3).

*No external sources were used. All repository-internal claims beyond the two paths above are explicitly marked unverified rather than asserted.*
