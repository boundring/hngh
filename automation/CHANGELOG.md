# Changelog

## 2026-09-11

- fix: delegated-session beat stall — every launch after the first in a
  beat refused `conflict labels=record-conflict` (rc=75, no session, no
  spend) because dream pass + executor + extra plan slots shared one
  bridge store and hngh records run-1 per store; lib/launch-session.sh
  now gives each launch its own store subdir (run-end matches). Also:
  classify_cause takes the launch rc and classifies a timeout kill
  (rc=124) bad-execution even with a clean log tail, so the respawn
  guard stops refusing timeouts as non-transient. Tests: tests/
  test-ocgo-launch.py, tests/test-causes.py. Record: docs/records/
  2026-09-11-beat-stall-diagnosis.md.

- fix: research-beat writer strips model tool-call syntax and marks
  truncation (corpus-loss cure): capture-side filter (lib/docfilter.py,
  shared signature with tests/test-doc-hygiene.py) applied before every
  digest/docs-research write; empty-after-strip files an alert and holds
  line state instead of landing a findings-less doc; finish_reason=length
  plumbed from the model chain and an over-cap write gets an explicit
  "[truncated at write: ...]" marker (mark_cut convention). Tests:
  tests/test-doc-filter.py (new, make test). Record:
  docs/records/2026-09-11-research-beat-capture-fix.md.

- feat: ocgo session cost reducers - small_model pinned to the free local
  llama-server leg (`unsloth-local/unsloth/Ornith-1.0-9B-GGUF`, env-var
  credentials only; primary agent stays glm-5.3-flash), input-budget
  sections in executor/scout prompts (no whole-file reads of src/main.lisp,
  README, docs/records, STATE.md, lessons tail only; scout results capped
  ~2k chars), and per-session top-3 tool-output burn tee in the emitter
  (`ocgo-attribution.py --burn` -> state/ocgo-agent-burn.tsv, launcher
  wired). Burn attribution + one-change/day config-optimizer verdict
  (FEASIBLE with fences) + bili-on-opencode verdict (VIABLE-NEXT):
  docs/records/2026-09-11-ocgo-cost-tuning.md. Tests:
  tests/test-ocgo-config-cost.py (new, make test), test-ocgo-launch.py
  small_model assertion updated.

- feat: session-executor row armed: opencode (operator word 2026-09-11;
  env HNGH_SESSION_EXECUTOR still overrides).

- refactor: drop lobehub leg (operator decision; history:
  docs/research/2026-09-10-lobehub-*.md, docs/research/2026-09-11-lobehub-grunt-work.md).

- fix: network-down headroom flag now measures the WAN directly —
  jobs/system-awareness.sh probes the loop's own push dependency
  (curl api.github.com, any HTTP answer = up) and flags network-down only
  when that fails; the old (model endpoint fail && tailscale peers 0)
  predicate never probed the network and fired nightly 2026-09-08..09-11
  whenever the local unsloth proxy hiccuped while the operator's peer
  devices slept (routed plan 2026-09-11-routed-system-network-down, root
  cause after 7 undiagnosed parkings 2026-09-04..09-11); regression test
  tests/test-system-awareness.sh wired into make test; disposition
  recorded as research subject fail-20260911-system-network-down.
- feat: hngh's own opencode configuration layer —
  `automation/config/opencode/` (opencode.jsonc OPENCODE_CONFIG target:
  secret-deny block copied verbatim (superset of opencode-safety.jsonc,
  test-enforced), MCP servers hngh/misakanet/codegraph, model +
  small_model pinned opencode-go/glm-5.3-flash, agents `executor`
  (primary, ceremony discipline) + `hngh-scout` (read-only subagent));
  self-steering lessons loop (`append_ocgo_lesson` appends one
  cause-class line per opencode session to state/ocgo-agent-lessons.md,
  capped 200, agents read the tail at session start); executor-branch
  fixes from the first supervised session: child rc no longer masked by
  the emitter, demote counter keyed to the model actually used,
  happy-path lesson skip, key-file credential fallback (mode 600, value
  never echoed). First supervised session run + attributed
  (source=ocgo-agent, 112883 in / 7788 out, $0.0381); record:
  docs/records/2026-09-11-opencode-configuration.md. ACP verdict: defer.
- chore: demote lobehub leg to opportunistic — `lobehub-research-share`
  row 6 -> 0 (0 = never pin; routing reduction, not a spend-cap change;
  caps/tests/telemetry/probe untouched). Re-arm: flip the row to a nonzero
  share, zero rebuild. Per docs/research/2026-09-10-lobehub-worth-it.md s3.

## 2026-09-10

- feat: wall_s telemetry on model legs + lobehub in-pipeline probe (R1
  datum). _model_emit now emits wall_s (curl %{time_total}, captured in
  _post_chat/unsloth_attempt through the same tmp-file subshell escape as
  tmp-postcode.txt) and usage tokens (chat-completions and Responses usage
  shapes; absent = NULL) on every kind=model row. One authorized in-pipeline
  MODEL_PIN=lobehub model_call 64: HTTP 200, wall_s 30.44, tokens_in 24638
  (quantifies the oversized agent prompt throttling the leg). Failing-first
  test cases 12-13 in test-model-ocgo-leg.sh; stub-lib reply gained a usage
  block. Verify: make test green normal + env -i hermetic (rc=0 both).
  docs/research/2026-09-10-passthrough-and-quota-interleaving.md s5 verdict
  updated (append-only); record amendment in
  docs/records/2026-09-10-opencode-go-leg.md.

- feat: opencode-go quota leg with 5h-window pacing (R3). OpenCode Go T2
  GLM (operator-armed 2026-09-10) wired as the fourth quota leg, balanced
  like the kimi leg: cadence-params rows opencode-url / opencode-model
  (glm-5.3-flash, the $60/mo = $12/5h-bucket model) / opencode-cap-5h-calls
  (60) / opencode-research-share (3); ocgo_chat + _ocgo_leg in lib/model.sh
  (Bearer auth, mandatory x-opencode-session header -- the Go gateway 400s
  MissingSessionID without it, live-verified -- shared _post_chat
  MODEL_TIMEOUT), new quota_pace_blocked_5h pacing the trailing 5h window
  (hard cap + soft-pace line, one call of grace; ~$0.005/bounded call ->
  cap 60 ~= $0.30 vs the $12 bucket). Chain: kimi -> ocgo -> lobehub;
  MODEL_PIN=ocgo and research-beat rotation (opencode-research-share 3)
  wired; credential-health gains a Bearer /models probe (probe-hygiene
  lint extended to ocgo_models_url). Verify: new hermetic
  tests/test-model-ocgo-leg.sh (written first, red, then green; caught the
  strftime threshold bug), kimi/lobehub/demote/probe-hygiene suites green,
  make test green except 2 pre-existing OmpBridge reds owned by a sibling's
  in-flight omp-bridge change, env -i hermetic green, bounded live call
  200 completed in 0.67s (docs/records/2026-09-10-opencode-go-leg.md,
  automation/docs/OPENCODE-GO.md).

## 2026-09-08

- feat: fail-first development — the TCP self-tuning engine extends from
  research to the delegated-session cycle. Speeds now map to CONCURRENCY
  (full=3 / standard=2 / cautious=1 concurrent sessions per beat,
  Inventory rows failfirst-dev-concurrent-*) instead of spend: the
  sessions-day-max ceiling stays a hard constraint above the tuning.
  overnight-cycle.sh gates each beat (THROTTLE skips the launch, plans
  stay queued), runs the accepted-plans batch concurrently (steps within
  one plan stay sequential), and records ok/degraded/failed outcomes per
  session from the existing disposition spine. Grow side of the demand
  synthesizer: when the accepted-plans queue runs dry, adopted research
  (recent verdict=adopted dispositions) is synthesized into a proposed
  development plan on the pinned local chain, bounded to
  failfirst-dev-synth-daily/day, admitted through the one accept-plans
  path. Also fixes a latent break: overnight-cycle used model_call
  without sourcing lib/model.sh, so machine plan drafts always failed
  fail-closed. Verify: make test green (rc=0) incl. new
  test-dev-plan-synth.sh and 6 new session-launch concurrency cases.

- fix: automation gate red (rc=2) since the fail-first subtree sync —
  e2b03ce took 6 of archived e9ff90f's 10 files and skipped both
  research test files plus the Makefile line registering
  test-failfirst.sh, so the gate ran pre-fail-first tests against the
  fail-first beat: test-research-governor still pinned the removed
  stamp-gate/defer matrix (case 1: fresh stamp + busy must stay
  silent — the beat now routes), test-research-accel2 still pinned
  research-deck-pin/research-deferred breadcrumbs, and the failfirst
  state machine was never exercised by the gate. Synced the missing
  e9ff90f deltas: both tests restored, `bash tests/test-failfirst.sh`
  registered between accel2 and wiki-health. Verify: make test green
  (rc=0); overnight plan acceptance unblocked.

## 2026-09-06

- fix: per-process tmp names for every dashboard feed writer —
  closes the 2026-09-01 feed-valid:readout.json unparsable alert
  (routed plan 2026-09-01-routed-dash-selfreview-feed-valid-readout.json
  and its 09-02 twin). The 08-30 "atomic writes" fix (760adb5) gave both
  readout writers tmp+rename but a SHARED tmp path: at the daily 11:30Z
  collision (30m 05-readout.sh tier + morning-report
  refresh-dashboard.sh ExecStartPost) writer A's mv renamed the shared
  tmp to readout.json while writer B's open fd still pointed at that
  inode — B's dump then landed INSIDE the live readout.json, leaving
  doc-B + doc-A-tail ("Extra data: line 331 column 1 (char 7876)"),
  corrupt for 30 minutes until the next solo 30m refresh; B's failed
  mv logged the misleading "reader failed; leaving prior readout.json".
  All feed writers now use `<target>.<pid>.tmp` (shell `$$`, python
  os.getpid()) — still `*.tmp`-gitignored, still rename-published — and
  update_dashboard's data.json write (two same-second callers daily at
  12:00Z: ping-hourly + morning-digest) gains the tmp+replace it never
  had. New tests/test-readout-writers.py pins the contract. Verify:
  dashboard-self-review all-clear; make test green.
- fix: automation gate green again after two wall-clock-coupled tests
  and a router dedup gap left the overnight cycle blocking ~21 plans
  with automation-gate-red-rc2. (1)
  `tests/test-router-tick.py` terminal-duplicate fixture used the
  local-time date while `scripts/router-tick.py` routes by UTC — from
  20:00 EDT (00:00Z) to local midnight the fixture landed on the wrong
  day, no same-day collision, no `-2` suffix, gate red. Fixture now
  uses the UTC date. (2) `tests/test-email-qa.py` verdict-line test
  hardcoded the authoring day's yesterday (2026-09-03); it failed
  every run since 2026-09-05T00:00Z. Now regex-matched like its
  sibling FINDINGS test. (3) `live_duplicate` glob
  `*-routed-<ident>.plan.md` never matched suffixed siblings
  (`-routed-<ident>-N.plan.md`), so a live suffixed candidate did not
  suppress refires — the router drafted a fresh one-stepper per hourly
  fire (observed: 2026-09-05-routed-tree-skew-hngh-2..-9,
  gate-check-automation-2/-3). Now a `date-routed-<ident>(-N)?`
  regex over the plans dir; regression test added.

## 2026-09-04

- fix: honest feedback loops, three corrections from the live 2026-09-04
  digest. (1) `scripts/router-tick.py` routed-plan dedup: a first-fire
  alert whose subject already has a non-terminal routed plan younger
  than HNGH_ROUTER_DEDUP_HOURS (default 12h) no longer drafts a
  duplicate one-stepper — the alert row still lands in reports.md, a
  `router | plan-dedup` crumb counts suppressions per day, and >=3
  dedups of the same subject in one day escalate an operator-visibility
  row (once/day). Window-aged or terminal (executed/rejected) plans
  route fresh on a suffixed slug, never overwriting; DRY_RUN=1 prints
  the decision and writes nothing. The agent-stall candidate template
  now asks for concrete verifiable outcomes (old session gone from
  supervision state, handoff brief file, replacement tool activity)
  instead of bridge-run mechanics transcript sessions don't have.
  (2) `scripts/email-digest.py` pace rubric: 0 steps in 24h with
  pending accepted plans is "stalling (0 steps in 24h; N plans
  pending)", not "steady"; 0 steps with an empty queue is "idle (queue
  empty)"; the progress section gains "routed one-steppers: N accepted,
  M executed (24h)" from plans.json slug dates. (3)
  `jobs/agent-supervision.py` grounds a session's own end-of-life
  marker: a transcript whose final line is a session_exit event is
  terminal — never "stalled (awaiting-operator)", never re-alerted, no
  false "recovered" row (the omp-impl-phase3-9d5ab9 dead session
  re-alerted daily because the exit marker was never read; the
  transcript shows a 7m-hung bash tool call then session_exit at
  23:14Z). Roguelike auto-replace stays bridge-only — the
  transcript-session replacement gap is parked with evidence in the
  kernel report queue (`supervision-replace-park:transcript-stalls`)
  and docs/records/2026-09-04-transcript-stall-no-replace.md. Tests:
  tests/test-router-tick.py dedup/window/escalation/DRY_RUN cases,
  tests/test-queue-progress.py pace + one-steppers cases, new hermetic
  tests/test-agent-supervision.py (exited terminal vs ask-stall
  control); Makefile runs the new suite.
- feat: operator-grade email notifications (operator direction 2026-09-04:
  answer-at-a-glance digests, summaries before dense sections, an
  "important enough" alert rubric, and a cyclical self-optimizing loop).
  `scripts/email-digest.py` restructured to operator reading order —
  HEADLINE TL;DR first (status OK/ATTENTION + 24h alert count; what
  changed: commits/plan-step deltas/research; spend today vs yesterday
  vs the $10/day target; action needed yes/no + the one item), then
  operator items, progress (movers-first live plans capped at 15 with a
  dashboard pointer, queue depth, one-line pace verdict rising/steady/
  stalling from the existing delta math), research, commits (top 5 per
  repo, one line each, "+N more" pointer), alerts (24h, one line each,
  "none — quiet window"), budget (spend + trend; telemetry capped), and
  a footer pointing at the digest file, dashboard :8890, and how to act.
  Long sections open with a one-line "Section summary:"; output is ASCII,
  every line ≤78 columns; list rows are truncated, never wrapped.
  Redaction duty (credentials-posture §4): the composer compare-and-
  redacts anything matching the conf's smtp `pass` value before printing;
  the secret is never printed or logged. `jobs/telemetry-report.py` now
  prints "session-cost total: $X" when the db carries cost data (the
  digest headline's spend source). `scripts/notify-email.py` gains
  classify_alert + a `classify --text` verb: ranked first-match rubric —
  IMMEDIATE (park/critical, service-ctl actions, unsloth serving
  down/recovered, agent-stall, git-push failures, credential/config
  touches, ceremony/verdict failures, kernel tree-skew, budget cap) vs
  DEFER-TO-DIGEST (gate flaps, ui-audit nits, repeat-crumbs,
  feed-validity one-steppers; default digest-only so noise never spams);
  HNGH_NOTIFY_IMMEDIATE=0 forces digest-only. `lib/notify-email.sh
  alert_row()` still writes the row ALWAYS and now emails only
  immediate-class alerts (conf-absent path still emits the one-a-day
  dormant crumb); `scripts/accept-plans.py`'s direct relay routes through
  the same rubric. NEW `cadence/day/13-email-qa.sh` + `scripts/
  email-qa.py`: daily adversarial QA of yesterday's digest (TL;DR head,
  summaries on long sections, no empty sections, headline/alerts
  consistency, <120 lines, no conf-password value) — verdict appended to
  `logs/email-qa.log`, findings file one optimization report row per day
  (identity-deduped); procedural, no LLM call. Tests: `tests/
  test-notify-email.py` extended (classify rubric incl. kill switch +
  CLI verb; headline/section-order/pace/caps/redaction/width) and new
  `tests/test-email-qa.py` — hermetic, 49 green via `make test`.

- fix: service recognition/recovery retargeted to the real serving path
  (corrective slice; evidence: hngh
  docs/research/2026-09-04-unsloth-launch-config-lane.md) — yesterday's
  slice targeted :8080/llama-server.service, but the model chain speaks
  `UNSLOTH_URL=http://127.0.0.1:8888` and :8888 is served by
  unsloth-studio.service; :8080 has been down in every probe and nothing
  consumes it. `jobs/service-state.py`: PORTS default
  `8888,8080,11434` (:8080 informational — the llama-server launch-config
  lane may host it later), SERVING_PORT 8888, SERVING_UNIT
  unsloth-studio.service, new serving-state classification incl. the
  state-divergence lesson: :8888 up while the unit is inactive ->
  "serving-out-of-unit (hand-launched)" — classified, NO recovery, NO
  alert, one informational breadcrumb per UTC day max; :8888 down + unit
  inactive -> the once-per-day alert (recoverable via service-ctl);
  :8888 down + unit active -> alert variant "check journal".
  dashboard/service-state.json gains the divergence field.
  `cadence/day/11-service-recovery.sh`: primary recovery is now :8888
  via unsloth-studio.service start (one attempt per UTC day, never an
  active unit, no-op while :8888 is up incl. out-of-unit); the
  :8080/llama-server branch removed (llama-server stays in the
  service-ctl allowlist for manual control). unsloth-studio launch
  internals untouched ("not established" per the research doc); no unit
  files edited. Tests: `tests/test-service-ctl.py` extended hermetically
  (fake systemctl, fixture ports, day-dedup, divergence + recovered +
  still-down paths) — 21 tests green.

- feat: 1Password credential seam (contract: hngh
  docs/design/credentials-posture.md §2-§4) — `lib/credentials.sh`
  (`cred_get REF` via `op read` with a 45s cap, `op_ready` session
  check, fail-closed nonzero + one breadcrumb per UTC day max on any op
  failure, `HNGH_OP_BIN` test seam, values never logged) and the first
  migration consumer: `notify-email.py` gains an optional
  `[1password] item = op://<vault>/<item>/<field>` conf section
  (password read at send time from the vault, conf `pass` as fallback,
  fail-closed when neither — the raw password then never touches
  disk). `setup-notify-email.sh --from-1password "<op-ref>"` builds the
  conf from the vault non-interactively (username from the item,
  host/port default smtp.gmail.com:587, test-send PASS/FAIL; the
  interactive mode stays as fallback). Hermetic tests
  (`tests/test-credentials.py`, 1Password precedence + refusal paths in
  `tests/test-notify-email.py`) wired into `make test` — op and SMTP
  always stubbed in tests.

- feat: service recognition (operator grant 2026-09-03) —
  `jobs/service-state.py` read-only probe of the three allowlisted
  `systemctl --user` units (llama-server / unsloth-warm / unsloth-studio)
  plus TCP probes of :8080 (unsloth) and :11434 (ollama); writes
  `dashboard/service-state.json`, mounted at cadence/5m. When :8080 is
  down while llama-server.service is installed-but-inactive it files ONE
  alert row per UTC day max (recoverable via service-ctl).
- feat: allowlisted service control — `scripts/service-ctl.sh` executes
  start/stop/restart/status for the three allowlisted installed user
  units ONLY (operator grant 2026-09-03; contract:
  hngh docs/design/service-management.md). Refuses any other unit or
  lifecycle verb (enable/disable/mask/... stay critical-class) with exit
  2 before any state change; every action writes a breadcrumb + progress
  row (who/what/when + resulting ActiveState); `--json`, `DRY_RUN=1`.
- feat: self-heal wiring — `cadence/day/11-service-recovery.sh` starts
  llama-server.service via service-ctl when :8080 is down and the unit is
  inactive (one attempt per UTC day, never restarts an active unit);
  success files a progress row, persistent failure files an alert with a
  journal hint. Known caveat: the unit's ExecStart has no model args.
- feat: queue-progress telemetry — `scripts/email-digest.py` gains a
  "Queue progress (24h)" section: per live plan step deltas vs the
  previous digest, kernel `docs/project/queue.md` queued-row count, and
  a plan-supply line (accepted plans with unchecked steps). Hermetic
  tests (`tests/test-service-ctl.py`, `tests/test-queue-progress.py`)
  wired into `make test`.

## 2026-09-03

- fix: `scripts/overnight-cycle.sh` session close — the rc=0 disposition
  was `evacuated`, which the kernel refuses as illegal from `:created`;
  every `--run-end` since 08-28 was silently swallowed (`|| true`) and
  every delegated run stayed open in its store. rc=0 now closes as
  `cancelled` (the legal close from `:created`). This was the amplifier
  of the 2026-09-02 stall: a delegated session paused to ask push
  confirmation that the operator's 2026-09-01 standing authorization had
  already granted. Every historical open run record is now closed.
- feat: standing operator authorizations (push origin on-demand, never
  ask the operator, digest may run in report mode) are encoded in the
  `STANDING_AUTH` block appended to every delegated-session beat prompt
  — the cycle never blocks on a human, and neither may its delegate.
- feat: `jobs/agent-supervision.py` transcript phase rule — a quiet
  session whose final assistant turn asks the operator something
  (`confirm`/`shall i`/...) is classified STALLED (awaiting-operator),
  never terminal; transcript scan window widened to the 6h eviction
  horizon so paused sessions stay visible. Selfcheck fixtures added and
  wired into `make test`.
- feat: one-command email setup — `scripts/setup-notify-email.sh`
  prompts (password hidden), writes `~/.hngh-automation/notify-email.conf`
  chmod 600, sends a test email via `scripts/notify-email.py`, prints
  PASS/FAIL plus the Gmail app-password hint; refuses overwrite without
  `--force`. Config-writer contract covered by hermetic tests.
- feat: email digest gains an "Operator items awaiting you" section
  (`scripts/email-digest.py`): the setup one-liner when the config is
  absent, machine-drafted draft plans (newest first, status from
  front-matter), alert rows from the last 7 days via the report-queue
  reader, and overnight runs still open — all with env seams so the
  hermetic tests cover each.

## 2026-08-31

- feat: machine acceptance of proposed normal-risk plans, per the kernel
  contract (hngh docs/project/plans/README.md) — new
  `scripts/accept-plans.py`, wired into every `overnight-cycle.sh` tick:
  a `proposed` plan with runnable Verification steps is auto-accepted
  (`status=accepted accepted=<UTC ts>`, atomic write) when both repos'
  `make test` gates are green; red gates or a missing Verification line
  file an ALERT row naming the failed check; `risk=critical` plans park
  with an alert, never machine-touched. Plan execution is now
  continuous 24/7 — evaluated every tick, no hour/window gating (the
  fix for the 2026-08-30/31 outage: two authored plans sat unexecuted
  for 8 hours waiting for an operator acceptance that the contract
  assigns to the machine).
- fix: `jobs/plan-feed.py` counted steps only in the first 2048 bytes
  (steps_total 0 for the 2026-08-30 plans) and truncated the accepted
  timestamp at the first dash ("accepted": "2026") — now reads the full
  file, counts `- [ ]`/`- [x]` under `## Steps`, captures full
  timestamps.
- test: `tests/test-plan-acceptance.py` — 10 hermetic tests (fixture
  plans, stub gates, stub report-queue, temp dirs only), wired into
  `make test`.
