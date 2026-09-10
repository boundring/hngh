<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-10 - peer hardening: install path, CI, state hygiene, docs

Operator-directed 2026-09-10. Converts the peer-standard review
(docs/research/2026-09-10-peer-standard-review.md) into machinery;
findings are peer-gates. Cross-references instead of duplicates: the
MCP surface stays routed as omp-hngh-integration step 1 (this plan
only upgrades its priority rationale - the LobeHub adoption path
needs it); gate serialization under parallel beats stays routed as
automation-schedule-optimization step 5; the sprawl simplifications
(verification contract, autonomy reference, continuity template,
routed-stub template) stay routed as the curator's work items per
docs/research/2026-09-09-queue-dependency-inventory.md. Ordering by
leverage: steps 1-3 are peer-gates; 4-5 polish. One ceremony per
beat; existing priority plans outrank this one.

## Steps

- [ ] 1. CI for the automation tier (review finding 2). First
      measure hermeticity: run `cd automation && make test` under a
      stripped environment locally (env -i with PATH only; no systemd
      user env, no /tmp/hngh state, no hngh units). Whatever fails is
      env-dependent: mark those tests in this plan's execution notes
      and SKIP-GUARD them in-suite (skip when the marker env var
      CI_HERMETIC=1 and the dependency is absent) rather than breaking
      CI. Then extend .github/workflows/ci.yml with a second job:
      ubuntu-latest, bash + python3 preinstalled, `cd automation &&
      make test`. The kernel job stays as-is.
      Verification: stripped-env local run recorded (failures listed
      here as env-dependent, each guarded); ci.yml gains the
      automation job; a pushed commit shows the automation job green
      on CI; `make test` green in both repos.
- [ ] 2. automation/bootstrap.sh + env contract (review finding 1,
      the blocks-peers one). The script: (a) declares the env
      contract as key NAMES hngh requires (read from a documented
      list - OPENCODE_API_KEY, KIMI_AI_KEY, LOBEHUB_KEY, OP_SERVICE
     _ACCOUNT_TOKEN, etc. - names only, values never printed);
      (b) validates presence of each dependency (op CLI, bili, omp,
      sbcl, python3, git) printing a pass/fail table; (c) reads
      machine-specific defaults (DECK_IP, DECK_HOST, tailnet peers)
      from a new automation/machine-profile.env (config.env
      convention), replacing the hardcoded defaults in
      cadence/day/06-remote-posture.sh and cadence/hour/32-deck-facts.sh;
      (d) prints what remains operator-manual (1Password grant,
      plasma env import, systemd enable) instead of pretending it
      automates them. Test-first: automation/tests/test-bootstrap.sh
      runs bootstrap in a sandboxed HOME with PATH stripped per case
      (missing op, missing bili, missing sbcl) asserting the table
      shape, non-zero exit when a required piece is absent, and the
      machine-profile override taking precedence over the hardcoded
      default.
      Verification: suite test covers table shape, fail-closed exit,
      profile override; bootstrap --check exits 0 on THIS machine;
      `make test` green.
- [ ] 3. failfirst state persistence (review finding 4; state path
      only - the trap handlers stay in stall-recovery step 7's lane).
      Move the failfirst state dir from /tmp/hngh-failfirst
      (automation/lib/failfirst.sh:38) to
      automation/state/failfirst/ (durable across reboots; the
      model-demote.tsv pattern). Preserve the key=value state-file
      format and the FAILFIRST_STATE_DIR env override. Migrate: on
      first read, if the new path is absent and the old exists, copy
      it. Test-first: extend automation/tests/test-failfirst.sh with
      a persistence case (state survives a simulated restart: new
      shell reads the same file; old-dir migration copies once).
      Verification: suite test covers persistence and one-time
      migration; `make test` green; the live ladder state carries
      over on the next beat (breadcrumb evidence).
- [ ] 4. Probe-class lint (review finding 3). New suite test
      automation/tests/test-credential-probes.sh encoding the rule:
      every curl in automation/jobs/credential-health.sh that targets
      a key-gated endpoint must pass an Authorization header built
      from the same resolution chain its real caller uses; the deck
      /health probe is exempt (no credential gate, health-only);
      headerless curls against key-gated endpoints fail the test.
      Run it in the automation gate (Makefile) so future probes
      inherit the rule.
      Verification: lint test green against the current
      credential-health.sh; a deliberately headerless mutation fails
      the test (checked once, locally); `make test` green.
- [ ] 5. Getting-started page + docs current/historical split
      (review findings 7-8). New docs/getting-started.md: one kernel
      cycle transcript (create-run through close-run with real
      scripts/hngh output), one automation beat walkthrough (a tick
      from breadcrumbs to ledger), the dashboard screenshot path, and
      the honest prerequisite list pointing at bootstrap from step 2.
      docs/README.md gains a two-marker split: CURRENT (read-order +
      getting-started) vs HISTORICAL (records/, journal/, research/)
      with a one-line rule for which to trust.
      Verification: docs/getting-started.md exists with all four
      sections and cites bootstrap; docs/README.md carries the split
      markers; every path the page cites exists (link-checked by
      script); `make test` green.

## Execution notes

- Steps 1-3 are the peer-gates; 4-5 are polish. Land one ceremony
  per beat; a slice is committed when its own Verification holds.
- Step 1's hermeticity measurement is the gate for the CI job - do
  not merge a red automation CI job; env-dependent tests get skip
  guards in the same slice.
- Step 3 touches the same failfirst file stall-recovery step 7
  (lifecycle traps) reads - coordinate beats, do not land both in
  the same ceremony.
- The MCP server is NOT re-routed here: it lives in
  omp-hngh-integration step 1 and this plan only raises its priority
  rationale (LobeHub's MCP-client adoption path makes it the peer
  surface).
