# Heartbeat service — systemd user timer & cron specification

`scripts/schedule-heartbeat` is a scheduler **tick**, not a scheduler.
The no-daemon boundary is kept by putting the *period* outside the
repo: your cron or your systemd user timer invokes one tick per fire;
the script never backgrounds itself, mounts no watcher, and starts no
process of its own beyond the closed driver it triggers.

Both configurations below are operator-owned examples — nothing in the
repository installs, enables, or schedules them. Copy, adjust the repo
path, and enable with your own systemd timer or crontab entry.

## What one tick does

1. Reads the queue ledger, selects the `Next` item, and checks whether
   a closed action card is mounted under `docs/project/heartbeat/`
   (`<id>.rotation` → rotate-queue governance; `<id>.worker` → bounded
   worker-driver cycle).
2. Probes preconditions: working tree, model route (route probe over
   the operator reviewer transports), origin network reachability, and
   the audio-intensity level.
3. Triggers the mounted driver from a fresh ephemeral
   `/tmp/hngh-heartbeat-*` store when eligible; an unreachable or
   missing reviewer route logs a non-fatal `unverifiable-review` fact
   and skips the rotation (it never blocks on the model).
4. Records a dated heartbeat entry — checkin.md entry plus a
   machine-readable timeline row — whose SHA-256 is verified by
   re-reading the written bytes, then commits the two ledger docs as
   one plain docs commit.

Exit codes: 0 tick complete; 1 tick complete with a reported condition
(postponed tree, unverifiable route, refused driver); 2 malformed
ledger/card; 3 telemetry or commit fault.

## Crontab one-liner (every 3 hours)

```
0 */3 * * * cd ~/Projects/etc/hngh && python3 scripts/schedule-heartbeat --route=auto >> /tmp/hngh-heartbeat.log 2>&1
```

Cron runs the entry with a minimal environment: `SHELL=/bin/sh`, a
bare `PATH` (Debian default `/usr/bin:/bin`), and no login-shell rc
files. The one-liner above survives that default only because
`python3` and `git` live in `/usr/bin`; if your toolchain lives
elsewhere (e.g. `/usr/local/bin`, a version manager, or a non-default
`sbcl` for `scripts/rotate-queue`), add explicit env lines at the top
of the crontab instead of relying on the login environment:

```
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
```

`HOME` is set by cron, so `~/.hngh-automation` reviewer configs and
the repo path resolve normally. The systemd user timer has the same
constraint in a different form: the service unit inherits systemd's
default user environment, not your login shell's — add
`Environment=PATH=...` to the unit if the default `PATH` misses your
toolchain.

### Already-running tmux/screen sessions do not pick up env or rc changes

If you test or run a tick from inside tmux or screen, know that
already-running multiplexer sessions keep what they were started
with: a tmux server holds the environment captured at server start
(inspect with `tmux show-environment -g`) and keeps its config until
re-sourced; running panes keep the env they were launched with. After
changing your rc files or `~/.tmux.conf`, re-source per session
(`tmux source-file ~/.tmux.conf`; inside screen, `source ~/.screenrc`),
respawn the pane you will run the tick from
(`tmux respawn-pane -k -t <session>:<window>.<pane>`), or restart the
multiplexer server when convenient. "Works in a fresh terminal, fails
in the operator's long-lived tmux pane" is this gap, not a heartbeat
bug — the same stale-startup-runtime class documented for the jcode
server in docs/records/2026-09-14-visible-spawn-flash-die.md.

## systemd user timer unit (systemd ≥ 252)

User timer units pair a `*.timer` unit (the schedule) with a
`*.service` unit of the same name (the action). Place:

```
~/.config/systemd/timer/hngh.timer
~/.config/systemd/timer/hngh.service
```

`hngh.timer`:

```ini
[Unit]
Description=hngh autonomous heartbeat (every 3 hours)

[Timer]
Interval=3h
Persistent=true
```

`hngh.service`:

```ini
[Unit]
Description=hngh autonomous heartbeat tick

[Service]
WorkingDirectory=<REPO_ROOT>  (the clone's absolute path, e.g. under ~/Projects)
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 scripts/schedule-heartbeat --route=auto
LogFile=/tmp/hngh-heartbeat.log
LogLevel=err

[Enable]
Enabled=true
```

`Interval=3h` means one tick every three hours, persistent across
reboots. To run a tick now, `systemctl --user start hngh}; stopping it
later (`systemctl --user stop hngh`) leaves the next interval bound.

Alternative equivalent: a user timer at the same path with
`Date=+%Y-%m-%dT%H:%M:%SZ` plus `Interval` for the recurring window.
All configuration is operator-side; the repository only guarantees the
tick contract the unit invokes.

## Behavior notes

- A tick on a dirty working tree is **postponed**, never
  interleaved: it refuses to write telemetry or commit while the
  operator has uncommitted work, and reports exit 1. Commit the open
  work, then the next period fires clean.
- When the queue's `Next` has no card mounted, the tick records its
  probes and takes no action — cadence without busywork.
- Rotations triggered by the heartbeat run the full governance loop with
  their own fresh store: real evidence → real model review →
  ten-principle verdict → certificate → candidate commit.

## Verification

```
python3 scripts/schedule-heartbeat --dry-run     # probe + decision, no mutation
```

While a real tick's telemetry lands in `docs/project/checkin.md` and
`docs/project/timeline.md` (the `heartbeat-N` event rows), dry-run
prints exactly what it would do and creates nothing.