# Durable coordination records: steers as data, append-only by tooling, agent-proof logs

Owner direction 2026-08-09 (13:10/13:14), three items, one design.
Home for the "lanes are memory" doctrine made machine-readable.

- "It'd be awfully nice if our designs covered that already" — /steer
  tracking as a first-class record.
- "Make sure we're planning on preventing those kinds of errors" — the
  inbox-clobber class (whole-file replace overwrote Cibo's verdict).
- "Durable logs and records that can't get erased by agents … Automatic,
  procedural breadcrumbs that can be read in logs that all agents follow
  and notice."

## 1. The layered record model

Lane files (inbox/outbox/worklog) stay MUTABLE PROSE by construction —
humans and seats read and write them. Durable truth lives in a separate
append-only layer that no seat edit can erase:

```
1. COORD JOURNAL (exists)       state/journal/coord-messages.lisp
   append-only, one Lisp form per line, entry shape
   (:ts <unix> :from <id> :to <id|*> :kind <string> :body <string> :id "coord-NNNN")
   Owner: hngh-coord (card 101), faces MCP + ACP.

2. STEER LEDGER (new, thin)     same journal, kind "steer"
   Every coordination steer lands here as DATA, not only as lane prose
   or a tmux line. Who steered whom, when, topic (body), channel
   (mcp|tmux|lane). The MCP `steer` tool already writes durable notes;
   extend the SAME shape to tmux/lane steers so one query answers
   "what steers went to Cibo today".

3. BREADCRUMBS (new, automatic) state/journal/breadcrumbs-<seat>.lisp
   Machine-readable STATE/STEER/DONE/ACK lines a seat writes at each
   phase boundary — procedural, not prose. One short form per line:
   (:ts <unix> :seat <id> :kind STATE|STEER|DONE|ACK :ref <sha|file> :body <short>)
   Written by lane-watch/seat-up/ride-along on the seat's behalf when
   the seat reports; seats may also write directly through the helper.

4. FILE LANES (mutable, existing)  tandem-<seat>/{inbox,outbox,worklog}
   Prose for humans and seats. Same info appears in the layers above
   in structured form; lanes are the interface, records are the truth.
```

## 2. Steers as data (owner 13:10)

Rule: **every steer is a record**. Channels:
- MCP steer → already durable (:kind "steer") — no change.
- tmux seat-steer (dashboard/ride-along) → the steer text is written to
  the COORD JOURNAL (kind "steer", from = steering seat or :human) by
  the same `steer` path that injects tmux input. Injection is
  transient; the record is permanent.
- lane steer (a STEER:/NOTE: appended to an inbox) → the APPEND HELPER
  (§4) records it as a breadcrumb (kind "steer") at write time.

Query surface: `hngh coord-view` / coord `status` extended to filter
kind="steer" (from, to, since ts). 111A normalization consumes these
records as the :human ground-truth class — a steer record is exactly
the "what a human judged worth steering for" case-base feed (§7.5 of
situation-scoring), no prose parsing required.

Consumers: lane-watch (nudge accounting — don't nudge a seat that was
just steered), dashboard (steer history per seat), case-base feed
(111A), audit/review pass.

## 3. Append-only enforced by tooling (owner 13:10, #2)

Prevention beats convention. Three mechanisms:

1. **Append helper is the only writer.** `lane-append <lane-file> <text>`
   (CL or shell, one small function) — opens O_APPEND, writes, and
   writes the matching breadcrumb. The ride-along console, seat-up's
   mission delivery, dashboards, and all seat tool calls use it.
   Direct human edits remain possible (that's fine); agent tooling
   never does whole-file replacement.
2. **Detect the clobber class.** lane-watch's per-seat check adds: if
   `stat -c %s` (size) of inbox/outbox DECREASED or mtime moved
   backwards since last scan, emit `CLOBBER:` + the failing file —
   same visibility class as `DEAD:` (visible, never silent). The
   11:05/13:xx inbox-loss incidents would have been flagged.
3. **Sibling-trust audit (light).** A per-author monotone check
   (last-write mtime per seat prefix in the file) is optional; the
   size-decrease detector catches the real failure mode (replacement
   is almost always a shrink or a jump) without parsing authorship.
   Keep it procedural and cheap — no LLM in the watch path.

## 4. Agent-proof durable logs + procedural breadcrumbs (owner 13:11)

- The COORD JOURNAL is already append-only at the store level:
  `hngh.core.state-store:append-journal` opens with append semantics,
  entries are `read-journal`-compatible. Seats cannot erase history by
  editing a lane file because the record lives in the journal.
- Add the **git backing** that already exists: `~/.hngh` is a
  backup-manager git tree (hourly auto-commit). The journal lives under
  `~/.hngh/state/journal/`, so even a rogue journal write is recoverable
  to the last hourly snapshot. Document this as the recovery floor.
- **Procedural breadcrumbs** are the "logs all agents follow": every
  seat writes one short machine-readable line per phase boundary
  (STATE/STEER/DONE/ACK + sha + ts) via the helper. lane-watch and the
  dashboard consume them as a structured feed (same consumption shape
  as §2's steer ledger). A seat that stops breadcrumbing is detectable
  in one scan — the heartbeat of "is this seat alive and progressing".
- Boundary: breadcrumbs are SHORT and automatic; long reflection stays
  in worklog prose. The dashboard shows breadcrumbs; humans read the
  lanes.

## 5. Where this lands

- dashboard.md §8: ride-along `ack`/`steer` commands write through the
  append helper → journal record + breadcrumb; dashboard steer-history
  panel reads the ledger. §8.5 P1 adds the helper + lane-watch
  CLOBBER check.
- 111A (cross-agent-normalization.md): steer-ledger records ARE the
  :human case-base feed (no prose parsing); breadcrumbs are the
  auto-detected-state feed. Field mapping extended in that doc.
- lane-watch: CLOBBER detection + breadcrumb consumption + steer-
  accounting for nudges (no nudge right after a steer).
- seat-up/ride-along/seat-steer: all writes via `lane-append`.

## 6. Cost + fail-closed

- All local, free; COORD JOURNAL + breadcrumbs are tiny forms.
- The append helper FAILS CLOSED on non-existent lane (does not create
  a new lane file on a typo'd path — known-lane list from registry,
  same gate as ride-along input).
- No new wire: reuses hngh-coord's journal, state-store, and the
  existing tmux/lane paths.

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes TUI,
2026-08-09 — owner design notes 13:10/13:14 (via killy). Grounded in
coord.lisp + state-store source (append-only journal already shipped).

## 7. Wake trigger / hngh-live-watch (killy handoff 13:10; design home: seu)

The stopgap watcher killy ran today (v4, pid 60487: 20s tick, grace
90s, real footer-idle parsing, FINAL-newer guard) is the P1 ride-along
concept (card 104) in miniature. Its design home is THIS document's
breadcrumb layer, not a separate script:

- **Idle = finished turn, not proof of stall**: `ready` footer means
  the seat's turn ended; fast nudging cannot interrupt real work.
  Idle-based nudging is the trigger for the NUDGE, never a verdict.
- **Bound per seat, uniform by default**: owner question "why 240s for
  cibo" — answered: ready-footed idle is finished-turn for ANY model;
  use one bound (180s) unless a seat declares a longer one. Bound is
  DATA (registry/roll config), not hardcode.
- **Escalation ladder**: nudge → check consumed (input line empty /
  footer busy) → re-nudge with explicit `-t <seat>:0.0` (bare sends
  land in the wrong pane, seen live) → after N nudges, flag in the
  lanes / to the owner, not endless pushing. Max-nudges is
  configurable, defaults low (3).
- **Provenance in the doc**: rely on the BREADCRUMB regularity to
  distinguish sleeping-flash from stalled (seats breadcrumb per phase;
  a seat that breadcrumbs every ~20s is alive even if the footer
  looks `ready`). Idle-nudge is the fallback, breadcrumbs are the
  signal.
- **Ship as a systemd unit** (like tandem-supervisor): `hngh-watch`
  user unit, parameterized via the registry (seats, bounds, max
  nudges); NOT a repo script that must be babysat. Writes its own
  journal breadcrumb so its activity is as auditable as the seats'.
- **Protect active user input.** Before a steer is inserted, inspect the
  target pane and require an empty or known watcher-owned input field.
  Never overwrite text that may be a user's paste. If ownership is
  uncertain, record the pending nudge and stop.

Build it when the P1 ride-along lands (dashboard §8.5); it replaces
the stopgap and gives the lane-watch doctrine a single home.

### 7.1 Lane-triggered wake (killy WATCHER DESIGN v2 13:15, owner-steered)

The stopgap's idle-clock cannot distinguish an in-turn `sleep 40` from
real thinking — both show a busy footer. The mechanism is therefore
BEHAVIORAL + LANE-TRIGGERED, per owner:

1. **SEATS END TURNS instead of sleeping.** When work is pending but
   blocking-wait is needed, write the state and end the turn. No
   in-turn sleeps — the seat re-enters when its lane moves.
2. **WATCHER TRIGGERS ON LANE CHANGE, not brute idle**: when any
   seat's inbox/outbox mtime is newer than its last-read marker,
   nudge it immediately (steer-as-notification, machine-driven).
   Idle-time nudge stays as BACKSTOP only.
3. Consequence: "ran sleep 40" is IMPOSSIBLE by design — the seat
   would have ended its turn, and the watcher re-wakes it on lane
   movement.

This is the P1 ride-along (card 104) essence. Seat-side: the
hngh-lane discipline "end turns, don't sleep" becomes a hard rule
(worklog + outbox written before ending). Watcher-side: `-t <seat>:0.0`
retargeting and the composer-active pre-check (killy 13:17 collision
class: never type over an owner's in-progress line) apply to lane-
triggered nudges too.

Attribution (added 14:58): tandem seu — deepseek/deepseek-v4-flash-0731,
hermes TUI, 2026-08-09 — §7.1 folds killy's WATCHER DESIGN v2 13:15
(lane-triggered wake, end-turns-not-sleeping) into the wake-trigger
design; also records the 13:17 seat-steer composer pre-check fix.