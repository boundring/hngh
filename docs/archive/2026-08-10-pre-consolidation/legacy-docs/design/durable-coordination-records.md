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
- claims (collision prevention, §8): registry written via the same
  helper; lane-watch/seat-up consult claims before writes/spawns.

## 6. Cost + fail-closed

- All local, free; COORD JOURNAL + breadcrumbs are tiny forms.
- The append helper FAILS CLOSED on non-existent lane (does not create
  a new lane file on a typo'd path — known-lane list from registry,
  same gate as ride-along input).
- No new wire: reuses hngh-coord's journal, state-store, and the
  existing tmux/lane paths.

## 8. Collision prevention: surface claims + serial execution (owner 15:13)

Owner directive: Hngh must PREVENT collisions and manage overlapping
work SERIALLY — not rely on post-hoc "flag conflicts" notes. Two
agents must not work on the same surface (file, doc section, script,
deck card) simultaneously.

### 8.1 Surface claims registry

A CLAIM is a machine-readable record that a seat holds a surface:
  CLAIM: <surface> <seat> <purpose> <ts>
- Surfaces are named by WOBBLE: `file:i`, `doc:§7`, `script:seat-up`,
  `card:105`, `deck-tasks/*.txt` — coarse enough to be predictable,
  fine enough to prevent same-file races.
- Written via the append-only helper (same gate as lanes) into
  `~/state/claims.lisp` (or the COORD JOURNAL with :kind "claim").
  One line = one claim; RELEASE is a paired `CLAIM-RELEASE` line or a
  phase landing in the worklog (lane-mtime delta).
- Claims are DATA the dashboard §8 STATUS panel shows (who holds what),
  and lane-watch/seat-up consult before any write or spawn.

### 8.2 Enforcement (three rungs)

1. PREVENT AT PICK TIME — when a seat picks its next deck card, the
   card's declared surface (the "Files + This-card-does-NOT" list in
   the card brief, machine-readable) is checked against the claims
   registry. Any overlap with a live claim → the card is NOT picked;
   the seat takes a different card or declares WAIT-GATE on the
   holder. This makes the collision impossible by construction, the
   same way lane-change wake makes in-turn sleeps impossible (owner's
   13:15 doctrine).
2. SERIALIZE ON WRITE — the append/write helper refuses (exit non-
   zero, logs) a write to a surface claimed by another seat. The
   writer then either waits (WAIT-GATE against the holder's lane → the
   watcher re-wakes it when the holder's lane moves, i.e. serial
   execution with the same machinery) or escalates to the operator if
   the claim looks stale (>WAIT_TTL without lane movement).
3. CROSS-CUTTING CHECK — the watcher's WAIT-GATE judge treats a
   claim on a surface as machine-verifiable NECESSITY for a gate that
   names it: `WAIT-GATE: card:105 (held by cibo)` is verifiable by
   looking up the claim, no prose trust needed. This ties §7.2's
   "cross-reference against deck/registry/lane state" to a concrete
   object.

### 8.3 The watcher surface, concretely (this session's collision)

The watcher update is the first live test. Surface:
- `script:hngh-live-watch` (repo scripts/ + ~/.local/bin shim) — held
  by CIBO for the code build.
- `doc:durable-records` — design home SEU; §7.2 is the build target.
- Collision rule for THIS wave: while CIBO builds, SEU holds the doc
  pen only for REVIEW notes (additive attribution lines / errata),
  not structural edits; CIBO's code commits must state "conforms to
  §7.2" or flag delta. The doc converges in one wave via review, not
  two writers racing.

### 8.4 Fail-closed

- A claimed surface is never written around: no "just this once"
  bypass flag. Wrong-claim (temporary) → WAIT-GATE + watcher re-wake;
  stale-claim (claim > WAIT_TTL, holder lane dead) → owner
  escalation, not silent take-over.
- Claims live in the same append-only journal as lanes (agent-proof,
  breadcrumbed), so takeover history is auditable.

Attribution (15:16): tandem seu — deepseek/deepseek-v4-flash-0731,
hermes TUI — §§8.1-8.4 owner directive 15:13; extends §5 (§5 now
mentions claims) and §7.2 (judge treats claims as verifiable gates).

## 9. Attribution (original)

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
  WAIT-GATE is the escape hatch. WAIT_TTL bounds self-declared gates;
  the TTL value is NOT a re-nudge cadence for owner-gated waits — see
  below.
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
- **TTL semantics — escalate to the OWNER, immediately, don't re-nudge
  (owner 19:22, 19:30)**: WAIT_TTL is NOT a seat re-ping rubber band,
  and an OWNER-gate is not a seat problem at all. Two gate classes:
  (a) co-agent gates (target = a sibling's lane): short TTL is fine —
  the lane moves in minutes; expiry means "still waiting, re-check
  the lane". (b) OWNER gates (target = a deck item awaiting the owner:
  109A pick, 110 scope, key presence): the seat declared correctly and
  is blocked ON THE HUMAN. The moment such a gate is DECLARED (not on
  expiry), the watcher must notify the owner through a dedicated OWNER
  SURFACE (e.g. `~/.hngh-night/owner/inbox.md`, or a wall-clock ping)
  — the owner decides at human pace, and re-pinging the seat every
  10min converts a human decision into seat noise. Seat-class gates
  carry `owner:` in the target so the judge classifies them.
  The owner should never have to WAKE A SEAT to discover a blocked
  decision; waking Killy to "check things" means the escalation
  surface did not exist. It must.
- **Delivery contract**: steer delivery = send-keys -t <seat>:0.0 -l
  '<text>' + Enter, then verify the input line is EMPTY (footer busy
  is fine). Visible text at the prompt is not delivery. Stranded
  owner steers are held by composer_active, never typed over.

Attribution (15:05): tandem seu + killy + cibo consensus recorded —
group design, owner-steered; seu drafting §7.2 for cibo's watcher
update build target.

### 7.3 Wake composition: what a woken seat does (owner 15:24)

The wake message is not a blank "check your inboxes + deck" template.
It is COMPOSED from state — the watcher knows why it nudged, who else
is working, and what the seat owns. The nudge text then says what to
DO, not just where to look.

Inputs the watcher already has (no new reads):
- nudge reason: lane-change (which lane moved) vs idle-backstop vs
  unmarked-sleep vs WAIT-GATE-expired.
- co-agent state: the claims register (§8) — who holds which surface;
  live lane mtimes per seat.
- deck state: open/unclaimed cards in ~/.hngh-night/tasks/.
- own claims: what THIS seat holds (from the register).

Composed wake, by reason:
1. LANE-CHANGE: name the lane that moved and why it matters —
   "cibo finished card 105 (lane move). Your waiting card
   `card:105` is free; pick it up or check its HANDOFF." The seat
   goes straight to the NEW work, not through a general scan.
2. IDLE-BACKSTOP with open deck: enumerate the seats working now and
   the unclaimed next card — "killy holds watchdog, cibo holds 105.
   Next unclaimed: 109B (brief ready). Take it." Coordination intent
   survives in the nudge itself.
3. WAIT-GATE EXPIRED: name the gate and the stale claim — "WAIT-GATE
   was honored 10min; its target (cibo's card 105) has not moved.
   Decide: escalate to owner or take a different card."
4. UNMARKED SLEEP: no composition needed — the doctrine line
   (declare-or-end) is the whole message; it is the one case where
   the fixed template is correct.

Generic checklist (appended when reason does not fit 1-4):
1. Reconcile: claims you hold that are done → CLAIM-RELEASE line.
2. Check co-agent HANDOFF files (who finished, what they left).
3. Pick the next unclaimed card whose surface you do not conflict
   with (§8.2 rung 1).
4. If nothing stands, WRITE THE STATE and end the turn — no in-turn
   sleep, the watcher re-wakes you on lane change.

The composed wake REQUIRES the HANDOFF phrasing in its text (per the
rename wave): "A HANDOFF does not stop the watch — the deck has more
work." (killy reconcile 17:01: one clause in the spec saves a re-sync
when cibo's code lands.)

Parameterization: seat lists come from the REGISTRY
(registry/roll config), never hardcoded `for s in killy seu cibo`.
The composition reads `$TANDEM-*/inbox.md` mtimes + claims
generically; a seat works SOLO when the registry has one entry and
the message then omits co-agent enumeration and says so directly:
"you are the only seat; owner surfaces: ..." — no phantom "help the
others" when there are no others.

Attribution (15:30): tandem seu — owner 15:24 direction — wake
composition design; cibo owns the wake-line code (owner-assigned),
this is its spec. Complements §7.2 delivery contract.

PLANNED FIX — implementation must catch up to composition-from-state
(killy finding 14:18, owner: "note problems, make sure we plan on
fixing them"): the CURRENT watcher script embeds a hardcoded claims
sentence ("your own claim is seat-specific: killy holds tandem-
watchdog/HANDOFF") instead of reading the claims register. Verified
stale: the text said killy held watchdog/HANDOFF after it was released
(13:59). The §7.3 spec above is correct (claims from register); the
CODE is behind the spec. Fix items:
1. Wake "claims" sentence reads the claims register / $TANDEM-*/
   outbox last-claim lines, not a frozen string in the script.
2. Co-agent sentences ("Seu is working on ...") likewise derived from
   live state, or omitted until verifiable.
3. IDLE-BACKSTOP with NO unclaimed card is a valid terminal state —
   the wake should not tell a seat to "pick the next unclaimed card"
   twice when none exists; it should say "all cards owned or
   owner-gated; reconcile + state-and-end".
Owner of the fix: wake-line code (cibo) against this spec (seu);
killy verifies the composed text is live-derived. Blocked by
nothing; slot after card 105.

### 7.4 Embedding doctrine: the watcher is Hngh, not a separate thing (owner 19:40)

Owner direction: the watcher must NOT be a permanent, separate
component. Hngh either EMBEDS the watcher under its full control, or
Hngh uses MODULAR REPLACEMENTS with a broad variety of watcher types.

Two acceptable architectures (either satisfies, mixed is fine):

A. EMBEDDED — the wake core moves INTO Hngh as a plugin/service:
   - The state machine (lane-change trigger, idle backstop, WAIT-GATE
     judge, escalation, composition) lives under Hngh's own
     lifecycle: started/stopped/statused by `hngh` itself (or the
     dashboard, which is Hngh surface per §7.2 code home), config
     from the registry, state in the claims journal — no systemd
     script as the owner of the logic.
   - The current `scripts/hngh-live-watch` + systemd unit is an
     INTERIM, a dogfooding vehicle for the contract. It must not
     become the reference implementation by inertia.

B. MODULAR — a watcher CONTRACT with pluggable implementations:
   - The contract is what this doc specifies: surfaces (claims),
     gate classes (co-agent vs owner), TTL semantics, escalation
     ladder, delivery verification, composition rules.
   - Any implementation conforming to the contract is swappable:
     the v5/v6 shell watcher, a native Hngh plugin watcher, a
     Nikolai-style external supervisor, a dashboard-embedded
     watcher. Hngh selects the watcher type from config
     (`watcher.impl` or equivalent), not from what happens to be
     running.
   - The state/journal seam is the swap point: any watcher writes
     the same per-seat state + claims + escalations, so consumers
     (dashboard, seats, owner surface) never depend on a specific
     watcher's implementation.

Rule (fail-closed): a watcher that stops being swappable — one whose
behavior only the shell script can express and no one else can
replicate via the contract — is a design defect, not a feature. The
watch is owned by Hngh's doctrine, not by any one file or unit.

### 7.5 Steer dispatch: the watcher's delivery logic is Hngh's steer engine (owner 14:25, killy 14:26)

Owner vision: Hngh will make MOST/MOST-ALL steers. Users submit
steers to Hngh for agents in various ways — PREMADE (templates),
PROCEDURAL (programmatic/generated), CUSTOM (free-form). The
watcher's seat-steer delivery logic (composer-check, stranded-
detect, busy-retry, consume-verify) is the PROTOTYPE of that steer-
dispatch engine. This makes the steer pipeline a FIRST-CLASS surface:

    source (premade | procedural | custom)
      -> Hngh dispatcher (queuing, policy, delivery adapter)
      -> seat (pane 0 Hermes input)

THE DELIVERY CONTRACT (already proven in the watcher, now the
dispatcher's adapter contract):
1. COMPOSER-CHECK — before any keystroke injection, verify the input
   field holds only a known prompt; NEVER type over a human's or
   seat's in-progress text. composer_active is the guard.
2. STRANDED-DETECT — if text is already sitting in the input line
   (a steer that was typed but not entered), decide: submit it
   (if it is a complete steer) or clear it (C-u) — never double-
   enter, never type on top of it blindly.
3. BUSY-RETRY (exit 4, shipped 14:26) — if delivery fails because
   the target is busy (input busy / text stranded -> cleared),
   return a distinguishable failure code; the caller does NOT count
   it against grace/nudge state, and RETRIES on the next tick once
   the input clears. Watch the typing, back off, retry when it
   stops (owner 14:23).
4. CONSUME-VERIFY — after delivery, verify the prompt CONSUMED the
   steer: input line empty / footer flipped busy. Visible text at
   the prompt is not delivery. A nudge that landed in the wrong pane
   is not a nudge (13:50 lesson, §7.2 ladder, consumption-verified
   before counting).

DISPATCHER SURFACE (what the pipeline owns beyond seat-steer):
- SOURCES: premade = template library (nudge templates, incline
  templates); procedural = lane-watch/program logic emits steers;
  custom = owner writes a steer to the dispatcher (tmux, owner
  surface, future CLI/API).
- QUEUING: a steer for a busy seat is QUEUED (PENDING), not dropped
  or force-injected — §8.2 collision-aware dispatch already
  specifies this shape for claims; the dispatcher generalizes it.
- DELIVERY ADAPTER: seat-steer (tmux, proven, v6) is the reference
  adapter. Per §7.4 the adapter is swappable: same contract via MCP
  tools, dashboard, or a future native transport — consumers don't
  care.
- TOPOLOGY: any seat's delivery logic — watcher, dashboard, another
  seat — routes through the SAME dispatcher contract. No second
  implementation of composer-check/busy-retry/consume-verify.

PEER DIRECTION — the two-way loop (owner 14:36: formalize it):
the pipeline above is NOT one-way (Hngh→seat). Seats steer each
other and the coordinator through the SAME dispatcher; there is no
privileged sender class. A steer's FROM field is one of: owner
(human), Hngh/the watcher, or another seat — the delivery adapter,
queuing, and verification are identical for all three.
- Symmetry rule: every seat is reachable the same way, including
  the coordinator (killy). `seat-steer <seat> "text"` is the tool;
  any seat may call it on any seat. The coordinator is not a
  black box that only waits on the owner.
- Contract doc: the hngh-lane skill's PEER STEERING section spells
  the tool + exit codes for every seat (0 consumed, 3 composer,
  4 busy-retry) and killy's lane path. Skill and this doc must not
  drift: the skill is the operational contract, this section is the
  design rationale.
- Attestation: the dispatcher must not require special
  authorization for seat→seat steers beyond the lane contract
  itself — a seat that can read another's outbox can steer it.
  Owner steers keep priority ordering (§2) but arrive through the
  same pipe (FROM=owner).
- Testing lens: the two-way loop is verified when a seat steering
  the coordinator produces the same observable behavior as the
  watcher steering it — consume-verified, logged to the steers
  log, retried on busy. Fixture: steer_dispatch self-test (killy
  14:33) proved the trail end-to-end; peer-direction should add a
  cibo→killy seat-steer delivery check.

Build order: the watcher IS the prototype (done); the dispatcher
surface is a Hngh plugin/service per §7.4 embedding; the dashboard
(105) becomes the first non-watcher consumer. The owner inbox
surface (this doc's §7.2) is a steer SOURCE (custom class) once the
pipeline exists.

Attribution (20:15): tandem seu — owner 14:25 + killy 14:26 vision —
steer dispatch design; seam handed to cibo's Lisp plan.

### 7.6 Transport roles — ONE delivery contract, three roles (card 123 seam 1, seu 23:55)

The three-writer incoherence (MCP coord, seat-steer, hngh-watch all
append to lanes) is killed by assigning ROLES — not by banning
writers. Every transport is an implementation of the SAME contract
(§7.5): compose-check → stranded-detect → busy-retry → consume-
verify, with one writer per message.

ROLES (the seam):
- MCP = NOTIFICATION + TOOL SURFACE. `post_message`/`steer` are the
  programmatic way to raise an event and have the coordinator
  journal it. MCP messages are NOT the storage; they carry a
  pointer to the lane record.
- LANES = STORAGE (the durable record). The inbox/outbox files are
  the single source of truth for what happened. Everything that
  must survive the session lives here. Append-only, lane-append
  helper, attribution footers.
- seat-steer = DELIVERY ADAPTER (the only writer that touches a
  pane). It implements the §7.5 contract end-to-end (composer-
  check, stranded-detect, busy-retry exit-4, consume-verify) and
  is the ONLY component allowed to send keystrokes to a seat's
  input. It appends to the lane as its durable record.

WRITER RULES (fail-closed):
1. One message = one writer = one lane append. MCP steer may
   journal + notify; it does NOT also append the lane unless the
   delivery adapter did (dedupe key = message id).
2. Only seat-steer writes a pane. hngh-watch, the coordinator, and
   other seats never inject keystrokes directly — they call
   seat-steer (or an equivalent adapter implementing the same
   contract per §7.4 swapability).
3. Lane appends are idempotent by message id: a re-delivery (busy-
   retry) does not double-append. If the adapter recorded delivery
   failure (exit 4), the lane carries the message once and the
   retry updates status, not text.
4. Consumers (dashboard, watcher, seats) read the LANE, not the
   transport. Nobody greps MCP history for state; the lane is the
   read surface. This is the feed-compat principle (§7.4/117)
   applied to lanes.

CONSEQUENCE: the (hngh-watch) marker coupling (card-123 gap 6) is
solved by role 3 — hngh-watch calls seat-steer for pane delivery,
and its lane appends use the standard STEER format with
FROM=hngh-watch. Dashboard reads the lane with the standard
parser; no implementation-specific marker filter survives.

This clause supersedes any earlier "MCP also mirrors into the
inbox" behavior (cibo 15:44): the mirror was a stopgap before
roles existed. With one-writer-per-message, MCP's job is notify +
journal; the delivery adapter owns the lane append.

### 7.7 Evidence and continuation gates (K3 review 95)

A seat may report `working`, `live`, `fixed`, or `done` only with an
evidence block appropriate to the claim:

```text
FINDING: <state>
EVIDENCE: <pane capture | command output | probe | rendered frame | commit>
OBSERVED AT: <timestamp>
UNKNOWN: <anything the artifact does not prove>
```

A sentence without its evidence object is a claim, not a finding. The
coordinator may relay an unverified sibling statement only when labelled
`RELAYED — NOT VERIFIED`; it may not turn it into its own finding.

Completion is a transition, not a stop:

1. Write the result and evidence to the outbox/worklog.
2. Release completed surface claims.
3. Re-read the inbox, sibling outboxes, live claims, and open deck.
4. Perform standing ACK/review duties first.
5. Select the next unclaimed, nonconflicting card, or declare a machine-
   verifiable WAIT-GATE / genuine rest condition.
6. End the turn. The watcher reactivates the seat when its gate or lane moves.

A seat does not manufacture work to appear active. Rest is correct when the
reconciled deck has no suitable work, the remaining work is claimed or gated,
or the model budget says to stand down. The defect is an unexamined stop: a
seat finishing one card and returning to `ready` without the reconciliation
transaction.

Authority reviews such as K3 artifact 95 are inputs to this transaction. Seats
convert each action into a card, design change, guardrail, or an explicit
rejection with evidence. They do not spend workhorse or reserve calls
re-confirming already verified findings.
