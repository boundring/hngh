# Which long-session compaction strategies (checkpointing state at turn boundaries) let a reborn session reorient in one bounded read without losing verified facts?

Status: crystallized 2026-09-07 from research line `ctx-compaction-strategies`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-compaction-strategies.md.

# research beat 2026-09-07 (contraction — final crystallization)

_line: Which long-session compaction strategies (checkpointing state at turn boundaries) let a reborn session reorient in one bounded read without losing verified facts? | state: contracting -> contracted (terminal record)_

## Verification status (read this first)

This line never captured any content from either repository. The one prior beat recorded a single tool call (`ls` on the hngh kernel repo) with no recorded output. Therefore:

- **No file inside either repository can be honestly cited.** Any claim of the form "file X does Y" would be fabrication.
- Everything below is a *design recommendation* for hngh / hngh-automation, not a description of existing code.
- The only two paths this record can name with confidence are the ones given in the line-state header itself: `research-lines.tsv` (the line-state file, referenced in the prompt header) and `/home/bricker/Projects/etc/hngh` (the kernel repository root, named in the prompt). Their contents remain **[unverified]**.

That limitation is itself the line's cleanest finding; see F1.

---

## Findings

**F1. The line's own history is a demonstration of the failure mode it studied.**
A beat that records *intent* (a tool call) but not *outcome* (its output) passed through compaction and emerged indistinguishable from a beat that actually verified something. Only an explicit audit at contraction time caught it. This is direct, first-party evidence — generated inside the line, not borrowed from literature — that **a tool call is not evidence; only its recorded output is**.

**F2. The core design answer: checkpoint artifacts, not narratives.**
Free-text turn summaries decay under repeated compaction (each pass paraphrases, and paraphrase launders confidence). A ledger of structured records — `{claim, status: verified|unverified, evidence, superseded_by}` — survives compaction because each entry is either carried verbatim or dropped, never re-worded.

**F3. "One bounded read" requires a hard two-tier split enforced at write time.**
If the reorientation document is allowed to grow, the system silently regresses to "read everything," which is the problem the line set out to solve. The bound must be a write-time cap (fixed token/line budget), not a read-time discipline, because a reborn session has no basis to judge what to skip.

**F4. Checkpoint timing matters more than checkpoint content.**
Checkpointing triggered by context pressure is written by a degraded, rushed session — the worst possible author. Checkpointing at every turn boundary is cheap (append to ledger, regenerate the bounded document) and makes rebirth a pure read with no catch-up write.

**F5. Verification status must survive compaction; confidence must not be laundered.**
The entry criterion for the verified ledger is a concrete, checkable pointer: a file path actually read, command output actually captured, an external source actually fetched. Absent the pointer, the claim stays `unverified` no matter how many compactions it has survived. F1 shows why this rule cannot be relaxed.

**F6. Stale checkpoints are worse than missing ones.**
A reborn session trusting a stale ledger inherits false confidence. The bounded document needs a freshness marker (last turn id, timestamp, or state hash) and the reborn session needs a defined behavior on staleness: treat all "verified" facts as suspect until re-checked.

---

## Recommendations (for hngh / hngh-automation)

1. **Per-turn ledger, not per-turn prose.** The checkpoint writer extracts and appends structured fact records; it does not re-summarize the conversation.
2. **Tier 0 / Tier 1 split.**
   - Tier 0 (the bounded read): current goal, lifecycle state, verified-facts ledger, open questions, single next action. Hard size cap enforced when written.
   - Tier 1 (working state): full history, tool outputs, prior material. Read on demand, never by default.
3. **Evidence-or-unverified gate.** A claim enters the verified ledger only with a checkable pointer. Tool *calls* never qualify; only recorded *outputs* do.
4. **Write at the boundary.** Hook checkpointing into per-turn completion so rebirth is read-only. **[unverified]** which completion hook or entry point exists in hngh-automation — none was captured.
5. **Freshness marker + staleness protocol** on Tier 0. **[unverified]** whether hngh has an existing turn-id or state-hash mechanism to reuse.
6. **`research-lines.tsv` as proto-Tier 0.** The line-state file already carries one line per line with lifecycle state — the right shape. Recommendation: extend its per-line payload (or a sibling file it points to) to carry the verified-facts ledger and freshness marker, rather than inventing a parallel store. **[unverified]** its current schema beyond what the prompt header shows.

---

## Open threads (for any future line that picks this up)

- **O1. Read the repositories.** The obvious, overdue next step: enumerate `/home/bricker/Projects/etc/hngh` and the automation repo, and replace every **[unverified]** tag above with citations or corrections. One bounded read of the repos is the exact operation this line theorized about; doing it would be both verification and demonstration.
- **O2. Empirical bound on Tier 0.** What is the actual minimum token budget in which a reborn session reorients without measurable loss (e.g., failure to recall a verified fact, re-doing completed work)? This line argued for "hard cap, ~2k tokens" as intuition; it gathered no data.
- **O3. Ledger merge semantics.** When a reborn session discovers a stale marker and re-checks facts, how are corrections merged back (supersession chains vs. in-place rewrite)? `superseded_by` was proposed but never exercised.
- **O4. Compaction adversaries.** F1 caught one failure mode (intent recorded, outcome lost) by manual audit. What automated check at write time would have caught it? A checksum/"output-present" invariant on beat records is a candidate, undesigned.
- **O5. External grounding.** Claims about how other long-session systems (e.g., conversation-summarization approaches in deployed LLM products) handle checkpointing were deliberately not made, because no external sources were fetched. If comparative evidence is wanted, it must be gathered and cited explicitly; this record asserts nothing about it.

---

## References

Files/repositories named in this record:

- `research-lines.tsv` — line-state file, referenced in the research prompt header; schema and contents beyond the header **[unverified]**.
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root, named in the research prompt; no contents were read on this line.
- The hngh-automation repository — referenced by the line framing (idle-host continuous turns); its path and contents **[unverified]**.

No other file paths, command outputs, or external sources are cited, because none were captured during this line's lifetime. Per F5, nothing else qualifies for the verified ledger.
