# opencode executor wiring with attribution emitter

Date: 2026-09-11. English/ASCII. Design: docs/research/2026-09-10-opencode-
agentic-surface.md (ship order s9). Commit: feat: opencode executor wiring
with attribution emitter (design 2026-09-10).

## 1. Install (toolchain)

- Package name verified from opencode.ai/docs install section: the npm
  package is `opencode-ai` (script install is offered but the desktop
  convention is npm global; same lane as bili).
- Installed `npm install -g opencode-ai@latest` -> 1.18.30 at
  ~/.npm-global/bin/opencode (prefix confirmed ~/.npm-global via ~/.npmrc).
  npm's install-scripts policy required
  `npm config set allow-scripts=opencode-ai --location=user` (postinstall
  fetches the real binary); noted in the update script.
- `command -v opencode` -> /home/bricker/.npm-global/bin/opencode;
  `opencode --version` -> 1.18.30.
- Update coverage: automation/scripts/hngh-omp-update.sh gained an
  `opencode-ai` section (one install line + version echo), matching the
  billion-context block's style.

## 2. Smoke (no auth, no paid calls)

- `opencode --help`: run flags confirmed on the installed binary —
  `run [message..]`, `-m provider/model`, `--format default|json`,
  `--dir`, `--auto` ("auto-approve permissions that are not explicitly
  denied (dangerous!)").
- `opencode models` works with NO auth (local registry): the Go provider
  id is `opencode-go` and the quota model is present as
  `opencode-go/glm-5.3-flash` (27 opencode-go/* models listed). No
  `opencode auth` run; no key file touched. The auth.json has no
  OpenCode Zen/Go entry (design s2) — provider credentials for the
  executor remain operator-side.
- Free-surface probe: one bounded `opencode run --format json` against
  the LOCAL unsloth provider (zero paid spend) captured the real event
  stream: `step_finish` parts carry
  tokens{input,output,reasoning,cache} and cost per step, every event
  carries sessionID — this is the attribution surface the emitter
  consumes, verified against reality rather than assumed.

## 3. Attribution emitter (R2 — landed before any agent session)

- automation/jobs/ocgo-attribution.py: parses the launcher's
  --format json event stream (per-session tokens/cost from step_finish
  parts), falls back to ~/.local/share/opencode/opencode.db message rows
  for sessions the stream only names (assistant rows carry
  cost/tokens/modelID/providerID/time — measured schema), emits through
  jobs/telemetry.py's exact write path (never a second schema): one row
  per session, kind=model, source=ocgo-agent, identity=<opencode session
  id> (idempotent — already-attributed sessions skipped), model=
  provider/model. Only spend inside the trailing 5h window (the pacer's
  window) is attributed. Also extracts the stream's text parts verbatim
  into the classifier's plain-text log (design risk 2: json escapes
  would break lib/causes.sh keyword matching). Best-effort: any fault
  exits 0 so attribution can never fail a session's cleanup.
- Pacer honesty: lib/model.sh quota_pace_blocked_5h now counts BOTH
  sources on the shared bucket (`ocgo,ocgo-agent`) — the $12/5h cap sees
  HTTP-leg and agent-internal spend together; zero pacer changes
  otherwise (design s6).
- Tests: automation/tests/test-ocgo-attribution.py (hermetic; fixture db
  with the real message-table schema + real-shaped event stream): fresh
  sessions emitted with correct source/tokens/cost/model; stale (outside
  5h) and foreign (not hngh-keyed) sessions emit nothing; rerun is
  idempotent; plain-text extraction for the classifier.

## 4. Executor row + launcher branch

- cadence-params.tsv: `session-executor` row added with EMPTY value —
  omp stays the executor; empty/absent = omp fail-closed;
  env HNGH_SESSION_EXECUTOR overrides the row (standard precedence).
  Values: omp | opencode | auto (auto is phase 2, not wired).
- lib/launch-session.sh: one branch at the invocation site. When the
  executor resolves to opencode (and the opencode binary + opencode-model
  row both exist — else fail-closed fallback to omp with a breadcrumb):

      OPENCODE_CONFIG="$AUTOMATION_ROOT/config/opencode-safety.jsonc" \
        timeout "$TIMEOUT_S" opencode run --dir "$ROOT" --format json \
        -m "opencode-go/<opencode-model row>" --auto "$body" \
        >"$ROOT/$log.json" 2>&1
      python3 jobs/ocgo-attribution.py "$ROOT/$log.json" \
        --plain "$ROOT/$log" --telemetry <standard store>

  OPENCODE_CONFIG is pinned (design risk 1) to
  automation/config/opencode-safety.jsonc — a COMMITTED COPY of the
  desktop's secret-deny permission block (*.env*, auth.json, *.key,
  ~/.gnupg, ~/.ssh/id_* denies; never referenced by path so operator
  config churn cannot widen machine-session permissions). Re-copy on
  operator-side deny-block changes.
- Everything else unchanged, verified by reading launch-session.sh end
  to end: bridge run-start (HNGH_LOADOUT identical), context pack, budget
  row, bridge run-end, classify_cause on the plain log, model-outcome
  demotion — the wrapper consumes only rc, the log path, and
  classify_cause(log), exactly as the design measured.
- Tests: automation/tests/test-ocgo-launch.py (hermetic, stubbed
  binaries): opencode branch launches with --auto and the pinned safety
  config, emits the R2 telemetry row from the stubbed stream, writes
  plain text at the classifier's log path; default (empty row) stays
  omp; opencode-unavailable falls back to omp fail-closed.

## 5. Default off / what remains operator-side

- The row is EMPTY: dormant-until-armed, matching every other leg's
  fail-closed convention. NO opencode agent session has run.
- Operator-side later steps: (a) provider-credential config for the
  executor (`opencode auth login` or key wiring — cert territory per the
  budget-governance guardrails); (b) the first supervised opencode
  session (research-class, per design s9); (c) arming the row.

## 6. Verification

- cd automation && make test green (includes the two new test files;
  identifier lint clean after adding the provider-defined OPENCODE_CONFIG
  to the lint's deliberate-literal list).
- `env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/local/bin make test` green.
- `opencode --version` -> 1.18.30; `bash -n launch-session.sh` clean
  (make test's bash -n pass covers it).
