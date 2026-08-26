# Post-ceremony push (push self-sufficiency)

Date: 2026-08-26

## Slice

Implement the hngh half of push self-sufficiency: after a successful
ceremony commit, `scripts/ceremony-drive` drives a certificate-gated
push so the committed slice reaches `origin` without a manual push.

## Change

`scripts/ceremony-drive`:

- `propose-argv` now takes a proposal `class` argument (default used
  for the feature proposal; `push-request` for the push proposal) so a
  single constructor covers both the commit-verdict and the push-verdict.
- `origin-present-p` reads `git remote get-url origin` and returns true
  only when it succeeds — the push gate.
- After the `commit` step completes successfully, `drive-loop` re-proposes
  under `class=push-request` into a fresh verdict file, then runs
  `issue-cert push run-1 <verdict> <files...>` and
  `mutation-check push run-1 <verdict> <files...>`, mirroring the
  prepare/commit gates. The push certificate validates because a commit
  does not change the candidate content hashes the certificate binds.
- When no `origin` remote exists, the push step skips cleanly (message,
  exit 0). It is a deliberate post-ceremony step inside `ceremony-drive`
  — not a git hook — so a half-ceremony is never pushed.

The kernel-side `:push` closed action, `command-for` (`git push origin
HEAD`), the `:push-request` admitted proposal class, and the real
mutation-check/issue-cert pipelines all already existed; this slice only
adds the driver that invokes them.

## Verification

- `make test` green (2774 lisp checks plus the python script suites).
- Live ceremony: this slice's own commit ran through the ceremony loop
  from a fresh `/tmp/hngh-cer-*` store (`mkdir -p` first), wrapped in
  `flock /tmp/hngh-ceremony.lock`, and — because the repo has an
  `origin` — the post-commit push step pushed the committed slice to
  `origin` without any manual `git push`. The commit is visible on
  `origin` as a result of this slice's own execution.