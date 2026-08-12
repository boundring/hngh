# Task E candidate evidence record

## Scope

Added a local read-only candidate evidence bundle. It accepts one explicit
manifest of sorted, duplicate-free repository-relative regular files and never
infers a candidate from Git status or staging semantics.

## Decision

`make verify-candidate CANDIDATE_MANIFEST=path/to/manifest` gathers
hash-bound evidence for one declared candidate. It records repository revision
and whole-tree dirty, staged, and untracked facts, but those facts do not expand
or select candidate scope.

The bundle refuses missing, empty, unsorted, duplicate, absolute, escaping,
ignored, excluded, missing, directory, unreadable, unsafe, or unavailable
input. `.hermes/**` is not an admissible candidate path. It performs no
staging, commit, push, provider call, service start, archive read, or model
invocation.

## Evidence

- `scripts/verify-candidate.py` reads manifest and declared candidate files
  only, emits a deterministic content hash, and reports a closed status.
- Fixed local checks cover declared Lisp parenthesis balance, the inward
  dependency rule, public-content patterns, whitespace, local Markdown links,
  and the independent `make test` kernel gate.
- `tests/scripts/test-verify-candidate.py` contains scratch-repository fixtures
  for successful evidence, malformed manifests, excluded and ignored paths,
  unsafe content, whitespace, links, Lisp guard availability and failure,
  inward dependency direction, and whole-tree observation.
- `Makefile` exposes the required explicit-manifest entry point.

## Verification

```text
python3 tests/scripts/test-verify-candidate.py
77 candidate verifier checks passed.

make test
8 reader guard checks passed.
495 checks passed.
ASDF load completed.

git diff --check
passed.
```

## Remaining unknowns

This report is evidence only. It cannot issue an authorization certificate,
record a receipt, stage, commit, push, or resolve review disagreement. Those
remain later governance and authorization tasks.
