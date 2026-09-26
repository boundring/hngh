# patrol: surface automation-gate filed gate-stale on consecutive runs -- why does the check still find no gate crumb against the crumbs-db seam after the refoundation moved crumb readers off STATE.md, and which guardrail or re-baseline closes it?

Status: crystallized 2026-09-26 from research line `patrol-20260925-automation-gate-gate-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260925-automation-gate-gate-stale.md.

# research beat — final crystallization

_line: patrol: surface automation-gate filed gate-stale on consecutive runs — why does the check still find no gate crumb against the crumbs-db seam after the refoundation moved crumb readers off STATE.md, and which guardrail or re-baseline closes it? | state: contracting -> **contracted (crystallized)** | prior beats: 2026-09-25 (expanding), 2026-09-26 (contracting, truncated at token cap)_

This is the line's lasting record. It consolidates the 2026-09-25 expansion and the 2026-09-26 contraction (which truncated mid-table at `max_tokens`; the decision table is completed here).

---

## 1. Epistemic status of the record

No filesystem read against either repository (this repo; `[redacted path] succeeded in any transition of this line. Therefore:

- **No repository file path has been verified.** The seam's components — the crumbs-db store, `STATE.md`, the automation-gate check implementation, the patrol runner — are named from the line statement and prior art, not confirmed on disk.
- Findings are tagged **[inferred]** (reasoned from the line statement) or **[line-stated]**. The decision procedure in §4 is designed so that the *first* grounded read converts directly into a fix with no further analysis needed.
- Nothing below asserts external facts. Where the record names a path, it names a *lookup target*, not a verified location.

## 2. Findings (consolidated)

**F1 — The failure is deterministic, not flaky [inferred].** `gate-stale` filed on *consecutive* runs [line-stated]. Intermittent causes (races, TTL boundary cases, transient IO) are thereby deprioritized; the defect is structural: reader and writer disagree on *where* or *under what key* the gate crumb lives.

**F2 — Patrol machinery is healthy; the defect is localized to the lookup [inferred].** The check schedules, executes, and emits a well-formed verdict. The failure sits strictly between "crumb should exist" and "reader finds it" — exactly the seam the refoundation touched, making the refoundation the proximal cause by construction.

**F3 — The migration admits three half-applied shapes, each producing this exact symptom [inferred]:**
- **(a) Reader moved, writer didn't** — crumbs still land in `STATE.md`; the crumbs-db reader finds nothing forever. (In this shape the check's verdict is *correct* and the writer is the defect.)
- **(b) Writer moved, one reader didn't** — the automation-gate check is a legacy or duplicated inline lookup still reading `STATE.md`, while other consumers migrated fine.
- **(c) Both moved, key/schema drifted** — both sides target crumbs-db, but the lookup key (gate name, run-id format, timestamp granularity, schema version) differs; fresh crumbs exist and the query still misses.

**F4 — Moment-of-action freshness is a cross-cutting suspect [inferred, grounded in prior art].** The vault's [[concepts/moment-of-action-freshness]] and [[sources/long-gates-run-async-against-interjections]] imply: if the crumb is read at enqueue but evaluated after a long async gate window, a correctly written, correctly read crumb can still be stale at evaluation. This fails repeatedly if patrol cadence systematically exceeds crumb TTL. Ranked below F3 by parsimony (F1 favors structural mismatch), but it must be re-checked *after* the seam is repaired, or the fix will appear not to hold.

**F5 — Ranked diagnosis [inferred]:** (b) left-behind reader > (c) key/schema drift > (a) writer never migrated > F4 freshness. Rationale: the line states readers (plural) were migrated, yet exactly one check breaks deterministically while its host machinery is clean — the signature of one consumer the migration missed.

## 3. Discriminating instrument: the round-trip canary

A minimal writer→reader pair exercised *inside the patrol run*, immediately before the real check:

- **Canary misses** → the seam is structurally broken (shape a or a store-level fault).
- **Canary hits, real check misses** → the defect is specific to the real check: its location (b) or its key/schema (c).
- **Both hit, verdict still stale** → freshness semantics (F4), not the seam.

This single instrument discriminates all four hypotheses in one run. Feasibility is **[to-verify]** against the patrol runner's execution model.

## 4. Decision table — canary outcome → closure *(completes the truncated 2026-09-26 table)*

| Shape | Canary outcome | Fix | Durable guardrail |
|---|---|---|---|
| (a) writer never migrated | canary write misses; `STATE.md` still receives crumbs | Migrate the gate-crumb writer to crumbs-db | **Writer-side emission assertion:** gate completion fails loudly if no crumb lands in the store |
| (b) left-behind reader | canary hits; real check misses; real check's read path targets `STATE.md` | Point the check at the shared crumbs-db reader; delete any duplicated inline lookup | **Single-reader invariant:** one canonical crumb-reader module; CI grep forbids direct `STATE.md` crumb reads outside it |
| (c) key/schema drift | canary hits; real check misses; both paths target crumbs-db | Align lookup key/schema; add a shared key-constructor used by writer and reader | **Fail-loud schema versioning:** crumbs carry a schema version; unknown versions raise, never silently miss |
| F4 freshness | canary hits; real check hits; verdict still stale | Recheck crumb freshness at moment of action, not enqueue | **TTL invariant:** crumb TTL ≥ max async gate window + patrol cadence, asserted at config load |

If two rows match simultaneously, apply fixes in table order; the guardrails are independent and all four are worth keeping regardless of which shape was live.

## 5. Recommendations (ordered)

1. **First grounded read** — the moment repo access is available: locate the automation-gate check's crumb-read path and the gate-crumb writer's emission path; classify against F3(a/b/c) in one sitting. Per [[sources/debug-repro-sandboxes-only]], run any repro against a sandboxed crumbs-db, never the live ledger.
2. **Land the canary first**, before the fix. It is the cheapest possible instrument and converts an ambiguous symptom into a one-bit answer; it should remain in patrol permanently as the seam's tripwire.
3. **Apply the row-matched fix** from §4, then **re-verify F4 explicitly** — a green check post-fix is not proof the freshness semantics are sound.
4. **Adopt all four guardrails** (writer emission assertion, single-reader invariant, fail-loud schema versioning, TTL invariant) as the re-baseline. The line's closing question — "which guardrail or re-baseline closes it" — resolves to: the canary closes the *diagnostic* gap; the single-reader invariant plus schema versioning closes the *recurrence* gap; the TTL invariant closes the *freshness* gap.
5. **Re-baseline the patrol expectation**: after the fix lands, treat a single `gate-stale` as page-worthy (the current consecutive-failure threshold was tuned for a flaky-seam world that F1 shows we are not in).

## 6. Open threads

- **[to-verify] All repository paths.** Every component of the seam remains unconfirmed on disk; the first read must map line-statement names to actual paths in both repos.
- **[to-verify] Canary feasibility** inside the patrol runner's execution model (write permissions against a sandboxed store, run-time budget).
- **[open] Which shape was live** — the record ranks (b) first but does not resolve it; the decision table makes resolution a mechanical follow-up.
- **[open] TTL configuration audit** — crumb TTL vs. longest async gate window vs. patrol cadence; no values were observable this line.
- **[open] Whether other consumers were silently affected** — if shape (b) is confirmed, audit for other duplicated inline lookups the migration missed.

## References

Named with confidence:
- `research-lines.tsv` — line state file for this research process (named by the transition prompt).
- `[redacted path] — the hngh kernel repository, as given by the transition prompt (directory named; contents unverified).
- Prior beats of this line: 2026-09-25 (expansion) and 2026-09-26 (contraction, truncated — completed in §4 above), reproduced in the transition prompt.
- Prior-art vault pointers (read-only, titles as provided): [[concepts/moment-of-action-freshness]], [[sources/long-gates-run-async-against-interjections]], [[sources/debug-repro-sandboxes-only]], [[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]], [[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]], [[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]].

Named but **not verified** (lookup targets, not citations): the crumbs-db store, `STATE.md` as a crumb location, the automation-gate check implementation, and the patrol runner — no concrete path for any of these was confirmed in any transition of this line, and none is asserted here.
