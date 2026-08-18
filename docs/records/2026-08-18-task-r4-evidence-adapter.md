# Task R4 read-only evidence adapter record

## Scope

Implements roadmap promotion rung 4: the read-only evidence adapter.
It adds `hngh.adapters.evidence`, an outer library that gathers a fixed,
enumerated set of read-only local evidence commands through an injected
process transport and maps the results to domain evidence facts and source
manifest entries with closed states. It adds no mutation executor, model
review adapter, daemon, service, watcher, clock, or environment access; the
five application use cases are unchanged.

## Decision

The adapter exposes `gather-evidence` over one request value. The fixed,
enumerable command set is `:repository-revision` (`git rev-parse HEAD`),
`:working-tree-status` (`git status --porcelain=v1 --untracked-files=all`),
and `:file-sha256` (`sha256sum <target>`). No caller-supplied command string
is ever built: the adapter resolves the exact argv for each named command.
Requests validate at construction — unknown commands, escaping, absolute,
home-relative, or option-like targets, duplicate targets, and missing
targets or source roles all refuse.

Gathering runs through `evidence-ports`, an injectable transport callback
contract `(run-process argv) => (values exit-code stdout stderr)`. A thrown
or malformed transport return fails the whole bundle closed with the label
`transport-fault`; unparseable command output fails closed with
`malformed-output`; neither state carries partial facts or manifest
entries. Everything else becomes evidence: a successful fixed command
produces `:current` facts, a missing file produces a `:missing` fact, and
an unreadable or failing command (for example a revision query outside a
repository) produces an `:unverifiable` fact, both without a manifest
entry. `:file-sha256` produces one `:content-hash` fact and one
source-manifest entry per target, keeping target order. The working-tree
fingerprint is the canonical porcelain output text, with `"clean"` for an
empty tree; the revision fingerprint is the revision itself; the content
fingerprint is the digest. The real transport, `process-run`, is exported
for composition; tests never execute a subprocess.

The adapter is the outer layer only. It depends on `hngh.domain` values and
Common Lisp process detail; it references no application package, decides
no policy, evaluates no requirement ledger, and mutates nothing. Domain and
application sources remain adapter-free, enforced by source-scan checks in
the fixture suite.

## Evidence

- `docs/project/roadmap.md` moves rung 4 to Completed and promotes the
  mutation executor to first in Next.
- `src/adapter/evidence.lisp` supplies the fixed command set, request,
  ports, result, and `gather-evidence`; src/packages.lisp exports the
  package; hngh.asd loads it serially after the application slices.
- `tests/adapter/test-evidence.lisp` adds fixture-backed checks covering
  command-set fixedness and enumerability, unknown-command, escaping-path,
  and duplicate-evidence construction refusals, malformed-output and
  transport-fault bundle refusals, missing and unverifiable evidence
  states, manifest mapping, defensive copies, and source-level dependency
  direction; `tests/support/fakes.lisp` adds the process-transport fake;
  `tests/fixtures/evidence/` holds raw command-output fixtures.
- `make test` reports 8 reader guard checks, 824 checks in
  `tests/run.lisp`, then an ASDF `:hngh` load. The real transport was
  smoke-tested against the live tree (revision, working-tree status, and
  content hashes gathered as `:current`).

## Remaining unknowns

The mutation executor (rung 5) is the first consumer of the gathered facts
and issued certificates; it must re-check every certificate fact
immediately before its named action. `:stale`, `:conflicting`, and
`:malformed` fact states remain ledger-side outcomes: the adapter records
what the fixed commands report, and the ledger decides meaning.