# 2026-08-26 — Continual scheduling, dashboards, publications, fleet

## Scope

One milestone that turns the operator's cadence from hand-invoked to
scheduled: a machine-level heartbeat pipeline, dynamic model routing,
live/exportable dashboards, a publication pipeline, and device-fleet
discovery — all inside the no-daemon boundary (every period lives in
operator cron/systemd; no script backgrounds itself).

## What landed

1. **schedule-heartbeat** (`scripts/schedule-heartbeat`): one
   single-tick scheduler entrypoint. Reads the queue ledger + Next
   item, checks the mounted action card
   (`docs/project/heartbeat/<id>.rotation|.worker`), probes the
   working tree, the model route, network reachability, and audio
   level, then triggers the mounted driver from a fresh ephemeral
   `/tmp/hngh-heartbeat-*` store and records a dated heartbeat entry
   (checkin.md + a `heartbeat-N` timeline row) whose SHA-256 is
   verified by re-reading the written bytes, committing the two ledger
   docs. `--dry-run` is the plan's verification (probe only, no
   mutation); `--loop N` re-ticks in the foreground.
2. **probe-model-route** (`scripts/probe-model-route`): the closed
   route vocabulary (`auto|local|remote`) resolved by one bounded
   authenticated probe of the operator reviewer-transport files. Any
   HTTP answer means reachable; missing configs resolve `none` (exit
   1) offline.
3. **Driver routing**: `rotate-queue --route=` resolves the reviewer
   transport by probe (no `--reviewer` file needed) with the loadout
   route label following the choice; `worker-driver --route=` names
   the session compute family. Both keep the established exit-code
   contract (2 malformed, 1 bare-cycle refusal).
4. **Dashboard live/export** (`scripts/dashboard-readout`): `--watch`
   / `--live` TUI refresh, `--json` spine, `--export-html`, and a live
   session read from the operator store rendered through
   `scripts/hngh present` (bounded, non-fatal, TTL-cached in watch).
5. **generate-publication**: `--daily`/`--check` (machine journals
   compiled from the verified git/checkin/timeline record; operator
   journals are never overwritten), `--ebook` (book.md + stdlib EPUB),
   `--site` (dashboard HTML + lane leaderboard).
6. **fleet-manager**: tailscale/LAN discovery, per-peer ping state,
   system probes (audio, tailscale, D-Bus, interfaces), WOL wake for
   operator-pinned MACs (unpinned/malformed refuse), dated record
   appends to `docs/project/fleet.md` + queue. The source pin registry
   is never written by a script.
7. **ceremony-drive**: closed governance glue for explicit candidates
   (create-run → admit → deterministic verdict → prepare-candidate →
   commit), used to land this milestone.

## Verification

- `make test` green at every phase boundary (2774 Lisp checks + the
  reader guards + the new script suites: schedule-heartbeat,
  probe-model-route, driver routes, dashboard live, publication,
  fleet).
- `scripts/schedule-heartbeat --dry-run` live: queue 15 queued/4 done,
  next=wake-mutation-lane, card none, model reachable (route=auto),
  network reachable, audio 8/10.
- `scripts/dashboard-readout --export-html` live: complete page with
  timeline/queue/sessions; `--json` spine parseable; watch loop
  renders with the store's session rows.
- `scripts/generate-publication --ebook/--site` live to /tmp;
  `--check 2026-08-25` correctly refuses the operator-authored journal
  (exit 1) and a machine-generated journal round-trips exit 0.
- `scripts/fleet-manager --discover` live: honest "no tailscale peers
  (logged out / no mesh)" with live system probes; unpinned wake
  refused exit 1.
- The governance smoke (scripts/audio-intensity as a bare candidate)
  drove the full loop; commit on an unchanged path failed closed as
  `command-failed` — the honest behavior for a no-op candidate.

## Remaining unknowns

- A real heartbeat tick end to end (a mounted card on a real item)
  needs the operator's card + schedule choice; the dry-run path is
  proven, the trigger path is one cron line away.
- `--route=remote` resolution is untested against a live remote
  endpoint (none configured); local is proven.
- Fleet wake is bounded and refused-safe, but no real WOL-capable
  device is pinned yet.
