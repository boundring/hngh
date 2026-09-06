# Writing register

Status: LAW — 2026-09-06. The prose rule for all operator-facing and
machine-drafted text in this project.

Cross-links: [display-register-spec.md](display-register-spec.md) governs
voice; this doc governs prose. Enforcement partners:
[descent.md](descent.md), [presentation-boundary.md](presentation-boundary.md).

Enforcement: model-drafted digests, reviews, plans, and docs receive this
register as prompt law. The display register governs voice (quiet,
evidence-first); this register governs sentences.

## Three anchors

### Orwell — concrete nouns, active verbs

1. Name the thing. "The gate went red" beats "a failure state was
   entered".
2. If a word has a precise technical meaning, use the technical word.
   A certificate certifies; a refusal refuses; never "an authorization
   event occurred".
3. Cut dead metaphor. If the phrase arrived pre-written, it leaves.

Before: `utilization of the evidence transport was observed to be
suboptimal in failure scenarios`.
After: `the evidence transport fails open on malformed output — fix it`.

### Leonard — cut the hooey

1. No significance adjectives. Nothing is historic, significant, major,
   or crucial. The record says what happened; the reader grades it.
2. No weather-opening. Start with the subject, not the atmosphere.
3. Adverbs rare. "Quickly", "seamlessly", "effectively" — usually the
   verb was wrong.

Before: `This major new capability significantly improves the
documentation experience going forward.`
After: `doc-suite now checks all 39 links daily
(hngh-automation/jobs/doc-suite-update.sh).`

### Adams — precision beats grandeur

1. A joke may land only if the fact beside it stays exact. The number,
   the path, and the timestamp are never the punchline.
2. Prefer the smaller true statement to the larger vague one.
3. Grand claims need receipts or deletion.

Before: `Hngh's infinitely extensible plugin architecture will
revolutionize operator ergonomics.`
After: `Hngh has 19 operator verbs, one webapp, and no daemon. The
webapp's tabs still pop in late on cold loads; that is the honest
complaint list.`

---

Back to the [documentation index](../README.md).
