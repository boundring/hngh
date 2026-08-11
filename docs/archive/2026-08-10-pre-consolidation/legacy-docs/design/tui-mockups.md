# Hngh TUI Mockups

**Author:** GLM-5.2 (designer)
**Date:** 2026-08-02
**Status:** Design proposal — for coder implementation

---

## Mockup 1: Mission Control Overview

```
+----------------------------------------------------------------------+
| HNGH v0.0.1 [MEGASTRUCTURE]                                  [RUN]  |
|----------------------------------------------------------------------|
|                                                                      |
|  DAEMON     UDS active     | AGENTS    4 active      | QUEUE    6   |
|  UPTIME     04:12:33       | MODEL     gemma-4-12b    | BLOCKED  2   |
|                                                                      |
|  --- SQUADS ------------------------------------------------------    |
|                                                                      |
|  day-queue       @  manager  .  worker-a  .  worker-b   [RUNNING]    |
|  night-ralph     @  manager  *  processor               [RUNNING]    |
|  duo-review      .  idle     .  idle                    [STOPPED]    |
|                                                                      |
|  --- QUEUE -------------------------------------------------------    |
|                                                                      |
|  * 66  phase2 claim/release         deepseek-free    04:21 lease     |
|  ? 67  complete/block/fail          --               pending          |
|  ? 68  M7 wire handlers             --               pending          |
|  ! 57  beads stealth pilot          --               BLOCKED         |
|  ! 58  svc-dash twine release       --               BLOCKED         |
|  + 62  beads gap research           mimo-free        done             |
|                                                                      |
|  --- EVENTS ------------------------------------------------------    |
|                                                                      |
|  15:16:45  task-claimed     66  deepseek-free :worker                 |
|  15:16:45  task-claimed     66  event emitted                        |
|  14:22:16  task-queued      70  flash-lite  :worker                   |
|  14:20:49  task-queued      71  mimo-free   :worker                   |
|                                                                      |
+----------------------------------------------------------------------+
| q: quit  t: tasks  s: squads  e: events  r: refresh  ?: help        |
+----------------------------------------------------------------------+
```

## Mockup 2: Task Queue Detail

```
+----------------------------------------------------------------------+
| HNGH v0.0.1 [TASK QUEUE]                                  [FILTER: *]|
|----------------------------------------------------------------------|
|                                                                      |
|  ID   STATUS  TITLE                    CLAIMANT       LEASE     AUTH  |
|  --   ------  -----                    --------       -----     ----  |
|  66   *       phase2 claim/release     deepseek-free  04:21     W    |
|  67   ?       complete/block/fail      --             --        W    |
|  68   ?       M7 wire handlers         --             --        W    |
|  69   ?       lease expiry             --             --        W    |
|  70   ?       ascii architecture       --             --        A    |
|  57   !       beads stealth pilot      --             --        O    |
|  58   !       svc-dash twine release   --             --        O    |
|  62   +       beads gap research       mimo-free      done      W    |
|  71   +       gbd audit                mimo-free      done      W    |
|                                                                      |
|  --- SELECTED: 66 -------------------------------------------------   |
|                                                                      |
|  Task:     phase2 claim/release                                      |
|  Status:   * claimed                                                 |
|  Claimant: deepseek-free (worker)                                    |
|  Route:    local/free                                                |
|  Lease:    04:21 remaining (300s default)                            |
|  Auth:     :worker                                                   |
|  Verifier: PM                                                        |
|                                                                      |
|  Transitions:                                                        |
|    :queued -> :claimed   15:16:45  deepseek-free  :claim             |
|                                                                      |
+----------------------------------------------------------------------+
| c: claim  r: release  v: complete  b: block  f: filter  ESC: back   |
+----------------------------------------------------------------------+
```

## Mockup 3: Squad View

```
+----------------------------------------------------------------------+
| HNGH v0.0.1 [SQUAD: day-queue]                             [RUNNING]|
|----------------------------------------------------------------------|
|                                                                      |
|  SQUAD: day-queue                                                    |
|  DESC:  Queue manager with two local workers                         |
|  STATE: :running   OWNERSHIP: hngh   STARTED: 14:20:49              |
|                                                                      |
|  --- ROLES -------------------------------------------------------   |
|                                                                      |
|  ROLE        MODEL               PANE   STATUS     BUDGET   FWD      |
|  ----        -----               ----   ------     ------   ---      |
|  manager     gemma-4-12b         0      @ working  0c       3        |
|  worker-a    gemma-4-12b         1      . idle     0c       0        |
|  worker-b    gemma-4-12b         2      * writing  0c       1        |
|                                                                      |
|  --- FORWARD PROMPT -----------------------------------------------   |
|                                                                      |
|  > Claim task 67, implement complete-task and block-task per        |
|  > phase2-claim-release.md spec. TDD: failing tests first.           |
|                                                                      |
|  --- LIFECYCLE ----------------------------------------------------   |
|                                                                      |
|  Spec:      squads/day-queue.spec                                    |
|  Launcher:  ~/.local/bin/squad                                       |
|  State:     ~/.hngh/squads/day-queue.lisp                            |
|  Forward:   ~/.hngh/squads/day-queue-forward.md                      |
|                                                                      |
+----------------------------------------------------------------------+
| u: up  d: down  f: forward  s: status  r: refresh  ESC: back         |
+----------------------------------------------------------------------+
```

## Glyph Legend

```
@  active agent / orchestrator
#  bulkhead / structural boundary
.  idle / empty slot
!  alert / blocked / breakage
*  claimed / active task
+  completed / done
?  unknown / pending verification
```

## Design Notes

- 80-column width throughout. No emojis in the dashboard.
- Status column uses single-character glyphs, not words, for density.
- Lease countdown is relative (mm:ss remaining), not absolute timestamp.
- Transition log in task detail is compact: from -> to, time, agent, reason.
- Squad view shows the forward prompt inline — the PM can read what was
  last sent to the squad without opening a file.
- Footer keybindings are terse: single letter + colon + one word.
- Color: ANSI 16-color per brand spec. Headers in bold cyan, status
  glyphs in semantic colors (green=done, yellow=claimed, red=blocked,
  dim=idle). Body text is default terminal color.

## Implementation Notes for Coder

These mockups are targets, not final code. The dashboard-tui.lisp
plugin currently renders a header and overview view. Implementation
should:

1. Add a view router (overview / tasks / squads / events)
2. Add keybinding handling for view switching
3. Render each view from current state (not mock data)
4. Use the glyph set above for status display
5. Keep rendering procedural — no external TUI library, just format strings

The mission-control plugin already has squad-up/down/status/forward.
The task driver has claim/release. Wire the TUI to read from both.

Attribution: Hermes (GLM-5.2, designer)
