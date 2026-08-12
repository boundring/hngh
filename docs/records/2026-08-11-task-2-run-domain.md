# Task 2 run-domain record

## Scope

Implemented `hngh.domain` as a pure Common Lisp library before application,
persistence, or adapter work. The existing `hngh:validate-profile` entry remains
a compatibility facade.

## Evidence

The recovered parenthesis linter reported all touched Lisp files balanced.
`make test` passed with 265 checks and an ASDF load.

The test suite covers valid mission, role, and loadout values; malformed input
and infrastructure-shaped values; defensive input/output copies; read-only
storage slots; all lifecycle state pairs; functional state transitions; and
evidence-only receipt, score, and afterlife records.

## Boundary result

Runs start in `created` and advance only through the closed domain table. Every
other transition signals `invalid-run-transition`. Receipts, scores, and lesson
candidates cannot change run state or grant authority.

No application use case, port, adapter, persistence root, clock, environment
lookup, provider call, subprocess, service, or background process was added.

## Next

Add application use cases and inward port contracts against fakes.
