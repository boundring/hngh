# 2026-08-01 — Resume: researched queue and safe local delegation

## State

- Config reroute and original queue are recorded in:
  - `journal/20260801-day-model-reroute.md`
  - `journal/20260801-day-tasks-queue.md`
- Do not touch existing uncommitted work: `docs/design/hngh-design-spec.md`, `.omc/`, `.omo/`, `build/`, or the existing `journal/` directory contents.
- Hermes restart is still required to activate the Terra main-model and 120-second request timeout changes.
- OpenCode 1.18.8 is available and authenticated. Ollama is up. The unsloth endpoint returned HTTP 401 without credentials, so do not claim it is unavailable.
- OpenRouter lifetime usage measured at `$562.56`; no launch happened from this session.

## Verified source snapshots

- MisakaNet: git-backed, redacted failure-memory library; 249 indexed recovery lessons; optional MCP/CLI/capture.
- ponytail-improved: minimal-solution ladder with an explicit safety exception for validation, error handling, security, and accessibility.
- hermes-bus: JSON over Unix socket transport with sessions and heartbeats; companion plugin supports context injection and command execution.
- agentburn: local read-only cost profiler; measures spend by source and accounting gaps.
- OpenWorker: approval-gated local-first desktop agent with schedules and an approval inbox.

## New local text-out tasks staged

`~/.hngh-night/tasks/11-research-misakanet.txt`
`~/.hngh-night/tasks/12-research-ponytail.txt`
`~/.hngh-night/tasks/13-research-bus-openworker.txt`
`~/.hngh-night/tasks/14-research-agentburn.txt`

Each is source-grounded, 110–125 words of input, has no repository writes, and requires the attribution line. `night-ralph` will process a maximum of 12 tasks in lexical order. Existing tasks `00`–`10` therefore consume the current cap; run these four deliberately after reviewing or moving completed prior tasks. Use `night-ralph --dry` first, then start it as a managed process if approved.

## Important constraints

- Local work is text-out only. Review artifacts before promotion.
- No install or config changes were made for external projects.
- Need a human decision before adopting any external package, bus protocol, MCP server, lifecycle hook, or cost profiler.
- The M7 draft favors length-prefixed S-expressions over Unix sockets, later TCP. hermes-bus is a comparison point, not an adoption decision.
- Current M8 artifact is too thin and uses obsolete route names; resolve against `docs/design/model-routing.md` and the reroute journal before changing it.

## Next low-risk steps

1. Review the four generated research artifacts.
2. Turn accepted findings into a single, bounded design/ADR task.
3. Re-run hngh verification after any code change: `make test`.
4. Use OptMem only for a short cross-session signpost; journals remain the payload.

## Daemon and day-task staging update

- `hngh-system.service` remains intentionally **not installed**. The root daemon's current package shell command, direct root writes, hard-coded snapshot path, missing helpers, and mismatched D-Bus policy make it unsafe to deploy.
- Mission Control now has a fifth, read-only maintenance pane. It watches pacman-lock state, update and kernel-update counts, pacnew/pacsave count, and `hngh-status` every 30 seconds.
- Fresh build smoke passed in a temporary stage directory, but the checked-in user systemd unit remains non-deployable: `/usr/local/bin/hngh` is absent and `--stop` is unsupported.
- Planned implementation is split into:
  - `.hermes/plans/2026-08-01_135346-day-ralph-maintenance-coordination.md`
  - `.hermes/plans/2026-08-01_141000-privileged-daemon-staging.md`
- Six bounded day-task prompts are staged under `~/.hngh-day/tasks/`. They are text-out only, 90–110 words each, and must not enter the live queue until authority, lease, pause, and maintenance gating are implemented.
- Four follow-on design prompts are staged as tasks 07–10. They convert reviewed Day-Ralph conclusions into an ADR draft, a Sentry Tier-1 fixture matrix, M8 route-table data requirements, and a gbd/Hngh adapter contract. Further roadmap research should be added as small, source-grounded prompts rather than packed into a long-lived agent context.

## Verification

- `make test`: Pass 980, Fail 0, Skip 0.
- Live Hngh queue remains unchanged: 0 queued, 0 running, 4 done, 2 failed.
