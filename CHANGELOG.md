# Changelog

All notable changes to Hngh are documented here. Entries are dated by the
day they were recorded. Nothing has been released yet; development work
lives under Pre-release / early development until the first release.

### 2026-09-22

- Router alert class channel landed: `report-queue --class critical`
  (durable `class:` meta + visible `class-upgrade:` re-fire rows,
  ceremony commit), router feed excludes critical-class/first-line
  critical-word/`class-upgrade:` rows from routing, and
  `operator_item`/`alert_row` carry an optional class arg through.
  Routed mem-caps candidate parked (`plan-dispose --cause obsolete`).
  Record: `docs/records/2026-09-22-router-alert-class-channel.md`.

#### Added

- **RAM guardrails + dashboard automation controls**
  (docs/records/2026-09-22-ram-guardrails-landing.md): after two
  amdgpu-memory-exhaustion Plasma crashes, the automation surface now
  (1) recovers unsloth-studio AND the dashboard from dead units once
  per UTC day with an operator-stop guard, (2) gates heavy cadence
  tiers and overnight spawns on a MemAvailable floor
  (`memory-gate.sh`, fail-closed), (3) adds a token-gated dashboard
  `system/service-act` route (start|stop|restart, allowlisted units,
  pre-written audit row) executing only `service-ctl.sh`, and (4)
  shows a UTC-day memory peak on the System page. Systemd MemoryHigh/
  MemoryMax caps remain parked on the operator with SLA + halt
  conditions (report alert afd8588b).

### 2026-09-21

#### Fixed

- **Filesystem record transport probe/read race fails closed**
  (docs/records/2026-09-21-filesystem-toctou-fault.md):
  `src/adapter/filesystem.lisp` `read-lines` converts record-file open
  failures to TRANSPORT-FAULT, so a file passing `probe-file` but
  failing open (the TOCTOU window in `existing-keys`/`store-entries`)
  can no longer surface a raw error. Failing test first
  (`tests/adapter/test-filesystem.lisp` probe/read-race checks); full
  gate green.

- **Filesystem record transport refuses read-eval syntax**
  (docs/records/2026-09-21-filesystem-read-eval-hardening.md):
  `src/adapter/filesystem.lisp` `read-line-form` now binds
  `*read-eval*` to NIL, so a store line carrying `#.` reader syntax is
  refused as a TRANSPORT-FAULT instead of executing code at replay
  time. Failing test first (`tests/adapter/test-filesystem.lisp`
  read-eval check); `make test` green at 2,932 checks.

- **Plaintext credential cutover to 1Password + vault freshness rung**
  (docs/records/2026-09-21-vault-cutover-freshness.md): the 26 API keys
  remaining in plaintext (`env_vars.sh`, `unsloth.env`, systemd user
  environment, 14 vestigial `EnvironmentFile` drop-ins) were purged in
  favor of the 1Password vault `Hngh Secrets`, read on demand through
  `automation/lib/opv`/`automation/lib/secrets.py` (27/27 reads
  verified). An 11-char ZHIPU_API_KEY prefix embedded in
  `docs/project/reports.md` (journal-harvest leak, alert 7796e3e3) was
  redacted. Key rotation freshness rung added:
  `automation/lib/vault-freshness.py` treats the vault item
  `updated_at` as the rotate date and `credential-health.sh` files
  `vault-freshness` alerts past the OLA (default 180d), fail-closed.

### 2026-09-20

#### Added

- **Strict-reader contract for the MCP research TSV feed**
  (docs/design/strict-reader-spec.md,
  docs/records/2026-09-20-mcp-research-feed-strict-reader-spec.md):
  skip-and-count contract for `automation/mcp/hngh_mcp_server.py::
  read_tsv` — malformed rows (wrong field count, embedded raw
  tab/newline, CR, NUL, undecodable bytes) are skipped, counted per
  category, logged to stderr, and surfaced as stable counters; cap
  operates on usable rows only; pinned-header/all-malformed feeds are
  fatal (`isError`); CLI wrappers embedding the reader exit 0/1/2; no
  silent repair. Failing test sketch landed
  (`automation/tests/test-mcp-read-tsv-strict.py`: 7 passing
  characterizations of today's fail-open/fail-locked seams, 14
  contract tests skipped until the reader implements the spec).
  Live census 2026-09-20: the contract changes no live row (lines
  file uniformly 4-field; the 72 legacy-width disposition rows pad,
  none skip).

#### Fixed

- **publication-review findings digest scrubbed through the
  single-source path redaction**
  (docs/records/2026-09-20-publication-review-findings-digest-scrub.md):
  `automation/jobs/publication-review.py` wrote the
  `PUBLICATION-REVIEW-<date>.md` digest with raw machine-local paths —
  the header embeds the manga/dispatch source paths and adversarial
  FAIL lines embed artifact paths. Run-proven first in a sandboxed
  `HNGH_REPORT_ROOT`/`HNGH_HOME_DIR` invocation (exit 0, no ambient
  writes outside the sandbox, `scrub_grep` census 3 leak lines), then
  fixed: `findings_md()` routes its whole output through
  `automation/lib/scrub.py` `scrub_paths()` at the emission point (the
  patrol.py pattern) — marker convention, URLs survive as wire data.
  stdout `FAIL <artifact> <cause>` keeps the raw path by machine
  contract (day-wrapper basename mapping plus the report-queue
  sink-side guard are the persistence scrub). Red-first tests in
  `automation/tests/test-publication-review.sh` section (e) (header +
  FAIL-line leak assertions via `scrub_grep`); 11/11 green,
  `test-scrub-module.py`/`test-patrol.py` unchanged green.

### 2026-09-19

#### Fixed

- **Doc-secrets gate was blind to docs/; committed OpenCode key redacted**
  (docs/records/2026-09-19-secret-hygiene-opencode-key-gate.md, bead
  hngh-dzf): `automation/tests/test-doc-secrets.py` computed its scan root
  as `automation/` instead of the repo root, so `docs/` — the tree that
  leaked in 2026-09-11 — was never scanned; and a raw key sharing a line
  with a `<redacted` note was blanket-allowed. Fixed: repo-root scan,
  placeholder masking instead of line skips, generic `sk-` prefix with
  value-suffix requirements, 8 red-first tests. Redacted the dead
  `sk-7ZXC…` OPENCODE_API_KEY from the lobehub research doc (probed live:
  upstream 401 Invalid credential = rotated; current env key answers 429
  weekly-limit = live) and a raw retired-system `ghp_…` fixture token from
  the secret-scan report. Stale `op whoami` prescriptions in
  credentials-posture.md and keyring.md replaced with the
  `op account list` / service-account seam per the 2026-09-09 record.

### 2026-09-17

#### Changed

- **notify-email outbound scrub: the send path redacts alert bodies
  itself** (docs/records/2026-09-17-email-outbound-scrub-seam.md):
  `scripts/notify-email.py send` now scrubs `--subject` and body
  through the machine-local token family (automation/lib/scrub.py,
  one family) before SMTP compose — the report-queue row's sink-side
  redaction never touched the email bytes, and emitters were not a
  reliable pre-redaction source (census of 54 `--add` callers closed
  in the record). Fail-closed: unreadable scrub module -> exit 2, no
  send. classify stays the vocabulary rubric. Red-first tests in
  `automation/tests/test-notify-email.py` (`OutboundScrub`, 5 cases).

#### Changed
- **Fixture containment: kernel tests can no longer contaminate the
  kernel .git/config**
  (docs/records/2026-09-17-fixture-containment-gitdir.md): the
  2026-09-13 rehearsal-lane incident (rehearsal-lane-20260913T000118
  log L159 sweep: hostile GIT_DIR exported over the kernel repo turned
  test-verify-candidate.py's bare fixture `git config`/`git commit`
  into kernel-repo writes, leaving author Fixture, kernel commits
  ba6b3905+d2d8f515) is closed as a class. Kernel test fixtures pin
  identity per commit invocation (`git -c user.*=`), strip
  GIT_DIR/GIT_WORK_TREE at import, pin global/system config to
  /dev/null, and verify-candidate carries a loud kernel-checkout
  guard; the loop-history guard pins all reads to its own repo's git
  dir. Automation test fixtures got the same GIT_DIR strip (7 python
  suites, 9 shell suites). Acceptance: full `make test` green with
  GIT_DIR pointed at a protected canary; canary .git/config
  byte-identical after.

- **Cert disposition surface closure: orphaned candidate certs are
  moot by mechanism**
  (docs/records/2026-09-17-cert-disposition-surface-closure.md):
  the gate follow-up on cert `a3286b78` (declared only on unreachable
  commit `5d9bd1ff`) resolved with no ledger surgery: no cert-id
  registry exists anywhere (kernel store, automation ledgers, MCP
  queue/dashboard surfaces, either home), commit-subject-on-main is
  the whole registry, and every orphaned cert's content landed via a
  reachable twin (`a25e82bb`/`cf36b6f2`, plus out-of-window
  2026-08-25 pairs `65820f40` and `9e1b74ee`). Corrects the
  wip-family-census wording that framed the external 64-hex cert id
  as a git object (`git cat-file` rejects it). Gate-inventory
  candidate-label row annotated; no code or ledger changes.

- **Research-doc writer redaction: crystallized-doc title gap closed**
  (docs/records/2026-09-17-research-doc-writer-redaction.md):
  the crystallized research-doc writer emitted the RAW lines-TSV
  question text as the docs/research title with no path-token guard
  (docfilter covers injection + char cap only; the model body's
  chokepoint scrub never sees the title). Cure: fail-closed redact_home
  over title AND body before any write, digest copy included; broken
  scrub module = redaction-failed outcome (alert, blocker escalation,
  no write). Red-first full-beat test proves the unguarded writer
  leaks and the cured one does not. Back-redaction: the TSV sweep
  tool's scope widened to tracked docs/research/*.md; 153 docs swept
  through the redact_home tilde family (forward-only, history
  untouched, tilde forms and URLs preserved; id slugs in filenames
  stay as immutable research keys). `make test` now gate-checks the
  full scope, so a newly committed raw research doc goes red.

- **Certificate ephemerality of record; mint-time persistence adopted
  as remediation direction**
  (docs/records/2026-09-17-certificate-ephemerality-of-record.md):
  the confirmed architectural finding is landed as a record. Kernel
  certificates are single-use stdout renders with no store write
  path; the commit-subject content-hash is their only durable trace
  (299 labeled commits), the loop-history guard's candidate check is
  format-only (tests/scripts/test-loop-history-guard.py:193), and
  post-hoc label verification is structurally impossible. Adjudicated
  a design gap, not a known limitation: no recorded decision chose
  ephemerality. Mint-time certificate receipts (store record.lisp) +
  a `label-unbacked` patrol checker are the adopted direction
  (proposal: docs/records/2026-09-17-candidate-reconciliation-closure.md);
  cross-linked from gate-inventory and decisions.md. Kernel src/
  untouched.

- **Progress-kind path redaction: sink widened to alert+progress**
  (docs/records/2026-09-16-progress-kind-path-redaction.md):
  the deferred progress-kind question from the 2026-09-16
  boundary-redaction work is closed. `scripts/report-queue` now
  redacts `--add progress` text through the same machine-local
  prefix class as alerts before id/row/body derivation (candidate
  79eb4733, ceremony-admitted 10/10), while repo-relative paths
  stay untouched. The research-beat line-ingest seam is redacted
  at the source before id/slug derivation and TSV append
  (2e51d01b), closing the id-slug leak
  (`fail-20260914-Where-exactly-in-home-bricker-Projects-e`).
  Forward-only: the 319 historical progress rows and 9
  research-lines rows keep their absolute paths; no history
  rewrite. Includes the 48-site `--add` call-site census.

- **Supportive-record fact corrections of record**
  (docs/records/2026-09-17-supportive-record-fact-corrections.md):
  four adversarial findings reconciled against primary evidence.
  Alert `fb894f8d` latency is ~6 minutes (pair 04:04:04Z/04:04:51Z,
  alert 04:10:41Z; the "~4h06m" and the reconciliation record's own
  "hours after" wording were -0400/UTC misreads, both corrected).
  `e916af9e`/`8e376ff2` are window day 0 (2026-09-13 20:20/20:21
  -0400), not 2026-09-16 — the per-command identity cure was
  demonstrated day 0 and not propagated for ~3 days, strengthening
  the cleanup-lag reading. The `bypass-j-adjacent-credentials`
  provenance chain is closed by verbatim transcript reads: gate-injected
  by rose (4 nodes), expanded by ant into 4 `bypass-j-adj-*` children,
  gate ox later injected 6 more adj-* gap nodes — supportive-5's
  list was right modulo the prefix, Caveat A answered machinery-grown.
  The plan's 07:15Z handoff row citation is fixed to its real location,
  automation/agent-handoffs.md (never lived in automation/STATE.md).

- **Ceremony commit identity pinned at the drive layer**
  (docs/records/2026-09-16-identity-seam-reconciliation.md, "Kernel
  ceremony commit identity"): the certificate-bound `git commit` from
  `scripts/ceremony-drive` (executed by the kernel mutation executor,
  `src/adapter/mutation.lisp` `command-for`) inherited ambient
  `.git/config` identity — 42 window commits rode the anonymous
  Fixture identity, and a fresh clone without repo-local config would
  ride the operator's personal identity. The drive now exports
  `GIT_AUTHOR_*` / `GIT_COMMITTER_*` defaults
  (`hngh-machine <automation@hngh.local>`) before the closed loop
  runs; explicit caller env keeps precedence. Kernel `src/` untouched
  (fixed-argv contract intact); covers every ceremony-drive caller
  (patrol gate-cure, omp-bridge --ceremony, direct sbcl). Test-first:
  `tests/scripts/test-ceremony-drive-commit-identity.py` red-proven
  pre-fix (leaky-ambient fixture repo committed as the leak identity),
  wired into `make test`. The fix itself landed through the pinned
  ceremony, attributed hngh-machine.

- **Refresh path obeys the credential-seam contract** (2026-09-17-refresh-argv-body-and-refreshfile-gate.md): the unsloth refresh curl interpolated the single-use refresh token VALUE into the `-d` argv argument (world-readable in /proc/<pid>/cmdline for the whole call); the body is now staged to a mktemp file (`-d @"$btmp"`, path on argv, value never — the chat-leg pattern), keeping the wire bytes, `%{http_code}`/`-o` semantics, and breadcrumbs identical. REFRESH_FILE gets the mode-600 stat gate every other credential-file read has (sixth reader; refusal `refresh key file too open (chmod 600 required)`, fail-closed before the read). test-probe-hygiene.sh now hard-fails any interpolated `-d "{...$var...}"` curl body in both lint targets and positively pins the staged refresh form, closing the -d blind spot in the zero-credentials-on-argv contract. Red proofs: value on argv + 0644 refresh file POSTed, pre-fix.

- **Refuted publish-claim corrected in the sink-bypass record**
  (docs/records/2026-09-16-report-queue-sink-bypass-closure.md, §What
  this does not cover): the sentence "Existing leaked bodies (976f09b8,
  3342f352, 71d03fef) are already in git history and on the public
  origin" was adjudicated REFUTED (publish-claim audit,
  2026-09-17T04:37Z) — the three body files are untracked, never
  committed to any ref, absent from all reflogs (zero fragment matches
  in `git rev-list --all --reflog --objects`), and at the 04:37Z audit
  existed only as unreachable stash/WIP objects (blobs 1d34a452,
  ea88947d, d4452432 held by WIP commits dcacfb74, 59f08875,
  91ab48ca), since pruned by gc (10:13Z re-verification: all six
  objects gone). Same correction folds in the closed follow-up: the
  20 pre-2026-08-27 tracked-era alert bodies at 6529562b contain zero
  raw `/tmp/hngh-*.store` paths (each has 2 `stale-store:` mentions,
  no raw path), so published history never exposed this record's
  actual leak class. Residual exposure is the live untracked
  working-tree files only; scrub decision stays operator-visible.

### 2026-09-16

#### Changed

- **Boundary redaction extended to the canonical scrub family**
  (docs/records/2026-09-16-scrub-consolidation-single-source.md): the
  alert-kind sink guard previously covered only the "home" and "tmp"
  absolute-prefix families; the consolidated family (mirrored from
  automation/lib/scrub.py — kernel code never imports automation/,
  parity is pinned by tests on both sides) also dies on the "Users"
  and "root" absolute-prefix families (any user segment or rest),
  scheme-relative //host/home/..., and credential URL userinfo
  (user:pass@host -> [redacted]@host), bare forms included. Rendering
  keeps the readable tilde convention. Red-first:
  test_alert_redaction_covers_full_canonical_family in
  tests/scripts/test-report-queue.py.

- **Report-queue sink bypass closure: identity, evidence, and every
  body write pass the boundary guard** (docs/records/2026-09-16-report-queue-sink-bypass-closure.md):
  the kernel ledger sink redacted only alert TEXT; pathy tokens still
  landed verbatim via `--evidence` (live leak: the 976f09b8 plan-accept
  pytest traceback) and `--identity` (live leaks: the 3342f352 /
  71d03fef `stale-store:/tmp/…` metas), direct `write_body` callers
  bypassed the guard entirely, and occurrence appends were unguarded.
  Identity/evidence are now rewritten at the argument boundary BEFORE
  the dedup window lookup on every kind (dedup key = redacted form;
  pre-guard raw stored metas are matched through the same rewrite so
  no duplicate rows strand), `write_body` defaults to redacting
  first/full text (progress argv keeps the per-kind carve-out), and
  `set_body_evidence` + both append paths pass through the guard.
  Red-first contract cases in `tests/scripts/test-report-queue.py`
  (24/24 OK); sibling sink consumers verified through the real script
  (evidence dedup, cap-block, router-feed, oversight/config-backup
  redact probes, patrol) all green.

- **Digest mega-block writer census: every daily-digest writer routes
  through the one scrub seam** (docs/records/2026-09-16-digest-writer-census-scrub.md):
  complete sweep of the automation tree found four writers of
  `archive/digest/<date>.md` (ping-hourly block + digest-ledger mega
  line, gdelt-news block, patrol morning rounds) and seven sidecar
  per-artifact files; `git-auto-land.py` (named by the gate) does not
  exist anywhere in the tree, history, or homes. The three unguarded
  writers now scrub free text through `digest-ledger.scrub_paths`
  (the single identity seam): ping-hourly writes its block via the new
  `automation/lib/digest-block.sh` (`append_news_block` /
  `digest_scrub_all`), gdelt `render_block` scrubs each rendered line,
  and patrol `morning_report` + `findings_md` scrub FAIL detail
  strings. Red-first tests per writer (`test-digest-append-scrub.py`
  new, `test-gdelt-news.py`, `test-patrol.py`); fix-at-writer chosen
  over fix-at-reader so new digest readers cannot leak by default.

- **Token-file reads gated to exactly 0600 (kernel reader)** (docs/records/2026-09-16-token-file-0600-gates.md):
  `scripts/grade-interface` read the reviewer conf's `token-file` with a
  bare `read_text()` and no permission check — a 0644 token was silently
  trusted and sent in the Authorization header. New `read_token(kv)`
  helper stats the file first and fails closed (`token file too open
  (mode NNNN); chmod 0600 required`, exit 1) before any read or send;
  the value travels through a `with`-block read. Test-first
  (`tests/scripts/test-grade-interface-token-mode.py`, mirroring
  `ProbeTokenMode`): 0644 refusal, 0600 control, missing-file loudness.
  The three automation-side readers of the same class
  (manga-vision.py, model.sh remote_chat, credential-health.sh
  probe_token) landed in the free-commit lane with their own red-proven
  suites; landed through the ceremony as bf5e9b75.

- **Launch-session provider key argv transit eliminated** (docs/records/2026-09-16-launchsession-key-argv-elimination.md):
  the opencode executor branch of `automation/lib/launch-session.sh`
  spawned the child via `env "KEY=<value>"`, putting the provider key
  VALUE on env(1)'s argv (readable in `/proc/<pid>/cmdline` for env's
  pre-exec lifetime; the child's own argv was always clean). The spawn
  is now a literal per-provider prefix assignment
  (`KIMI_API_KEY="$oc_key" ... "${oc_cmd[@]}"`) over a command array —
  no intermediate argv, and the launcher's own environment stays
  untouched for the other legs. Test-first in
  `automation/tests/test-ocgo-launch.py`: an argv-recording env stub
  pins all three provider legs (opencode-go/kimi/zai) red under the old
  spawn, green under the prefix, with key delivery asserted intact.

- **Probe-model-route token file mode enforced** (docs/records/2026-09-16-probe-token-mode-check.md):
  `scripts/probe-model-route` `reachable()` now stats the reviewer conf's
  `token-file` before reading and refuses (ValueError, one-file exit 1)
  anything not exactly 0600, closing the loose-perm-secret hole that the
  kimi/ocgo/zai readers in `automation/lib/model.sh` already closed;
  test-first (`tests/scripts/test-probe-model-route.py`
  `ProbeTokenMode`: 0644 refusal + 0600 control with a stubbed urlopen).

- **Notify-seam token argv exposure closed** (docs/records/2026-09-16-notify-token-argv-exposure.md):
  `automation/lib/notify.sh` telegram and webhook sends now carry the
  secret-bearing URL through the stdin curl config (`curl -K -`,
  `url = ` line) instead of argv, so no token sits in
  `/proc/<pid>/cmdline`; non-secret args stay on argv, fail-closed
  breadcrumb behavior unchanged, stub-curl suites assert argv/stdin
  separation (test-first, red then green).

- **Accepted-risk dispositions recorded for the credential-argv sweep candidates**
  (docs/records/2026-09-16-risk-dispositions-cred-argv.md): the three
  accepted-risk-candidate classes from the 2026-09-16 sweep now carry
  explicit, evidence-backed dispositions instead of silent carry-over —
  STEER_MODEL URL stays on curl argv as operator-trust-class config with a
  binding no-embedded-key requirement added at the site (and a verified
  reason NOT to convert to `curl -K -`: newline/quote in the value injects
  following stdin lines as curl config directives); git-push.sh failure
  text accepted after empirically verifying git strips userinfo from
  push/fetch stderr across DNS-failure, connection-refused, and HTTP-401
  classes (git 2.55.0, raw-token grep 0 in all three); notification/event
  TEXT on argv accepted under the recorded no-credential-values invariant.
  Docs + one site comment; no behavior change.

### 2026-09-15

#### Added

- **Doctrine reconciliation record** (docs/records/2026-09-15-doctrine-reconciliation-kernel-gates.md):
  kernel-gates operator-only (host grant layer) and flexibility
  doctrine 2a (authorization routing layer) documented as layered, not
  contradictory; zoom-gating inertia flags closed.


#### Added

- **Swarm-resume mission completed; ambient mode enabled (garden-only)**
  (docs/records/2026-09-15-swarm-resume-and-ambient-enablement.md):
  the interrupted 2026-09-14 exploration graph was recovered and
  re-driven in 15 gentle batches to 56 evidence artifacts including
  both parent syntheses (megastructure viz ladder; history/upcoming
  view designs); ceremony-bound implement nodes parked for the
  operator. Ambient mode enabled scoped (ocgo, 75k/day, 30m min
  interval, proactive work off) and verified through a first
  gardening cycle; quota-check tooling added at ~/.hngh/tools/
  (outside the repo).


#### Fixed

- **Loop-history guard 526cd3f exemption cure completed**
  (docs/records/2026-09-15-loop-history-526cd3f-exemption-cure-completed.md):
  the 2026-09-14 gate-cure of portfolio commit `526cd3fd` had left the
  `KNOWN_EXEMPTIONS` table with two entries for the same commit -- the
  stale `526cd3f` declaration (wrong patch-id `4496b336…`) and an
  uncommitted `526cd3fd` re-declaration -- reding the safeguards suite
  (`registered patch-id drift for 526cd3f`). Merged into one `526cd3f`
  entry with the verified patch-id `5b6840df…`; both guard suites green
  at the certificate-bound commit `30966c38`
  (`hngh: candidate 785e57b1…`), pushed.

#### Added

- **Viz payload schema validation seam**
  (docs/records/2026-09-15-viz-schema-validation-seam.md):
  `automation/jobs/viz_schema.py` — one stdlib-only validator (no
  jsonschema) for the dashboard viz payload families (`graph/1`,
  `patrol/1`, `history/1`) with `validate(payload_text, tag) ->
  (ok, detail, warns)`, a public `SCHEMA` table, per-family adapters,
  and a CLI (`--schema TAG payload.json`) whose contract is rc 0 accept
  (warns on stderr, never fatal), rc 2 fail closed, rc 1 usage. Fail
  closed on: malformed JSON; missing/non-string/wrong/unknown `schema`;
  unknown envelope keys; missing required fields; wrong types; duplicate
  node ids or entry keys; self-loop edges; dangling edge endpoints;
  nested payloads behind unknown keys. Additive tolerance is warn-only:
  unknown scalar keys inside nodes/edges/entries, unknown
  rel/state/kind values. Envelope keys fail closed (versioned surface).
  Known gap gated, not papered over: `graph-data.build()` does not
  stamp `"schema": "graph/1"` yet, so live /graph.json fails closed
  until the one-line stamp lands. Suite:
  automation/tests/test-viz-schema-seam.py (32), plus the pre-existing
  history acceptance gate (16), and the sibling patrol (23) and
  version (14) gates.

### 2026-09-14

#### Added

- **Jcode session/swarm nodes in the operations graph**
  (docs/records/2026-09-14-graph-jcode-sessions.md): `automation/jobs/
  graph-data.py` emits a `jcode-session` node per jcode session file and
  a `swarm` hub per coordinating session (coordinates/hosts/spawns
  edges, optional works-on into the kernel). Same 4-state vocabulary;
  malformed session files surface as alerting nodes instead of being
  skipped; default output is scoped to 24h-active sessions plus
  parent-linked ones with an `all_sessions` builder escape. Injectable
  sessions dir keeps the suite hermetic; tokens=N stays reserved until
  a real token source exists. Suite:
  automation/tests/test-graph-data.py (`JcodeSessionNodes`).

- **Graph viewer absorbs jcode-session/swarm kinds + tab-visible auto-load**
  (deep-task node sg-viewer-rendering;
  docs/records/2026-09-14-graph-view-kind-absorption.md): the
  dashboard operations-graph view (`automation/dashboard/
  graph-view.js`) renders the two new node kinds — size-map entries
  and filter chips, state colors/legend untouched — and auto-refreshes
  /graph.json every 60s through the shared HnghPoll helper, gated on
  the graph panel being the active tab so a parked tab never fetches.
  Contract tests in tests/test-dashboard-p0.py; producer-side
  emission of the kinds is a sibling change.

- **Graph viewer two-shell layout (density mitigation)**
  (deep-task node sg-layout-density;
  docs/records/2026-09-14-graph-view-two-shell-layout.md): the default
  feed actually carries ~350 nodes (124 jcode-session + 226 kernel-side),
  so the viewer moves jcode-session/swarm nodes onto a secondary outer
  fibonacci shell (radius grows sublinearly with their count; kernel
  side keeps the origin shell, kernel at origin). Camera default, reset
  button, and the 2D-fallback scale re-fit to the outer shell. With no
  session nodes the layout is byte-identical to the legacy algorithm —
  executed-invariant regression tests (new `run_node` helper in
  tests/test-dashboard-p0.py) pin both properties; min pairwise
  distance on the real feed improves 14.4 → 31.4 world units.

- **Graph feed refresh path proven + `all-sessions=1` plumbing**
  (node sg-refresh-wiring; docs/records/2026-09-14-graph-feed-refresh-wiring.md):
  `automation/tests/test-graph-feed-refresh.py` pins the `/graph.json`
  refresh contract end-to-end over an ephemeral-port server — 30s cache
  reuse without a rebuild, fail-soft to the last good graph when the
  builder raises (cold start still fails closed), and pass-through of
  unknown node kinds (`jcode-session`, `swarm`) unmodified.
  `automation/dashboard-server.py` now forwards `?all-sessions=1` to
  `graph_data.build(all_sessions=...)` with its own cache slot, so the
  builder can adopt the extended session-shaped graph without further
  server changes.
- **Work-graph feed + gantt plan reality + story view skeleton**
  (plan 2026-09-09-work-graph-visualization, steps 1-4;
  docs/records/2026-09-14-work-graph-feed.md; direction:
  docs/design/work-visualization-direction.md): `automation/jobs/
  plan-feed.py` now emits the work graph — per-plan steps arrays and
  an edges list (unlocks/feeds/parked-because) into
  `dashboard/plans.json` beside byte-compatible summary fields,
  failing closed per plan with an alert row on a parse error. The
  gantt renders accepted/executing plans as step rows (filled = done,
  pulse = next unchecked, blocked-by from real edges, park-cause
  chips; estimates still labeled projections, step checkmarks the
  facts) and the new story view renders today's chapters (accepted,
  steps-completed with commit-hash footnotes from real evidence,
  blockers, parks) with one dry aside per section and the a11y
  findings folded in. Comic/animation renderers are later rungs on
  the same graph. Suite: automation/tests/test-plan-feed-graph.py,
  automation/tests/test-story-view.py, wired into make test.

#### Changed

- **kglobalaccel journal patrol row promoted propose -> restart-unit**
  (automation tier 2026-09-14): the operator ran the propose-recommended
  command (`systemctl --user restart plasma-kglobalaccel.service`) by
  hand, confirmed the fix, and asked for automation coverage of that
  situation. The `kglobalaccel-dead` row now auto-restarts via a new
  `unit=` guard token that pins the operator-verified unit (the row's
  regex captures the DBus name, not the systemd unit), keeping the
  restart-loop guard at max=2 per UTC day -- re-fails beyond that alert
  for human eyes instead of masking a deeper fault.

### 2026-09-13

#### Added

- **generate-publication reads the migrated telemetry store**
  (userspace-home layout contract 2026-09-13): the three
  automation/dashboard/telemetry.db sites (the dispatch_numbers read,
  the day-story spend meter, and the prose citations) now resolve
  ~/.hngh/db/telemetry.db through the HNGH_HOME_DIR seam (call-time
  env read; the automation tier's hngh_home.py stays userspace-only,
  not imported by kernel scripts), and the journal's public-edition
  pointer moved from docs/dispatch/ to ~/.hngh/dispatch/. Failing test
  first: tests/scripts/test-generate-publication.py proves the meter
  reads the seeded home db (calls=1, spend=1.25) under HNGH_HOME_DIR;
  live smoke against the real db reads 60 calls / $8.72 for
  2026-09-13. Landed through the certificate ceremony.
- **:wake-mutation certificate action lands** (operator authorization
  2026-09-13; plan 2026-09-13-wake-mutation-src-mutation): the closed
  mutation vocabulary admits `:wake-mutation` (src/adapter/mutation.lisp
  `+mutation-actions+` plus a fixed command-for template; closed
  certificate-action set in src/domain/governance.lisp), binding the
  rung-17 wake surface — one certificate, one wake, one pinned peer,
  fixed argv ("hngh" "wake-peer" <run> <pins-file> <peer>) behind the
  mutation executor port, refused on stale or missing facts. The
  operator-flexibility doctrine (section 2a) and the AGENTS.md boundary
  paragraph are amended: certificate-bound kernel mutations need no
  separate operator stall; park only actions with no certificate path.
  Queue row wake-mutation-lane done; landing record
  docs/records/2026-09-13-wake-mutation-lane-landing.md.
- **Presentation pass 1 records** (plan 2026-09-09-presentation-pass-1,
  step 5; direction docs/design/presentation-direction.md): a
  docs/records/ entry (2026-09-13-presentation-pass-1-adoption.md)
  closing out the pass — the direction adoption, the rungs 1-2 front
  door and docs spine, the guarded flavor layer (one epigraph per
  major document), and the publication spine surfacing in
  docs/publication/book.md, each with its commit anchors. The record
  also names what stays open: the drifted 2026-09-12 daily journal
  and rungs 3-7 of the direction doc as future-plan surface.
- **Userspace data home `~/.hngh` adopted** (operator directive
  2026-09-13; layout contract: `newspaper/<date>/`, `manga/`, `wiki/`,
  `db/`, `archive/`, `dispatch/`, append-only `catalog.tsv`): user data
  — newspaper article copies, digest archives, dispatch editions,
  telemetry.db, manga/imagegen outputs — now lives outside the repo.
  Writers resolve paths through the new `automation/lib/hngh_home.py`
  and `lib/common.sh` (`HNGH_HOME_DIR` override; `hngh_catalog`
  appends manifest rows). Secrets, credentials, and kernel run stores
  stay in `~/.hngh-automation/` (the documented two-home split);
  kernel/gate/certificate state never moves there, and kernel `src/`
  knows nothing of either home. Policy updated in AGENTS.md,
  `docs/README.md`, `automation/README.md`, `~/.hngh/README.md`, and
  the `.omp/` hngh skill.
- **Quota legs: Z.AI leg and every-window pacing** (operator
  directive 2026-09-13): `lib/model.sh` gains `zai_chat` /
  `zai_pace_blocked` (Z.AI GLM Coding Plan gateway, 5h + fixed-Monday-
  weekly windows) and `ocgo_pace_blocked` (OpenCode Go 7d + monthly
  windows) — every product window is now gated, tightest wins, and
  pacing is enforced at the launch branch itself so direct
  `launch_session` callers cannot land an unpaced call.
  `launch-session.sh` and `lib/ocgo-delegate.sh` route
  PROVIDER=opencode-go|kimi|zai with per-leg agents and attribution;
  `config/opencode/opencode.jsonc` carries the executor-zai role;
  window caps live in `config/leg-budgets.tsv` and
  `automation/cadence-params.tsv`.
- **Newspaper paid-cost conversion** (operator directive 2026-09-13;
  automation/CHANGELOG.md carries the full entry): GDELT headline
  polish becomes a deterministic slug normalizer (the paid
  per-headline model call is gone), article generation pins the LOCAL
  leg only with a per-session token budget, and a new
  `jobs/newspaper-edition.py` + `cadence/hour/41-newspaper-edition.sh`
  builds one edition per UTC date inside the operator sleep window,
  idempotent via `edition.json` and fail-closed with a retry next
  tick; editions live under `~/.hngh/newspaper/<date>/`.

#### Fixed

- **Automation test suite is load-independent and fast** (operator
  directive: tests must never be a repeated blocker). Audit found the
  suites already stub their endpoints (PATH-shimmed curl, local stub
  servers, seeded loadavg files) with three environment leaks, now
  closed:
  - `tests/test-imagegen-submit.sh`: stubs `IMAGEGEN_LOADAVG_FILE`
    (and moves the `rocm-smi` VRAM stub early) so the production
    load/VRAM gates in `jobs/imagegen-submit.sh` are exercised against
    fake idle and fake busy signals -- the load gate gained a
    deterministic behavior check (busy stub -> exit-0 skip, zero
    endpoint calls) and the suite no longer reads the host's real
    `/proc/loadavg`, which had turned its eight managed-start checks
    into environment-gated flakes under desktop load.
  - `tests/test-installer.sh` / `tests/test-permissions.sh`: sandbox
    stubs for `systemctl` and `curl` -- under `env -i` the real
    binaries stalled ~2s per call on D-Bus/health timeouts (x12 per
    installer run); tests assert installer behavior, not host
    systemd/service state. test-installer 25s -> 0.6s,
    test-permissions -> 0.7s.
  - `tests/test-plan-identity.py`: per-run `TMPDIR` so accept-plans'
    gate lock never collides with a concurrent real gate evaluation
    on the host ("gate-lock-busy" flake).
  Plus `tests/test-research-governor.sh` lock-hold trimmed 5s -> 2s
  (still outlasts RESEARCH_LOCK_WAIT=1). Full `automation && make
  test` measured 128s before; after, exit 0 deterministically
  regardless of host load (measured wall reported in the workstream
  record).

### 2026-09-11

#### Added

- **Interactive installer skeleton** (`install.sh` at the repo root +
  `automation/lib/platform.sh`): one-command public install face that
  delegates the fail-closed core to `automation/bootstrap.sh`, detects the
  system package manager (pacman/apt-get/dnf/zypper/apk) with a per-manager
  prereq package map, checks systemd --user availability and the python3
  3.12 floor (read-only), polls editor/browser/desktop/JS-toolchain
  preferences only on a TTY (env overrides win; defaults otherwise), records
  choices to `automation/config/installer-choices.json` (gitignored), and
  prints - never runs - optional companion installs and the systemd enable
  step. Installs nothing itself; no secrets; no privilege escalation
  (grep-sentinel-tested). `automation/tests/test-installer.sh` added to
  `make test`; design decisions and the unverified-distro honesty markers in
  `docs/records/2026-09-11-installer-skeleton.md` (peer-review finding 1
  rung one).
- **opencode executor wiring with attribution emitter**
  (docs/records/2026-09-11-opencode-executor.md, design
  docs/research/2026-09-10-opencode-agentic-surface.md): opencode
  installed (npm `opencode-ai` 1.18.30, update script coverage), the R2
  attribution emitter (jobs/ocgo-attribution.py) that turns opencode's
  local session spend into kind=model source=ocgo-agent telemetry rows
  through the standard write path (5h pacer now counts ocgo +
  ocgo-agent on the shared bucket), one `session-executor` launcher
  branch (opencode run --format json + pinned copied secret-deny
  OPENCODE_CONFIG; bridge/budget/log contract unchanged), and its
  tests. Row is EMPTY: default stays omp, dormant-until-armed — no
  opencode agent session has run; first supervised session remains
  operator-side.
- **omp-hngh full integration** (plan 2026-09-09-omp-hngh-integration,
  steps 1-11; docs/records/2026-09-11-omp-integration.md): omp
  sessions in this repo now see hngh through a five-tool read-only
  MCP server (automation/mcp/hngh_mcp_server.py), an automatic orient
  brief injected at session start, the `hngh_propose` plugin tool
  writing plan files with status readback (omp-bridge
  --propose/--plan-status), a project skill, executor/scout agent
  definitions, the live research feed, and a dashboard Plans tab
  (queue + accepted plans + last ceremony commit). Kernel stays
  side-effect-free: all omp-facing code lives in automation/, .omp/,
  and ~/.omp/; no daemons.
- **Feedback auto-apply for quick theme/format items**
  (docs/records/2026-09-11-feedback-apply.md): the apply slice of the
  operator interactivity loop — jobs/feedback-apply.py (30m cadence
  drop-in) applies whitelisted [quick] css-theme/data-format feedback
  (font/gap/margin/padding +/−2px clamped to +/−16px from a recorded
  baseline, explicit colors; max 5 appended rules per beat) to
  dashboard/style.css, files inspection report rows for correction
  items (named check run, never an edit), leaves everything else an
  unapplied operator item, and carries a one-deep `--revert-last`
  restore path via dashboard/feedback/APPLIED.md +
  state/feedback-applied.tsv. 9 hermetic tests wired into make test.

#### Fixed

- **Two omp-bridge post-hoc certifications** (`a2f4d0e`, `31768d2`
  declared; cure candidate this entry,
  docs/records/2026-09-11-omp-bridge-post-hoc-certification.md): the
  integration plan's --propose/--plan-status commits landed without
  candidate labels, reding the loop-history guard and the kernel gate
  for two days. Both declared by name in the guard's exemption table
  per the 2026-09-06 decision; the final script content is re-bound by
  this candidate. History not rewritten.

### 2026-09-10

#### Added

- **Automation tier in CI** (.github/workflows/ci.yml): a second
  `test-automation` job installs bash + python3 + sqlite3 (jq/curl/git
  preinstalled) and runs `automation/ make test` — the 40-test machine
  suite, verified hermetic in a bare environment (env -i, PATH=/usr/bin:/bin,
  exit 0). Peer review finding 2 (docs/research/2026-09-10-peer-standard-review.md):
  CI previously tested the kernel only; the tier that does the live damage
  ran only on the operator's desktop.
- **Probe-hygiene lint** (automation/tests/test-probe-hygiene.sh, wired
  into the suite): guards the probe-measures-itself class — every curl in
  jobs/credential-health.sh targeting a key-gated endpoint (unsloth,
  lobehub, kimi) must carry Authorization: Bearer; the deck /health probe
  is the single documented bare-GET exemption. Fail-closed on new
  headerless curls. Peer review finding 3; lesson from the five-day
  kimi-401/lobehub-404 self-probe incident.

### 2026-09-09

#### Changed

- **Notify-email secret path moved to 1Password headless**
  (automation/scripts/setup-notify-email.sh): the conf now stores an
  `op://` item reference instead of the raw SMTP password ("password
  sourced from 1Password at send time"); the vault gate swaps
  `op whoami` (broken under desktop-app integration) for
  `op account list`, and `--force` is now honored in any argument
  position (regression-tested in
  automation/tests/test-notify-email.py). Interface contract for the
  operator's 1Password service account:
  docs/records/2026-09-09-1password-service-account-interface.md.

### 2026-09-07

#### Added

- **Automation tier import** (`b881186` subtree merge;
  docs/records/2026-09-07-automation-subtree-import.md): phase 2 of
  the repo-merge plan — hngh-automation imported as `automation/` via
  `git subtree add --squash` on top of the P1 machine-data quarantine
  (222 tracked files, zero machine data; pack 4.04 MiB after gc).
  Path references, the 37 systemd units, and the old remote are
  untouched (P3–P5 queued).

#### Fixed

- **Loop-history guard vs parentless commits** (`2aec814`
  `hngh: candidate 7a3dfa8…`): the guard test crashed with exit 128
  on the parentless git-subtree squash root and, past the crash, would
  flag its unprefixed import paths as code-surface touches. The diff
  helper now resolves parentless commits against the empty tree, and
  squash roots are skipped by rule (content is judged at the merge
  commit where paths carry the `automation/` prefix). Guard policy
  unchanged; 81 commits checked, 0 violations.

### 2026-08-30

#### Added

- **Lessons & fold-back** (`1f04b5b` machine docs wave;
  docs/records/2026-08-30-lessons-and-foldback.md): the 2026-08-30
  doc-suite audit folded back into the kernel docs — the closed
  requirement-kind list corrected to 24 kinds (autonomous-development-control.md
  was stale at 21; `:review`, `:remote-attestation`, `:federated-claim`
  added), the roadmap Now paragraph corrected to seven application use
  cases (select-course was missed) and to promotion rungs 14–18 (all
  landed 2026-08-25 but absent from the frontier prose), and the
  uncommitted 2026-08-28/29 machine docs state landed (evening-selfdev
  changelog, journals, lessons harvest, six crystallized research
  docs, ledger appends). Two backlog rows carry the window's lessons
  as candidate work: night-agent plan authoring (plans ran dry and the
  kernel idled 40h+) and alert→plan-candidate routing.

### 2026-08-28

#### Added

- **Evening selfdev wave** (hngh-automation `585ccd0`, `c9474bf`,
  `6a9d561`, `5b6ad25`, `4bc46ae`, `6ef85c4`, `2ea3db0`): the
  automation gate repaired and both repos now gated daily
  (`03-gate-check.sh` sweeps kernel + hngh-automation, identity-scoped
  red alerts); the lint-identifiers scanner learned quoted-heredoc
  scoping and caught a real bug — the deck-setup .bashrc block's
  `$DESKTOP_IP` splices never expanded (quoted tag), so the deck's
  `HNGH_DESKTOP_IP` sourced empty; tree-skew whitelists
  machine-maintained append paths (dashboards, ledgers, journals) so it
  fires only on stalled agent edits; the review digest carries findings
  + reviewed ranges instead of the echoed prompt with ~1100 diff lines
  (122KB -> 1.9KB); first telemetry readers (`telemetry-report.py`) and
  session-cost capture (one row per omp session, usage parsed from
  transcripts, idempotent by session id); the 5m oversight tick now
  escalates unread gate-red rows (hourly cap, per-repo identity) and
  files a single ui-audit regression breadcrumb when a rule's violation
  count crosses upward.
- **Pre-trip sprint** (hngh-automation `be984d2`, `933c7c5`, `448e2d5`,
  `4787207`, `abb2be2`): hourly adversarial workbeat (the kick-start
  automation, guardrails included); winamp-only themes and the
  digest-freshness P1 fixed; wake-time context in every beat prompt
  (UTC now, last-activity age, unread alerts) with the accepted →
  executed plan transition; Steamdeck paired — tailscale userspace
  daemon, `hngh-desktop` ssh alias, `hngh-tunnel`, remote-posture card
  on the System page; plan ledger gains dashboard-qol and
  remote-hardening waves; the first autonomous overnight shift was
  evaluated and its lessons landed as fixes (budget counting,
  ceremony-store sweep, selector timeout with kill-after); acceptance
  policy reconciled — normal-risk plans machine-accepted by gate,
  critical-risk and the policy itself stay operator-owned.
- **Winamp conversion wave 1** (hngh-automation `5a4ac12`): the classic
  skin is the dashboard's default — playlist-editor schedule rows
  (uniform 48px rows, striping, LED greens), LCD marquee ticker, panel
  shade/roll-up, schedule jump filter and status bar, and a programmatic
  UI audit (`jobs/ui-audit.mjs`: axe-core + display-register rules,
  mounted on the hour tier) whose first runs found and fixed real
  contrast and landmark defects.
- **Docs wave**: route-doc corrections (intent, architecture, index,
  roadmap), register framing across the dry docs, spec-triage bounds
  sentences, and the automation-advancement review record.
- **Lessons consolidation** (hngh-automation evidence, hngh docs):
  yesterday's and today's process lessons folded to their homes —
  ceremony-loop lessons into autonomous-development-control.md
  (timeout-split ceremonies hand off via a runbook, refusal surfaces
  carry the refusal reason, expected-dirty ledger paths are not skew),
  the ledger append invariant into ledger-and-records-spec.md, two
  backlog rows (gated-red cadence watch fixes; report-queue escalation
  caps), the operator-goals design-pressure paragraph in roadmap Next,
  and the reports.md double-header repaired — the review digest's open
  P1 (alert 31527cac), fixed at the source. Record:
  docs/records/2026-08-28-lessons-consolidation.md.
- **Continuous operation wave** (hngh-automation `362a10a`, `3007081`,
  `3f4ad10`, `6d6e837`, `6e772d9`): budgeted remote GLM leg in the
  model chain (OpenRouter-compatible, key-file gated, daily call cap);
  the research-line lifecycle (beats advance lines
  planned → expanding → contracting → crystallized, crystallizing into
  docs/research/); the overnight work loop (`hngh-overnight.timer`:
  accepted plan step → top queue lane → research beat, executed through
  bridge-gated delegated GLM sessions with post-session critical-path
  audit); Winamp skin v2 (classic base-2.91 tokens, hard pixel bevels,
  visible playlist stripes, LCD insets, square everywhere); the plan
  ledger (docs/project/plans/, operator-authored and operator-accepted,
  machine-executed) with `dashboard/plans.json`;
  docs/design/subsystem-anatomy.md — the body vocabulary rooted in
  Clean Architecture, signals never flowing outward; and the ceremony
  commit landing the subsystem-anatomy update, the
  automation-advancement framing correction (plans are operator-accepted,
  not machine-accepted), and four newly-landed 2026-08-28 research docs
  (log-presentation-patterns, session-cost-display, tech-tree-research-ux,
  telemetry-schema-exemplars; gantt-legibility landed earlier).

### 2026-08-27

#### Added

- **Self-improvement cadence wave** (hngh-automation `34cd275`,
  `232c5fe`): the orphaned 30m and hour cadence tiers wired (systemd
  unit pairs, tick allowlist, make enable/disable); four day-tier
  routines — ledger prune (48h alert retention, archived), daily kernel
  gate check, fresh-eyes review over both repos' last 36h of commits,
  and a daylight research beat (round-robin over
  `research-subjects.txt`) — all fail-closed report-row writers;
  telemetry store v0 (`jobs/telemetry.py`, SQLite WAL, capture-first);
  the schedule and research feeds mounted on the 30m tier.
- **Nerve center unification** (hngh-automation `e04b6be`, `6a5ee15`,
  `f67f972`): the dashboard consolidates into one page with formal tabs
  (Health, Counts, Timeline, Schedule, Queue, Lanes, Agents, Reports,
  Digest, Sessions), fixing dead tabs (a triple state-system collision)
  and a cold-load mount pairing bug. New: session-per-column transcript
  observatory (2,688 parsed conversation entries across 24 omp
  sessions, collapsible thinking/tool blocks, search, redaction),
  unified Schedule view (recurring vs one-off, system backdrop
  compaction, honesty-labelled estimates), `POST /tile` window tiling
  (Phi 62/38 profiles, KWin-snapped, opt-in), and
  `jobs/window-tile.py`.
- **Operator session notes**: `docs/project/session-notes-2026-08-27.md`
  — the day's direction, intent, designs, decisions, and forward work,
  harvested and tagged `[landed]`/`[queued]`/`[decision-pending]`.
- Acceleration wave (four parallel slices, each committed through its own
  certificate loop):
  - `scripts/omp-bridge` closes the roguelike delegation loop:
    `--run-start` gates a delegated session behind hngh admission
    (create-run + admit-transport `:worker`, loadout token/time limits as
    the delegated budget, persistent `OMP_BRIDGE_STORE`), `--run-end`
    closes it with a client-validated disposition; `HNGH_BIN` env seam
    for hermetic tests; suite `tests/scripts/test-omp-bridge.py`
    (9 checks) wired into `make test`.
  - Interface-plan S3: `scripts/hngh status` — one truth-telling spine
    read (verdict-first: `all-clear`/`attention`/`unavailable` from the
    data.json digest + system.json headroom booleans; system/active/next/
    roster panes; `stale (Nm)` freshness; all panes fail closed to
    `unavailable`). Optional sources via `HNGH_STATUS_*` env overrides;
    +37 kernel checks (suite now past 2,851).
  - Interface-plan S1: truth-telling dashboard on the readout spine —
    verdict-first hero + state legend (evacuated = finished & detached),
    display-only `ETA` → `Depends on` rename, reorder-by-usefulness
    (active work floats, stable otherwise), unified `stale (Nm)` pane
    labels, additive `verdict` key on `--json`.
  - `docs/design/display-register-spec.md` — the slow-tier register
    consolidation: one Nihei-register spec (voice/captions, gen-4 measured
    proportions, palette discipline, perceptual-only vocabulary table,
    dosage ladder, future grade hooks), consolidating the dormant
    aesthetic decisions.
  - `.gitignore` now excludes `docs/project/report-bodies/` (write-once
    ledger artifacts, never committed): git porcelain scans drop from
    6,312 rows to 25, speeding every evidence/ceremony/watchdog gate.
- Closed both upstream papercuts flagged by the automation digest:
  - `create-run --store=/missing/dir` (and every command through
    `dispatch-command`) now refuses with `store directory missing: PATH
    (create it first, or drop --store)` exit 2 instead of a raw
    `transport-fault` exit 3; existing stores proceed unchanged, all
    other faults stay faults (+4 checks, suite past 2,855).
  - `scripts/run-autonomous provision_card` no longer turns a prose
    evidence field into garbage candidate paths (the
    node-lattice-admission card wedged every autonomy tick with
    `invalid candidate manifest`, exit 3): only real repo-relative
    paths are kept, prose degrades to the item-id placeholder (+1
    regression test; wedged card removed).
  - `scripts/run-autonomous` defers ceremonies whose card candidates
    are missing from disk (a placeholder card is a declaration of
    intent, not a drivable manifest — the re-wedged
    `hngh-autonomy.service` tick proved the first fix incomplete):
    exit 0 with a deferral line instead of exit 3, card stays mounted
    until real paths replace the placeholder (+1 regression test,
    suite 9).
  - `scripts/report-queue` ledger hygiene: `--add --identity KEY
    [--window S]` collapses repeated entries into one row with a `×N`
    marker and per-occurrence body lines; `--prune --before TS --kinds
    ... [--archive PATH]` removes aged rows/bodies with optional
    archive. Suite 8 → 14 checks. Incident during development: a debug
    repro seded the live reports.md ts cells (~2 min); repaired
    in place (7,083/7,083 rows re-verified against body filenames and
    body meta, 0 mismatches) and the lesson stored
    (`debug-repro-sandboxes-only`).
  - `scripts/report-queue` dedup widened: identity matching now scans
    ALL same-kind rows within the window (newest match wins), not just
    the newest row — multi-identity writers no longer spam duplicates
    (+1 alternation check, suite 15).
  - `jobs/dashboard-self-review.py` + hourly drop-in — Hngh checks its
    own dashboard on schedule: feed freshness vs tiers, feed validity,
    served-marker regression, ledger/body drift; every finding
    classified `unacceptable-now` or `acceptable-for-now` (with the
    planned improvement named), deduped via report-queue identities,
    all-clear ticks silent.
  - Host orientation + retention rungs added to the backlog (new-system
    situating pass; report-ledger rotation policy).
- Closed P1 #1.5: machine-steered course selection extracted from the
  service tick into the pure kernel:
  - `src/domain/course.lisp` — pure `course-candidate` value and the
    fixed written ranking policy (mounted card first, ascending last
    increment with never-incremented most due, queue priority
    tiebreak), with `select-course-candidate` reasons.
  - `src/application/select-course.lisp` + ports — the `select-course`
    use case over `course-selection-ports` (fetch/clock/record),
    accepting only validated candidates, refusing empty sets as
    `no-courseable-lanes`, failing closed on callback faults.
  - `scripts/hngh select-course ID:MOUNTED:TS:RANK...` CLI dispatch
    (exit 0 accepted / 1 refused / 2 malformed) and the
    `course <id>: <reasons>` renderer.
  - `scripts/run-autonomous` now asks the kernel selector first and
    falls back to the internal rule only when the kernel is
    unavailable or refuses (fail-closed, never fabricated).
  - Unit suites `tests/domain/test-course.lisp` and
    `tests/application/test-select-course.lisp` wired into
    `tests/run.lisp`; `make test` green.
- Stood up the four P2 DESIGN contracts (ceremony-ready):
  - `docs/design/command-center.md` — unified CLI+GUI command center
    over one spine, S1–S8 mapping, control + awareness contracts.
  - `docs/design/system-awareness-map.md` — read-only probe
    architecture, `system.json` flow, flap-suppressed alerts,
    headroom thresholds, fail-closed rules.
  - `docs/design/buddy-menu-spec.md` — summoned non-nagging pixel-RPG
    overlay: quest ask, toggles, shortcut lenses, state→animation
    mapping, QML6 delivery over `/tmp/hngh-osd.json`.
  - `docs/design/gamified-runs.md` — runs-as-stories model with the
    closed event vocabulary, the roguelike death rule, and the
    `perceptual:true` honesty leash.
  - Indexed in `docs/architecture-index.md` and the
    `docs/README.md` read order.
- Stage-3 "Roguelike delegation live" wave (hngh-automation
  `9a8d647`, `a004d74`, `b7d78f7`, `e44a09d`, `4ea4bdd`; hngh
  `600b993`), all four stage-3 exit criteria witnessed:
  - Ledger hygiene + hardening: stale-store flap backlog pruned
    (8,876 alert rows archived to the gitignored report-bodies/,
    progress rows untouched), `journal_day` hardened against
    full-ISO `HNGH_TICK_TS` (+1 regression test, suite 11),
    AUTO `.gitignore` runtime markers, gantt theme-read guard.
  - Wrap witnessed live: bridge runs render as observatory
    `working` (terminal states pass through); a real delegation
    cycle ran start → `working` → `cancelled` end-to-end with the
    run visible in `dashboard/sessions.json` at every step.
  - Roguelike auto-replace: a stalled bridge-store run is closed
    `dead`, its record rotates into a timestamped bridge subdir,
    and `omp-bridge --run-start` re-provisions the same mission in
    one unattended tick (hermetic stub test + live seeded stall;
    supervision UTC timestamp parse fixed — local `mktime` skewed
    stall ages by the UTC offset).
  - Per-lane medians + actuals: cadence drop-ins time themselves
    into `logs/drop-in-timing.log`; the time ledger gains
    `dropin:<name>` and `bridge:<slug>` walls (closed runs only —
    hngh close receipts carry no timestamp, mtime is the close
    moment); gantt draws one solid actual bar per anchored lane at
    its real last-run epoch beside the dashed projections
    (source-labelled tooltip; exact lane-unit identity, dense-band
    lanes included; embedded Schedule view now feeds the ledger to
    the engine).
- Third-evening intake folded (eight operator observations):
  `docs/design/ledger-and-records-spec.md` (telemetry/records split —
  SQLite WAL store for high-frequency telemetry, git-tracked docs stay
  curated; session-cost and research-beat capture feeding the Sessions
  columns and the stage-5 tech-tree research view), and
  `docs/design/knowledge-base-spec.md` (markdown vault as canon,
  wiki-grade client-side viewer, thin adapters to whatever the host
  has, publisher choice deferred, story-of-creation curation surface);
  Schedule text-legibility floor added to the display register's grade
  hooks; working-agreement standards noted (ADRs, Diátaxis, Shape Up
  appetite/hill charts, Now/Next/Later); roadmap working order item 5.

### 2026-08-26

#### Added

- Added the autonomy reporting layer:
  - `scripts/report-queue` — append-only report ledger (progress /
    expense / optimization / scheduled / alert kinds) with body files,
    a read cursor, newest-first `--list`/`--unread` table rows, and a
    `--json` dashboard payload.
  - `scripts/run-autonomous` — one no-prompt ceremony tick for the
    hourly cadence: journal generation when absent, one check-in-scale
    ceremony slice when the queue/lane/card gates open (fresh
    `/tmp/hngh-auto-*` store), scheduled reporting, fail-closed exits
    (2 malformed card, 3 refusing sub-step, 0 nothing-due).
  - Hermetic suites `tests/scripts/test-report-queue.py` (8 checks)
    and `tests/scripts/test-run-autonomous.py` (6 checks), wired into
    `make test`.

#### Fixed

- `scripts/generate-publication`: restored the missing `import os`
  (NameError at import; suite 4/4 green again).

- Added the autonomous scheduling & heartbeat layer (the machine-level
  heartbeat pipeline):
  - `scripts/schedule-heartbeat` — one non-daemon scheduler tick that
    reads the queue ledger, probes system preconditions (working tree,
    model route, network, audio), triggers a mounted driver (heartbeat
    cards in `docs/project/heartbeat/`), records a dated heartbeat entry
    with SHA-256 verification, and commits the ledger docs. `--dry-run`
    probes without mutating; `--loop N` re-ticks in the foreground.
  - `scripts/probe-model-route` — one bounded read-only reachability
    probe over the operator reviewer-transport files (local/remote/auto),
    resolving a route choice to a live endpoint.
  - `docs/project/heartbeat-service.md` — cron one-liner and systemd
    user timer specification; the queue's Scheduling section carries
    the cron example.
- Added dynamic model route fallback to the drivers:
  - `scripts/rotate-queue --route=auto|local|remote` resolves the
    reviewer transport by probe when no `--reviewer=` file is given;
    the loadout route label follows the choice.
  - `scripts/worker-driver --route=auto|local|remote` names the session
    compute family (local default); `auto` probes once.
- Extended `scripts/dashboard-readout` with live/export surfaces:
  - `--watch [N]` / `--live [N]` foreground TUI refresh loop;
    `--json` machine-readable spine; `--export-html=FILE` self-contained
    page; live session telemetry read from the operator store through
    `scripts/hngh present` (read-only, bounded, non-fatal).
- Added `scripts/generate-publication` (journal, e-book, site):
  - `--daily [DATE]` compiles `docs/journal/YYYY-MM-DD.md` from the
    verified git/checkin/timeline record (refuses to overwrite an
    operator journal); `--check [DATE]` verifies machine journals;
    `--ebook [DIR]` assembles book.md + a stdlib zipfile EPUB;
    `--site [DIR]` exports the dashboard HTML plus a lane leaderboard.
- Added `scripts/fleet-manager` (device-fleet discovery):
  - `--discover`/`--json` report tailscale peers, per-peer ping state,
    audio/tailscale/D-Bus/interfaces probes; `--wake PEER` sends one
    WOL magic packet for an operator-pinned MAC (unpinned/malformed
    MACs refuse); `--record` appends dated observations to
    `docs/project/fleet.md` and the queue ledger. The source pin
    registry is never touched by a script.
- Added `scripts/ceremony-drive` — a closed ceremony glue for explicit
  file candidates (create-run → admit → deterministic verdict →
  prepare-candidate → commit) used to land the milestone.
- Added the full-screen dashboard TUI (`scripts/dashboard-tui`): a
  textual (rich) read-only TUI with an animated operative, an
  active-lanes panel, and live session tables, fed from the operator
  store through the same read-only renderer as `dashboard-readout`
  (`--watch`/`--live` foreground loop, `--json` spine, `--export-html`).
- Added the interface grading loop (`scripts/grade-interface` +
  `docs/project/ui-grades.md`): a deterministic first-finding grade
  (target + grade + first finding) per interface, feeding every UI
  iteration.
- Added the operative evolution story (`scripts/evolve-operative`,
  generations 1–4/5) with `docs/design/operative-frames.md` (the
  frame/animation spec) and the operative layer framed in
  `docs/design/assistant-interface.md`.
- Added the desktop OSD overlay (`scripts/osd-operative` +
  `osd-operative.qml`): a frameless always-on-top Plasma 6 webview that
  floats the operative above app windows, backed by
  `tests/scripts/test-osd-operative.py`.
- Added backlog tooling: `scripts/backlog-lanes` parses
  `docs/project/backlog.md` into lane rows (json/text, status + date,
  in-queue mapping) for any "active lanes" surface; `scripts/notify-agent`
  is a bounded KDE notification reaction agent
  (`org.freedesktop.Notifications`) that classifies job-search signals
  and appends hits to `docs/project/notify-log.md` — one-shot, no
  daemon, stdlib only.
- Added research docs: `docs/project/integrations-marketplace.md` (where
  Hngh's governance pattern binds to CI, agent harnesses, ops, and
  security tooling, each with a ranked now/next/later first slice) and
  `docs/project/system-harness-roadmap.md` (a resource pool of nodes
  under one governance: pool view, config manager, security manager).
- Added the scheduled-runs investigation record
  (`docs/records/2026-08-26-scheduled-runs-investigation.md`): the
  hngh-automation schedule is healthy (7 systemd user timers firing),
  the cancelled store runs were beacons closed `cancelled` by design,
  and exit-0 runs now close `evacuated`.

#### Changed

- The queue ledger's Scheduling section documents the heartbeat cron;
  the fleet observation record and heartbeat card mounts land in
  `docs/project/`. The dashboard documentation now covers the
  full-screen TUI, the grading loop, the operative evolution, and the OSD
  overlay.

### 2026-08-25

#### Added

- Added the operator reviewer transport (promotion rung 13):
  - `review RUN content-hash=HASH paths=PATH,... [reviewer=PATH]` admits
    an operator reviewer-transport file (endpoint, model, max-tokens,
    timeout, token-file; strict parsing, closed refusals) that replaces
    injected review ports with the real curl-backed provider transport;
    the provider token travels only in the one Authorization header.
  - `hngh.adapters.model:make-model-transports` now works against real
    OpenAI-compatible servers: stdin is a string stream (not a filename),
    the request envelope is a chat message with `enable_thinking:false`,
    and the model's completion document is extracted from the provider
    response envelope by a minimal JSON scanner (`model-response-content`;
    numbers/booleans/nulls consumed opaquely).
  - The rung-6 fixed review prompt carries an explicit advisory-reviewer
    instruction; output contract unchanged.
  - Verified live against the local Unsloth server with Ornith-1.0-35B
    (`status=complete`, closed findings document, `:current` review fact).

- Added the operator pinned-key registry and signature-verification
  transport (promotion rung 12, the "revocation policy refinement" named
  in the roadmap):
  - `hngh.domain` adds the pure `key-pin` value (plain bounded identifier
    plus absolute key path; option-like path components refuse) and the
    immutable `key-pin-registry` (duplicate identifiers refuse, defensive
    copies, `lookup-key-pin`) in `src/domain/attestation.lisp`.
  - `hngh.adapters.federation` adds `parse-pinned-keys` (strict
    `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH` line parser over operator text;
    comments and blanks skipped, everything else refuses),
    `hex-decode` (the pure envelope signature codec), and
    `make-pinned-attestation-ports` (attestation ports that resolve keys
    from the registry and verify signatures through one bounded
    `openssl dgst -sha256 -verify` invocation on the injected process
    transport; no default transport).
  - `verify-attestation RUN FILE [pins=PATH]` admits the operator pins
    file — the trust anchor that replaces injected ports with the real
    pinned registry and process transport; a missing or malformed pins
    file is a malformed invocation. New `list-pins PATH` renders one
    tab-joined line per pinned key through `render-pin-list`.
  - Live proof (RSA-2048/SHA-256 throwaway keypair): a real signature
    verifies `status=verified key=live-key-1` exit 0; a tampered payload
    refuses `bad-signature`; an unpinned key refuses `unknown-peer-key`.

#### Changed

- Root README restated the self-governance claim honestly: the loop is
  the default lane for behavior changes, closed exceptions (the
  dependency guard refusing to certify a no-behavior commit) are by
  rule, and pre-loop history is recorded rather than rewritten as
  ceremony. Fixed the stale check-count line (now "a suite past 2,690
  checks; the run prints the current number") and expanded the
  `Where this is going` section with the node-lattice megastructure
  vision (small ledgered machines sharing learned facts, wake-on-demand,
  persistent tunnels without a watching daemon, evidence-first
  admission of low-powered peers).

#### Added

- Ed25519 signature-transport hardening (promotion rung 14): the pins
  file gains an optional closed ALGORITHM column
  (`rsa-sha256` default, `ed25519` admitted; unknown, empty, or extra
  columns refuse), the `key-pin` domain value carries the algorithm, and
  signature verification routes per pin — digest signatures via
  `openssl dgst -sha256 -verify`, raw Ed25519 signatures via
  `openssl pkeyutl -verify -pubin -inkey -rawin -sigfile -in`.
  `list-pins` renders each pin's resolved algorithm. Verified live end
  to end with a real Ed25519 keypair (`status=verified key=ed-key` exit
  0; tampered payload refuses `bad-signature`) and committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`,
  excluded by the dependency guard; candidate commit bound to the
  implementation and tests).

- Network claim method (promotion rung 15): `+federation-methods+` gains
  `:http-claim` (carrier-bundle and http-claim are the closed method
  set; anything else still refuses at request construction).
  `fetch-evidence RUN peer=ID [method=carrier-bundle|http-claim]
  [max-facts=N]` accepts the closed method option (unadmitted methods
  are malformed exit 2); the transport sees the method on the request,
  and the peer remains a plain identifier with endpoint resolution
  transport-owned — no default wire. Verified live over a real local
  HTTP server through an injected transport (`status=complete` with the
  closed claim states) and committed through the self-governed ceremony.

- Operator policy profiles (promotion rung 16): the domain gains the
  pure `evidence-profile` value (principle → permitted requirement
  kinds; duplicate principles and non-closed kinds refuse) and
  `evaluate-policy-proposal-under-profile`, which narrows a proposal's
  requirements to a listed principle's permitted kinds — a profile only
  narrows, never broadens. The requirement-kind vocabulary admits
  `:review`, so a profile can demand review evidence; `propose` gains
  `profile=PATH` (strict `PRINCIPLE<TAB>KIND` lines; missing or
  malformed files are malformed invocations). Committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`).

- Wake-on-demand (promotion rung 17): `wake-peer RUN PINS-FILE PEER`
  issues one explicit wake request for a pinned lattice peer behind an
  injected transport. The pins registry is the admission evidence; the
  transport receives `(PEER KEY-PATH)`; a zero exit issues, a nonzero
  exit refuses `wake-refused`, a throw faults `wake-fault`; an unpinned
  peer refuses `unknown-peer-key` before any transport call. No default
  transport — without injection the command refuses
  `no-wake-transport`. Committed through the self-governed ceremony
  (chore export lane for `src/packages.lisp`).

- Machine-checked self-governance (2026-08-25): the README's restated
  claim is now falsifiable by construction.
  `tests/scripts/test-loop-history-guard.py` walks every code-surface
  commit since the restatement `1915713` and fails the gate on any
  commit that is neither `hngh: candidate <hash>` nor labeled
  `(excluded from cert manifest by dependency guard)`. The carve-out is
  recorded as a decision entry in `docs/project/decisions.md`, with the
  one pre-guard violation (`915e0e3`, comment-only) named rather than
  rewritten. Committed through the self-governed ceremony.

- Bounded read-only worker task (promotion rung 18): the worker-rung
  first slice. `hngh.adapters.worker` supplies a closed `worker-request`
  (bounded task label plus optional bounded payload), `worker-ports`
  (one injected `execute-worker` callback, no default transport), and
  `run-worker-task`, which binds a `:worker` `:current` evidence fact
  on a zero exit and refuses/faults closed otherwise. `:worker` joins
  `+admitted-transports+` behind the `worker-task` tool label on the
  run loadout; `run-worker RUN task=LABEL [payload=TEXT]` is the
  operator surface. A worker self-report is evidence, never acceptance,
  and a worker never carries a mutation certificate. Committed through
  the self-governed ceremony (chore export lane for `src/packages.lisp`).
- Live worker proof (2026-08-25): the full cycle ran through the
  dispatch surface with a real subprocess worker transport —
  create-run (worker-task label) → admit worker → run-worker
  (`worker status=complete task=scout candidates`) → present — with
  the `:worker` `:current` evidence fact bound from real output.
- Continual-worker driver (2026-08-25): `scripts/worker-driver` runs
  the one-shot worker cycle as a single explicit invocation
  (`--store=PATH OBJECTIVE TASK [PAYLOAD]`: create-run with the
  worker-task label → admit worker → run-worker → close). It is glue
  over the existing dispatch surface, adds no transport or authority,
  and the periodic invocation stays with the operator's scheduler.
  Committed through the self-governed ceremony.

- Queue rotation (2026-08-25): `scripts/rotate-queue` closes one
  queued item through the full loop — queue-row flip, real evidence,
  a real local-model review via the operator reviewer file, a
  ten-principle proposal, certificate binding, and the certificate-
  bound commit. The first rotation (doc-sync-loop, the doc-numbers
  guard) ran live end to end: review `status=complete findings=4`
  (advisory), verdict admitted 10/10, `git add` + `git commit`
  executed as `hngh: candidate bbd1d598…`, queue ledger flipped in
  the same commit. The queue ledger lives in
  `docs/project/queue.md`; a scheduler (operator-owned) may invoke
  rotate-queue periodically.

### 2026-08-24

#### Added

- Added the distributed attestation & evidence federation slice (promotion
  rung 11):
  - `hngh.domain` adds the pure `remote-attestation` envelope value and the
    closed structural checker `verify-attestation-shape` plus `utc-string-p`
    in `src/domain/attestation.lisp` (no clock, no network, no key store).
  - `hngh.adapters.federation` is a bounded federation adapter with two
    injected-port entry points: `gather-federated-evidence` reads an
    operator-carried carrier bundle through the `fetch-remote` callback and
    maps its claims into domain evidence facts with the closed
    evidence-state vocabulary (`:current` when locally re-hashable,
    `:unverifiable`, `:malformed`, `:missing`, `:conflicting`); and
    `verify-remote-attestation` runs the kernel shape gate, resolves the
    signing key against the operator-pinned list, checks the signature
    through `verify-signature`, and checks the expiry window against the
    injected `now`, binding a `:remote-attestation` fact only on a fully
    verified envelope. The closed refusal taxonomy names `unknown-peer-key`,
    `bad-signature`, `signature-fault`, `malformed-attestation`,
    `malformed-expiry`, `expired-attestation`, `attestation-clock-skew`,
    `transport-fault`, and `output-too-large`.
  - `hngh.domain:+admitted-transports+` is now
    `(:filesystem :model :terminal :federation)`;
    `hngh.domain:+evidence-requirement-kinds+` gains `:remote-attestation`
    and `:federated-claim`.
  - `hngh.application:admit-transport` admits `:federation` only under a
    loadout carrying the `remote-evidence` network label or the
    `carrier-bundle` tool label, else the closed
    `loadout-refuses-transport` refusal.
  - `hngh.main:dispatch-command` gains `fetch-evidence` and
    `verify-attestation`, threaded through `&key federation-ports
    attestation-ports` with no defaults: un-injected, the operations refuse
    `no-federation-transport` / `no-attestation-transport`, so plain
    `scripts/hngh` never touches a wire; both serve only a run holding a
    `:federation` admission receipt.
  - `hngh.presentation` adds the two outward renderers
    `render-federation-result` and `render-attestation-result`.
  - Test suite `tests/adapter/test-federation.lisp` and updated vocabulary
    coverage in `tests/domain/test-governance.lisp` (closed transport set)
    and `tests/domain/test-governance-properties.lisp` (requirement kinds).
- Added the bounded model and terminal worker transports (promotion rung
  10): `hngh.adapters.model:make-model-transports` returns the transport
  `complete` callback shape so the existing bounded review adapter can
  drive a real provider (advisory only, no default provider);
  `hngh.adapters.terminal` captures one bounded operator statement as a
  `:terminal` evidence fact with an in-process SHA-256 fingerprint
  (advisory only, no subprocess, no default input);
  `hngh.domain:+admitted-transports+` is now `(:filesystem :model :terminal)`
  and `hngh.application:admit-transport` reuses the run loadout for the two
  new kinds (`:model` needs a non-`local` route plus the `model-review`
  network label; `:terminal` needs the `terminal-input` tool label) with
  the closed `loadout-refuses-transport` refusal;
  `hngh.main:dispatch-command` gains the `review` and `terminal` operations,
  both fail-closed without injected ports
  (`no-review-transport`/`no-terminal-transport`) and both served only to a
  run holding the matching admission receipt;
  `hngh.presentation` adds the one outward renderer `render-operator-result`.
- Added the operator-facing command surface and transport admission (promotion rung 8):
  - `hngh.domain:+admitted-transports+` (`(:filesystem)`) in `src/domain/governance.lisp`.
  - `hngh.application:admit-transport` in `src/application/admit-transport.lisp` creating `:admission` receipts with facts `transport`, `scope`, `route`, `run`, and `timestamp`.
  - `hngh.adapters.filesystem` in `src/adapter/filesystem.lisp` recording canonical run-and-receipt lines under an explicit `--store=PATH` without domain imports.
  - `hngh.main:dispatch-command` exposing the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a closed exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault).
  - `scripts/hngh` executable SBCL wrapper.
  - Test suites: `tests/application/test-admit-transport.lisp`, `tests/adapter/test-filesystem.lisp`, `tests/main/test-dispatch.lisp`.
  - Record: `docs/records/2026-08-24-command-surface-and-transport-admission.md`.
- Added the operator governance command surface for the dogfood loop
  (`scripts/hngh`, promotion rung 9):
  - `propose [key=value...]` forms a closed `policy-proposal` from operator
    fields and renders the deterministic `policy-verdict` (0 admitted,
    1 refused with labels, 2 malformed).
  - `issue-cert ACTION RUN [PATH...]` reads the stored run from `--store`,
    binds repository identity/base revision/candidate paths to it, and mints
    a candidate certificate under an admitted verdict (refuses runs without
    an admission receipt).
  - `mutation-check ACTION RUN [EVIDENCE...]` builds fresh fixture evidence
    and executes the certificate-bound mutation through injected ports, so
    the loop runs fully in-process with no subprocess (0 executed, 1
    mismatch/refused, 2 malformed, 3 transport fault).
  - `hngh.main:dispatch-command` gained a `:mutation-ports` injection key;
    test suite `tests/main/test-governance-dispatch.lisp` asserts no real
    process is ever spawned.
  - Record: `docs/records/2026-08-24-command-surface-dogfood.md`.
- Completed the first self-governed development loop (promotion rung 9):
  Hngh proposed, reviewed, certified, and committed its own documentation
  change (`propose`, `issue-cert`, `mutation-check` against live repository
  evidence), then pushed the certificate-bound commit to origin.
  Record: `docs/records/2026-08-24-first-self-governed-commit.md`.
- Completed the second self-governed development loop: Hngh proposed,
  certified, staged, gated, and committed its own adapter bug fixes
  (`process-run-at` value-order; certificate path sorting) under a real
  evidence certificate (`33b8d94 hngh: candidate 1befdda9...`), then pushed
  to origin. Record: `docs/records/2026-08-24-second-self-governed-commit.md`.
- Added exhaustive governance property tests (backlog item): totality
  over the 7 proposal classes x 21 evidence-requirement kinds (147
  combinations; absent-matrix-principle refuses rather than errors) and
  monotonicity of the deterministic evaluator (ignoring evidence never
  flips refused to admitted; single- and double-ignore exercised).
  suite total 2353 checks. Record:
  `docs/records/2026-08-24-governance-property-tests.md`.
- Recorded the 2026-08-24 prior-art research session:
  `docs/records/2026-08-24-prior-art-landscape.md` maps the closest prior
  art (Progent arXiv:2504.11703 closest, CaMeL arXiv:2503.18813,
  AgentSpec arXiv:2503.18666), the four deliberate divergences from
  in-toto/SLSA/DSSE (no PKI / hash self-certification, duplicate facts
  refuse, moment-of-action freshness recheck as a novel property, no
  multi-party machinery), the adopted invariants (monotonicity, deny with
  structured reason, totality over closed kinds, DSSE as a YAGNI-gated
  future export grammar), harness-landscape positioning (Claude Code,
  Codex CLI, mini-swe-agent, Aider, OpenHands/ACP), the no-public-
  governance-benchmark gap, and the strategy sequencing ending in
  federation as a scope-broadening proposal class.
- `docs/project/decisions.md` records the no-PKI / hash self-certification
  stance as a single-machine decision with an explicit revisit trigger:
  multi-machine evidence sharing.
- `docs/project/backlog.md` gains four entries: governance property tests
  (matrix totality over closed kinds plus monotonicity), a DSSE envelope
  export serializer (YAGNI-gated), a governance-benchmark research lane
  (AgentDojo / InjecAgent / R-Judge prior-art scan; tamper-evidence,
  approved equals executed, reconstruction-from-record metrics), and the
  dogfood loop as a future rung candidate (Hngh proposes, evaluates, and
  commits changes to itself via its own harness). Documentation only; no
  source or behavior change.


### 2026-08-19

#### Changed

- Root README `Why` and `Where this is going` rewritten to frame Hngh as a
  growing system harness: the Why contrasts Hngh's record-first posture with
  the throughput-first agent-harness mainstream (grounded in a 2026
  empirical study of 70 agent-harness projects and the 2026-07-28 stateless
  MCP update), and Where-this-is-going names the corridor: local and remote
  models, priced routes, pooled hardware, all behind the same bounded, recorded,
  human-closable cycle. Documentation only; no source or behavior change.

- Retired the `make check-archive` archive gate and the archive-boundary
  framing: the external retirement archive is historical evidence only, no
  active gate verifies it, and meaningful archive material is harvested
  into the operator's separate llm-wiki knowledge base. The archive itself
  is untouched. Makefile and documentation only; no source or behavior
  change.


### 2026-08-18

#### Added

- A read-only evidence adapter (promotion rung 4): a fixed, enumerable set of
  read-only local evidence commands — repository revision, whole-tree
  working-tree status, and file content hashing — gathered through an
  injected process transport and mapped to domain evidence facts and source
  manifest entries with closed states; unknown commands, malformed output,
  escaping targets, and duplicate evidence fail closed, and the adapter
  never decides policy or mutates anything.

- A fixture-backed mutation executor (promotion rung 5): `hngh.adapters.mutation`
  rechecks every certificate fact against fresh evidence and emits only the
  certificate-bound fixed Git action through an injected transport; stale facts,
  expiry, disabled actions, malformed evidence, command failures, and transport
  faults refuse without mutation.

- A fixture-backed bounded model-review adapter (promotion rung 6):
  `hngh.adapters.review` sends one closed review request (candidate paths, content
  hash, policy-context labels) through an injected reviewer transport and maps the
  model's structured output into sanitized, duplicate-free finding labels and
  citations plus one deterministic review evidence fact. Malformed JSON, unknown
  fields, unsafe citations, oversized or overlong findings, duplicate labels, and
  transport faults refuse closed; a failed review call becomes an `:unverifiable`
  fact. Reviewers advise, never decide; the adapter is pure (no provider defaults,
  no network, no subprocess calls).

- An operator-visible presentation layer (promotion rung 7):
  `hngh.presentation` renders application results, runs, receipts, evidence facts,
  policy verdicts, candidate certificates, and installed adapter results into
  plain factual strings without mutating canonical state or importing an adapter;
  refusals stay literal, and the optional reference lexicon applies display copy
  only at a named surface and can never carry canonical control.

- A composition root (promotion rung 7): `hngh.main` composes the five use cases
  into one `run-harness` with injected or fail-closed default port adapters
  (in-memory record store, per-harness identifier source, clock, and `unknown`
  admission, verification, and manifest evidence), wires the installed evidence,
  mutation, and review adapters through injected transports, keeps an
  operator-visible in-memory record root, and renders every result through
  `hngh.presentation`. It starts no background work by import and supplies no
  default model or terminal transport.

- Public read-only accessors on domain run and receipt values
  (`run-identifier`, `run-mission`, `run-role`, `run-loadout`, `receipt-kind`,
  `receipt-facts`) so presentation renders without touching canonical state,
  and a dependency-guard extension that rejects any inward package importing an
  adapter.

#### Changed

- Root README, documentation index, and roadmap now frame Hngh's intent and
  direction in plain language, recovered from the archived pre-refactor plans;
  added `docs/intent.md` as the human-facing vision document. Documentation
  only; no source or behavior change.


### 2026-08-17

#### Added

- Pure governance values for closed proposal, principle, failure, evidence, and
  verdict vocabulary; they remain non-authoritative policy data.

- A deterministic proposal-evidence-ledger policy: closed requirement kinds
  bind evidence facts to principles without making fact producers or adapters
  domain policy.

- A deterministic principle evaluator over the proposal ledger: ten
  matrix-ordered principle results and closed refusals for missing, stale,
  malformed, conflicting, or unverifiable evidence; `:admitted` only when every
  principle passes.

- A closed failure-disposition policy: each of the eight failure categories
  maps to one deterministic disposition, unknown categories refuse, and
  conditional rows resolve to their primary default.

- A non-mutating candidate authorization certificate: an immutable value
  binding one closed action plus the admitting verdict and recorded facts,
  minted by a pure mechanical issuer.

- The policy-gated `close-run` use case: a run reaches a terminal state only
  under an `:admitted` policy verdict, with closed transition refusals and one
  atomic run-and-receipt record.


### 2026-08-12

#### Added

- A read-only, fixture-tested Common Lisp parenthesis guard in the fast gate.

- A pure run domain with validated mission, role, loadout, lifecycle, and
  evidence values.

- A pure application create-run slice with explicit identifier, clock, and
  atomic recording capabilities.

- A pure application arm-run slice with explicit admission facts and atomic
  recording capabilities.

- A pure application start-run slice with one atomic transition recording
  capability.

- A pure application checkpoint slice with closed verification and manifest
  evidence callbacks plus one atomic transition recording capability.

- A policy-only autonomous-development-control design: source-grounded
  principle evaluation, closed proposal and authorization classes, bounded
  reviewer challenges, and certificate-gated future mutations.

- A read-only candidate evidence bundle with an explicit manifest, fixed local
  checks, whole-tree observation, hash-bound output, and closed refusals for
  unsafe or out-of-scope input.

#### Changed

- Routine design, review, and future mutation decisions move from
  approval-by-perception to source-grounded, fail-closed certificates; human
  approval is a deployment profile.

- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.


### 2026-08-11

#### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.

- Compact active documentation and cutover record.

- Clean Architecture charter, component map, test boundary, and
  presentation/reference-lexicon boundaries.

- Fixture guards for inward dependency direction and renderer-only lexicons.

#### Changed

- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
