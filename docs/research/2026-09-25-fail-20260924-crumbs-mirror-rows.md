# Which writer appended the duplicated crumbs-mirror rows into STATE.md on 2026-09-24, and what parity deficit remains between mirrored and source rows before the crumbs reader flip can clear its 2026-10-01 SLA?

Status: crystallized 2026-09-25 from research line `fail-20260924-crumbs-mirror-rows`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260924-crumbs-mirror-rows.md.

# Research Line Final Record

**Line:** Which writer appended the duplicated crumbs-mirror rows into STATE.md on 2026-09-24, and what parity deficit remains between mirrored and source rows before the crumbs reader flip can clear its 2026-10-01 SLA?

**State:** contracting → **finalized**

**Lifecycle:** continuous research line, idle hosts, no batched execution

**Epistemic boundary:** No live read access to the working repository or hngh kernel tree was obtained during this contraction. All file paths below are either directly named by the research line itself (STATE.md, research-lines.tsv) or explicitly marked as unverified candidate locations. Claims requiring external verification are flagged as such.

---

## Findings

### Writer identity (2026-09-24 duplication event)

Three hypotheses remain, ordered by likelihood:

| Priority | Hypothesis | Signature | Status |
|----------|-----------|-----------|--------|
| H1 | Mirror writer retry without idempotency | At-least-once append with lost ack; source-identical duplicates | Most likely; unconfirmed |
| H2 | Overlapping manual/scripted backfill | Contiguous duplicate block interleaving with live rows | Unconfirmed |
| H3 | Kernel replay with stale checkpoint on watcher reconnect | Duplicates clustered at restart/reconnect boundaries | Unconfirmed |

**Discriminator:** provenance metadata on the 2026-09-24 rows (writer ID, sequence number, or kernel event ID). Machine-generated IDs with retry spacing → H1/H3; batch-uniform stamps → H2. If rows carry *no* provenance metadata, that absence is itself the headline finding.

**Prior-art linkage (unverified):** A vault note from 2026-09-15 describes scroll-drift as a known failure family in this system. The mechanism (scroll cursor re-reading an already-mirrored window) matches H1's signature. The vault note was not read during this contraction; the linkage is plausible but unconfirmed.

### Parity deficit (pre-flip SLA assessment)

The deficit is three orthogonal quantities. Reporting one number conflates them:

1. **Duplication surplus** — mirrored rows that are duplicates of other mirrored rows (the 2026-09-24 event lives here)
2. **Coverage gap** — source rows with no mirrored counterpart
3. **Content drift** — rows present on both sides whose fields disagree

The 2026-10-01 flip SLA almost certainly requires (1) = 0 and (2) = 0. Whether (3) must be zero or merely bounded is a policy decision that, on current evidence, has not been recorded anywhere. That ambiguity is a risk to the SLA in itself.

---

## Recommendations

### R1 — Block the flip on provenance, not just parity

Before any reader flip, STATE.md mirrored rows must carry an append-time writer stamp (process name + cursor/checkpoint position). If the mirror writer does not emit this, add it *first* — otherwise the 2026-09-24 event class is unreproducible-by-design and will recur undiagnosed after the flip.

**Candidate locations (unverified):** a `crumbs-mirror` or `state-sync` module in the automation hook tree; an automation hook in hngh-automation.

### R2 — Make appends idempotent before the SLA, not after

Dedup key = (source row identity, mirror cursor generation) enforced at append time. This directly retires H1 and H3 as future causes regardless of which hypothesis is confirmed.

### R3 — Record drift tolerance policy before the flip

The SLA's treatment of content drift (3) must be explicitly documented: zero-tolerance, bounded-threshold, or deferred. Without this, the flip's pass/fail criteria are ambiguous.

---

## Open threads

- **H1/H3 discrimination:** Requires provenance metadata inspection on the 2026-09-24 rows. Not run during this contraction.
- **Vault note verification:** `sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` was referenced but not read.
- **Drift tolerance policy:** No record exists in the prior material or the research line itself.
- **Mirror writer identity:** Candidate paths are unverified; no process name or module name has been confirmed.

---

## References

**Verified (named by the research line itself):**
- `STATE.md` — the file receiving duplicated crumbs-mirror rows
- `research-lines.tsv` — the line state file tracking this research line

**Unverified (candidate locations, not asserted as existing):**
- hngh kernel tree at `[redacted path]` — referenced in prior material but access was not obtained
- hngh-automation hook tree — candidate location for mirror writer module
- `crumbs-mirror` or `state-sync` module — candidate location, not confirmed
- `sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` — vault note referenced but not read during this contraction

**Explicitly unverified:**
- No live read access to the working repository or hngh kernel tree was obtained during this contraction. All file paths beyond STATE.md and research-lines.tsv are candidate locations requiring verification pass confirmation.

---

*This record is the lasting crystallization of research line: Which writer appended the duplicated crumbs-mirror rows into STATE.md on 2026-09-24, and what parity deficit remains between mirrored and source rows before the crumbs reader flip can clear its 2026-10-01 SLA?*
