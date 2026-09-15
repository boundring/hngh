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
