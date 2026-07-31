# Mission Control

One command opens a tiled tmux session that watches the whole agentic stack:
the services dashboard, the hngh daemon, the task-queue watcher, and the
event journal — plus free panes for summoning agents. Scrollable, auto-tiling,
attach or detach at will.

## Start

```sh
mc                        # attach (starts the session if needed)
mc start                  # create the session detached
tmux attach -t hngh-mc    # same thing, directly
```

KDE: **"Hngh Mission Control"** in the Application Launcher
(`~/.local/share/applications/hngh-mc.desktop`). The session also autostarts
at graphical login via `~/.config/autostart/hngh-mc.desktop` — delete that
file to make it on-demand only.

## Panes (default layout)

| Pane | Content |
|---|---|
| 0 | **svc-dash** — services dashboard (systemd units, port probes, sparklines) |
| 1 | **event journal** — tail of `~/.hngh/journal/events/<today>.lisp` |
| 2 | **hngh daemon** — `make run` in the hngh repo; the event loop logging live |
| 3 | **status watch** — `watch -n2 hngh-status` (queue table + latest events + process check) |

New panes tile automatically (`tiled` layout after every `mc add`). Scrollback
is per-pane (tmux `Ctrl-b [` to enter copy mode).

## Summoning agents

```sh
mc add 'agent-call hermes "review the last commit" "unsloth/gemma-4-12b-it-qat-GGUF"'
mc add 'opencode'          # interactive opencode pane
mc add 'hermes chat'       # interactive hermes pane
```

Every `agent-call` logs one line to OptMem (`~/.optmem/memo recall agent-call`).

## Reading progress

- **Queue**: `hngh-status` (or the watch pane) — id, status, task per entry.
- **Results**: `~/.hngh/tasks/queue.lisp` (s-expressions), `~/.hngh/agents/<id>/transcript.lisp`.
- **Daemon log**: the daemon pane (scrollable).

## Operations

```sh
mc status        # list panes
mc add "<cmd>"   # new tiled pane running cmd (re-tiles after)
mc stop          # kill the session
```

If the daemon pane dies or runs stale code:
`mc add "cd ~/Projects/etc/hngh && make run"` starts a fresh one; kill the old
pane manually. (Learned the hard way, 2026-07-31: `C-c` without a follow-up
`make run` leaves the pane dead — and check your status scripts are executable.)

## Conventions

- Top-level sessions only run `~/.optmem/memo`; subagents never do.
- Per-model attribution: queue entries and transcripts record tool and model
  for every task (`:local-openai-api` = unsloth local, $0; `:opencode` =
  opencode CLI, pinned to the free local 12b by default).
