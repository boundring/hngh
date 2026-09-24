# 2026-09-23 — Attribution rewrite: all history authored to the operator identity

## Directive

> "Are we able to retroactively attribute all of Hngh's commits to my
> github profile?"
> "There's no co-author. It's just me. boundring@gmail.com."

GitHub links a commit to a profile when its author email matches a
verified address; the operator confirmed `boundring@gmail.com` is
verified.

## What was folded

Inventory before the rewrite (`git log --format='%an <%ae>' | sort | uniq -c`):

- 1059 `boundring <boundring@gmail.com>`
- 566 `Fixture <fixture@example.invalid>` (fixture/test identity in old history)
- 530 `hngh-machine <automation@hngh.local>` (machine lane; the repo-local
  config residue had also de-attributed operator session work to this pair)
- 1 `Cibo <cibo@localhost>`

2,156 commits total. `git log --format='%G?'` = 2156 `N`: no commit was
signed, so the rewrite dropped no signatures.

The forward fix landed first: the repo-local `user.name`/`user.email`
override was unset so new operator commits carry the verified identity.
The machine lane keeps its recorded identity seam — auto-committers pin
`-c user.name=hngh-machine -c user.email=automation@hngh.local` per
invocation (`automation/tests/test-identity-seam.py`), so machine ledger
syncs stay attributable to the machine, not the operator.

## The rewrite

- Safety bundle first: `~/.hngh-automation/scrub/pre-attribution-20260923.bundle`
  (55,389,902 bytes, all refs), alongside the pre-path-scrub bundle and
  the path-scrub rules file.
- `git filter-repo --force --name-callback 'return b"boundring"'`
  `--email-callback 'return b"boundring@gmail.com"' --refs refs/heads/main`
- Verified after: 2,156 commits, all `boundring <boundring@gmail.com>`;
  messages, trees, and author/committer timestamps unchanged (spot-checked
  old vs new); content untouched — every registered patch-id byte-identical
  (asserted with the loop-history guard's own `patch_id()` for all 29 of
  its declared targets: zero drift, authorship is not diff text).
- Consequences accepted: every hash re-keyed (the day's third rewrite,
  after the two path-scrub passes), so the loop-history guard's
  declarations went unreachable again and were re-declared through the
  certificate ceremony (candidate
  `0576d68352e0f62dea3a82427992178a956ea56cd0203cb61bf085f4e1339b9c`,
  commit `5e778946e124c9c9ec60fe6a4de681c9c84f4c1d`). `main` was
  force-pushed; the remote holds the rewritten history.

## Forensic lesson (recorded)

`.git/filter-repo/commit-map` is not per-run reliable after multiple
rewrites in one repository: it composites across runs (keys from earlier
runs' inputs, values from later runs' outputs), and a run's own input
hashes may exist only as another run's values. Match commits by content
instead: author timestamp + flattened-subject matching (`git log %s`),
with a first-six-words fallback for wrapped subjects, each pairing
asserted via `git diff-tree -p | git patch-id --stable`. Patch-ids
survive authorship rewrites; they change only when content bytes change
(the path-scrub's two registered drifts).
