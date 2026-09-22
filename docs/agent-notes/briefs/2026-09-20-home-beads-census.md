# 2026-09-20 home-beads census (`~/.beads`) — global-home-beads-census::seed-524046b0

Read-only census. Nothing in `~/.beads` was deleted or modified except bd's own
telemetry appends (`eventsData/*.evtq`), which happen on every `bd` invocation.

## What `~/.beads` is

- Real, live beads store at `~/.beads` (bd 1.3.0, dolt-embedded).
  `metadata.json`: `dolt_database: tmp_CJynXp14cN`, `project_id 81c26f01-4c95-…`.
  Repo store `.beads/metadata.json` is `dolt_database: hngh`,
  `project_id c2736f9d-a9b4-…` — two distinct stores, resolved by cwd.
- Created Sep 18 16:37 (machine-id), config Sep 18 18:53. **Not a git repo**
  (`git rev-parse` fails) → no `refs/dolt/data` sync, `bd dolt push` has no
  remote. Anything written here never leaves this machine.
- `config.yaml` is the pristine bd template (no custom keys set).

## Census results

- `bd status` FROM `~/.beads`: **11 issues, 11 open, 0 closed, 0 in progress**.
- All 11 are session test/probe writes, ids prefixed `tmp_CJynXp14cN-`
  (prefix follows the auto-generated db name): 2× P0 "brand new content"
  (`9mb`, `zj4`), "probe" (`3gm`, `nxe`), "child-probe" (`e8a`),
  "scratch audit issue" (`fim`, `xfe`), "probe issue" (`oc7`, `r1z`),
  "resurrect-test-issue" (`t21`), "lease test" (`zqj`).
  Created 2026-09-18 by `boundring`; sampled issues (`9mb`, `t21`) carry no
  deps/labels/description.
- `last-touched` = `tmp_CJynXp14cN-r1z`, Sep 19 22:16 — issue-level writes
  continued into Sep 19.
- `embeddeddolt/` holds TWO database dirs:
  - `tmp_CJynXp14cN/` — the live one.
  - `hngh/` — **in-progress, half-materialized** (`.dolt` only, zero branches,
    `repo_state.json` has remote `origin` =
    `git+ssh://git@github.com/boundring/hngh.git`, Sep 18 18:38). bd warns
    `skipping in-progress database directory …/embeddeddolt/hngh` on every
    command. A `bd dolt` sync attempt against the real hngh remote was run
    from the wrong cwd and left this debris in the home store.

## Footgun, verified empirically

- `bd count` from `$HOME` → 11 (home store); from repo cwd → 56 (repo store:
  56 total / 17 open / 39 closed). `bd` resolves the store purely from cwd;
  any session that runs `bd` outside a `.beads`-bearing repo silently reads
  and writes `~/.beads`.
- The 11 issues ARE absorbed session writes (probe/lease/scratch titles,
  created Sep 18–19 by sessions, none matching legitimate hngh work).
- Telemetry side channel: every `bd` invocation appends
  `~/.beads/eventsData/*.evtq` **regardless of which store is used** (fresh
  `.evtq` files at 11:15/11:17/11:19 today, from multiple sessions plus this
  census). That channel is telemetry, not issue data.

## Could it be mistaken for the hngh store?

Yes, maximally: a half-materialized `hngh` database dir with the real hngh
remote configured, hngh-adjacent probe titles, same bd binary, and cwd-based
resolution. It is NOT the hngh store: different `project_id`, no git repo, no
synced history. Anything created here is stranded.

## Documented rule

Appended "Beads cwd guard (2026-09-20)" to
`docs/agent-notes/jcode-orientation.md` (standing-rules section, auto-included
via AGENTS.md): run `bd` only from a cwd whose git root contains `.beads`,
refuse otherwise, optional `~/.bashrc` guard function. Deletion/quarantine of
`~/.beads` is left to the operator (destructive).

## Not done here (candidate follow-up nodes)

- Salvage audit: do any of the 11 absorbed issues carry content worth
  exporting into the repo store (`bd export` from the home store)?
- Quarantine/archive decision for `~/.beads` (operator-owned).
- Verify whether a `BD_*`/`BEADS_DB` env pin exists in bd 1.3.0 as an
  alternative to the shell guard (config.yaml documents a `BD_*` env prefix;
  specific var not verified).
- Repo-store count drift vs `.beads/issues.jsonl` export not cross-checked.