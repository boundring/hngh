# 2026-09-16 — identity-seam reconciliation: the Fixture authorship window

## Defect

A placeholder `[user]` block (`name=Fixture`, `email=fixture@example.invalid`)
sat in this repo's `.git/config` from 2026-09-13 00:04:04 -0400 until
2026-09-16 19:25 -0400. Every commit made by any session in that window
without an explicit per-command identity carried the anonymous author.

## Canonical census (method + ground truth)

Method: `git log --format=%ae ba6b3905^..30556e67` (inclusive window),
cross-checked with `git log ba6b3905..30556e67` plus the boundary commit.

- Window: `ba6b3905` (2026-09-13T00:04:04-04:00, first Fixture commit) ..
  `30556e67` (2026-09-16T15:22:25-04:00)
- **566** commits authored `fixture@example.invalid`
- **2** commits authored `automation@hngh.local` (`e916af9e`, `8e376ff2`,
  the only per-command `-c` identity commits in the window). Both are
  2026-09-13 20:20:31 / 20:21:07 -0400 -- window **day 0**, not
  2026-09-16: the per-command identity cure was demonstrated in-session
  the same day the window opened, then not propagated to the ambient
  `.git/config` for ~3 days (strengthens the cleanup-lag reading below;
  corrected of record in
  docs/records/2026-09-17-supportive-record-fact-corrections.md)
- Total: **568**

Count reconciliation: commit `16dae2eb`'s message says "564"; the
supportive-4 artifact says "567". Both are wrong; this record is canonical.
(The 564 figure was computed before the window's final commits landed;
the 567 figure used an exclusive-window `git log` that drops the boundary
commit. Use the method above.)

## Full window census recount (2026-09-17, gate follow-up)

The audit child's attribution table summed to 608 over the 566 population.
Recount over `ba6b3905^..30556e67` (both boundary commits are
Fixture-authored and inside the window: `ba6b3905` "fixture",
`30556e67` "research: fail-20260916-..."), each commit assigned to exactly
one bucket, writer-template subjects taking precedence:

| Bucket | Subject template | Writer | Commits |
|---|---|---|---|
| research-beat | `research: <id> <state>` | `cadence/hour/33-research-beat.sh` | 240 |
| kernel ledger sync | `docs: machine ledger sync — N changed file(s)` | `cadence/hour/30-kernel-ledger-sync.sh` | 89 |
| ceremony candidates | `hngh: candidate ...` | kernel `src/adapter/mutation.lisp` | 42 |
| torch audit | `automation: torch numbers refresh (date)` | `cadence/day/17-torch-audit.sh` | 4 |
| plan-ledger sync | `automation: plan-ledger sync — N changed file(s)` | `cadence/day/14-plan-ledger-sync.sh` | 2 |
| lesson harvest | `chore: lesson-harvest handoff counter tick` | `cadence/day/01-lesson-harvest.sh` | 2 |
| plan-tick session commits | `docs: plan tick — ...` / `plan tick — ...` | one-off manual/overnight sessions | 6 |
| one-off manual/overnight | everything else | ad-hoc sessions | 181 |
| **Total** | | | **566** |

Plan-ledger updates total 9 commits: the 2 writer ticks + 6 session ticks,
plus `1f818776` (`research: fail-20260911-correction-style-css ...; plan
ticked`), which combines a research-beat disposition with a plan tick and is
counted under research-beat.

The 181 one-off commits by subject family: `automation:` manual automation
slices 77 (plus 2 `automation tests:`/`automation+kernel-tests:` variants →
79 `automation*`), `docs:` manual docs edits 40, `fix:` 15, `feat:` 12,
non-candidate `hngh:` (observe/registry/stall-verify) 6, `design:` 4,
long-tail singletons (tests, slow-units, bench-trigger, routing,
rehearsal-lane, dash-selfreview, cost-tiering, cap-block, journal,
viz-transport, gdelt, jcode, patrol, plan, mcp server, model.sh, config,
non-harvest `chore:`) 23, degenerate fixtures (`fixture`, `Revert
"fixture"`) 2.

Deltas vs the child's table (240 + 89 + 42 + 4 + 4 + 2 + 227 = 608): the
overflow is exactly 42 = the candidate count, so the child counted the 42
ceremony candidates twice (once as a lane, again inside its one-off
residual). Its "plan-tick 4" matches only the 4 `docs: plan tick` subjects:
the writer produced 2, and 6 session tick commits exist (8 plus the research
overlap). Correct one-off figure is 181 (child's 227 − 42 double-counted
candidates − 4 tick subjects reattributed). Verified by two independent
methods: per-family `git log --grep` counts and a per-commit first-match
assignment whose buckets sum to exactly 566 with a single overlap.

## Remediation landed (2026-09-16, operator-approved)

1. Local `.git/config` identity set to `hngh-machine
   <automation@hngh.local>` (the convention already established by
   `e916af9e`/`8e376ff2`).
2. `automation/jobs/config-backup.sh` — the one committed auto-committer —
   now pins identity per invocation (`-c user.name` / `-c user.email`),
   so attribution never depends on ambient config state.
   Commit `16dae2eb`; `make test` 2931 checks green; CI green.
3. Post-fix verification: all 15 commits `16dae2eb..HEAD` correctly
   authored `hngh-machine`; zero post-fix Fixture commits.

## No-rewrite decision

The 566 misauthored commits keep their recorded authors. Rewriting would
churn every patch-id the loop-history guard pins (its exemption table
carries the 2026-09-13 fixture pair by design), for metadata whose
security value is nil — git authorship is trivially forgeable and is not
an authorization surface. The certificate system (paths + content hashes
+ ten principles) verified every mutation in the window; the exposure is
attribution/traceability only. This record is the correction of record.

## Remaining unpinned committers (closed 2026-09-16, ~20:30)

The ambient-identity-writer-audit (this node) enumerated every
git-invoking automation writer (cadence/, jobs/, lib/, scripts/):

- Committing writers: the five cadence committers below, plus
  `jobs/config-backup.sh` (pinned by 16dae2eb). All now pin identity
  per invocation (`-c user.name="hngh-machine"
  -c user.email="automation@hngh.local"`); contract pinned by
  `automation/tests/test-identity-seam.py` in the automation gate.
- Read-only writers (never commit): `jobs/doc-suite-update.sh` (rev-parse
  / log / cat-file fact checks), `lib/context-pack.sh` (status),
  `cadence/hour/16-remote-push.sh` (fetch/push only),
  `cadence/day/04-review-prep.sh`, `cadence/day/09-email-digest.sh`,
  `jobs/security-check.sh` (fetch), the python feeds
  (`plan-feed.py`, `research-feed.py`, `history-feed.py`, `patrol.py`),
  `scripts/rehearse-gate.sh` / `scripts/accept-plans.py` (archive /
  show), `scripts/email-digest.py` (log/status).
- Kernel ceremony executor `src/adapter/mutation.lisp:362` builds a bare
  `git commit` and still takes ambient identity; its 42 window commits
  prove it fired under Fixture. Kernel src/ is outside the
  automation free-commit surface, so it is reported here for the
  operator rather than edited. Mitigation in depth: the remediated
  local `.git/config` identity plus the automation contract test above.
  CLOSED 2026-09-17: see "Kernel ceremony commit identity" below — the
  pin landed in `scripts/ceremony-drive`, src/ untouched.

The five writers fixed in this slice, with the window commits they
authored as Fixture (family census above):

- `automation/cadence/day/01-lesson-harvest.sh:86` (2, `chore:` ticks)
- `automation/cadence/day/14-plan-ledger-sync.sh:39` (2, `automation: plan-ledger sync —`)
- `automation/cadence/day/17-torch-audit.sh:202` (4, torch refresh)
- `automation/cadence/hour/30-kernel-ledger-sync.sh:45` (89)
- `automation/cadence/hour/33-research-beat.sh:183` (240)

## Kernel ceremony commit identity (closed 2026-09-17)

The last open seam from this window is closed. The kernel ceremony
executor (`src/adapter/mutation.lisp` `command-for`, the certificate
bound `git commit`) still took ambient identity after the automation
pins above: its 42 window commits prove it fired under Fixture, and
`scripts/ceremony-drive` set no `GIT_*` identity before spawning the
mutation-check subprocess. Kernel `src/` stays untouched (the fixed
argv contract and its tests are intact); the pin landed at the drive
layer instead, in `scripts/ceremony-drive` (kernel `scripts/` —
committed through the ceremony itself, per the operator-flexibility
doctrine): it exports `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` /
`GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL` =
`hngh-machine <automation@hngh.local>` as defaults before the loop
runs, applied only when the caller did not already export the
variable, so an explicit operator environment keeps precedence.

- Contract test: `tests/scripts/test-ceremony-drive-commit-identity.py`
  (red-proven pre-fix — a real drive over a leaky-ambient fixture repo
  committed as `Leaky Ambient <leaky@example.invalid>`; green
  post-fix; second case pins the operator-override precedence). Wired
  into the kernel `make test` gate.
- Post-land verification: the ceremony commit carrying this fix is
  itself authored and committed `hngh-machine <automation@hngh.local>`
  through the pinned path.

## Alert trail

Alert `fb894f8d` (2026-09-13 04:10:41Z) named the Fixture identity
minutes after it appeared: the pair landed 04:04:04Z / 04:04:51Z
(commits stamped -0400), so detection latency was 6m37s / 5m50s.
Earlier wording here ("hours after it appeared") was a -0400/UTC
timezone misread, corrected 2026-09-17 (see
docs/records/2026-09-17-supportive-record-fact-corrections.md); the
near-immediate detection sharpens the point: the loop-history guard
went red same-day and the ceremony refusal was correct behavior, and
the gap was execution, not detection. Filed
upstream (jcode maintainer): the deep-swarm machinery defects
encountered while auditing this (gate ownership-strip variants, driver
await-wedge) are separate records.

## Non-sh/py writer audit (closed 2026-09-17, bounded negative)

The contract test scanned only `*.sh`/`*.py` under
`automation/{cadence,jobs,lib,scripts}` (`SURFACES` + the suffix
filter); every executable automation artifact outside those two
suffixes was enumerated and checked for git-commit capability. Result:
**no non-sh/py writer can run `git commit`**. The negative is bounded
by the exact file set below; the guard now covers the code classes so
it stays true.

### Exact files scanned and verdicts

Code (read line-by-line for git/commit/subprocess capability):

- `automation/dashboard/*.js` (15: app, sessions, gantt, graph,
  history, story, system, plans, research, routes, schedule, kb,
  overview, feedback, sessions-view) — browser-side display only, zero
  `child_process`/exec/spawn usage. The only `git`-adjacent strings
  are display prose and commit-hash footnote rendering.
- `automation/jobs/ui-audit.mjs` — the only automation JS with
  `child_process`; `execFileSync('python3', ...)` to report-queue /
  telemetry only (no git argv anywhere).
- `automation/jcode/worker.mjs`, `render-blocks.mjs` — SDK client over
  a pinned Jcode instance home; mutations refused unless certificate-
  scoped; no process spawn, no git.
- `automation/dashboard-server.py` (root, outside all SURFACE dirs —
  a path gap in the original guard, .py suffix not dir-scoped) — every
  `subprocess` call enumerated: report-queue, system-feed, systemctl
  reset-failed, `jobs/config-backup.sh agent-configs --mode push`
  (the pinned seam itself, dashboard-server.py:827), fleet-manager,
  launcher/tile spawn. Launcher templates come from built-in
  `konsole tail` defaults or `~/.config/hngh/ui-config.json`
  (operator-owned, display-only `tail -f` templates); none can express
  git.
- `automation/scripts/model-health` (bash, unsuffixed) — no git usage.
- `automation/scripts/generate-publication` (python3, unsuffixed) —
  the word "commit" appears once, in a docstring ("never committed").
- `automation/Makefile` — `sweep` delegates to `jobs/sweep-artifacts.sh`
  (a .sh, inside the scanned surface).
- `automation/systemd/*.service|*.timer` ExecStart lines — all point
  at `jobs/*.sh`, `scripts/*.sh|night-session.sh`, or
  `dashboard-server.py`; the two non-automation entries are
  `/usr/bin/python3 scripts/run-autonomous` and dashboard-server.py.
- Kernel-adjacent executable `scripts/run-autonomous` (repo root,
  referenced by `hngh-autonomy.service`) and `scripts/ceremony-drive`
  (Lisp, .lisp-suffixed records under `automation/store/*/record.lisp`
  are receipts, not executed code; the ceremony executor's identity
  seam is closed separately above).

Config / registration (no executable writer outside .sh/.py):

- `automation/cadence-params.tsv` — every job reference is .sh/.py.
- `automation/config/opencode/opencode.jsonc`,
  `opencode-safety.jsonc` — MCP stdio servers (context7, docs,
  codegraph) and agents; no shell/git command hooks.
- User crontab: empty. All scheduling is systemd user timers driving
  `cadence-tick.sh` (itself .sh, scanned).
- `automation/package.json` — no `bin` entries, no scripts; node
  entry points are the .mjs files above.
- The broad `git commit` grep over all non-sh/py files matches only
  DATA: `dashboard/plans.json` (plan-ledger prose), `logs/*.json`.

### Guard scope extension (this slice)

`automation/tests/test-identity-seam.py` now also scans `.js`/`.mjs`
under `automation/{dashboard,jcode}` plus the four original surfaces,
with JS comment stripping (//, /* */) and string contents KEPT (the
ordinary JS invocation is quoted: `` execSync(`git commit ...`) `` /
`spawn("git", ["commit", ...])` — fail-closed: reword prose instead),
plus git-array/argv form detection (`["git", "commit"]`,
`spawn("git", [... "commit" ...])`, `"git", "-c", ..., "commit"`) on
shell/python raw lines. Built-in self-tests (tmp-dir fixture probes
run on every invocation) keep the scanner itself from rotting.
Red-proven: a planted unpinned `dashboard/*.mjs` writer failed the
old guard (rc=0) and fails the new one (rc=1, single precise
violation); green on the clean tree; full automation `make test`
green. Remaining known blind spots (deliberate): `.lisp` store
records (data), other suffixes under SURFACES (none exist today —
the unsuffixed/non-sh/py inventory above is `.md/.tsv/.json/pyc`).

### config-backup parity verification (post-fix, secondary)

`16dae2eb` (2026-09-16 15:27 -0400) pinned the identity. Since then:
exactly one `config-backup.sh` run in the journal (Sep 16 20:30:02,
the 30m tick): `ok copied=10 skipped=0 committed=0 pushed=1
target=git@github.com:boundring/agent-configs.git`. Lane repo
`~/.local/state/git-back-dots/agent-configs` working tree is clean
(zero drift), last gbd commits are `3f9e429` (Sep 16 13:30) and older,
all authored `git-back-dots <gbd@localhost>` (the operator-run timer
lane, expected), `workarounds/*` initial states authored boundring.
`committed=0` with a push is correct parity behavior: no drift, no
commit — the pin has simply not yet been exercised by a real commit.
The hngh-machine author on this lane remains unobserved-by-design
until the first drift; the contract test pins the mechanism, not the
observation.

## Identity-record hygiene caveats (2026-09-18, plan step 8)

Appended per backlog item identity-record-hygiene-caveats
(plan 2026-09-18-backlog-p0-security-fixes.plan.md step 8). These
caveats bound what the pins and this record can honestly claim:

- Attribution-only exposure. The `hngh-machine
  <automation@hngh.local>` pin answers "which writer acted", not
  "who authenticated": every push rides the operator's stored SSH
  credential, and the author string is set by whoever invokes git.
  The pins support forensics and audit-log readability; they are not
  user attribution in an authentication sense.
- Forgeable authorship. Git author/committer identity is client-side
  metadata with no cryptographic binding on this repo's push path.
  Any process (or person) with repository write access can write
  these strings verbatim. Audit conclusions drawn from
  authorship-matching should therefore be corroborated by commit
  content, timestamps in journal/breadcrumb data, or the push-side
  provenance instead of resting on the author string.
- Nil security value where applicable. The identity pin closes an
  attribution and correctness gap (anonymous "Fixture" authors in
  audit trails), not a confidentiality or authorization gap. It
  neither restricts what a session can do nor protects the
  repository; capability enforcement lives in the gate/certificate
  ceremony and filesystem permissions, not in `git -c user.name`.
