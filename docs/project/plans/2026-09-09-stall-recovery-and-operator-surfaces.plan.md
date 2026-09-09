<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-09 — stall recovery, operator surfaces, lifecycle accommodation

Authorization: operator-directed 2026-09-09. The operator reviewed five
independent performance/dashboard reports (supportive + adversarial, this
session) and directed: autonomous reaction to blockers, direct session
interaction surfaces, subagent observation, notification for important
matters (operator away on paid work all today), and smooth accommodation
of steamdeck availability and desktop restarts. Evidence base: the report
findings cited per step. The executing session folds this directive into
docs/records/ with its first commit.

## Steps

- [ ] 1. Model-outcome demotion in the session launcher. Evidence: all 9
      sessions today (automation/agent-handoffs.md rows 9-17) ended
      rc=0 cancelled cause=bad-execution on unsloth/Ornith-1.0-35B
      (local-bench), burning the full 8/day budget with zero landings;
      the fail-first ladder paced spend down but never demoted the model.
      Change: automation/lib/launch-session.sh (or failfirst state) counts
      consecutive bad-execution cancellations per model; at 2 consecutive,
      demote to the next model in the bench ladder and file an alert row.
      Test-first in the automation suite.
      Verification: suite test covers the demotion counter (2 strikes ->
      next model, alert filed, counter resets on success); full `make test`
      green.
- [ ] 2. Prove the notification send path. Evidence: notify-email.conf
      exists but logs/notify-email.log is empty — no send ever recorded;
      the daily digest said "ATTENTION: 52 alerts in 24h" and the operator
      received nothing on the machine-matters channel. The operator has
      authorized Hngh notifying them for important matters.
      Change: send exactly one test email via scripts/notify-email.py
      marked TEST, verify the send log records it; only if email fails,
      wire the implemented-but-unborn telegram/webhook seam in
      automation/lib/notify.sh and test that instead.
      Verification: one test send recorded in logs/notify-email.log with
      rc=0 (or telegram equivalent); no repeat sends.
- [ ] 3. Budget-governance directive record. Evidence: cap chain
      env OVERNIGHT_MAX_SESSIONS_DAY > inventory sessions-day-max
      (operator authorization 2026-09-07) exhausted at 01:12:38Z today;
      the operator's 2026-09-09 directive is "as few blockers and stalls
      as possible today". Change: record the directive; when the cap
      blocks an operator-priority plan, file an operator-item requesting
      the cap amendment instead of silently waiting or burning filler —
      never amend spend caps unilaterally.
      Verification: directive recorded in the record doc; operator-item
      path demonstrated once in a suite test (no real cap change).
- [ ] 4. Tmux-based subagent observer. Evidence: auto-tiling Konsole
      observer already works (automation/jobs/window-tile.py, POST /tile,
      ui-config tiling.enabled=true) but tails raw s-expr logs; a tracked
      omp-tuned .tmux.conf exists in
      ~/.local/state/git-back-dots/agent-configs/ undeployed; pygmentize
      is installed. Change: deploy the tracked .tmux.conf; add a tmux
      observer launcher (labeled panes, one per session, tailing
      logs/overnight-*.log through pygmentize) registered as a launcher
      key in ~/.config/hngh/ui-config.json and wired to POST /spawn and
      POST /tile like the Konsole templates.
      Verification: launcher spawns a tmux session with one labeled pane
      per running session log and highlighted output; ui-config validation
      passes; suite test covers the launcher template parse.
- [ ] 5. Rebuild the orphaned write-surface UI. Evidence: POST /spawn,
      /tile, /flag are served and validated but have zero served-JS
      callers (grep of dashboard/*.js) — the operator has no UI path to
      set up manual/automated sessions with prompt/context control, their
      stated need. Change: add the controls to the served dashboard
      (spawn form naming a launcher key + session mission/context fields,
      tile button, flag control), preserving the server's rule that the
      client may only NAME a launcher, never supply a command.
      Verification: served page renders the controls and a dry POST
      against the running server is accepted (one /flag call, recorded in
      the ledger); no server changes beyond what exists.
- [ ] 6. Dashboard exposure and data-quality fixes. Evidence:
      dashboard-server.py binds 0.0.0.0:8890 with eight unauthenticated
      POST actions (systemd unit says "phone-accessible on LAN");
      system.json reports tailscale_peers:'0' contradicting its own raw
      state blob (3 nodes); no uptime/boot probe. Operator is remote
      today — remote access must be safe, not LAN-open.
      Change: require a shared token (from ~/.config/hngh/ui-config.json)
      on POST endpoints, or bind non-GET to the tailscale interface;
      fix the peers parser; add uptime/last-boot to the system feed.
      Test-first where the change is parseable.
      Verification: POST without token refused rc=401/403 in a suite
      test; system.json peers matches raw tailscale state; uptime field
      present.
- [ ] 7. Lifecycle accommodation: traps and persistent state. Evidence:
      timeout wraps bili so SIGTERM kills the whole tree (rc=124) with no
      trap handlers in overnight-cycle.sh; no mid-plan checkpoint beyond
      git/checkboxes; failfirst state lives in /tmp/hngh-failfirst and
      resets on reboot. Operator requires smooth safe stop/restart on
      updates and shutdowns.
      Change: trap SIGTERM/SIGINT in overnight-cycle.sh to log the
      in-flight slug and disposition before exit; move failfirst state
      under a persistent path (automation/state/ or
      ~/.local/state/hngh-failfirst) so pacing survives reboots; document
      the restart sequence. No systemd unit changes (critical boundary).
      Verification: suite test simulates SIGTERM mid-beat and asserts the
      breadcrumb + clean exit; state path survives a simulated reboot
      (dir not under /tmp); `make test` green.
- [ ] 8. Steamdeck availability windows. Evidence: hourly 32-deck-facts
      probes file deck-unreachable alerts (rc=255) and the operator
      receives email for what is normal gaming/travel; operator commits
      the deck to weekday 09:00-17:30 EST availability when feasible and
      expects Hngh to recognize unavailability otherwise.
      Change: availability schedule in cadence params (weekday 09:00-17:30
      EST expected; outside it, unreachable is expected-state — no alert,
      dashboard shows "off-duty" instead of down); within-window
      unreachable still alerts. Adjust automation/jobs system/remote
      probes and the digest classifier accordingly.
      Verification: suite test: unreachable outside window -> no alert,
      status off-duty; unreachable inside window -> alert retained;
      `make test` green.

## Execution notes

- Priority order is the step order: 1-3 directly attack today's stall
  (model burn -> notifications -> budget governance); 4-6 are the operator
  surfaces; 7-8 are lifecycle. Steps 1, 2, 3 are mutually independent.
- Inherited guardrails: no provider/credential configuration changes, no
  systemd unit lifecycle changes, no unilateral spend-cap amendments.
  Failing-test-first for every behavior change; full `make test` green
  per slice.
- The two operator-priority plans already in the queue
  (2026-09-09-omp-hngh-integration — acceptance-parse fixed by the
  operator session at 2026-09-09T13:05Z after the router flagged
  step-2-no-verification for ~12h — and
  2026-09-09-automation-schedule-optimization) execute through the normal
  selector; this plan's steps 1 and 3 unblock their throughput.
