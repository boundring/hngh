# 2026-09-14 — Visible-spawn workers flash-die: root cause and fix

Operator observation: "Konsole windows popping up and dying
immediately" during the deep-graph run_plan fanout.

## Root cause (verified by reproduction)

Visible swarm workers run `jcode self-dev` in a terminal window. That
command launches the self-dev TUI, which **requires a real PTY**:

    Error: jcode TUI requires an interactive terminal
    (stdin/stdout must be a TTY)

When the worker's child process is wrapped non-interactively (as the
run_plan driver's spawn path did), the TUI exits instantly, Konsole
closes with it, and the worker never persists a session file —
matching the log evidence exactly: workers recorded
`spawned → queued` transitions and zero further events, no session
JSON on disk. Confirmed by capturing the child's stderr through a
`bash -c` wrapper (reproduces the error) versus direct `konsole -e
jcode self-dev` (works, TUI runs, session persists).

Secondary finding: cancelling a run_plan driver also killed its
workers' process group — the first batch's windows all vanished at
the moment of `bg cancel`.

## Fix landed

1. **tmux spawn router** (`~/bin/jcode-spawn-router`): routes all
   headed spawns into a persistent `hngh-swarm-view` tmux session,
   one window per agent, named by session id. tmux allocates a real
   PTY, so the TUI runs; and windows survive driver cancellation
   because tmux owns the process group.
2. **Config** (`~/.jcode/config.toml`):
   - `[terminal] spawn_hook = "~/bin/jcode-spawn-router"`
   - `swarm_spawn_mode = "visible"` (kept — observation was the goal)
3. Live-verified: a manually routed `jcode self-dev` runs indefinitely
   inside its tmux window (`hngh-swarm-view:agent:<id>`).

## Outstanding

The **running jcode server** captured its config at startup and has
not picked up the new `spawn_hook`; graph workers spawned before a
server restart will still flash-die. Fixing it requires restarting
the shared server (`jcode server stop`; it relaunches on next client
connect). That is an operator action — it drops this session's
connection and every running swarm — so it is parked with the
operator rather than executed unilaterally.
