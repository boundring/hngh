# D2 — Backup observe: store + alert scope (card 110, Sprint 1)

One page. Extends ADR docs/design/backup-sync-integration.md Phase A
(observe, DONE) to D2-A: observe + STORE + ALERT — no auto-restart,
no writes to Syncthing. Watcher layer within Hngh's scope and
control (operator directive, folded into card 117).

## DECISION (operator 15:39): D2-A — observe+store+alert, no
auto-restart. Watcher layer must be within Hngh's scope and control.

## SCOPE — what D2 adds to Phase A

Phase A (done, card 95): Syncthing REST observation (documented
endpoints §8), Tier-0 detectors syncthing-unreachable / out-of-sync /
conflict-file. D2 adds TWO surfaces on top, nothing mutating:

1. STORE — observation history, not just current state:
   - Every detector verdict (and the raw reachability/folder-status
     facts it consumed) appends to a per-device observation log in
     the Hngh state tree (backup-manager plugin's domain:
     `state/plugins/backup-manager/observe/`), one line per sample:
     `TS | device | endpoint | key fields (state, needBytes,
     pullErrors, conflict count) | verdict`.
   - Append-only, bounded: rotate at N samples or T days (default
     10k lines / 30 days), old lines to archive. Never overwrite.
   - Why store: alerts need history ("degrading" vs "flapped once"),
     and the L2/L3 situation brain (§7 of situation-scoring) learns
     from real Syncthing behavior. Without store, alert = noise.
2. ALERT — bounded brief to the operator, not a raw poke:
   - Triggers: detector verdict = unhealthy AND the state PERSISTS
     across M consecutive samples (default M=3, so transient flake
     doesn't page the operator — the "noise budget").
   - Format: the card-115 bounded brief — DECISION (one sentence),
     CHOICES (A: fix via syncthing CLI, B: restart unit — NOT
     automatic, C: wait/degrade note), SIZE/URGENCY/BLOCKS,
     IF-NO-DECISION (fail-closed: stays degraded, alert re-fires on
     next persistence window).
   - Destination: operator inbox (owner/inbox.md), reviewed by >= 2
     seats per 115 before landing. Dashboard (116) renders it.
   - NO auto-restart: alerting is the ceiling of D2's agency. A
     restart/reconcile is Phase B (`:operation`-gated, ADR §51).

3. WATCHER-LAYER SURFACE (operator directive):
   - The backup observation routine is a ROUTINE under the card-117
     watcher layer: registered, feed-compatible, lifecycle owned by
     the layer (within Hngh's scope and control), NOT a shell script
     appendage. The detector emits to the situation bus (existing
     pattern); the layer's dashboard feed carries the status.
   - Concretely: observation runs as a Hngh routine (Lisp plugin
     per §7.4/117), its knobs (sample period, M persistence window,
     rotation) are config, its output is the same state-feed the
     dashboard consumes. The shell prototype gains nothing.

## FIXTURES (design-for-test, cibo impl after gate)

- STORE: fixture writes a recorded REST response to a tmp state
  tree; assert the observation log line format + append + rotation
  at boundary (no live Syncthing).
- ALERT: fixture replays a sequence of recorded REST responses
  (healthy x2, unhealthy x1, unhealthy x2, unhealthy x3) against a
  fixture inbox; assert: no alert before M=3, alert lands after M=3
  in bounded-brief format, alert does NOT re-fire mid-window, and
  the re-fire after the next window carries fresh facts.
- NO-MUTATION guard: fixture asserts zero writes to Syncthing config
  (the observe client never calls a POST endpoint; unit test on the
  endpoint allowlist).
- gbd-agent-configs alignment: card 110 item 3 (service-map notes a
  failed gbd unit) — the alert path reuses the same bounded-brief +
  persistence logic; diagnosing THAT unit is a separate situation
  detector (gbd-unhealthy), same shape, same fixture pattern.

## ACCEPTANCE

- This scope doc (done) → cibo's impl gate after review.
- Store: append-only observation log, bounded, fixture-tested.
- Alert: bounded-brief to operator inbox, persistence window M=3,
  no auto-restart (unit-tested), 2-seat review per 115.
- Routine registered under watcher layer per 117; feed-compatible
  with the dashboard.
- make test green; docs updated.

## Open questions (operator)

- M persistence window: 3 samples at what period? (Recommend:
  sample every 5 min, alert after 3 consecutive = 15 min of
  sustained degradation — long enough to ignore flake, short enough
  to catch real drift.)
- Rotation: 10k lines / 30 days reasonable? (Recommend yes —
  bounded, archivable.)

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes
TUI, 2026-08-09. Extends ADR-043 §8 (endpoint facts verified
documentation-first) + card 110 scope + operator 15:39 directive.
