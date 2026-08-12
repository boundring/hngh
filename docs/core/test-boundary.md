# Test boundary

Tests prove policy and boundary behavior without a live service, real home
root, provider call, or background process.

## Layers

1. **Domain tests** exercise pure values, validation, and state transitions.
2. **Application tests** exercise use cases with fake ports for time,
   identifiers, stores, ledgers, completion, tools, repository facts, and
   rendering.
3. **Adapter tests** exercise one concrete transport against restricted fixture
   inputs and injected failures.
4. **Acceptance tests** compose a local vertical slice under a temporary root.

A higher layer does not replace a lower one. A test that needs an undeclared
external detail identifies a missing boundary.

## Fixture policy

Fixtures are explicit, small, and read-only unless a test names its temporary
write root. Malformed input, unknown fields, duplicate values, and path escape
cases are first-class fixtures. Fixtures contain no provider credentials,
private transcripts, local project paths, or live machine state.

The current suite includes Task 1 through Task 3.2 fixtures:

- an inward package may not import presentation or adapter packages;
- a reference lexicon record may contain renderer copy and provenance, but not
  canonical state, receipt, CLI, use-case, or outcome control;
- domain constructors reject malformed values and infrastructure-shaped inputs;
- every run-state pair has an explicit legal transition or a typed refusal;
- receipt, score, and afterlife values cannot change run state or grant
  authority;
- creation validates all top-level values before callbacks and records one
  run-and-receipt pair atomically;
- admission requires authority, ledger, loadout, and exclusive-write facts to
  be `:confirmed` before an armed replacement run can be recorded.

## Testing API and nondeterminism

Tests call public inward APIs. A future use case receives time, identifiers,
stores, ledger facts, tool execution, completion, and rendering through ports
or injected values. A callback boundary catches only callback errors and
malformed returns; domain and application failures stay visible. An accepted
application result carries its recorded run-and-receipt pair, and any
non-accepted result carries neither. A use case does not read globals, resolve
a home directory, or start a process to make a test pass.

Randomness, clock time, process output, network responses, and filesystem roots
are fixture inputs. Unknown or missing evidence is a refusal case, never a
reason to query a live default.

## Gates

`make test` is the current fast required gate. It first runs the standard-library
fixture suite for `scripts/lint-parens.py`, a read-only guard for balanced Common
Lisp source. The guard reports only; the Common Lisp reader and ASDF load remain
authoritative. It then runs the focused Common Lisp checks and loads the ASDF
system. There is no slow or live-service gate yet. When one is admitted, it
must be separately named and must not become a prerequisite for the fast policy
suite.
