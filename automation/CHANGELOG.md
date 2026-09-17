# Changelog

## 2026-09-17

- research-beat: source-side ingest redaction — both question-text
  ingest seams in cadence/hour/33-research-beat.sh (ensure_lines from
  research-subjects.txt, followon_queue from review FOLLOWON lines,
  plus the demand-synthesizer append) now run redact_home
  (lib/scrub.py single token family, tilde rendering) BEFORE id/slug
  derivation and BEFORE any write into research-lines.tsv /
  research-subjects.txt. The TSVs are git-tracked and pushed publicly,
  so the report-queue sink-side guard can never cover this seam; the
  leaked fail-20260914-Where-exactly-in-home-bricker-Projects-e id and
  9 pathy text rows proved the leak happens at/before derivation.
  Forward-only: existing rows left untouched. Red-first contract test
  tests/test-research-beat-ingest-redact.sh (sources the REAL seams
  via brace-anchored extraction; red proven 5-fail against the
  unpatched script) wired into make test.

- patrol: doctrine-coverage classifier extension — every doctrine LARGE
  class now maps to a concrete pre-check rule on the repo's REAL
  surfaces or a documented exception
  (docs/records/2026-09-17-large-precheck-doctrine-coverage.md). New:
  `<name>.env` basename forms match _CRED_PATH_RE (real files
  automation/config/machine.env + automation/config.env were invisible
  before); _SYSTEMD_PATH_RE catches the services registry
  (hngh-services.tsv, no .service suffix), service-mgmt.sh, and
  sudoers grants; _SPEND_PATH_RE catches the cadence-params Inventory
  (sessions-day-max, kimi-daily-cap, zai/opencode cap windows —
  OUTSIDE automation/config/) and lib/failfirst.sh (the fail-first
  concurrency family); _PUBLIC_PATH_RE refuses publish code
  (digest-public.py, dispatch/, newspaper/). Documented EXCEPTION: the
  kernel surface (src/, tests/, Makefile, hngh.asd) is NOT refused —
  every guard violation is kernel-surface and the ba6b390 Makefile
  cure is the lane's founding precedent; its policy path is the
  ceremony certificate plus the suite green. Rename numstat forms
  ("old => new") now classify BOTH sides. Red-first: the new
  test_large_cure_violation_real_repo_paths asserted real LARGE
  surfaces (machine.env.example, cadence-params.tsv, failfirst.sh,
  hngh-services.tsv, digest-public.py, leg-budgets.tsv) and failed on
  the pre-extension classifier before going green.
- patrol: gut-shape classifier fix — the LARGE pre-check's original
  pure-deletion rule (additions==0 and deletions>0) did not catch the
  real gut it was written for: ba6b390's actual numstat is 1+/36-
  Makefile, 1+/386- README.md (the gut kept one vestigial line per
  file), so a replay and the c4 delete-KNOWN_EXEMPTIONS trigger
  (ba6b390+d2d8f51) would both have auto-declared. The rule is now
  deletion-dominance: pure deletion (additions==0, deletions>0) OR
  >= 20 deletions at >= 20:1 deletions-to-additions per file
  (_GUT_MIN_DELETIONS floor keeps 1+/1- doc edits SMALL; the ratio —
  not a hard additions cap — keeps 2+/386- a gut; revert shapes like
  d2d8f51's 36+/1-, 386+/1- fail the ratio and stay SMALL).
  Red-first against a REAL temp-git fixture (new
  tests/test-patrol.py::RealGitClassifier — gut/revert/tiny-edit
  through unmocked commit_numstat; the gut test failed with reason ''
  before the fix), green after. Live replay of the six production
  declared SHAs through the fixed classifier: ba6b390 LARGE-refuse
  (gut-shape diff 1+/36- Makefile); d2d8f51, 04f0001, 29d2a27,
  526cd3fd, e6e98f75 all SMALL-declare; the c4 trigger set
  ba6b390+d2d8f51 refuses. Full automation make test rc=0 (ALL PASS).
  Record amendment:
  docs/records/2026-09-17-patrol-large-cure-refusal.md (2026-09-17
  gut-shape amendment).

- security: identity-seam guard scan scope extended past `*.sh`/`*.py`
  (the non-sh/py writer audit, closing the admitted gap). The guard now
  also scans `.js`/`.mjs` under `automation/{dashboard,jcode}` plus the
  four original surfaces — JS comments stripped, string contents kept
  (fail-closed: an execSync("git commit ...") or spawn("git", ["commit",
  ...]) invocation shape is flagged even inside quotes; reword prose
  instead) — and detects git-array/argv forms (`["git", "commit"]`,
  `["git", "-c", ..., "commit"]`) on shell/python raw lines; built-in
  tmp-dir self-test probes run on every invocation so the scanner
  cannot rot. Audit
  verdict (bounded negative, recorded in
  docs/records/2026-09-16-identity-seam-reconciliation.md): no
  non-sh/py automation artifact can run git commit — dashboard JS is
  display-only (zero child_process), ui-audit.mjs spawns python3 only,
  dashboard-server.py's subprocess set is enumerated (its backup
  button calls the pinned config-backup.sh), crontab empty, opencode
  configs carry no shell hooks, package.json has no bin/scripts. Same
  record carries the config-backup parity verification: one post-16dae2eb
  run, `committed=0 pushed=1` = expected no-drift parity, pin intact
  but not yet drift-exercised. Red-proven: a planted unpinned
  `dashboard/*.mjs` writer passed the old guard and fails the new one
  with a single precise violation; clean tree green; full make test
  rc=0.

- patrol: gate-cure LARGE pre-check — `check_gate_cure` now refuses the
  auto-declare (existing `gate-cure-refused` park, no exemption append,
  no decisions.md entry, no ceremony drive) when the violating commit
  set touches credential-like paths (.env/credential/secret/token/pem),
  systemd units (.service/.timer/.socket), spend/cost/budget/cap
  configs under `automation/config/`, or contains a pure-deletion
  numstat diff (the ba6b390 gutting shape). New
  `is_large_cure_violation` + `commit_numstat` in jobs/patrol.py;
  the 2026-09-13 SMALL-matter amendment's LARGE classes are enforced
  before the mutation instead of relying on the ceremony verdict after
  it. Test-first: four new cases in tests/test-patrol.py (classifier
  matrix + refusal wiring), red-proven (3F+1E) against the
  pre-check-free patrol, green after; full make test rc=0.
  Record: docs/records/2026-09-17-patrol-large-cure-refusal.md.

- security: model.sh chat legs moved off bearer-on-argv — the three
  remaining `/proc/<pid>/cmdline` exposures (the `_post_chat` scaffold
  behind the remote/kimi/ocgo/zai/deck legs, `unsloth_attempt`, and the
  `_unsloth_ctx_limit` probe) now feed
  `printf 'header = "Authorization: Bearer %s"' | curl -K -`; the chat
  request body is staged to a tmp file (`-d @"$btmp"`) because `-K -`
  and `-d @-` cannot share stdin, and the keyless deck leg sends no
  Authorization header at all. The e1 "already-audited
  cred-refresh-hygiene" exclusion was backed by a nonexistent audit
  record (candidates 2026-09-10-automation-ci-and-probe-hygiene,
  credentials-posture, and the 2026-09-16 risk dispositions each
  checked and none covers model.sh), so the sites were fixed outright
  — the credential-health PROBES of the same endpoints were already
  converted in ccf8d7b5, leaving these as the tree's last
  Bearer-on-argv sites. Test-first: new
  tests/test-model-bearer-argv.sh (stub curl ARGV:/STDIN: recorder,
  red-proven, deck-leg negative case), test-probe-hygiene.sh extended
  to classify lib/model.sh (no Authorization on argv, -K - required,
  refresh-path body token the single documented exemption), real-curl
  loopback co-delivery check; sibling suites
  test-model-remote-token-mode / test-model-pin-routing /
  test-credential-health-argv green. Record:
  docs/records/2026-09-17-model-bearer-argv-stdin.md. Registered in
  `make test`.

## 2026-09-16

- security: identity-seam contract extended to all five cadence
  auto-committers (16dae2eb covered config-backup.sh only). The
  ambient-identity-writer-audit enumerated every git-invoking automation
  writer; the five ambient committers (lesson-harvest tick,
  plan-ledger-sync, torch-audit, kernel-ledger-sync, research-beat)
  authored 339 of the 566 window commits as the leaked Fixture identity
  and now pin hngh-machine per invocation. New contract test
  tests/test-identity-seam.py (red-proven pre-fix, wired into
  `make test`) fails on any future unpinned `git commit` in
  cadence/jobs/lib/scripts. Kernel ceremony executor
  (src/adapter/mutation.lisp) still rides ambient identity: reported in
  docs/records/2026-09-16-identity-seam-reconciliation.md, not edited.

- security: fifth token-file reader gated — unsloth_chat now refuses a
  non-0600 TOKEN_FILE fail-closed before the value is read or sent
  (test-first, red-proven; record:
  docs/records/2026-09-16-unsloth-tokenfile-600-gate.md). g2's "all
  four un-gated reads" miscounted: the unsloth chat read was a fifth
  instance; an operator-created/restored 0644 unsloth.token was sent
  as a bearer header on every chat call (chmod-600 only happens after
  a successful refresh). Exact kimi-leg byte shape (too-open breadcrumb
  -> next backend); post-refresh re-read needs no gate. New test
  section in test-model-remote-token-mode.sh: 0644 -> zero POSTs vs a
  live stub, 0600 -> exactly one POST, absent -> dormant. The four
  unsloth-leg suites (pin-routing, kimi-leg, ocgo-leg, review-ladder)
  now chmod 600 their sandbox tokens; ocgo-leg's outside-window case
  deflaked (7d soft-pace cap raised to 1e8 — with 100000 it blocked
  for ~9.4 min after each Thursday 00:00Z cycle start, observed live).

## 2026-09-16

- security: scrub consolidation — ONE path-token definition, family,
  and marker mapping (test-first, red-proven on the two open digest
  seams; record: docs/records/2026-09-16-scrub-consolidation-single-source.md)
  — lib/scrub.py is now the single-source redaction module
  (scrub.sh is the shell wrapper, redact.sh a compat shim): one token
  family (home/Users/root/tmp bare or segmented, scheme-relative
  //host/home/, tilde, credential URL userinfo) and one marker mapping
  ([redacted path] for prompt/echo-guard seams; tilde ~/... ~tmp/...
  as the kernel-ledger sink rendering — one family, two named
  renderings, parity-tested both sides). digest-ledger last_plan and
  queue_next seams closed (red-first: test-digest-plan-seam-scrub.py);
  the previously uncovered /Users, /root, //host, userinfo families
  die everywhere. Migrated: news-articles, digest-ledger, patrol,
  digest-html, gdelt-news, model.sh (jq copy retired), digest-block.sh;
  kernel scripts/report-queue mirrors the family sink-side (kernel
  test red-first). All prior scrub suites green.

- security: render-layer scrub closed the downstream half of the
  digest leak chain (test-first, red-proven; record:
  docs/records/2026-09-16-render-layer-scrub.md) — the writer census
  scrubbed digest writers, but deck B, the beat side-notes, the
  operator email HTML part (render_mega), the /digest-html/ LAN route
  payload, and the public edition all rendered below-ledger digest
  text (patrol morning rounds, any direct writer) verbatim. Both
  renderers now re-export digest-ledger scrub_paths (no fourth regex)
  and scrub at the parse chokepoint: digest-html.parse_sections (one
  seam covering deck A rows, deck B mega items, the rounds table, the
  route payload, and digest-public's parse) + beat_sidenotes excerpt,
  html-digest.news_sections + render_mega. Marker stays the existing
  [redacted path] identity seam; URLs survive verbatim. New
  RenderLayerScrubTest (5 cases) injects a pathy append below the
  ledger layer and asserts zero /home/, /tmp/, ~/ tokens across the
  newspaper page, the bound-server route payload, the email HTML
  part, the public edition, and the sidecar excerpt path — red on all
  5 before the seams, green after, full make test ALL PASS.

## 2026-09-16

- security: chain-wide reply-side path scrub at the model_call
  chokepoint (test-first, red-proven; record:
  docs/records/2026-09-16-model-reply-path-scrub-chain.md) — extending
  the news lane's no-echo law to every model.sh consumer: model_call
  now scrubs the winning reply through _scrub_paths (the news
  PATH_TOKEN_RE law ported to one jq gsub: /home //tmp ~ tokens redact
  to [redacted path], URL-shaped tokens preserved, prose kept,
  fail-closed empty on scrub failure), so research beat, reviews,
  digest, overnight and ping lanes inherit the law at the single
  consumer entry instead of owning a scrub each. Archive-only contract
  intact (raw prompt archived unmutated — input hygiene stays with the
  caller); JSON-mode callers: none exist. Red-first suite
  tests/test-model-reply-scrub.sh pins deck + ollama leg echoes scrubbed
  exactly (truncation flag preserved); research-beat reply-persistence
  spot-audit: all reply surfaces flow from model_call captures, no
  per-file scrub needed there. model.sh implementation landed inside
  f8b0fe7f by the sibling lane's add sweep (attribution in the record);
  this entry's slice is the suite + registration + docs.
- security: token-file reads gated to exactly 0600 across the remaining
  readers (test-first, red-proven; record:
  docs/records/2026-09-16-token-file-0600-gates.md) — closing the class
  probe-model-route's gate (f809a05f) left open: manga-vision.py read
  TOKEN_FILE unguarded (a 0644 token was silently trusted and sent),
  model.sh remote_chat read REMOTE_TOKEN_FILE with no mode check (the
  one asymmetry in its own file — kimi/ocgo/zai always gated), and
  credential-health.sh probe_token read TOKEN_FILE unguarded. All three
  now refuse fail-closed BEFORE reading or sending: manga-vision raises
  TokenFileModeError naming the path and 0600 (the headerless-send
  fallback is gone), remote_chat breadcrumbs "key file too open (chmod
  600 required) -> next backend" (kimi leg's exact shape, with the
  absent-dormant contract preserved and made explicit first), and
  probe_token returns the literal code `too-open` before curl spawns
  (flows through ok(); new alert branch "token file too open; chmod 600
  required"). New suites test-manga-vision-token-mode.py (guard proves
  the file is never opened), test-model-remote-token-mode.sh (red run
  reproduced the hole: the 0644 key POSTed to a live stub), and
  test-probe-token-mode.sh (fake curl proves zero spawns and no value
  leak); all registered in make test. Kernel-side sibling
  (scripts/grade-interface read_token, same class) landed through the
  ceremony as bf5e9b75.
- security: read-side ledger surfaces closed (test-first, red-proven;
  record: docs/records/2026-09-16-readside-ledger-surfaces.md) —
  graph-data.py's patrol-alert matcher expected the obsolete ledger row
  shape and matched zero live rows (graph patrol alerting was dead in
  production); it now kind-gates live `alert` rows, extracts only
  `patrol:<registry-id>` tokens anchored at non-id boundaries (pathy
  text like `/home/x/patrol:not-a-surface` can never mint a node id),
  and intersects with the patrol registry before any node id exists —
  validated read-only against the live ledger (110 alert rows/24h, 9/9
  tokens registry ids, zero foreign). system-feed.py dropped the
  hardcoded `~/...` root (README sweep item): env
  HNGH_HOME/HNGH_REPO still wins, else the repo that ships the script.
  Both suites (previously unregistered) registered in `make test`;
  guard-node/patrol/surface behavior unchanged. Neighbor-lane WIP was
  excluded: full gate verified ALL PASS on HEAD + this slice only.
- security: credential-health bearer probes moved off argv to the stdin
  curl config (test-first; record:
  docs/records/2026-09-16-credential-health-bearer-stdin.md) — the
  unsloth, kimi, and ocgo probes passed the resolved key as
  `-H "Authorization: Bearer $key"` on the curl argv, leaving it
  readable in `/proc/<pid>/cmdline` for the call duration (the same
  class the notify-seam argv fix closed; silent carry-over from the
  2026-09-10 authenticated-probe fix). All three now send
  `printf 'header = "Authorization: Bearer %s"' | curl -K -`; only the
  endpoint URL, timeouts, and `-o/-w` stay on argv; breadcrumb strings
  and `-o /dev/null -w '%{http_code}'` semantics byte-identical. New
  `tests/test-credential-health-argv.sh` (stub curl ARGV:/STDIN:
  records, red-proven, plus a real-curl loopback ordering check),
  registered in `make test`; `tests/test-probe-hygiene.sh` contract
  consciously evolved to require `-K -` per probed gate, forbid any
  `Authorization:` on a curl record, and pin one Bearer stdin directive
  per gate (`$tok`, `$kimi_key`, `$ocgo_key`); deck `/health` remains
  the single exempt bare GET. No exemptions. g2's missing TOKEN_FILE
  pre-probe gate deliberately untouched (coordinate, no collision).
- harden: reply-side no-echo scrub + no-paths house law on the news
  lane (test-first, red-proven; record:
  docs/records/2026-09-16-model-reply-path-scrub.md) — closing the
  llc-news-prompt-audit open question: `lib/model.sh` has NO system
  prompt on any leg (`_json_body` sends a single user message), so
  hygiene law lives with the caller; `news-articles.py model_reply`
  now runs the same `PATH_TOKEN_RE` seam over the reply after the
  fence strip (input-side scrub alone cannot stop a model echoing a
  path it saw, inferred, or hallucinated), and `build_prompt` gains a
  no-paths house law (worded without the literal redaction marker so
  the section-8 exact-marker-count pin stays exact). Pinned in
  `tests/test-news-articles.sh` section 8: a stubbed pathy model draft
  comes back with zero path tokens, exactly three identity-seam
  markers, prose kept. model.sh itself untouched (kernel-surface
  change would need the ceremony; chain-wide reply scrub is a
  follow-up).
- boundary: emitter-side path-redaction backstops + the report-queue
  alert-kind boundary control (test-first, red-proven; record:
  docs/records/2026-09-16-emitter-boundary-redaction.md in the kernel
  repo) — new shared `lib/redact.sh` `redact_home()` rewrites
  `/home/<user>/` to `~/` and `/tmp/` to `~tmp/`; wired into
  `jobs/config-backup.sh` `fail()` (alert row + STATE.md crumb; the
  console log keeps the raw path for the operator) and
  `jobs/oversight-tick.sh` `alert()` (text, identity token, and crumb
  redacted; flapping-suppression bookkeeping keyed on the redacted key
  so a prefix-only drift cannot re-fire). Sink side: kernel
  `scripts/report-queue --add alert` (ceremony-committed) rewrites the
  same path class before id/row/body derivation — the backstop for
  emitters that lack their own guard; progress kinds intentionally
  untouched (some lanes carry repo-relative paths). New suites:
  `tests/test-report-queue-redaction.py` (8 cases),
  `tests/test-config-backup-fail-redact.sh` (real fail() seam vs a
  fake queue), `tests/test-oversight-tick-alert-redact.sh` (real
  alert() seam; caught the identity-token leak the first emitter pass
  missed), plus 3 kernel contract cases in
  `tests/scripts/test-report-queue.py`. Forward-only: the ~295
  historical absolute-path progress rows stay (append-only ledger; no
  public history rewrite for username-class content).

- harden: credential-evidence integrity close-outs on the repaired rung
  (test-first; lib/credential-evidence.py + hermetic suite only) —
  duplicate credential names now fail closed (every instance reports
  `duplicate-row`, no `ok` for a duplicated name: a ledger that repeats
  a credential is untrustworthy); epoch fields enforce an unsigned-digits
  grammar and a future-vs-clock rotate epoch is malformed (same-host
  clock, no skew allowance); OLA 0 disables stale findings only
  (integrity findings still fire), pinning the cadence-params
  `credential-fresh-ola` semantics; record() stores canonical absolute
  evidence paths only — a relative path resolves beside the LEDGER or
  the record refuses, and a relative row can never verify from any cwd
  (raw-path rows' meaning depended on the invoking process). Epoch 0
  remains a stored-verbatim legal timestamp (fail-visible: it then
  reports stale) per the 06fa18d7 strict-parse decision; an ABSENT
  record epoch stamps the live clock. Suite: 22 hermetic cases including
  the exact production argv shapes (record positional epoch; bare
  `check LEDGER OLA` live clock). Full gate verified green on HEAD +
  this slice in a scratch clone (shared tree carries an unrelated
  in-flight dashboard lane's WIP).

## 2026-09-15

- fix: key-rotation-freshness rung un-deadened (three defects that only
  worked together to produce silence, then an alert storm when half
  fixed): (1) `lib/credential-evidence.py` record's production argv
  shape `record NAME FILE LEDGER "$(date +%s)"` stored rotate_epoch=0
  because the positional epoch was ignored (only `--now EPOCH` was
  read) — the positional epoch is now accepted, `--now` kept for the
  hermetic tests, and a non-integer epoch/OLA fails closed with a
  `malformed-argv:` SystemExit instead of a silent 0 or an
  os.time()-shaped AttributeError (check's no-`--now` default was
  `os.time()`, which does not exist on Python 3 — the check leg had
  never once emitted a finding because its stderr was discarded);
  (2) `jobs/credential-health.sh` sourced params.sh only after its
  `get_param` call, so the OLA silently became empty via
  command-not-found — sourced first, with a non-numeric guard falling
  back to the designed 604800; record/check stderr is no longer
  discarded; (3) steady state decided and documented: the first
  healthy-probe run seeds the ledger at the live clock (a stale epoch-0
  row can only be a legacy artifact of defect 1), afterwards only the
  tracked 401-rotate path re-records, so `stale` means no tracked
  rotation within the OLA and `hash-mismatch` means an untracked token
  change; findings are bounded (`head -n 5`) and ride the alert()
  identity dedup. record() now fchmods the ledger 600 on every write
  (O_TRUNC alone kept an existing wider mode). Tests: five new hermetic
  cases in test-credential-evidence.py invoke the exact production argv
  shapes (positional-epoch record pins a non-zero epoch, no-`--now`
  check verifies against the live clock, re-chmod-on-rewrite,
  malformed-argv refusals, extra-argv refusal); live epoch-0 ledger row
  migrated to the live clock.

- fix: report-ledger public-push exposure closed (decision record
  docs/records/2026-09-16-report-ledger-public-push-exposure.md) —
  credential-health alert() now dedups via --identity
  credential:<name>:<shape> + --evidence (observed fact; unchanged
  evidence suppresses, changed evidence re-fires, --window 0), so a
  persisting condition folds into one row's ×N marker instead of one
  public row per 5m run; path-bearing credential-evidence.py findings
  (ledger-missing / evidence-missing / hash-mismatch) and alert text
  are tilde-redacted ($HOME -> ~) before reaching the git-tracked,
  publicly pushed ledger; hygiene.py report root pinned structurally to
  the kernel repo (parent of automation/) — the cwd fallback had forked
  a second ledger at automation/docs/project/ whose two stray rows are
  migrated to the kernel ledger and the fork reverted. Tests:
  test-credential-alert-dedup.sh (new, sources the real alert() seam
  against a fake queue), test-credential-evidence.py path-leak case,
  test-hygiene.py hermetic kernel-root pin case.

## 2026-09-15

- docs: consideration deliverables promoted from .agent-scratch/consider/
  into the committed evidence ledger (docs free-commit lane) —
  docs/design/hnnghh-minimal-core-spec.md (minimal-core design exercise;
  d4-principles correction sidecar folded into its errata paragraph:
  patrol gate-crumb TTL exists, GATE_CRUMB_TTL_S=86400 in
  jobs/patrol.py, and cadence tier count is 8 live tiers) plus six
  docs/design/consider/ copies (memory-systems-survey.md,
  memory-bridge-design.md, research-lifecycle-audit.md,
  refactor-assessment.md, email-notification-comparison.md,
  pivot-synthesis.md). Copies per governed-fleet.md promotion
  convention (scratch originals retained); internal cross-references
  repointed to the promoted paths. No code changed.

- feat: research lessons + routes surfaces admitted to patrol and
  registry (GAP closure) — patrol-routes.tsv `research-ledger` row
  (30m, bad-execution) backed by `check_research_ledger`
  (ledger-missing / header-drift / row-malformed / lineage-contradiction
  / harvest-stale, 6h LESSONS_STALE_HOURS freshness vs the last adopted
  disposition); `research-routes.json` joins FEEDS freshness at 8h
  (build-on-demand feed tier); torch-ledger.tsv rows for
  research-lessons.tsv and research-routes (both audited live: 8 and 4
  non-writer consumers). tests/test-patrol.py red-first: 8 new cases,
  healthy fixture seeds both surfaces, counts 19->21 PASSes / 15->16
  results. Record:
  docs/records/2026-09-15-lessons-routes-patrol-admission.md.

- feat: adopted-lessons block in the context pack (node d1-surface) —
  closes the d1-harvest open question "should harvested lessons be
  surfaced in context-pack consumption". `lib/context-pack.sh` renders
  up to 5 `lesson: <ISO Z date> <line_id>: <sentence>` lines under an
  `adopted lessons (top-5 newest active, from research-lessons.tsv)`
  header, immediately after the `research index:` line: active rows
  only, newest first, lesson text visibly cut at 160 chars (marked_cut
  convention), block omitted silently when the ledger is absent, empty,
  or header-only. Derived-data rule respected — the ledger and wiki
  pages stay the sources of truth; the pack only cites. The
  `$(cat)`-swallows-trailing-newline trap was caught by live-ledger
  rendering before landing (last lesson line concatenated with the
  frontier header); a regression assert pins the next section's line
  start. `tests/test-context-pack.sh` +3 cases (absent ledger silent,
  empty ledger silent, populated: cap/order/placement/frontier
  intact).
- feat: research harvest organ (node d1-harvest) — the lifecycle audit
  (.agent-scratch/consider/research-lifecycle.md) showed adopted
  dispositions were a terminus (0 of them fed any runtime decision).
  `lib/research-harvest.py` now runs inside the 33-research-beat review
  transition after the disposition row lands: every adopted verdict is
  condensed into one actionable row in `research-lessons.tsv`
  (lesson_id=les-<yyyymmdd>-<line_id>, date ISO Z, line_id, subject,
  one-sentence lesson from the verdict reason, status=active), keyed by
  line_id — a re-adoption REFRESHES the row (never duplicates), a later
  non-adopted disposition retires it, and a rerun is a no-op. With the
  llm-wiki project vault mounted the lesson also appends
  `wiki/sources/LES-<line_id>.md` in the vault's established
  source-page shape (type: source frontmatter; the contract was
  determinable from local evidence: WIKI_SCHEMA.md packet/page shapes,
  the SRC-* pages, and hngh-lessons-current.md already indexed in the
  vault registry); hngh never writes meta/ or raw/ — the extension's
  wiki_rebuild_meta owns indexing and the wiki-health UNINDEXED alert
  covers the interim honestly. Fail-closed: malformed disposition
  input (header drift, prefix-short rows, over-wide rows) exits
  non-zero writing nothing (the beat alerts); legacy narrow rows from
  the pre-2026-09-12 6-column writer schema are padded, never fatal
  (the live dispositions file carries 72 of them). Malformed line
  enrichment is skipped. Vault absent: lessons TSV alone lands.
  Test `tests/test-research-harvest.py` (hermetic, 9 scenarios:
  harvest-on-adopted, non-adopted ignored, refresh-not-duplicate,
  idempotence, wiki shape, absent vault, fail-closed, fallback
  lesson), wired into `make test`; beat wiring proven end-to-end in a
  HOME-sandboxed stub run (disposition row -> lesson row in one beat).
- known-limit: the wiki page is not in the vault registry/index until
  the extension's next wiki_rebuild_meta run (once-daily auto-rebuild
  fires only when the probe flags the vault UNHEALTHY; a healthy vault
  with new pages turns UNINDEXED, which the probe alerts and the
  rebuild then heals). Operator-visible only as the standard
  wiki-health alert path.

- feat: isolated-worktree gate rehearsal (plan 2026-09-09-rehearsal-lane
  step 2) — `scripts/rehearse-gate.sh` runs a repo's gate inside a
  `git archive HEAD` temp-dir copy (plus named candidate overlays);
  `scripts/accept-plans.py` gained the off-by-default
  `ACCEPT_ISOLATED_GATE=1` seam: with it, both gate runs go through the
  rehearsal instead of contending with parallel delegated sessions (the
  2026-09-09 gate-red-rc2 blocks were load-correlated); a red — or rc=2
  refused — rehearsal blocks acceptance fail-closed with the tail in the
  alert row. `REHEARSE_LOG` is the rehearsal breadcrumb (log rows:
  `ts | repo=... | gate=... | rc=N`), used as the script's `--log`
  default. Test `tests/test-rehearse-gate.py` (10 hermetic cases),
  landed 550e8ff5 red (fixture inconsistency + missing wiring), repaired
  to green; wired into `make test`.
- known-limit: the rehearsal refuses (rc=2, fail-closed, with evidence)
  on the kernel tree as-is — the kernel suite's
  `tests/scripts/test-loop-history-guard.py` runs `git log` in the
  working repo, which an archive copy lacks. Operator-item: an
  out-of-repo seam there (kernel tests/ surface, forbidden in machine
  sessions today 2026-09-15) before an archived-tree kernel `make test`
  can run; the automation-repo rehearsal surface is proven on sandbox
  trees and the automation suite is green in the working tree.
- test: viz schema version-gate acceptance tests
  (`tests/test-viz-schema-version.py`, 14 cases, wired into
  `make test`) — hermetic gate for the versioning behavior of the
  validation seam (viz_schema.py, ea265b86): each family accepts its
  own current version (graph/1, patrol/1, history/1) through both the
  library API and the CLI; 'schema' absent/non-string/unknown fails
  closed (graph/99 detail names both versions); malformed JSON fails
  closed; unknown envelope keys fail closed while additive scalar keys
  inside entries WARN-accept; validate -> rc 2 contract asserted end to
  end; payloads survive json round-trip and still validate.

- fix: graph feed emits each surface node once
  (`jobs/graph-data.py`) — patrol-routes.tsv repeats surface values
  (kernel-gate and services are each walked by two patrols), and the
  patrol loop emitted `surface:<name>` once per row, so every feed
  carried duplicate node ids (`surface:kernel-gate`, `surface:services`)
  that corrupted graph-view's idxOf map (last-write-wins) and would
  trip the S2 feed validator. Surface nodes are now deduped per build;
  each patrol row still gets its own `watches` edge (edges stay N:1).
  Regression `BuildGraph.test_repeated_surface_node_emitted_once`
  extends the fixture with a second `services` patrol and asserts the
  global invariants end to end: unique node ids, zero self-loops, no
  dangling edges. read_tsv comment-row skipping untouched. Headless
  probe over real registries: dup_ids=[] and self_loops=0 in both
  all_sessions modes (545 nodes / 879 edges default).

- test: patrol/1 viz payload acceptance tests
  (`tests/test-viz-schema-patrol.py`, 23 cases, wired into
  `make test`) — strict validator for the viz synthesis input envelope
  `{"schema": "patrol/1", "findings": [...]}` with entries
  `{id (patrol:<id>), date, surface, cause, detail, supportive}`:
  malformed JSON, schema tag missing/wrong, unknown envelope/finding
  keys, missing fields, wrong types (id prefix, non-bool supportive,
  non-calendar YYYY-MM-DD), and duplicate ids all fail closed; unknown
  cause values WARN-accept (the cause vocabulary grows additively,
  journal rounds file unclaimed-err by design). Producer drift
  cross-check: a hermetic seeded patrol run (handoffs 3-dead fixture)
  must file its alert at identity `patrol:<id>` (stub report-queue
  argv) and the producer-shaped finding must validate clean, so the
  schema cannot silently drift from `jobs/patrol.py`. Fully hermetic
  (tempfile sandbox, PATROL_* env, no real ledgers/queue/home).

- feat: research-routes map view (routes/1, node d6-routes-view,
  0bb09044 + b9f58dc8) — research lines rendered as routes across a
  time axis. `jobs/research-routes.py` builds the payload from the
  research ledgers (dispositions transitions as segments, terminus
  shape by action: adopted filled / killed x / parked hollow / open
  origin dot, harvested = active row in research-lessons.tsv, violet
  dot); `viz_schema.py` gains the routes/1 family (`ROUTES_SCHEMA`,
  envelope `("schema", "generated", "routes")`, extras fail closed,
  live-vocab statuses incl. `contracting`); `dashboard-server.py`
  serves `GET /research-routes.json` (30 s cache, fail-soft);
  `dashboard/routes-view.js` + `routes.html` draw SVG polylines in
  lanes reviewed/crystallized/planned with a Routes tab (source files
  `git add -f` per the 6fbe8000 precedent — the `dashboard/` gitignore
  dir rule skipped them; b9f58dc8). Test `tests/test-routes-view.py`
  (37 hermetic cases, red-first) green post-commit; the
  viz-schema-version probe red-while-uncommitted by design went green
  on the slice commit. Record:
  `docs/records/2026-09-15-research-routes-view.md`.
- known-limit: no patrol/registry admission for the routes surface yet
  (jobs/research-routes.py, /research-routes.json, routes-view.js are
  not in config/patrol-routes.tsv); the running dashboard service needs
  a reload to serve the live route. Owned by the
  admit-lessons-routes-surfaces node.

- feat: report-link reply grammar (node d2-replyparse,
  `scripts/imap-poll.py`) — a reply whose subject carries
  `[hngh <report-id>]` (the same 8-hex id docs/project/reports.md
  carries) now drives state: `annotate_report()` appends an
  operator-reply annotation block to the report's body sidecar
  `docs/project/report-bodies/<ts>-<kind>-<id>.md` (absent sidecar
  recreated when the ledger row exists; the ledger itself and plan
  drafts are never touched), and `apply_directive()` scans the reply
  for the first `approve:`/`deny:`/`note:` line (colon is grammar; bare
  words never count) and transitions matching OPEN operator-items in
  `dashboard/operator-items.json` (approve -> handled, deny ->
  dismissed, note/missing/unknown -> annotation only) with an evidence
  string appended. Fail-closed: errors leave the feed byte-identical
  (tmp + os.replace); no subject link means behavior unchanged. Test
  `tests/test-imap-poll.py` +`ReportLinks` (12 cases; suite 32, green
  in-tree). Record: `docs/records/2026-09-15-email-reply-parse.md`.
- known-limit: `operator-items.json` feed rebuilds clobber
  email-driven dismiss/handled transitions (items reappear open);
  owned by the fix-email-dismiss-clobber node. The imap-poll suite is
  not wired into `make test` (runs via cadence/30m/56-imap-poll.sh);
  wiring is a candidate for the same admission pass.

## 2026-09-14
- feat: jcode permission bridge (plan 2026-09-14-jcode-primary-harness
  step 4) — `lib/launch-jcode.sh` refuses `JCODE_WORKER_APPROVE=1`
  without a readable `JCODE_WORKER_CERT` scope file (JSON
  `{"actions": [...], "expires": "<ISO-8601>"}`) that parses,
  declares a non-empty action list, and is unexpired (fail-closed
  rc 75 before any child spawns); `jcode/worker.mjs` re-validates the
  scope, denies every `permission_request` in an uncertified lane,
  allows only tool names inside the certified action list, and
  writes an allow/deny audit line to stderr per decision. Blanket
  auto-approval stays forbidden. Test `tests/test-launch-jcode.sh`
  cases 8-13 wired into `make test`.

- fix: dashboard report-queue mark-read failures surface inline instead of
  being silently swallowed (dashboard/app.js). Any non-403 POST failure now
  shows "mark-read failed: <error>" in the queue header and clears on the
  next successful fetch — the 2026-09-12 stale-server incident (live
  process predated the mark-read endpoint, 9b0876c) left 76 operator clicks
  invisible with zero feedback. Contract pinned in
  tests/test-dashboard-p1-ui.py (MarkRead). Research subject
  fail-20260912-correction-3146c023 killed with recorded disposition;
  position-cursor semantics tracked by plan
  2026-09-14-routed-correction-5dfa8329.
- fix: dashboard operator-items dismiss arm (armedId) revalidates at the
  fetch boundary (dashboard/app.js fetchOpState) — it survives a data
  refresh only while the armed item is still live (present and not
  dismissed) and clears otherwise, instead of persisting across fetches
  (ux-review finding dashboard-logs:2, routed plan 2026-09-10). Tab
  switches carry no new data and keep the arm. Contract pinned in
  tests/test-dashboard-p0.py.
- park (cause: premise stale): ux-review finding dashboard-logs:1 —
  "rerenderWithOpState and rerenderOp call renderLogs without checking
  lastRender.res, crashing when operator state updates before the
  initial spine load". Unreachable in the served sources: both entry
  points early-return on `lastRender.d === undefined` before any render
  call — the pre-load window routes to the known empty state, exactly
  the behavior the finding asks for; `lastRender.d` and `.res` are
  assigned atomically in renderLogs, so no state has d defined with res
  undefined; the renderLogs chain consumes no `res`; the sole res
  consumer (renderHeader) is call-site guarded. A literal res check
  would skip the op-items re-render these functions exist for. Contract
  pinned in tests/test-dashboard-p0.py (OpRerenderPreloadSafety).

## 2026-09-13

- feat: newspaper paid-cost conversion - procedural pipeline, local-only
  model sessions, overnight scheduling. Operator directive 2026-09-13
  (metered spend hit $5.55 / 220 calls / 5.09M tokens in 24h, edition
  no. 7): mechanical work becomes zero-LLM code and only genuinely
  editorial steps keep a model, always the LOCAL leg, always inside the
  operator's sleeping hours.
  - gdelt-news.py: headline polish is now a deterministic slug
    normalizer (collapse whitespace, strip wire prefixes, ASCII, 120-char
    cap) -- the hourly per-headline model call through the paid chain is
    gone; the model seam and GDELT_NEWS_POLISH flag are removed.
  - news-articles.py: pick_pin() returns LOCAL always (unsloth ->
    ollama); the kimi/ocgo quota-leg rotation and paid remote/deck
    fallbacks are never touched by this lane. Token cap per session is
    the cadence-params row newspaper-article-budget (default 1024, env
    NEWS_ARTICLES_BUDGET). Articles + story images now live under
    ~/.hngh/newspaper/<date>/articles|media (HNGH_NEWSPAPER_DIR seam,
    operator userspace-home policy: never in the repo); LAST_USAGE
    accumulates per-edition model-call telemetry from model.sh's usage
    counters.
  - newspaper-edition.py (new) + cadence/hour/41-newspaper-edition.sh
    (replacing 41-news-articles.sh): one edition per UTC date, built
    only inside the sleep window (cadence-params row
    newspaper-sleep-window, default 01:30-06:30 LOCAL; env
    HNGH_NEWSPAPER_WINDOW overrides; hour-tier ticks at :00 so keep the
    window spanning an hourly boundary). Edition = digest.md copy +
    local-model articles + rendered index.html + edition.json metadata
    with the cost line (sessions, tokens in/out, paid_calls=0) also
    appended to logs/newspaper-edition.log. Fail-closed: bad window /
    no digest / chain down = breadcrumb + exit 0, next hour tick
    retries; edition.json is the idempotence marker.
  - digest-public.py: extended-article links now read the hngh
    newspaper dir and say "(local edition only)" -- newspaper user data
    no longer lives under docs/ for the public edition to link.
  - Tests: new tests/test-newspaper-window.py (window parse/gate/
    idempotence + a full in-window build with the model stubbed: paid
    calls 0, usage counters recorded); test-news-desk.py polish cases
    rewritten procedural; test-gdelt-news.py + test-external-content.py
    drop the dead GDELT_NEWS_POLISH pin; test-news-articles.sh paths +
    hermetic HNGH_HOME_DIR/HNGH_NEWSPAPER_DIR seams. Targeted suites
    green (news-articles, news-desk, newspaper-window, gdelt-news,
    external-content, digest-html, digest-local); live smoke: one real
    edition end-to-end on the local llama-server, paid_calls=0.

## 2026-09-12

- feat: privilege model - 1password keyed access, sudoers.d delegation,
  checkbox grant surface. lib/credentials.sh now maps
  ONEPASSWORD_SERVICE_KEY onto OP_SERVICE_ACCOUNT_TOKEN at the shared
  seam (keyed entry: op ignores the desktop app, whose CLI-access
  prompts caused the 4-5 sudo-password dialogs; pre-set token wins) and
  op_ready falls back to `op account list` (whoami lies under desktop
  integration). New authoritative grant surface:
  config/permissions-profile.json (shipped default = everything denied)
  read through lib/permissions.sh (perm_load/perm_validate/perm_granted,
  fail-closed: missing or invalid profile = minimum grants);
  install.sh --profile FILE seeds checkbox prompts (TTY) / seed-as-is
  (non-interactive) and writes the resolved profile to
  ~/.hngh-automation/permissions-profile.json; sudoers drop-in TEMPLATE
  shipped at config/hngh-automation.sudoers.example (exact-command
  Cmnd_Aliases, no NOPASSWD:ALL, visudo-validated; never installed by
  the repo). Tests: tests/test-permissions.sh (hermetic: enum
  validation, fail-closed, sudoers law, installer TTY + non-interactive
  paths), tests/test-credentials.py mapping contract. Record:
  docs/records/2026-09-12-privilege-model.md.

- feat: gdelt news source - ranked world events with editorial priority
  scoring. jobs/gdelt-news.py (hour-tier drop-in cadence/hour/
  40-gdelt-news.sh) pulls GDELT 2.0's latest 15-minute export window,
  filters it through a tone-balanced editorial lens (world lane:
  QuadClass 3|4 or GoldsteinScale <= -5; good lane: CAMEO roots
  05/06/07/08 with AvgTone > 0, capped at NOTABLE), ranks stories by
  NumSources-driven priority bands (CRITICAL >= 60 / NOTABLE >= 20) and
  appends Deck-A-shaped per-article-linked blocks to the daily digest;
  fail-closed with 24h SOURCEURL dedup, so the paper publishes even when
  GDELT is unreachable. Tests: tests/test-gdelt-news.py (hermetic).
  Record: docs/records/2026-09-12-gdelt-source.md.

## 2026-09-11

- feat: bili compression on the opencode executor (clobber-safe
  integration) — launch-session's opencode branch rides a bili proxy via
  env-only MITM redirect (HTTPS_PROXY + the bili root CA; proxy reused
  from 127.0.0.1:8787 or self-spawned per launch and killed after the
  run; fail-open direct like the omp bctx branch). `bili opencode` was
  rejected: its temp-config path strict-parses JSON and would silently
  replace the hngh-owned OPENCODE_CONFIG layer (secret-deny block lost
  on .jsonc). One real session verified: rc=0, emitter attribution
  unchanged, proxy killed on exit, config byte-identical; plus the
  launch_store "$slug" fix for the set -u bare-call that voided
  per-launch stores (live-caught rc=75). Record:
  docs/records/2026-09-11-bili-opencode.md.

- fix: kernel gate recertified — loop-history exemption register
  re-keyed to the post-purge hashes (572d3e2/adb0307) and the 41f646a
  miss declared post-hoc, through one certificate ceremony; guard gains
  purge-proof patch-id fallback keying and a standing
  exemption-reachability self-check. Record:
  docs/records/2026-09-11-kernel-gate-recertified.md.

- feat: orchestrator stall detector + blocker-ledger re-attempt loop
  (as-above-so-below) — the run domain's created/.../dead lifecycle now
  exists at the orchestrator's own level: jobs/beat-watchdog.py (30m tier)
  detects consecutive launch-plane failures (beat-stall-n), same-cause plan
  deaths (blocker-escalate-n), and beat silence (beat-stall-silence-hours)
  over STATE.md/handoffs records, filing beat-stall alerts + one
  state/beat-blockers.tsv row per scope; overnight-cycle.sh's remediation
  loop forces the dream on blocked plans (blocker line: state what you
  would do differently), clears rows on success, parks after
  blocker-escalate-n same-cause dream-informed failures (bounded retries),
  and skips parked plans in the selector. Fail-first: a detector crash
  never breaks the tick. Tests: tests/test-beat-watchdog.py,
  tests/test-beat-blockers.sh. Record: docs/records/
  2026-09-11-orchestrator-roguelike-loop.md.

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

## 2026-09-14

- feat: `lib/harness/` capability-adapter layer (plan
  2026-09-13-dev-os-harness-cross-platform-patterns) — `TargetAdapter`
  ABC (`probe()` capability dict, `execute()` fail-closed on non-dict
  action) with static-capability `KDEAdapter`/`GNOMEAdapter`, and
  `registry.resolve_adapter()` mapping `HNGH_DE` (kde|gnome, case/space
  tolerant) to an adapter instance; unknown or unset value raises
  ValueError. Test `tests/test-harness-adapters.py` (10 hermetic cases)
  wired into `make test`.
- feat: gdelt lane multi-window NumSources signal (plan
  2026-09-12-dev-bigeye-caution-audit; research R3 from
  docs/research/2026-09-12-gdelt-gkg-trends.md) — `rank_rows` retains
  `num_sources` per item, `num_sources_window()` aggregates
  trailing-window records (bare timestamp = one source; malformed fail
  closed), and the hourly run reads the day's snapshots via
  `story_history()` to attach a 24h aggregate (`ns24`) to each fresh
  item's story-selection metadata before pick/render. Test
  `tests/test-gdelt-news.py` (9 hermetic cases) failing-first, green.
