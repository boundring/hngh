# omp-bridge — the Hngh-facing half of the oh-my-pi session bridge

**Date:** 2026-08-26
**Slice:** first concrete bridge between an omp (oh-my-pi) session and
Hngh — the Hngh-facing shell an omp plugin would call. This slice proves
the bridge exists and carries a session's actions through Hngh's own
governance, without rebuilding omp.

## Why

Roadmap Next #1 names "the worker-driver surface (the hngh-omp bridge
tools that run a disposable worker session through run-worker) — the
one-shot `scripts/worker-driver` cycle is done; the bridge-hosted
end-to-end session (run → worker → review → certify) is the open half".
This slice is the first seam of that half: give a session invoked through
Hngh (a) a project-state brief it does not have to rediscover, (b) a
certificate-gated commit path through `ceremony-drive`, and (c) a
registration line in the watchdog-visible handoff ledger so it is never
an invisible lane.

## Contracts

`scripts/omp-bridge` (python3, repo convention) exposes three read/one
write operations. It is an outer adapter: it only invokes the existing
`scripts/ceremony-drive` and the watchdog's own handoff ledger surface; it
never imports or mutates the hngh kernel, and records no side effect
beyond the ledger line it is explicitly asked to write. No daemon, no
scheduler.

- **`--orient`** — emit a one-shot project-state brief already ground from
  the repo: Queue Next (`docs/project/queue.md` `## Next`), Roadmap Next
  (`docs/project/roadmap.md` `## Next`), working-tree dirty check, and the
  last ceremony commit (latest `hngh: candidate` commit). The calling
  agent is handed this instead of re-walking the files.
- **`--register[=SESSION] [--note TEXT]`** — append one line to the SAME
  handoff ledger the roguelike watchdog
  (`hngh-automation/jobs/agent-watchdog.sh`) appends `session-drop` lines
  to, so the session is a governed, watchdog-visible lane. Ledger path
  overridable via `OMP_HANDOFF_LEDGER` / `HNGH_AUTOMATION_ROOT` (default:
  sibling `hngh-automation/agent-handoffs.md`).
- **`--ceremony OBJECTIVE FILE...`** — run `scripts/ceremony-drive`
  `--store=FRESH OBJECTIVE FILES` under a global non-blocking flock
  (`OMP_CEREMONY_LOCK`, default `/tmp/hngh-ceremony.lock`), a fresh
  ephemeral store, and a generous timeout — certificate-gated; most
  importantly `ceremony-drive` auto-pushes when origin exists.

Exit protocol (repo convention): 0 ok, 1 refused/conflict (lock held),
2 malformed input, 3 fault (missing ceremony-drive, ledger unwritable,
ceremony fault/timeout).

Path resolution respects `HNGH_BRIDGE_ROOT` (default = repo root from
`__file__`).

## Live evidence

Orientation against the live repo produced a real brief:
Queue Next `wake-mutation-lane`, Roadmap Next `(Next slice).`, working-tree
(dirty: the running dashboard/alert session's uncommitted report bodies),
and last ceremony commit `c27c4d7 … hngh: candidate 30697a3…`.

Registration against the live wizard watchdog ledger appended a real line:

    bridge-register | 2026-08-26T22:39:20Z | hngh|… | session-start: …

(see `hngh-automation/agent-handoffs.md`).

The ceremony contract was exercised for its own commit below.

## Files

- `scripts/omp-bridge` (new) — the bridge.
- This record, ceremony-committed in hngh.

## Next roadmap candidate

The plugin side of oh-my-pi that an omp session actually calls is the
operator's omp repo, not this one; wiring that side, and driving a
disposable run-worker end-to-end (run → worker → review → certify)
through the bridge, is the next auto slice once this seals the seam.