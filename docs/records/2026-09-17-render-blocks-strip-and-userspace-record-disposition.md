# 2026-09-17 — dangling-object disposition: render-blocks strip + userspace-home record

Pre-gc sweep of the two sole-copy objects flagged by wip-family-census /
stash-internal-content (both unreachable, both gc-exposed until the
operator's next gc either way — this slice removes their uniqueness, not
their existence):

- `91ab48ca` — dangling autostash commit (2026-09-16 18:20)
- `13ac26f9` — dangling untracked-files commit (2026-09-14 18:06)

## Item 1: render-blocks consumer strip (`91ab48ca`) — LANDED, p0-safe

The autostash carried the only surviving copy of the sessions-view.js
consumer strip (.sv-rb classes, `initRenderBlocks`, fetch of
`render-blocks.json`) for the producer slice already on main
(`automation/jcode/render-blocks.mjs`,
`automation/jobs/render-blocks-feed.py`, worker.mjs fd3 passthrough,
`tests/test-render-blocks-feed.py` in `make test`). It had been
quarantined because its raw `window.setInterval(load, 60000)` fails
`tests/test-dashboard-p0.py` (`PollHygiene.test_every_view_timer_
goes_through_the_helper`: sessions-view.js must have NO `setInterval(`
and route every timer through `HnghPoll.start(fetch, ...)`;
docs/records/2026-09-16-token-file-0600-gates.md, Gate section).

The strip had already been restored to the working tree with the
interval line adapted to the shared helper — this slice verified it
against the autostash copy and hardened it:

- Verbatim export (a): full autostash file extracted to
  `.scratch/91ab48ca-sessions-view.js` (untracked scratch, superseded
  by this landing); the only delta vs the working tree at slice start
  was the single interval line (autostash: raw `setInterval`; tree:
  `HnghPoll.start(load, { interval: 60000 })`).
- p0-safety (b): the 60s feed cadence rides `window.HnghPoll` (app.js:
  pause-while-hidden via visibilitychange, exponential backoff capped
  at 60s) — same contract graph-view's `POLL_MS = 60000` lane already
  satisfies. Added on top: named `RB_POLL_MS` constant and an `rbPoll`
  idempotence guard so a second `init()` cannot stack a second poll.
- Proof (c): `python3 automation/tests/test-dashboard-p0.py` green —
  22 tests, 0 failures, 0 skips, `PollHygiene` and the node-executed
  groups (`GraphTwoShellLayout`, `GraphCameraPreserve`) all ok with
  node v26.8.2 present.

## Item 2: userspace-home record (`13ac26f9`) — DELETE as superseded

The untracked `docs/records/2026-09-13-userspace-home.md` was verified
byte-identical to the copy inside `13ac26f9` (git cat-file diff: empty).
Cheaper correct option = delete: its substance is fully mirrored on
main — AGENTS.md (current-boundary userspace paragraph), docs/README.md
"Userspace data home (`~/.hngh`)" section, automation/README.md (layout
+ two-home split), `.omp/skills/hngh/SKILL.md` "Userspace data home"
section — and the migration evidence it cites lives in catalog rows and
CHANGELOG.md:363, not in the file. The record had no standalone value
beyond the mirrors (its verification list described a past gate lane's
run). Deleted without replacement; this note is the tombstone.

## Gate

`cd automation && make test` full gate green on the tree carrying this
slice (sessions-view.js strip + this record). Working tree also carries
foreign in-flight lanes (dash-mangled-id scrub seams CHANGELOG entry,
33-research-beat, accept-plans.py, causes.sh, scrub.* etc.) whose
content this slice does not touch; the shared tree was already green
with the strip present before this slice's hardening edits.

## Residue

`91ab48ca` and `13ac26f9` remain unreachable objects; nothing in this
repo references them anymore, so the operator's next `git gc` may prune
them without data loss.
