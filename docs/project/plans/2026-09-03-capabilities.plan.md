<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-03 — operator-directed capabilities: service management, 1Password credentials, browser-messaging line

Authorization: operator-directed 2026-09-03, recorded faithfully in
docs/records/2026-09-03-capabilities-direction.md — (1) Unsloth
management: recognize local Unsloth hosting (API up ~99%, occasionally
halted for updates); long-run Hngh manages Unsloth AND software
generally — stopping/starting services, config and update management;
(2) 1Password: local 1Password is available for credential storage
with an SDK and CLI (`op`); Hngh should manage software like
1Password too, and use it for credentials; security is paramount;
(3) near-autonomous posture: automate any and all "operator steps";
difficulties become lessons and tuning; blockers after that process
get handled with priority above later work; (4) the queue needs more
reliable progress at a steady continual pace; (5) continual, steady
documentation expansion — progress AND coherence of intent; expand
sections as Hngh itself expands; (6) open question: browser-based
messaging automation targeting active logins (Google Messages web,
Discord, WhatsApp) as a near-zero-token-cost channel. The design
contracts land kernel-side as docs/design/service-management.md and
docs/design/credentials-posture.md; the research line lands as
docs/research/2026-09-03-browser-messaging-automation.md. Normal-risk
autonomous work is pre-authorized; critical-class work parks with
operator-facing alerts.

Sources: docs/project/plans/README.md (the contract this file obeys);
docs/design/service-management.md and docs/design/credentials-posture.md
(the design contracts this plan implements, ceremonied 2026-09-04);
docs/research/2026-09-03-browser-messaging-automation.md (the probe
gates step 6/7 re-run); the sibling automation slice 2026-09-03
(hngh-automation jobs/service-state.py, scripts/service-ctl.sh,
cadence/day/11-service-recovery.sh, queue-progress telemetry in
scripts/email-digest.py — declared, NOT yet on disk at authoring time
2026-09-04; every step touching them is verify-on-arrival);
docs/project/plans/2026-09-03-staging.plan.md (avoid duplication —
its steps 2 (bench calibration), 3 (stage sweeps), 4 (unsloth
recovery note), 6 (package-upgrade runbook) already own the bench,
sweep, and runbook work; none of those are repeated here);
docs/project/plans/2026-09-01-operator-items.plan.md (its 9 steps
remain the queue's standing backlog; not duplicated here);
docs/project/roadmap.md stage-4 row (amended 2026-09-04 with the
first-managed-service note); docs/project/backlog.md rows
config-manager, package-manager, credential-rotation,
notify-agent; docs/project/master-plan.md §3 spine + §5 P4
(harness-harness); docs/records/2026-09-03-staging-notes.md and
2026-08-31-continuous-cycle-fix.md (record patterns); evidence
gathered 2026-09-04 read-only: unit states (llama-server disabled,
unsloth-warm disabled, unsloth-studio enabled; all inactive at check
time), :8080 health 000 vs :11434 200, `op --version` → 2.32.1 at
~/.linuxbrew/bin/op, no chromium-family
binary on PATH,
playwright not importable, ~/.config/{chromium,google-chrome} exist.

Grounding notes (evidence over brief, checked 2026-09-04):
- The sibling slice's three files were absent at authoring time; steps
  1 and 3 treat their landing as the precondition and park with the
  exact gap if still absent at execution time.
- The brief's "notify-email.conf chmod 600" is not current state: the
  file does not exist (email channel dormant per lib/notify-email.sh).
  Step 5's first-consumer migration therefore gates on the operator
  providing the SMTP credential into 1Password — itself a promptable
  setup item, matching the near-autonomous posture (directive 3).
- The brief's "unsloth-studio active while :8080 down" was the
  2026-09-03 observation; on 2026-09-04 all three units were inactive
  with unsloth-studio's unit-file state enabled. Steps read live state
  at execution time; the record carries both observations.

Autonomy rule (standing): hngh docs changes land via certificate
ceremony with a green `make test`; hngh kernel src/, tests/, Makefile,
hngh.asd changes are FORBIDDEN to machine sessions — park them with an
alert row instead. hngh-automation script work lands as plain commits
gated by hngh-automation `make test`. Never touch tracked deletions
outside the 48h prune, secrets, or anything touching the security
posture. AMENDED 2026-09-03 operator grant (recorded in
docs/design/service-management.md §3): start/stop/restart of an
ALLOWLISTED INSTALLED user unit (exactly llama-server, unsloth-warm,
unsloth-studio, via scripts/service-ctl.sh) is normal-risk; enable/
disable/mask, unit-file edits, enablement changes, and anything
touching the security posture remain critical-class and park. Hngh
itself starts no daemons of its own — it manages existing installed
software. Machine-owned dirty paths (docs/journal/ current days,
docs/project/reports.md, docs/project/ui-grades.md,
docs/design/ui-evolve/current-overlay.json, .omp/, untracked routed
plans and research docs, queue.md) are never ceremony candidates for a
plan step — the machine's own steps land those.

Paced-cadence contract: beats are bounded at ≤ ~60m wall each; strict
grow↔research alternation per master-plan §4 (a grow beat may not
follow a grow beat, a research beat never writes code); every step
names its own verification and is executable by a bounded delegated
session with no human present; blockers surface as lessons + tuning
first, then take priority over later work (directive 3); this plan
must not run empty — the parked section names follow-on candidates
and step 9 authors the next plan so the queue stays fed (foldback
lesson 1).

## Steps

- [ ] 1. GROW — service-state recognition verified live. Confirm the
      sibling slice landed (hngh-automation jobs/service-state.py
      exists on disk); run the probe read-only (systemctl --user
      is-active/is-enabled + list-unit-files for the three allowlisted
      units, curl the :8080/:11434 health endpoints) and confirm the
      alert classes of docs/design/service-management.md §1 fire
      correctly against the live state (expected today: :8080 down
      while units inactive → class 2; :11434 up → no alert). If the
      sibling slice has not landed, record the exact gap and park this
      step's remainder as an operator-visibility note.
      Verification: a breadcrumb or report row naming each allowlisted
      unit's live state and the fired alert class (or the parked gap
      note naming the missing file); no unit is started, stopped, or
      modified by this step; kernel `make test` green.
- [ ] 2. RESEARCH — unsloth launch-config lane proposal. What
      config.env-driven launch config llama-server.service needs to
      re-host the 35B fleet: model path(s) for unsloth/Ornith-1.0-35B-
      GGUF (the 5/5 bench leader all three days per
      stats/model-bench-2026-09-0{1,2,3}.jsonl), context/port
      arguments, and where the config file should live so the unit
      references it without any unit-file edit (EnvironmentFile= was
      already present-or-absent — establish which from the unit as
      installed, read-only). Output feeds backlog config-manager as
      the first declared config lane (design doc §5). No unit edit,
      no service start.
      Verification:
      docs/research/2026-09-04-unsloth-launch-config-lane.md exists
      with the proposed config.env inventory, the unit's current
      EnvironmentFile state quoted, and an explicit no-unit-edited
      statement; kernel `make test` green.
- [ ] 3. GROW — service-ctl exercised: status read-only, then the
      recovery path when :8080 is actually down. Run
      scripts/service-ctl.sh status for each allowlisted unit
      (read-only verb, always admitted). Then the recovery path —
      only if :8080 is down AND the unit state matches the sweep's
      precondition (installed-but-inactive): one start via the
      allowlisted normal-risk verb, re-probe, and confirm the bench
      re-validation gate (design doc §4) keeps the model lane on
      fallback until the next bench scores the endpoint. If the
      sibling slice's service-ctl.sh is absent, or :8080 is up, or
      the unit is active (nothing to recover), record that state as
      the outcome — no forced exercise.
      Verification: the status outputs for all three units recorded;
      either a completed start→re-probe cycle with the gate behavior
      noted, or a grounded no-action note naming which precondition
      failed; exactly one progress row per action taken; kernel
      `make test` green.
- [ ] 4. RESEARCH — credentials-posture redaction audit. Grep the
      automation surface (logs/, digests, report rows, telemetry,
      breadcrumbs) for any value that should not be there: SMTP
      password material, unsloth token/refresh values, anything from
      the §1 inventory. The audit MUST find zero; a nonzero finding
      is a security-posture incident that parks and alerts
      immediately (priority above later work, directive 3). Also
      verify the redaction duty is stated in every consumer's design
      surface per credentials-posture.md §4.
      Verification: an audit record
      (docs/research/2026-09-04-credential-redaction-audit.md) with
      the greps run, patterns used, and the zero-findings result (or
      the parked incident row with the exact finding and NO value
      quoted); kernel `make test` green.
- [ ] 5. GROW — lib/credentials.sh op-seam implemented; notify-email
      password as first consumer. Implement lib/credentials.sh per
      credentials-posture.md §2 (cred_get REF via `op read`,
      `op whoami` session check, fail-closed file fallback with a
      one-crumb-per-day breadcrumb). First consumer: the notify-email
      SMTP credential — IF the operator has loaded it into 1Password
      and `op whoami` succeeds. If the CLI is signed out or the item
      is absent, park with the exact operator step quoted ("run `op
      signin`; add the SMTP credential as item <name> field
      password") — one park, no retry loop. hngh-automation plain
      commit gated by its `make test`; no secret value in the commit,
      logs, or test fixtures.
      Verification: lib/credentials.sh exists with cred_get +
      fallback path; either notify-email.conf is produced from
      1Password at send time with a successful end-to-end dormant→
      live transition recorded, or the parked operator step quoted
      verbatim; hngh-automation `make test` green; kernel `make test`
      green.
- [ ] 6. RESEARCH — browser-messaging admit/park gate. Re-run the
      probe battery from
      docs/research/2026-09-03-browser-messaging-automation.md §1
      (browser binary on PATH, `python3 -c "import playwright"`,
      profile-dir existence only). Verdict: ADMIT the prototype slice
      (step 7) if playwright is importable and a chromium build is
      available to it; PARK otherwise, naming the missing install as
      the operator-procedural step (playwright install is a
      normal-risk hngh-automation dependency, but browser acquisition
      on this host has not been granted — record which boundary
      applies). Also record the credentials rules the profile will
      inherit (credentials-posture.md §4).
      Verification: the probe results quoted in a research note
      (or appended to the 2026-09-03 research doc as a dated
      re-probe section) with the ADMIT/PARK verdict and the exact
      missing piece if parked; kernel `make test` green.
- [ ] 7. GROW — browser-messaging prototype slice (gated on step 6's
      ADMIT; otherwise this step parks and records). Google Messages
      web ONLY, Playwright persistent context with an isolated
      profile, ONE message to the operator ("hngh browser channel
      proof, <timestamp>"), behind an explicit enablement note in the
      slice itself. Profile dir 700, never backed up, never copied;
      failures recorded as lessons, never retried against a refusing
      service. If Google Messages web requires QR pairing, park with
      the pairing step quoted as the one human step (directive 3:
      automate operator steps or surface them as prompted setup
      items).
      Verification: the enablement note + the send attempt outcome
      recorded (delivered, or the parked step naming the pairing/
      install gap); no second message, no other service, no operator
      profile touched; hngh-automation `make test` green (slice code)
      and kernel `make test` green.
- [ ] 8. RESEARCH — queue-drain verification beat. The operator's
      directive 4 asks for more reliable progress at a steady
      continual pace: measure it. Metric: unchecked-step counts per
      accepted plan (2026-09-01-operator-items, 2026-09-03-staging,
      this plan), routed one-stepper throughput per day from
      reports.md rows, and the queue rotation state (queue.md Next +
      Scale section). Conclude with a paced-cadence verdict: is the
      daily step-completion rate steady, rising, or stalling — and
      the single highest-leverage fix if stalling (candidates:
      beat length, plan step granularity, sibling-slice dependency
      ordering).
      Verification:
      docs/research/2026-09-04-queue-drain-verification.md exists
      with per-plan step counts (checked/unchecked), the observed
      daily completion evidence, and a named verdict; kernel `make
      test` green.
- [ ] 9. GROW — wrap, lessons, author-next-plan (the plan-supply
      law). Land this plan's lessons into the foldback/lessons path
      (expected candidates: the sibling-slice verify-on-arrival
      pattern, the park-with-exact-operator-step pattern from steps
      5–7), and author the next plan file
      (docs/project/plans/<date>-<slug>.plan.md, status=proposed)
      covering the parked follow-ons below plus the newest executed
      evidence, so the queue never runs empty. Fold in directive 5:
      the next plan includes a documentation-expansion step (design
      docs grow as Hngh grows).
      Verification: the next plan file exists with contract-valid
      front-matter (first line `<!-- plan: status=proposed risk=normal
      accepted=- -->`) and every unchecked step carrying an indented
      Verification line; kernel `make test` green.

Parked (not in this plan, recorded for the operator; follow-on
candidates for the next plan's author):
- The unsloth token-pair migration into 1Password — LAST in the
  migration order (credentials-posture.md §3), only after the refresh
  path is proven against the vault; requires the operator's
  `op item create` for the pair.
- Architecture A (CDP attach to the operator's running browser) —
  rejected for now on security-posture grounds (research doc §2);
  revisiting it is critical-class and operator-decided.
- Discord and WhatsApp channels — behind Google Messages proving the
  pattern; each adds ToS/fragility surface.
- `enable`/`disable` posture changes for the allowlisted units (e.g.
  enabling llama-server at boot) — critical-class under the amended
  grant; operator-decided.
- Config-manager implementation beyond the first declared lane —
  stage-4 row territory; the launch-config lane research (step 2)
  feeds it.
