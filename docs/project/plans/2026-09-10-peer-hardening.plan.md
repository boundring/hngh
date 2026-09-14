<!-- plan: status=executed risk=normal accepted=2026-09-10T20:01:31Z -->
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

- [x] 1. CI for the automation tier (review finding 2). First
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
- [x] 2. automation/bootstrap.sh + env contract (review finding 1,
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
- [x] 3. failfirst state persistence (review finding 4; state path
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
- [x] 4. Probe-class lint (review finding 3). New suite test
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
- [x] 5. Getting-started page + docs current/historical split
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

- Step 1 landed 2026-09-14: the env-dependent class measured by the
  stripped-env/CI bring-up chase was the hngh-bridge plugin tests
  (the omp plugin lives outside the repo) - skip-guarded in-suite
  under the HNGH_CI=1 marker (ci.yml exports it; guards at
  automation/tests/test-hngh-bridge-plugin.py:31,80,138) instead of
  the originally named CI_HERMETIC. ci.yml carries the test-automation
  job (ubuntu-latest, sqlite3+sbcl added, bootstrap --check prereq);
  kernel job unchanged apart from the session-store fixture seed and
  full fetch-depth for the loop-history guard. Both jobs green on CI
  (run 34806924097, commit 307e958); kernel gate locally green after
  the fleet-manager tailscale stub (candidate 9ca1270a) cured the
  meshed-host env skew that had been blocking kernel commits.
- Step 2 closed 2026-09-14: the machinery landed across earlier residue
  beats (bootstrap.sh + lib/prereqs.sh pass/fail table, env.example as
  the key-names-only contract, config/machine.env(.example) profile
  consumed by cadence/day/06-remote-posture.sh and
  cadence/hour/32-deck-facts.sh). This beat verified the three
  verification items on the step's surface: automation/tests/
  test-bootstrap.sh PASS (table shape, fail-closed on stripped PATH,
  profile override beats the hardcoded default), `bootstrap --check`
  exits 0 on this machine, automation `make test` green. Names diverged
  from the plan text by convention: machine profile is
  config/machine.env (the documented config.env convention), not
  machine-profile.env at the automation root.
- Step 3 closed 2026-09-14: the machinery landed across earlier residue
  beats (lib/failfirst.sh state dir now $AUTOMATION_ROOT/state/
  failfirst with the FAILFIRST_STATE_DIR override preserved, one-shot
  /tmp/hngh-failfirst -> state/failfirst mv-on-migration in
  failfirst_state_file; suite sections d1-d2 cover durable state
  across shells and exactly-once legacy migration). This beat verified
  the three verification items on the step's surface: test-failfirst.sh
  d1/d2 PASS, /tmp/hngh-failfirst empty on this machine (migration
  already naturally done), live ladder state in the durable path
  (failfirst-research: speed=1 oks=51 last=ok), automation
  `make test` green. Plan-note correction: state lives as one
  key=value file per operation under state/failfirst/ (the
  model-demote pattern's durability convention, not a single tsv);
  format and override semantics unchanged.
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
- Step 4 closed 2026-09-14: the machinery landed in an earlier residue
  beat as automation/tests/test-probe-hygiene.sh (committed; wired
  into the automation gate at Makefile:138) - the plan named it
  test-credential-probes.sh, but the landed name is the same contract,
  not a duplicate: every curl in jobs/credential-health.sh joined
  across continuations, exactly one authenticated curl per key-gated
  endpoint var (UNSLOTH_URL, kimi_models_url, ocgo_models_url), the
  deck /health bare GET as the single documented exemption, and a
  fail-closed catch-all for any other headerless curl. This beat
  verified the three verification items on the step's surface:
  test-probe-hygiene.sh PASS against the current credential-health.sh
  (exit 0, all 9 cases ok); a deliberately headerless mutation (kimi
  Authorization header stripped on a /tmp copy) failed the test with 2
  failures as expected; automation `make test` green (exit 0).
- Step 5 closed 2026-09-14: the machinery landed in an earlier residue
  beat (docs/getting-started.md with the four sections - kernel cycle
  transcript captured live, automation beat walkthrough from tick to
  breadcrumbs/ledger, dashboard surface plus the shots caveat,
  prerequisites pointing at bootstrap --check; docs/README.md
  CURRENT/HISTORICAL markers and the getting-started read-order
  entry already committed; the durable link check
  automation/tests/test-getting-started-links.py wired into the
  automation gate at Makefile:59). This beat verified the four
  verification items on the step's surface: the page exists with all
  four sections and cites bootstrap; docs/README.md carries the split
  markers; the link check passes (5/5, every cited path exists); the
  kernel cycle in the transcript re-run live (create-run -> close-run
  -> present, RC=0); automation `make test` green (exit 0). Ceremony
  note: the first drive refused on public-content evidence - the
  page's verbatim STATE.md excerpt carried absolute /home paths (the
  known lesson class); home prefixes elided to ~ with the excerpt
  wording adjusted, second drive green.
