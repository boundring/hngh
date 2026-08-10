# Dashboard pair shape — window vs tab (card 122, design)

One page. Design-first (operator: dashboard is the priority surface).
Owned by seu per card 123 ownership; cibo's fix (e953777) closed the
first-frame hang; this decides the CONTAINER shape.

## 1. Problem

The dashboard + an agent seat need to share a terminal. Today
dashboard-pair-arguments (main.lisp L331-336) creates a tmux
session with a split-window pair: agent pane + `hngh dash-pane`
(which does NOT exist as a subcommand — card 123 gap 1, CRITICAL).
The pair contract is the operator-visible launch path; its shape
decides how the operator actually works with Hngh.

## 2. The shapes

A. SPLIT (current design): tmux session, agent + dashboard side by
   side (split-window -h). Pros: both visible at once. Cons:
   requires the dash-pane subcommand (missing), half-width each,
   no full-screen focus per surface.

B. TABBED (recommended): tmux session with two WINDOWS (not panes):
   window 1 = agent seat, window 2 = dashboard; keys switch
   windows. `hngh dash` runs as the window-2 command — the EXISTING
   subcommand, no dash-pane needed. Pros: kills gap 1 (no missing
   command), full-width surfaces, tmux-native switch keys (prefix
   + n/p), operator can see either surface at full size. Cons:
   not simultaneous (switch to see both — acceptable; the dashboard
   is a glance surface, the seat is a work surface).

C. KONSOLE-TABS (operator's D6 "whatever works"): Konsole --new-tab
   per surface, no tmux. Pros: native tabs, no tmux dependency.
   Cons: loses tmux socket-per-seat infra (the -L <seat> model),
   seat-steer delivery relies on tmux. Breaks the delivery
   contract's pane target. NOT recommended — the -L sockets are
   load-bearing (seat-up, seat-steer, hngh-watch).

## 3. Recommendation: B (tabbed tmux windows)

- Kills the CRITICAL gap 1: `hngh dash` already exists; no
  dash-pane subcommand to invent or maintain.
- Keeps the -L socket model (delivery contract §7.5 intact).
- One change to dashboard-pair-arguments: split-window ->
  new-window, and the pair command is `hngh dash` (not dash-pane).
- Optional polish: the dashboard window gets a distinct window name
  ("[dash]") so `tmux list-windows` and the watcher can find it.

## 4. Verification (after cibo lands the change)

- `bin/hngh dash` (the pair launcher) opens: session exists, window
  1 = agent, window 2 = dashboard rendering live rows (not hanging
  at "Das").
- `tmux -L hngh-dash list-windows` shows two named windows.
- seat-steer still delivers to the agent window (pane target
  resolves on the seat's own socket — the pair session is
  separate; no interference).
- No dash-pane subcommand anywhere in the tree.

## Acceptance

- Pair shape = tabbed windows; gap 1 closed (no missing command).
- `hngh dash` interactive renders immediately (e953777) in the new
  window shape.
- make test green; docs updated.

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes
TUI, 2026-08-09. Card 123 ownership (122 design side).
