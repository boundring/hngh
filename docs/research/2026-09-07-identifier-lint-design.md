# 2026-09-07 — identifier-consistency lint design

Status: DESIGN
Date: 2026-09-07

## Scope

Design `scripts/lint-identifiers.sh` per the backlog row (observed 2026-08-25):
a retyped identifier (`UNSLOOTH_…` vs `UNSLOTH_…`) landed in `config.env` while
every probe written from memory used the other spelling. The tool extracts every
`$UPPER_NAME` reference and `NAME=` definition, flags referenced-but-never-defined
and defined-but-never-referenced names, and checks every canonical name against
an exact-spelling dictionary.

## Canonical name dictionary

Every variable assigned in any shell config file under `lib/`, `jobs/`,
`scripts/`, `cadence/`, `config.env`, `*.env`. The dictionary is built from the
actual tree, not hardcoded — hardcoding is the failure mode (the bug was that
the dictionary was stale).

Pass 1: extract all `NAME=` assignments (with `=` not `==`, not in comments):
```
grep -rn '^[A-Z_][A-Z_0-9]*=' lib/ jobs/ scripts/ cadence/ --include='*.sh'
```
Combined with `config.env` and any `*.env` files.

Pass 2: extract all `$NAME` references (uppercase identifiers only, not `$var`):
```
grep -rnoE '\$[A-Z_][A-Z_0-9]*' lib/ jobs/ scripts/ cadence/ --include='*.sh'
```

## Three-pass structure

### Pass 1: collect definitions

Scan every `.sh` file and `config.env` for `NAME=value` lines. Build a set
of defined names. Ignore lines starting with `#` (comments), lines inside
heredocs (handled by ignoring content between `<<` and the closing delimiter).

### Pass 2: collect references

Scan every `.sh` file for `$NAME` expansions where NAME is uppercase. Extract
unique name set.

### Pass 3: cross-reference

- **Referenced but never defined**: names in references not in definitions.
  These are likely typos or missing exports.
- **Defined but never referenced**: names in definitions not in references.
  These are likely dead assignments or unused configuration.
- **Near-miss detection**: for each defined name, check against the dictionary
  of known canonical names (e.g., `UNSLOTH_URL`, `OLLAMA_URL`, `MODEL`,
  `HNGH_STORE`). Flag names that are close but not exact matches.

## Near-miss detection

Use string similarity (Levenshtein distance ≤ 2) to detect near-miss identifiers.
For example, `UNSLOOTH_FALLBACK_MODELS` should flag as near-miss to
`UNSLOTH_FALLBACK_MODELS` (distance 1).

## Where to run

- `scripts/lint-identifiers.sh` — one fail-closed pass over `config.env`,
  `lib/*.sh`, `jobs/*.sh`, `scripts/*.sh`, `cadence/*.sh`.
- Wired into `make test` as a new test target.
- Wired into the 4h security-check job as a read-only pass (no mutation).

## How we know it works

It flags a deliberately reintroduced `UNSLOOTH_FALLBACK_MODELS` typo (both
sides: the stray definition and any misspelled reference), and passes clean
on the current tree.

## Sources

- docs/BACKLOG.md (identifier-consistency lint row)
- docs/research/retyped-identifiers-manufacture-phantom-anomalies.md (root cause)
- lib/model.sh (canonical `UNSLOTH_URL`, `UNSLOTH_FALLBACK_MODELS` usage)
- config.env (definitions)
- jobs/security-check.sh, jobs/credential-health.sh (references)
