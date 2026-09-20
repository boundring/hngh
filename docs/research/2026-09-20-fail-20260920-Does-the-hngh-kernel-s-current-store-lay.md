# Does the hngh kernel's current store layer already compute per-entry SHA-256 digests, and if so, are they stored in a field adjacent to the record payload?

Status: crystallized 2026-09-20 from research line `fail-20260920-Does-the-hngh-kernel-s-current-store-lay`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260920-Does-the-hngh-kernel-s-current-store-lay.md.

# Line crystallization: per-entry SHA-256 digests in the hngh store layer

**Line:** Does the hngh kernel's current store layer already compute per-entry SHA-256 digests, and if so, are they stored in a field adjacent to the record payload?
**Lifecycle:** expanding → contracting → **crystallized (this transition)**

---

## Final finding

**The empirical question remains unresolved, and this crystallization must record it as unresolved — not by oversight, but as the line's honest terminal state.**

Two consecutive transitions have now lacked filesystem access to `[redacted path] This transition is no different: I cannot execute the grep-and-read procedure defined in the prior beat, cannot confirm the existence of any store-layer file, and cannot cite a single concrete path inside the hngh repository with confidence. Any crystallization that asserted "yes" or "no" — or that dressed up the procedure as a finding — would be fabrication. The lasting record of this line is therefore:

1. A precisely scoped question with an explicit decision rule (preserved below).
2. A ready-to-run verification procedure costing minutes on any host with repo access.
3. Branched recommendations that are valuable regardless of the answer.

That is a complete and useful crystallization even without the bit being flipped.

## What is established (grounded in prior material only)

- The question is **genuinely open**: no prior beat, vault note, or lesson in scope answers it. Both the expanding and contracting beats confirm this.
- The resolution criterion is fixed and non-negotiable: **yes** requires (i) SHA-256 specifically — not MD5, SHA-1, or a non-cryptographic hash — computed per entry, and (ii) persistence of that digest in the same serialized record as the payload. A read-time-only digest or a whole-log/merkle-style aggregate resolves **no**.
- The store layer exists as a premise via the vault entity note `[[entities/hngh]]`, but its concrete shape (record types, serialization format, language) is **unverified** — every recommendation below inherits that caveat.
- CaMeL (`[[entities/camel]]`) is a distinct layer over hngh whose Measure side may depend on this line's answer.

## What I cannot verify (explicit, carried forward)

- No filesystem or shell access in this transition; nothing under `[redacted path] has been read by any transition on this line to date.
- The llm-wiki vault entries cited as prior art are read-only pointers; their contents are known only by title and the summaries carried in prior beats.
- Whether the store layer exists in the assumed form, what language it is written in, and whether records serialize to JSON, SQLite, or files — all unconfirmed.

## Recommendations (final, standing)

**R1 — Execute the verification procedure (blocking; minutes).** Unchanged from the contracting beat; it is restated here as the line's primary open thread:
1. `grep -rniE "sha.?256|sha256sum|hashlib" [redacted path] --include='*.py' --include='*.rs' --include='*.go' --include='*.ts'`
2. `grep -rniE "digest|checksum|content.?hash" [redacted path] — digest fields are often named without naming the algorithm.
3. Locate the record/entry type definition (`class .*Store`, `def put|append|write|store` or equivalents) and inspect whether a `digest`/`hash`/`sha256` member sits alongside the payload member.
4. Confirm the digest appears in the **serialized** form, not just the in-memory one.

**R2 — If "no": settle canonicalization before adding digests.** The hard decision is what bytes get hashed (payload only vs. payload+metadata vs. key-inclusive) and the schema-versioning/backfill strategy. Hashing is trivial; the canonical form is an API commitment.

**R3 — If "yes": verify enforcement, not just storage.** A stored digest nobody recomputes is decoration, not tamper-evidence. Check for a verification path on read/audit/replication, and note that in-store digests are self-attesting — weak against adversarial modification of the store itself.

**R4 — Resolve the CaMeL dependency.** This line's answer determines whether CaMeL's Measure side can assume kernel-provided digests, must compute its own, or ignores record integrity. A "no" may block the CaMeL line; flag it there when this resolves.

## Open threads (handed off)

1. **R1 execution** — the only thing standing between this line and resolution is one host with repo access. Any future transition with filesystem access should run it immediately and record the outcome against the decision rule.
2. **Threat-model question (R3)** — survives independent of the answer: accidental corruption vs. adversarial store modification are different designs.
3. **CaMeL coupling (R4)** — cross-line dependency; should be annotated on the CaMeL entity/line once R1 lands.
4. **Process lesson** — this line spent two transitions unable to execute a minutes-long procedure for lack of host access. If research-line transitions routinely lack filesystem access, lines of the form "does repo X already do Y" should be scheduled only on hosts with access, or the question should be answered synchronously by an agent that has it. (This echoes the failure-lesson pattern already in the vault, e.g. `LES-fail-20260915-*`.)

## References

- `research-lines.tsv` — line state record (this repository).
- Prior research beats on this line: 2026-09-20 (expanding → contracting; defined the decision rule and R1–R4) and the contracting beat reproduced in the prior material above.
- llm-wiki vault (read-only pointers; contents not independently verified this transition):
  - `[[entities/hngh]]` — Hngh Agent Kernel
  - `[[entities/camel]]` — CaMeL (Control-and-Measure Layer)
  - `[[concepts/hngh-lessons-current]]` — Hngh Lessons — Current (created 2026-09-07)
  - `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24)
  - `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]`
  - `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]`
- **No files inside `[redacted path] are cited**, because no transition on this line has verified that any specific path exists. This absence is deliberate and is itself part of the record.
