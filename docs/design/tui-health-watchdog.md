# TUI-health watchdog — detecting failed init / flawed-trace (card 124, design)

One page. Design-first (operator 23:05: the VALUE is Hngh catching
failed-init and flawed-trace ITSELF, not the human noticing).
Owned by seu per card 123 ownership.

## 1. Problem

Twice the operator observed what seats claimed was working was
actually broken: a dashboard that "renders seat states" but hangs
at "Das", a render "verified" from a fragment. The claim-vs-find
discipline has recurred all day. Card 124 makes the CATCH
mechanized — Hngh detects failed-init / flawed-trace outcomes
instead of only humans noticing.

## 2. What to detect (the two failure classes)

A. FAILED-INIT (the 122 hang): the interactive TUI starts but never
   renders a usable frame. Detectable by: process alive + bounded
   timeout passed + no "ready" marker in output. Mechanized: a
   health probe on the dashboard's lifecycle.
B. FLAWED-TRACE (claim-vs-find): a seat claims outcome X from a
   partial trace (a fragment, a stale capture, an assumed success)
   when the full trace shows Y. Detectable by: the claim record vs
   the evidence record disagreeing. Mechanized: claims carry an
   EVIDENCE POINTER; a checker re-runs/reads the pointed evidence
   and compares.

## 3. Design

### 3.1 Init-health probe (kills A)

- Every interactive surface (dashboard, seat-up spawn, watcher)
  emits a READY MARKER when init completes: dashboard writes
  `state/health/<surface>.ready` (or logs "init complete" line),
  seat-up writes after spawn, watcher after first cycle.
- A HEALTH WATCHDOG routine (117 contract: function of feeds,
  events out) checks: for each surface expected to be up, is the
  process alive AND the ready marker fresh (< TTL)? If alive but
  no fresh marker -> event `surface-failed-init` -> dashboard
  renders it, operator inbox gets a bounded brief (115 format).
- The 122 hang would have been caught: process alive, no ready
  marker, TTL expired -> "dash failed init" before the operator
  had to look.
- TTL default 30s (dashboard renders in <1s when healthy; 30s is
  generous). Config knob per 117 §3 (auto-tunable).

### 3.2 Evidence-pointer claims (kills B)

- A claim that something WORKS carries an EVIDENCE POINTER: the
  file/line/command that proves it (e.g. "dashboard renders:
  fixture test-dashboard-tui.lisp L142 PASS, 45/45"). The pointer
  is part of the claim line (worklog/lane/outbox).
- A TRACE CHECKER routine re-checks pointers on a schedule (or on
  wake): does the pointed evidence still exist and still say what
  was claimed? Cases:
  - pointer missing -> "claim unverifiable" (the claim-vs-find
    failure class — the seat claimed from no evidence)
  - pointer exists but contradicts -> "claim falsified" (event to
    the dashboard + bounded brief)
  - pointer stale (fixture changed since) -> "claim stale"
- The checker is DETERMINISTIC (no model judgment): it compares
  claim line vs evidence file. The JUDGMENT (was this a real
  misstep, what to do) is a separate 115 escalation, human-gated.

### 3.3 Where it lives

- Both are ROUTINES under the 117 watcher layer: init-health-probe
  and trace-checker. Feeds: state/health/ + claim lines. Outputs:
  events (surface-failed-init, claim-unverifiable, claim-falsified,
  claim-stale) -> dashboard (116) + operator inbox (115 brief).
- The dashboard gains a HEALTH view (one more feed — reuses the
  live-feed pattern 92e062b: reads state/health/*).
- No new daemon: these are functions registered with the layer,
  per 117 §4 embedding (Hngh-scope-and-control directive).

## 4. Fixtures (design-for-test)

- init-health: fixture starts a fake surface that never emits a
  ready marker; assert the probe fires surface-failed-init after
  TTL. Healthy fixture emits marker < TTL; assert silent.
- trace-checker: (a) claim with valid pointer -> passes;
  (b) claim with missing pointer -> unverifiable; (c) pointer
  contradicts -> falsified; (d) pointer to stale fixture ->
  stale. All deterministic, no live services.

## 5. Acceptance

- Init-health-probe + trace-checker routines designed (this doc),
  fixture-tested, wired to dashboard health view + operator briefs.
- A re-run of the 122 scenario is CAUGHT by the probe (the exact
  "Das" hang class), demonstrated in a fixture.
- make test green; docs updated.

## Open question (operator)

- Claim verification scope: ALL worklog claims carry pointers, or
  only operator-facing claims (outbox/116/115)? Recommendation:
  operator-facing claims always; worklog pointers best-effort (the
  checker only reports what it can find, never blocks work on
  missing worklog pointers).

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes
TUI, 2026-08-09. Card 123 ownership (124 design side).
