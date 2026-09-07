# The Mirror — the operator-coherence layer

Status: DESIGN — operator-directed 2026-09-07. Hngh is guided by a human;
this layer preserves the coherence of that human's intent. Nothing here is landed.

Cross-links: [descent.md](descent.md), [display-register-spec.md](display-register-spec.md)
(the perceptual-alias discipline its registers inherit),
[writing-register.md](writing-register.md),
[presentation-boundary.md](presentation-boundary.md),
[autonomous-development-control.md](autonomous-development-control.md),
[gate-inventory.md](gate-inventory.md) (the design-hold precedent),
[bestiary.md](bestiary.md).

## 1. The problem

The operator's intent drifts across sessions — journals age, preferences
shift, priorities get re-ranked and never re-enter any machine-readable
record. Hngh already checks every decision against policy
([autonomous-development-control.md](autonomous-development-control.md)
source resolution, step 1: "current operator policy and recorded project
decisions"), but the operator's own corpus — journals, diaries, emails,
letters, personal documents, collected books, videos, images, memes — sits
outside that chain. Machine decisions cannot today be checked against what
the operator actually wrote, valued, or meant.

The Mirror closes that gap: it builds understanding, memory, and
embodiment of the operator's aesthetics, sensibilities, morals, and goals
from everything its access allows — without becoming a surveillance
hazard. The rule it must never break: the Mirror serves the operator's
stated intent; it does not observe the operator.

## 2. What exists today (the substitutes)

Four operator-preference surfaces already exist, each partial:
[writing-register.md](writing-register.md) and
[display-register-spec.md](display-register-spec.md) are operator-preference
registers (versioned, citable prose constraining machine-drafted text and
rendered surfaces); `hngh-automation/cadence-params.tsv` is operator
preference as data (one row per loop tunable: key, value, provenance,
note); the llm-wiki vault (`~/.llm-wiki/`) is the emerging memory corpus
(backlog row "Memory surface" wires Hngh to it);
[../project/lessons-index.md](../project/lessons-index.md) is the learning
record. The Mirror generalizes them: preference and principle registers
over the whole recorded life, not just prose style.

## 3. Architecture (design-intent)

1. **Source ingest.** Named sources only — journals, emails, letters,
   personal documents, books, videos, images, memes. Each enters with a
   manifest row naming path, kind, and version; nothing is ingested that
   was not named (no covert collection, §6).
2. **Normalized corpus.** Local-first, content-addressed: one item, one
   hash, one path — in-repo for project-adjacent material, vault-backed
   (`~/.llm-wiki/`) for personal material. Append-mostly; items are
   superseded, never silently rewritten.
3. **Preference and principle registers.** Extracted, versioned, citable
   rows — the same perceptual-alias discipline as the display register
   ([display-register-spec.md](display-register-spec.md) §5): preferences
   are DATA, never silently rewritten; a row changes only through a
   recorded disposition citing what superseded it. Prose style stays
   governed by [writing-register.md](writing-register.md); the Mirror adds
   substance — morals, goals, taste, priorities.
4. **Coherence checks.** A Disposition-station check ([descent.md](descent.md)
   station 2): "does action X conflict with recorded operator intent Y?"
   Wired as a grow-admission check analogous to the design gate
   ([gate-inventory.md](gate-inventory.md), the `design-hold` row): a plan
   contradicting a cited register row holds with `cause=intent-conflict`,
   named here as a new cause class — adding a row to the Bestiary's closed
   class set ([bestiary.md](bestiary.md)) rides that doc's own amendment
   route and is not granted by this doc.

## 4. Model-exposure policy (the security spine)

The corpus is **local-first by default**: it lives on the operator's
machine and is processed by local models where possible. Remote-model
exposure requires **per-item policy rows** — the param-ledger pattern of
`hngh-automation/cadence-params.tsv`: one row per item or item class,
naming what may leave and under which consumer. PII and personal documents
default to local-model-only processing. Nothing from the Mirror enters a
remote prompt without a policy row naming it — no row, no exposure; the
kernel's fail-closed rule ([../intent.md](../intent.md)) applied to memory.

## 5. Ingest candidates and where they already exist

- Memes, videos, images: research and interest signals, routed through the
  existing research machinery (`hngh-automation/research-lines.tsv`,
  `hngh-automation/research-subjects.txt`).
- Browser history and collected pages: the browser-relay lines —
  [2026-09-03-browser-messaging-automation.md](../research/2026-09-03-browser-messaging-automation.md)
  and [2026-09-04-browser-relay-architecture.md](../research/2026-09-04-browser-relay-architecture.md)
  — already define the transport and its credential rules (§4 of the first).
- Email digests: the email channel is procedural today
  (`scripts/email-digest.py`, cited by the browser research §3).
- The operator's documents and books: vault-backed ingest via the llm-wiki corpus.

## 6. Boundaries and non-goals

- **No covert collection.** Every source is named and versioned before
  first ingest; an unnamed source is refused, like any unverified input.
- **Deletion is a recorded disposition.** The operator can delete any
  corpus item; the deletion lands as a disposition row citing what was
  removed and why — evidence-first applies to the Mirror itself.
- **No personality emulation.** The Mirror informs checks; it does not
  speak for the operator or invent detail around a register row.
- **No read of live sessions, keystrokes, or screens.** Ingest is over
  documents the operator's access explicitly yields.

## 7. Lexicon

| Flavor name | Canonical term | Scope |
|---|---|---|
| the Mirror | operator-coherence layer | design layer; display alias only |

The alias follows the display-register boundary law
([presentation-boundary.md](presentation-boundary.md)): records and APIs
say `operator-coherence layer`; `the Mirror` never enters a record.

---

Back to the [documentation index](../README.md).
