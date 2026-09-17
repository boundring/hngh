# 2026-09-17 — gate-cure LARGE pre-check: doctrine-coverage inventory

Gate: a4d-large-surface-autocure (audit lineage a4d-c1 kernel-classifier
audit, a4d-c3 large-precheck implementation, a4d-c4 fast-test-cache
question). The c3 pre-check's classifier asserted its coverage only
against synthetic paths and left at least two doctrine classes with no
matching rule. This record enumerates every LARGE class from the
doctrine verbatim (docs/design/autonomous-development-control.md,
"2026-09-12 amendments — large vs small matters") and maps each to a
concrete pre-check rule on the repo's REAL surfaces, or files an
explicit documented exception. No silent omissions.

## Doctrine classes -> rules (or documented exceptions)

| Doctrine class (verbatim source) | Real surface(s) | Guard |
|---|---|---|
| "credentials and provider configuration" | `automation/config/machine.env`, `automation/config.env`, `.env*` family | RULE: `_CRED_PATH_RE` extended with `[\w.-]+\.env(\..+)?` so a `<name>.env` basename matches (previously only `.env*` prefix forms did). |
| "systemd unit lifecycle" | `automation/config/hngh-services.tsv` (registry), `automation/lib/service-mgmt.sh` (lifecycle manager), `*.sudoers` grants | RULE: new `_SYSTEMD_PATH_RE`, in addition to the existing `.service/.timer/.socket` suffix rule. |
| "spend caps (`sessions-day-max`, the fail-first concurrency family)" | `automation/cadence-params.tsv` (the Inventory: `sessions-day-max`, `kimi-daily-cap`, `zai/opencode-cap-*`), `automation/lib/failfirst.sh` (fail-first engine), `automation/config/leg-budgets.tsv` | RULE: new `_SPEND_PATH_RE` for the Inventory and the fail-first family (both sit OUTSIDE `automation/config/`, so the old prefix+basename rule was blind to them); `leg-budgets.tsv` was already covered by the prefix rule (`budget` token). |
| "non-prune deletions" | any pure-deletion or deletion-dominated diff | RULE (pre-existing, hardened in ad08254f): `additions==0` pure-deletion plus the `_GUT_MIN_DELETIONS`/`_GUT_PURITY_RATIO` gut-shape rule. |
| "the public surface (pushes, digest-public, published digests)" | `automation/jobs/digest-public.py`, `automation/dispatch/**`, `automation/newspaper/**` | RULE (new `_PUBLIC_PATH_RE`) for publish CODE; published digest CONTENT is an EXCEPTION below. |
| "kernel surface: `src/`, `tests/`, `Makefile`, `hngh.asd`" | the kernel tree itself | EXCEPTION (see below). |
| (published digest content, the outward half of "public surface") | userspace `~/.hngh/newspaper/<date>/`, `~/.hngh/dispatch/`, archive copies (never in git) | EXCEPTION (see below). |

## Exception 1: kernel surface — the ceremony backstop is the guard

The classifier deliberately does NOT refuse `src/`, `tests/`,
`Makefile`, `hngh.asd` paths. Reason, with code shape: the gate-cure
lane exists to declare loop-history-guard violations, and every such
violation is kernel-surface by construction (the guard watches src/,
tests/, scripts/, Makefile, hngh.asd). The founding cure (ba6b390,
declared in the guard's KNOWN_EXEMPTIONS) touched `Makefile`
(36+/1-). A kernel-surface rule at the pre-check would refuse every
red-gate cure and dead-end the 2026-09-13 SMALL-matter amendment
instead of guarding it. The doctrine's pre-decided policy for this
class is the ceremony certificate (ten-principle verdict,
issue-cert + mutation-check, `scripts/ceremony-drive`) plus the
suite green that `cure_red_gate` runs through verify-candidate. Both
of those run on every cure; the pre-check's job is the classes the
ceremony verdict does NOT mechanically see (path-shaped content in the
proposer's diff).

## Exception 2: published digest content — the push gate is the guard

Published digest CONTENT lives in userspace under `~/.hngh/` (the
2026-09-13 userspace-home split), outside any git tree, so no commit
classifier can see it. Its guards are structural: (a) pushes are not
auto-run — ceremony-drive's push is a separate deliberate
certificate-gated step re-proposed under `class=push-request` into a
fresh ten-principle verdict; (b) the egress boundary record
(docs/records/2026-09-16-newspaper-egress-boundary.md) governs what
may leave the machine. Publish CODE in the repo (digest-public.py,
dispatch/newspaper trees) IS refused by the pre-check per the table
above.

## Carried question c4: cached green and the cure suite leg

Question: can `scripts/verify-candidate.py`'s cached-green marker
(lines ~142-178) skip the suite leg on a cure candidate, and is that
acceptable for a declaration-only cure?

Mechanism (scripts/verify-candidate.py:132-196, 345-364): the marker
file under `$TMPDIR/hngh-fasttest-<repo>-<sha256>.ok` keys on
`candidate_hash` (sha256 over each manifest entry name PLUS the
current bytes of the file, `candidate_hash` lines 122-135) plus the
sorted tracked porcelain of NON-candidate files. A cache hit requires
byte-identical candidate content and an unchanged surrounding tracked
tree; any real edit to the candidate cold-misses the cache and
`make test` runs (line 352). The short-circuit prints
`fast-test: passed (cached)` and skips only the suite leg — the
dependency/public-content/whitespace/relative-link checks always run
fresh.

Verdict: YES a cached green can skip the suite leg, but ONLY when the
candidate's content bytes are identical to a previously green run.
For a declaration-only cure this is exactly correct, not a hole: the
declaration-only cure's own diff is documentation prose (guard-table
exemption rows + decisions.md entry), which the suite does not
exercise either way; the suite green that MATTERS is the green over
the DECLARED commits' content, and the cache key cannot hit for those
unless their bytes are literally unchanged from a run that already
passed the full suite. A stale marker cannot validate new bytes: the
hash is over current bytes. Accepted as-is; no code change. (The one
theoretical residual — /tmp marker poisoning between runs on shared
machines — is an operator-environment concern, not a doctrine hole;
the marker carries the candidate-hash it certifies.)

## Carried question c3: does the ten-principle verdict mechanically refuse LARGE content?

Verdict: PARTIAL — deterministic but content-blind; it refuses only
on its own evidence-requirement inputs, not on diff shapes.

Code evidence:

- The ten principles are a closed vocabulary
  (src/domain/governance.lisp:19-21: `:closed-authority`,
  `:least-authority`, `:dependency-direction`, `:fail-closed`,
  `:evidence-before-claim`, `:atomic-mutation`, `:reversibility`,
  `:no-hidden-execution`, `:cost-and-route-discipline`,
  `:source-grounding`).
- `evaluate-policy-proposal` (governance.lisp:401-407) is a
  deterministic evaluation over the proposal's EVIDENCE REQUIREMENTS:
  a principle passes only when every required evidence fingerprint is
  present in the supplied evidence facts (%evaluate-matrix, lines
  ~360-393); the verdict is `:admitted` only when every
  principle-result is `:passed` (make-verdict-from-results, lines
  ~395-403).
- Nothing in the evaluator inspects paths, diff shapes, credential
  filenames, systemd units, spend parameters, deletions, or publish
  trees. LARGE refusal happens only if the PROPOSER declared evidence
  requirements that the supplied evidence fails to cover. A proposal
  that declares no requirements touching the LARGE content admits.
- The consumer enforces the verdict honestly:
  close-run.lisp:25-31 refuses unless `:admitted`; the mutation
  adapter validates verdict shape and binds certificates to verdict
  signatures (src/adapter/mutation.lisp:132-136, 225-249,
  297).
- ceremony-drive (scripts/ceremony-drive:6-13) runs propose ->
  issue-cert + mutation-check per action, and the push is a separate
  certificate-gated re-propose under `class=push-request`.

Conclusion: the ceremony verdict is a mechanical ADMISSION gate over
declared-evidence coverage, and its LARGE refusal is emergent — it
refuses LARGE content only when the proposal's own evidence structure
fails, not because the content is LARGE. This is precisely why the
automation-side path classifier (this pre-check) exists, and why its
coverage had to be complete: for path-shaped LARGE classes it is the
only mechanical guard, with the ceremony as the admission backstop
and the operator park as the terminal.

## Validation

- `cd automation && python3 -m unittest tests.test-patrol` — 48 tests
  OK (includes the new `test_large_cure_violation_real_repo_paths`:
  real path names asserted LARGE, real files asserted to EXIST,
  kernel-surface exception asserted, rename numstat forms asserted,
  real SMALL surfaces asserted SMALL).
- Full `make test` in automation/ (see ceremony commit below).

Commits: automation lane (classifier + tests + this record), then the
certificate-gated declaration of the git-history-cited commits.
