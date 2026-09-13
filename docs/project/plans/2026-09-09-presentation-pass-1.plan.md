<!-- plan: status=accepted risk=normal accepted=2026-09-09T20:01:16Z -->
# 2026-09-09 — presentation pass 1: front door, docs spine, flavor layer

Authorization: operator-directed 2026-09-09 (presentation as
first-class acceleration work; doctrine §3). North star:
docs/design/presentation-direction.md — classy, dry, witty; Nihei
architecture and Hayashida grime-warmth as texture, never cosplay.
This plan ships rungs 1–2 (front door + navigable docs) and plants the
flavor layer; rungs 3–7 are horizon, not this plan.

## Steps

- [x] 1. README front-door pass. Rewrite the root README's opening
      screen: two-sentence identity (what hngh is, including the live
      automation tier and omp direction), truthful status block,
      navigation table that mirrors docs/README.md's read-order, the
      dry voice per the direction doc's binding rules. Keep every
      existing factual claim; change register and structure, not
      truth. No badges except ones generated from real repo state.
      Verification: relative-link checker passes on README (the
      ceremony enforces this); a read-through shows zero marketing
      register; `make test` green.
- [x] 2. Docs spine promotion. Make the navigable path the entry
      point: docs/README.md read-order gains a visual structure
      (sections: Start here / How it governs itself / The live machine
      / Records and history), each entry one descriptive line, every
      listed doc cross-linked both ways where sensible. Promote
      docs/publication/book.md to a linked "the long-form record"
      entry.
      Verification: link checker over docs/ passes (zero
      broken relative links); the read-order reaches every anchor
      record from 2026-09-09 within two hops; `make test` green.
- [x] 3. Flavor layer, guarded. Add the texture layer: short
      epigraphs (Nihei-architecture register) at the heads of the
      major docs (README, docs/README, architecture.md, the plans
      contract), and dry asides in section spines where the material
      earns them. Budget: one epigraph or aside per document, no
      more. Sweep for marketing register and emoji in all public
      docs; delete on sight.
      Verification: grep for exclamation marks and emoji in docs/*.md,
      README.md, CHANGELOG.md returns zero (code comments exempt); the
      voice reads as one author; `make test` green.
- [x] 4. Publication spine surfacing. Extend
      scripts/generate-publication's ebook mode to include the 2026-09-09
      records and the presentation direction doc in the spine, and
      regenerate docs/publication/book.md + EPUB.
      Verification: the generated book lists the new records; --check
      passes against the real git/timeline records.
- [ ] 5. Records: CHANGELOG entry for the presentation pass, and a
      docs/records/ entry recording the direction adoption (linking
      docs/design/presentation-direction.md).
      Verification: `make test` green; record cross-linked from
      CHANGELOG.

## Execution notes

- The direction doc is the arbiter of voice; if a step's output reads
  like a product launch, it fails its own verification.
- Rung 3+ (dashboard character, node-graph navigator, WebGL
  environmental surface, hot-swap GUI wrapper, the CachyOS-based
  distribution) are recorded ambitions in
  docs/design/presentation-direction.md — future plans pick them up;
  this plan does not attempt them.
- All slices are docs/publication surfaces: normal risk, no kernel
  changes, fail-first queue applies.
