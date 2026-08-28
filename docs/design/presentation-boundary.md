# Presentation boundary

The renderer shows the machine's face; it never speaks in the machine's
voice.

Presentation renders facts for the operator. It does not decide, authorize,
mutate, start, spend, or conceal a system action.

## Factual status rule

Canonical state, receipt fields, CLI flags, configuration keys, use-case names,
and errors use plain technical terms. A renderer may add concise display copy,
but the rendered copy must not change the fact it describes.

For example, a renderer may display a quiet status label for `:evacuated`; the
stored state remains `:evacuated`. A refusal remains a literal refusal even
when a report gives it an optional visual treatment.

## Original lexicon

Hngh uses its own technical names and original fallbacks. The default renderer
needs no named-reference pack. A reference pack is optional display data owned
by presentation only and may be removed without a data migration or behavior
change.

No presentation language may imply affiliation, endorsement, shared authorship,
or a hidden execution capability. No command error becomes fiction.

## Boundary rules

- Renderers consume application output; they do not call concrete adapters.
- Display aliases never enter canonical records or package APIs.
- A reference pack cannot carry canonical state, receipts, CLI flags, use-case
  outcomes, authority, or execution instructions.
- Every optional display value has an original fallback.
- A presentation change is reviewed for factual clarity before style.

The reference-pack data contract and release review record are defined in
[the reference lexicon policy](reference-lexicon-policy.md).
