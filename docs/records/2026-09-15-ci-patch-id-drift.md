# 2026-09-15 - CI-only patch-id drift on the 526cd3f exemption

## Scope

Diagnosis of the GitHub Actions `test` job failure
("registered patch-id drift for 526cd3f") first flagged by
`patrol:github-ci` on 2026-09-15. Local kernel `make test` is green,
including the exact CI recipe (scratch HOME + seeded
`.github/fixtures/ci-store/run-1` + `HNGH_CI=1`, verified 2026-09-15).

## Finding

- The standing exemption table `KNOWN_EXEMPTIONS` in
  `tests/scripts/test-loop-history-guard.py` registers patch-id
  `5b6840dfb796a0baeb4a7193a134a94b8b0ebf36` for `526cd3f`
  ("docs: portfolio surface", 2026-09-06).
- That commit carries `docs/publication/hngh-memoir.epub`, a binary
  blob. `git show <sha> | git patch-id --stable` hashes the rendered
  diff text, and binary diffs render as base85 "GIT binary patch"
  hunks whose encoded bytes depend on the git build (zlib compression
  defaults and binary-delta encoding, not the file content).
- Local git 2.55.0 reproduces the registered value exactly. GitHub
  Actions runners ship a newer git whose binary-hunk encoding differs,
  so `patch_id_of("526cd3f")` returns a different hash only on CI and
  the safeguard assertion fails there.
- The exemption registry is not wrong; the hash input is
  environment-unstable for commits that touch binary files.

## Cure options (operator/ceremony lane)

1. Preferred: make the guard's `patch_id_of` use
   `git diff-tree -p --no-binary <sha>` piped to `git patch-id
   --stable`, so binary content never enters the hash. Deterministic
   across git builds. Requires re-registering every current patch-id
   computed under the old recipe (a one-pass gate-cure), and a guard
   test update. Kernel `tests/` surface: certificate-bound ceremony.
2. Alternative: pin the runner's git version to match the authoring
   build. Fragile; rejected as a long-term cure.
3. Stopgap: none needed - the failure is CI-cosmetic (local gate
   green); the patrol alert remains open until the ceremony lands.

## Evidence

- CI job log (run 34973375975, step "Test local kernel"):
  `AssertionError: registered patch-id drift for 526cd3f`.
- Local repro script `.agent-scratch/ci-repro/run-repro.sh` (scratch
  copy, not committed): exact CI env, rc=0.
- `git show 526cd3f --stat` shows the epub binary;
  `git show 526cd3f | git patch-id --stable` locally returns the
  registered `5b6840df...` on git 2.55.0.

## Disposition

Parked with cause for the operator: cure is a kernel-test change and
must go through the ceremony (propose -> issue-cert -> mutation-check).
No kernel code or tests were modified in producing this record.

## Correction (2026-09-15, same day)

The "newer runner git build" mechanism above is falsified: the runner log
shows git 2.55.0, identical to local. The verified mechanism:

1. `git patch-id` ignores abbreviated `index` lines for text-only diffs:
   commit `915e0e3` renders differently across repos (7- vs 8-hex index
   lines) yet yields the identical patch-id, and neutralizing its index
   lines does not change the hash.
2. For a diff containing a binary-file section, the index lines ARE part
   of the hashed input: neutralizing them changes `526cd3f`'s patch-id.
3. The abbreviations come from `core.abbrev=auto`, whose length is an
   object-count heuristic: this long-lived repo renders 8-hex; a fresh
   init+fetch (the CI checkout recipe, and an exact local repro) renders
   7-hex. Same blobs, same git, different hash.
4. Pinning abbreviations (`core.abbrev=40` / `--full-index`) makes the
   id deterministic but different from the registered values - so the
   cure necessarily includes a one-pass re-registration of every
   KNOWN_EXEMPTIONS patch-id under the pinned recipe, in addition to
   making `patch_id_of` hermetic (e.g. `git diff-tree -p --full-index
   <sha> | git patch-id --stable`, which also sidesteps `git show`
   config surface).

Discriminating repro (local, git 2.55.0 both sides): fresh clone passes;
init+fetch with `+refs/heads/*` fails with the CI assertion. The drift
is repo-state-dependent abbreviation, not git-build encoding.
