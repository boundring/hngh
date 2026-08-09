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

The watcher is SHIPPED as v5 (systemd --user hngh-live-watch.service,
Restart=always, enabled; single-instance pidfile lock that exists ONLY
when executed, never when sourced — v5 source-guards the whole main, so
sourcing the file never starts a loop). It is the P1 ride-along
concept (card 104) in miniature. Its design home is THIS document's
breadcrumb layer, not a separate script:

- **Idle = finished turn, not proof of stall**: `ready` footer means
  the seat's turn ended; fast nudging cannot interrupt real work.
  Idle-based nudging is the trigger for the NUDGE, never a verdict.
- **Bound uniform, shipped**: IDLE_BOUND=15s, NUDGE_GRACE=45s (owner
  went 60→10→45: 60 was invented courtesy, 10 too hot, 45 the call),
  TICK=10s, WAIT_TTL=600 (WAIT-GATE honored 10min then re-nudged —
  the implied time-bound on self-declared gates). Bound is DATA,
  not hardcode.
- **NO FINAL ABATEMENT**: v5 never checks FINAL in the nudge path
  (owner 13:32: "dumb to include anything that fully halts
  inappropriately"). FINAL files are archive artifacts
  (tandem-*/archive/), not permission to stop — the deck always has
  next steps.
- **Lane-change trigger is primary, idle is backstop** — the lane
  mtime vs last-read-marker check (WATCHER DESIGN v2, §7.1). Nudge
  cadence is NUDGE_GRACE; no lossy suppression.
- **Provenance in the doc**: rely on the BREADCRUMB regularity to
  distinguish sleeping-flash from stalled (seats breadcrumb per phase;
  a seat that breadcrumbs every ~20s is alive even if the footer
  looks `ready`). Idle-nudge is the fallback, breadcrumbs are the
  signal.
- **Protect active user input.** composer_active pre-check lives in
  seat-steer (skip + exit 3 when the input line holds non-prompt text;
  Ctrl+C busy-hint excluded) AND is the watcher's first per-seat
  guard. Never overwrite text that may be a user's paste. If
  ownership is uncertain, record the pending nudge and stop.
- **Cross-seat wake task.** A wake is not merely "resume your own lane":
  after checking its inbox and deck, a seat checks sibling lanes and helps
  an agent with active work when its own lane is clear. The watcher prompt
  must name this behavior explicitly.

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
triggered nudges too. FINAL does not abate the watch: v5 never checks
it (owner 13:32) — a HANDOFF file (see rename consensus 13:48) is an
archive artifact, not a stop signal; the deck always has next steps.

Escalation ladder (per Q3 consensus 15:30): lane-change pulse →
idle backstop (NUDGE_GRACE cadence) → consumption-verified before
counting (input line empty / footer busy; a nudge that landed in the
wrong pane is not a nudge) → explicit `-t <seat>:0.0` retargeting →
after max-nudges (config, default 3), write an `ESCALATE-OWNER: <seat>
<state>` lane marker + sibling inbox notes, then STOP poking — poking
a stuck seat is harassment; surfacing is the move. No overwrite /
repeated Enter.

Attribution (added 14:58): tandem seu — deepseek/deepseek-v4-flash-0731,
hermes TUI, 2026-08-09 — §7.1 folds killy's WATCHER DESIGN v2 13:15
(lane-triggered wake, end-turns-not-sleeping) into the wake-trigger
design; also records the 13:17 seat-steer composer pre-check fix.

Attribution (13:50 update): §7/§7.1 aligned to SHIPPED v5 per killy's
FACT-SYNC — no FINAL abatement, 15/45/10/600 params, composer_active
in seat-steer, systemd lifecycle, source-safe by construction. The
13:45 joint-diagnosis findings (source-guard placement, singleton
lock) were against the pre-v5 file; v5 already implements both fixes.

### 7.2 Consensus boundary + escalation ladder (15:30, cibo + killy + seu)

The group design is converged (owner: watcher is a group design, not
solo). Recorded here so the code and the doc agree:

- **Code home**: `scripts/hngh-live-watch` versioned in the hngh repo;
  `~/.local/bin` is only the gbd-tracked installed SHIM; user systemd
  owns lifecycle; card 105 dashboard controls/statuses it. The CORE
  (state machine: lane-change trigger, idle backstop, WAIT-GATE
  judge, escalation) is separated from the daemon wrapper so the
  ride-along and dashboard never fork the logic.
- **Necessity recognition**: WAIT-GATE is the written contract, not
  the authority. The judge cross-references the gate target against
  deck/registry/live-lane state (structured form:
  `WAIT-GATE: <target> <reason>`; target = deck card, lane, or
  registry entry). Self-declared/unstructured gates are NOT
  machine-verifiable → after grace, remedy is END-TURN (declare),
  not merely "stop sleeping". DECLARE-OR-END is the default;
  WAIT-GATE is the escape hatch. WAIT_TTL=600 bounds self-declared
  gates.
- **Ladder (agreed order, no overwrite / repeated Enter)**:
  lane-change pulse → safe exact-pane preflight (`-t <seat>:0.0`,
  verify input EMPTY after) → skip composer-active/uncertain input
  (Ctrl+C busy-hint excluded) → declare-or-end for unmarked in-turn
  sleep → WAIT-GATE hold until lane change/deadline → bounded owner
  escalation (`ESCALATE-OWNER: <seat> <state>` lane marker + sibling
  inbox notes, max-nudges config default 3, then STOP) → done.
  Consumption-verified before counting (a nudge that landed in the
  wrong pane is not a nudge).
- **No FINAL abatement**: HANDOFF files are archive artifacts
  (tandem-*/archive/), never a stop signal; the deck always has next
  steps. The escalation + watch continues until the seat is working
  or the owner stops it.
- **Delivery contract**: steer delivery = send-keys -t <seat>:0.0 -l
  '<text>' + Enter, then verify the input line is EMPTY (footer busy
  is fine). Visible text at the prompt is not delivery. Stranded
  owner steers are held by composer_active, never typed over.

Attribution (15:05): tandem seu + killy + cibo consensus recorded —
group design, owner-steered; seu drafting §7.2 for cibo's watcher
update build target.