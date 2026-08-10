# Workspace-root migration

Status: READY — v3, operator-directed 2026-08-10. Supersedes v2's flattened layout.

## Decision

Preserve both workbench trees intact under Hngh's canonical state root:

```text
~/.hngh-night/  -> ~/.hngh/.hngh-night/
~/.hngh-day/    -> ~/.hngh/.hngh-day/
```

After each atomic move, the old root becomes a compatibility symlink to the
new target. Internal paths do not change. A consumer using
`~/.hngh-night/tandem-cibo/inbox.md` therefore keeps working during the
referencer migration.

Do not flatten workbench files into `~/.hngh/tasks`, `sessions`, `artifacts`,
or other existing state directories. The workbenches and Hngh's runtime state
have different contracts; merging them creates collision and rollback risk.
The earlier flattened mapping is retained only as superseded history in git.

## Scope

This wave moves data and installs compatibility links. It does not redesign
the queue, archive old artifacts, rename lane files, or prune workbench
content. Those are separate reviewed waves.

Current inventory includes active task/artifact/lane trees under night and a
smaller day queue/artifact tree. Empty directories and old artifacts move with
their parent; no per-file classification occurs during migration.

## Safety contract

The migration script is `scripts/hngh-workspace-migrate.sh` (card 125).

- `--home PATH` makes every test hermetic; default is `$HOME`.
- `--check` is read-only.
- `--migrate` uses same-filesystem rename only. No copy/delete fallback.
- The canonical `~/.hngh` root must already exist.
- An existing destination, unexpected symlink, conflicting source, or partial
  state that cannot be proven safe fails before mutation.
- Correctly migrated state is idempotent.
- `--rollback` works only when each old root is the expected compatibility
  symlink and no conflicting source exists.
- Representative lane and artifact bytes must survive a scratch-HOME
  migrate/rollback round trip.

Killy alone runs the live migration after Cibo's implementation and an
independent review. Cibo must not mutate the live home from its task.

## Execution sequence

1. Build and pass the scratch-HOME fixture.
2. Review the script for fail-closed preflight, atomicity, idempotence, and
   rollback.
3. Ensure active seats are at a phase boundary. A lane may move only between
   turns, never while a seat is writing it.
4. Pause the user watcher briefly so it cannot observe the rename/link gap.
5. Run `--check`, then `--migrate` once against the real home.
6. Verify both new roots directly and both old roots through exact symlinks.
7. Restart the watcher and verify `ActiveState=active`, a new `MainPID`, and
   `ExecMainStatus=0`.
8. Verify each seat can read and append through the old compatibility path and
   the new direct path.
9. Record the backup-manager state wave. Do not remove the compatibility links.

If a gate fails, run no later step. Use `--rollback` only after inspecting the
reported state; never improvise file moves.

## Follow-up: one work-root seam

Compatibility links make the move safe; they are not the final interface.
Introduce a work-root getter distinct from Hngh's runtime-state root:

```text
HNGH_WORK_ROOT
  env override
  -> config
  -> ~/.hngh/.hngh-night/
```

Consumers include the dashboard, coordinator lanes, watcher, seat tools,
squad configuration, and task/artifact helpers. Day-Ralph uses an explicit
`HNGH_DAY_ROOT`, defaulting to `~/.hngh/.hngh-day/`.

After all live consumers use these seams, a referencer sweep may remove direct
old-root literals from active code and configuration. Historical journals and
migration docs keep old paths as facts. Compatibility symlink retirement is a
later operator decision, not part of this wave.

## Acceptance

- Scratch-HOME fixture covers check, migrate, idempotence, refusal cases, and
  rollback.
- `~/.hngh/.hngh-night/` and `~/.hngh/.hngh-day/` contain the complete source
  trees after the live wave.
- `~/.hngh-night` and `~/.hngh-day` are exact symlinks to those targets.
- Watcher and lane reads work after migration.
- No data is flattened, merged, pruned, or overwritten.
- Rollback remains available while compatibility links remain.

Attribution: operator direction; Killy design authority; Cibo implementation;
K3 artifact 95 priority signal. 2026-08-10.
