# Operator-gating evolution in hngh (as of 2026-09-15)

## NOW-AUTOMATED (with since-when)

- Certificate-path kernel src mutations (`:wake-mutation` class): machine proceeds
  through propose -> issue-cert -> mutation-check, no separate operator stall.
  Since 2026-09-09 doctrine section 2, narrowed/confirmed by doctrine 2a and the
  landing record (docs/records/2026-09-13-wake-mutation-lane-landing.md;
  docs/records/2026-09-09-operator-flexibility-doctrine.md §2/§2a).
- Session-cap headroom: cap chain env -> cadence-params Inventory row -> legacy 4;
  `sessions-day-max` raised 8 -> 200 by operator authorization 2026-09-09, machine
  tunes concurrency within the cap autonomously
  (docs/records/2026-09-09-budget-governance-directive.md).
- Headless secrets: 1Password service account (`ONEPASSWORD_SERVICE_KEY` ->
  `OP_SERVICE_ACCOUNT_TOKEN`) removed the interactive-unlock stall class since
  2026-09-09 (docs/records/2026-09-09-1password-service-account-interface.md).
- Userspace data writes: machine sessions may write `~/.hngh/` (newspaper, manga,
  wiki, db, dispatch) since the 2026-09-13 directive
  (docs/records/2026-09-13-userspace-home.md; AGENTS.md boundary paragraph).
- Policy self-amendment: hngh may update its own policies via its governance loop
  (certs + green gates + records) without per-change operator sign-off since
  2026-09-09 (doctrine §1).
- Unattended execution generally: overnight routed plans, patrol, slow-units,
  self-review cadence run unattended (automation/cadence/ 10m/1m/30m/5m/day/hour/
  month/week tiers; agent-handoffs.md rows all night 09-14 -> 09-15 are machine-landed).
- Jcode worker permissions: blanket autoApprove replaced by certificate-scoped
  JCODE_WORKER_CERT with refuse-75 fail-closed wrapper and audit lines, landed
  2026-09-14 (automation slice 4eaf0f1; docs/records/2026-09-14-jcode-delegate-controls-landing.md
  family; agent-handoffs 2026-09-14T19:24:55Z).

## STILL OPERATOR-GATED (governing rule)

- Credentials, payments, provider-key activation beyond a recorded grant, public
  surfaces, deletions, security posture: doctrine §1 and §2a closed list
  (docs/records/2026-09-09-operator-flexibility-doctrine.md).
- Kernel gate recertification / ceremony certificate issuance stays operator-bound
  for config changes: "kernel-gates: operator-only" is the only admitted value;
  installs/upgrades and deletes stay operator-run
  (docs/records/2026-09-12-privilege-model.md; services record below).
- Service installs/enables: machinery prints the operator step, never runs
  `systemctl enable`; unsloth-llamaserver is operator-run
  (docs/records/2026-09-12-services-management.md).
- Budget ceiling amendments: caps raised only by explicit operator authorization;
  machine tunes within (docs/records/2026-09-09-budget-governance-directive.md).
- Social/public surfaces: standing policy (docs/records/2026-09-11-social-surfaces-policy.md).
- 1Password operator-side items (UI setup, sudoers install in /etc/sudoers.d):
  operator-only (2026-09-12-privilege-model.md).
- Ceremony push ratification for certain lanes and ambient-mode enablement remain
  operator-approved decisions (docs/records/2026-09-15-swarm-resume-and-ambient-enablement.md).

## Trend line (this week)

Moved operator-gated -> certificate-automated: kernel src mutation class
(09-09 -> 09-13 landing), session caps (09-09), headless secrets (09-09),
userspace data writes (09-13), worker-tool permissions (09-14, now scope-JSON
certs instead of human approval per action). The pattern is consistent: the
operator authorizes a CLASS once, records it, and the ceremony enforces the
instance. doctrine 2a states the principle outright: a parked queue item with an
open certificate path is a routing defect, not a governance outcome.

## Possible inertia-only gates

- Legacy constant 4 in the cap chain is unreachable while the Inventory row exists;
  dead tier, harmless but vestigial (budget-governance record).
- `/etc/sudoers.d` being operator-only is recorded (privilege model), so justified.
- `kernel-gates: operator-only` for gate config changes has record backing but the
  closed-list framing in doctrine 2a (certificate-path slices proceed) sits in
  tension with it; no explicit reconciliation record exists. Candidate for a
  doctrine clarification, not obviously wrong.
- No other unstamped operator gate surfaced in the 2026-09-1x records sampled;
  every gate found cited an operator directive or standing policy record.
