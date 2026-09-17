# 2026-09-17 Fixture containment: kernel .git/config contamination closed

## Forensics: which command wrote user.*=Fixture into the kernel .git/config

Incident: overnight lane
`automation/logs/overnight-2026-09-09-rehearsal-lane-20260913T000118.log.json`,
2026-09-13, session probing kernel-test behavior under a hostile
environment. It extracted a throwaway tree at /tmp/hngh-arch-test
(`git archive HEAD | tar -x`, HEAD then 3a14acb, 2026-09-13T04:03Z,
log L120) and ran kernel tests from there with
`GIT_DIR=/home/bricker/Projects/etc/hngh/.git` exported.

Verdict (high confidence): the first and only writer of
user.*=Fixture into the kernel .git/config is the L159 for-loop sweep
at 2026-09-13T04:04:02-04:04:06Z,

    for t in tests/scripts/test-*.py; do
      GIT_DIR=/home/bricker/Projects/etc/hngh/.git python3 "$t"; done

specifically its execution of `tests/scripts/test-verify-candidate.py`
`make_repository()` (then lines 37-43): bare `git init`, `git config
user.email fixture@example.invalid`, `git config user.name Fixture`,
`git add README.md Makefile`, `git commit -m fixture` run from a
fixture TemporaryDirectory. Under an exported GIT_DIR every one of
those writes resolves to the KERNEL repository (re-proven 2026-09-17
on this host: `git init` under GIT_DIR creates no target/.git; config
and commit land in the hostile repo).

What the log verbatim proves:

- L159 command text (the sweep with the hostile GIT_DIR) and its
  step_finish at 04:04:06.000Z (L160).
- Commit ba6b3905ca9346332cd45a15b190059f960a7680 "fixture" exists
  with parent 3a14acba (then kernel main HEAD), author `Fixture
  <fixture@example.invalid>`, author+commit date 2026-09-13
  04:04:04.565Z (git object metadata; shown verbatim in log L220).
- L195 output shows ba6b390 plus a staged `A Makefile / A README.md`
  while cwd is /tmp/vr-test; L220 shows ba6b390 diffing -422/+2 lines
  against the kernel README/Makefile (the fixture's one-line files
  replaced the real ones in the commit).
- L223 creates revert d2d8f515 (also authored by Fixture, inherited
  from the contaminated config); L238 pushes 3a14acb..d2d8f51 to
  origin main.

Inference (all corroborated, none contradictory):

- ba6b390's timestamp 04:04:04.565Z falls INSIDE the L159 sweep
  window (loop started after L158's 04:04:01.189Z step_start, finished
  04:04:06.000Z), so the sweep's own `git commit` created it.
  `test-verify-candidate.py` is the only fixture-identity writer in
  the 3a14acb tests/scripts tree (git grep over that tree: exactly one
  hit; test-ceremony-drive-* did not exist yet), so it is the writer
  beyond reasonable doubt.
- The later explicit commands L162/L165/L171/L174 (04:04:08-16Z,
  re-running test-omp-bridge/test-verify-candidate under the same
  hostile GIT_DIR) re-executed the same bare writes but were NOT the
  first writers: L171's traceback shows the fixture `git commit`
  already failing (rc=1) at 04:04:14Z, and L174 (04:04:16Z) succeeds
  only after setting the fixture cwd's own identity, printing `t@t`.
- L192 (04:04:26Z, clean-room reproduction in /tmp/vr-test with an
  explicit `GIT_DIR=... git commit`) is a separate later experiment;
  L195/L198's `git log` outputs are observations of the already-created
  ba6b390, not its creation. ba6b390 has exactly one parent (3a14acba)
  and one authoring instant, so L192 created no second commit.
- Side effect worth naming: because `git add` under hostile GIT_DIR
  still resolves RELATIVE paths against the fixture cwd, the sweep's
  commit replaced the kernel's README.md/Makefile content on the
  kernel index and committed that (the "gut" shape later classified by
  automation ad08254f). The lane detected, reverted (d2d8f515), and
  pushed the pair at L238.

Residue state today: kernel .git/config carries the pinned machine
identity (hngh-machine / automation@hngh.local) from the 2026-09-16
identity-seam reconciliation; no user.*=Fixture remains in the
kernel config; ba6b390/d2d8f515 remain reachable in main's history
(never rewritten, exempted via the loop-history guard's patch-id
mechanism).

Exposure class: LATENT (gate probes of the Sep 14-16 overnight lanes
found no recurrence of the hostile GIT_DIR pattern). Any session that
exports GIT_DIR at the kernel repo and runs the old test suite could
reproduce it silently.

## What changed

Kernel surface (tests/, landed via ceremony, `hngh: candidate <hash>`):

- tests/scripts/test-verify-candidate.py — make_repository() no
  longer writes `git config` anywhere: identity pinned per commit via
  `git -c user.email=... -c user.name=...`; the test process strips
  GIT_DIR/GIT_WORK_TREE at import and pins
  GIT_CONFIG_GLOBAL/GIT_CONFIG_SYSTEM to /dev/null; new loud guard
  `check_not_kernel_repo()` (asserted first in main(),
  test_repository_guard_refuses_kernel_checkout) refuses by name if
  the resolved repository is the hngh checkout.
- tests/scripts/test-ceremony-drive-dry-run.py,
  tests/scripts/test-ceremony-drive-commit-identity.py — same recipe
  (import-time env strip, /dev/null global/system config, commit-time
  `-c` identity pins, zero fixture `git config` writes); the
  commit-identity suite also keeps repo-selection vars out of the
  drive's child env.
- tests/scripts/test-loop-history-guard.py — every git read is pinned
  to the repository the script lives in (`--git-dir $KERNEL_GIT_DIR`,
  resolved with hostile env stripped in the probe itself), covering
  run(), reachable(), and the patch-id sink; a hostile GIT_DIR can no
  longer re-point the guard's reads or crash the gate.
- tests/scripts/test-loop-history-guard-safeguards.py — the
  commit-tree probe strips GIT_DIR/GIT_WORK_TREE so the probe object
  lands in the repo the guard reads.

Automation surface (free-commit lane, same exposure class sweep):

- automation/tests/test-history-feed.py — _git strips
  GIT_DIR/GIT_WORK_TREE (global/system /dev/null pinning already
  present).
- automation/tests/test-narrative-ledger.py — fixture `git init` and
  `git config` strip hostile env.
- automation/tests/test-dashboard-selfreview-ledger-skew.py — both
  fixture builders strip hostile env (commits already -c pinned).
- automation/tests/test-plan-identity.py — accept-plans child env
  strips hostile vars (fixture commits already -c pinned).
- automation/tests/test-rehearse-gate.py — git() helper strips
  hostile vars.
- automation/tests/test-candidate-hash-reconciliation.py,
  automation/tests/test-patrol.py — fixture env dicts strip hostile
  vars (already env-identity based).
- automation/tests/{test-bootstrap,test-dispatch,test-remote-push,
  test-research-blockers,test-research-commit-per-op,
  test-research-doc-writer-redact,test-research-review,
  test-research-tsv-path-sweep,test-review-ladder}.sh — `unset
  GIT_DIR GIT_WORK_TREE` after `set -u` (all already mktemp-sandboxed;
  this closes the inherited-env leg).

Already clean (verified, no change): scripts/ceremony-drive pins
GIT_AUTHOR_*/GIT_COMMITTER_* defaults (2026-09-16 identity-seam
reconciliation); automation/tests/test-identity-seam.py keeps
enforcing per-invocation pinning; kernel .git/config identity.

## Acceptance (2026-09-17)

Canary acceptance: fresh throwaway repo with an explicit protected
[user] section (email=canary@watch, name=Canary) recorded before the
run; full kernel gate `make test` executed with
`GIT_DIR=<canary>/.git` exported. Result: gate exit 0 (all python
suites green + 2931 lisp checks), canary .git/config byte-identical
after (cmp), canary still exactly 1 commit (base), author set
unchanged (`Canary canary@watch`), zero fixture entries in the canary
reflog. Clean-env `make test` re-run after the edits: green. The
hardened verify-candidate suite alone also passes under
GIT_DIR=<kernel>/.git (78 checks).

## Ceremony note

tests/ is kernel surface per AGENTS.md: the five kernel test-file
changes are committed only through the ceremony loop
(scripts/omp-bridge --ceremony -> ceremony-drive -> certificate-bound
commit) with the `hngh: candidate <hash>` label. The automation/
test changes are a free-commit behind a green `cd automation &&
make test`. This record closes the vector that wrote Fixture into the
kernel .git/config; the config repair itself was the 2026-09-16
identity-seam reconciliation.
