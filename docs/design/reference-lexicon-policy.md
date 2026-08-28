# Reference lexicon policy

Phrases may dress the facts; they may never rewrite them.

A reference lexicon is optional renderer data. It can add a display phrase to a
presentation surface, but it cannot alter machine behavior or canonical terms.
No reference pack is active in the current kernel.

## Pack contract

Each entry has exactly these fields:

| Field | Meaning |
|---|---|
| `surface` | Renderer location receiving the display copy |
| `original` | Hngh’s default display copy |
| `reference` | Optional replacement display copy |
| `provenance` | Source or operator-selected basis for review |

The pack has no fields for state, receipts, CLI flags, use cases, outcomes,
authority, commands, configuration, or protocol values. Removing a pack leaves
the original value in place and requires no migration.

## Review fixture

The Task 1 reference-lexicon fixture accepts the four-field renderer record and
rejects a fixture that carries `state`, `receipt`, `cli`, or `use-case`. This
is a structural guard: it protects the pack boundary before a renderer exists.

## Public-release review

Before publishing a retained reference entry, record:

1. the exact reference string;
2. its renderer surface;
3. its original fallback;
4. provenance;
5. the operator decision to retain, replace, or remove it.

The record is a product review of clarity and provenance. It does not grant an
exception to the machine boundary or turn a reference into product identity.
