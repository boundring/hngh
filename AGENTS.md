# Hngh agent notes

- Reply to the operator in English. Every message, summary, annotation and
  title is English/ASCII, whatever language the prompt or the conversation is
  in: bilingual-model language drift renders as unreadable CJK in the
  operator's terminal.

## Start here

1. Read `harness/PRINCIPLES.md` (the v2 doctrine) and `harness/CANON.md`.
2. Get the current state once, with `hngh-orient`. If the assignment carries a
   pre-digested brief, skip the orient run.
3. Run `git status --short` before editing anything.
4. Before reporting a result, run the smallest named verification. For a
   harness tool that is its `-selfcheck`, not a manual re-run.

## Current boundary (v2 — the Omarchy system harness)

Hngh v2 is a **thin harness of CLI tools** over the operator's existing tools:
oh-my-pi sessions, Tern tabs, the unsloth studio, and git. There is no daemon,
and none may be started: no service, provider, watcher, scheduler, agent, or
background process. Every tool is a foreground command that runs, reports, and
exits.

v2 lives in `harness/` in this repo (`harness/bin/`, `harness/roles/`,
`harness/src/`, `harness/PRINCIPLES.md`, `harness/CANON.md`,
`harness/ROUTE-v0.md`) and is mirrored from the canonical working tree
`~/Projects/hngh`. The v1 generation (Common Lisp kernel, `docs/`, `src/`,
`scripts/`, `automation/`) is ARCHIVED — see the last section of this file.

### Nothing lands without a selfcheck

Every tool has a `-selfcheck` sibling. A tool without one is not landed.
Before relying on a tool you changed, run its selfcheck:

```bash
bash ~/Projects/hngh/bin/<tool>-selfcheck
```

The repo mirror is `harness/bin/<tool>-selfcheck`. A selfcheck must be
sandboxed and honest about exit codes. A tool whose behaviour changed without
its selfcheck green is not landed.

### Proposals, not edits

The local-model funnel (`hngh-plan` -> `hngh-fill`) produces **proposals**.
It never edits silently. Fill output lands in
`~/.local/state/hngh/fill/filled/` with `SPEC.md`, `item.json`,
`test_out.log`, the reply attempts, and the workdir.

Integration is explicit, done by a human or by an orchestrator holding the
operator's go:

- copy the proposal into the target repo by **explicit pathspec** (never
  `-A`, never a bare `git commit`),
- run the target's own gate,
- commit under the operator's go; **pushes need the operator's go** too.

A proposal the operator has not integrated stays a proposal. Do not
"helpfully" apply it. Escalated items live in
`~/.local/state/hngh/fill/escalate/`, superseded ones in
`~/.local/state/hngh/fill/superseded/`.

### State roots

Live state is under `~/.local/state/hngh/`:

| Root | Holds |
|---|---|
| `fill/` | the fill funnel: `queued/`, `filled/`, `escalate/`, `superseded/`, `log.jsonl` |
| `route/` | `hngh-route` queue and results |
| `quotas/` | quota ledger rows and pause markers |
| `sessions/` | session feed |

Ledgers are append-only (JSONL). Fold views are derived from them and never
hand-edited. Exactly one writer per ledger file: two writers produce
split-brain diagnostics, not a merge.

### Gates: the four authority tiers

Actions are tiered by the house rules (`~/AGENTS.md` §11):

| Tier | Consent | Examples |
|---|---|---|
| **Silent** | never asks | read-only state probes; dry-runs |
| **Confirm** | asks once per domain | default handlers, editing an instruction file, enabling a service |
| **Presence-gated** | observe-only while the operator is at the machine; actuation needs an idle window or an explicit per-action go | anything that steals focus, moves the pointer, or types |
| **Forbidden** | explicit per-action approval, every time | deletion, `pacman`, `/usr/share/**`, secrets, the 2TB drive |

"May I act" and "is now a safe moment to act" are different questions.

### Model safety (VRAM)

- Every load carries an explicit **`max_seq_length`**, never an auto-derived
  one (`max_seq_length_auto_derived=false`; `hngh-fill` uses `HNGH_FILL_CTX`,
  default 32768). Auto-fit contexts have twice killed this desktop by fitting
  240k ctx against a 12B model.
- The **VRAM admission gate** holds current residency plus the studio's
  estimate at or below the budget (17 GB default, `HNGH_VRAM_BUDGET`;
  `estimate=resident` avoids double-counting). `hngh-vram-gate` is wired into
  `hngh-fill`'s preload and `hngh-route`'s dispatch.
- **Qwen3.8-27B is banned on this machine** (operator ruling 2026-10-30): it
  hangs the GPU. The ban stands while the desktop shares the card.
- **The desktop lives on the iGPU** (display on card0); the
  **dGPU is inference-only** (card1). The iGPU move landed 2026-10-30 and
  closed the shared-card crash class. After every reboot, verify display on
  card0.

### Quota pacing

- Daily allowance = remaining × 0.8 ÷ remaining days. Pacing the burn rate
  matters more than the session count.
- Tiered slowdown at 60% / 80% / 95% of a lane's window.
- Refresh the meter before trusting a number:
  `hngh-quota-refresh --source omp-usage`. The meter was once frozen for two
  days by a pause gate short-circuit; a stale row reads as false headroom.
- Analysis tasks are budgeted. An unbounded analysis is a quota leak.

### Doctrine

Read `harness/PRINCIPLES.md` (11 rules) and `harness/CANON.md` (12
crystallized principles, each with its adversarial guard) before designing
anything new. `harness/ROUTE-v0.md` records the routing design and the
measured fleet.

Short version: shepherd, don't replace; every tool has a selfcheck; ledgers are
the audit trail; gates at operator presence; config over code; measure before
features; boring shapes; small blast radius; never discard work without
measuring it; decisions get briefs; admission before load.

## Archived v1 generation (Common Lisp kernel — history, not the current boundary)

The v1 iteration (last synced 2026-10-16) is archived on the
`archive/v1` branch (`cc7aeb70`); its history is preserved in main's
ancestry. Its README and records live in `archive/v1` plus `docs/`. The
rules below still apply to v1-era trees (`docs/`, `src/` (Lisp),
`scripts/`, `automation/`) — they do not describe how v2 tools behave.

**Hngh v1 was a side-effect-free local kernel. Do not start a daemon,
service, provider, watcher, scheduler, agent, or process.** (v2 keeps the
no-daemon rule; see "Current boundary" above.)

Userspace data home (2026-09-13 operator directive): machine sessions
MAY write userspace data — newspaper copies, manga outputs, digest
archives, dispatch editions, local databases, knowledge-base content —
under `~/.hngh/` (layout contract: `newspaper/<date>/`, `manga/`,
`wiki/`, `db/`, `archive/`, `dispatch/`, plus the append-only
`catalog.tsv`), resolving paths through `automation/lib/hngh_home.py`
or `lib/common.sh` (`HNGH_HOME_DIR` overrides for tests). Nothing under
`~/.hngh/` is ever committed to this repo. Secrets, credentials, and
kernel run stores stay in `~/.hngh-automation/` (the two-home split);
kernel/gate/certificate state never moves to `~/.hngh`, and kernel
`src/` knows nothing of either home.

Machine sessions do not touch kernel `src/`, `tests/`, `Makefile`, or
`hngh.asd` (2026-09-03 staging boundary) — except certificate-bound
kernel mutations, which the operator-flexibility doctrine
(docs/records/2026-09-09-operator-flexibility-doctrine.md §2, amended
2026-09-13: docs/records/2026-09-13-wake-mutation-lane-landing.md)
allows through the ceremony — when a slice has a certificate path
(propose -> issue-cert -> mutation-check), the machine proceeds;
park on the operator only actions with no certificate path. Headless
secrets come from the 1Password service
account: `OP_SERVICE_ACCOUNT_TOKEN="$ONEPASSWORD_SERVICE_KEY"`
(docs/records/2026-09-09-1password-service-account-interface.md); with
that set, `op` needs no desktop app. Probing gate/secret state: use
`op account list`, not `op whoami` (whoami misreports under app
integration).

The retired system is outside this repository in an operator-configured local
archive. It is evidence, not an implementation source, and no active gate
verifies it anymore; the archive verifier was retired on 2026-08-19. Meaningful
archive material is harvested into the operator's separate llm-wiki knowledge
base, not imported back into this repository. Treat prior-state records
(`docs/records/`) as the authoritative history of the refactor.

### v1 brief: start oriented, do not re-walk

Run `python3 scripts/omp-bridge --orient` once for the current-state brief
(queue next, roadmap next, working tree, last ceremony commit), then act on
it -- do not re-run orientation reads (queue/roadmap files) before acting.
If your assignment already carries a pre-digested context pack or brief, use
that and skip `--orient`. Read-only hngh state is also exposed as MCP tools
(server `hngh`: `hngh_present`, `hngh_status`, `queue_report`,
`dashboard_readout`, `research_lines`) -- prefer those over opening repo
files for hngh-state questions.

### v1 engineering rules

- Keep dependency direction inward and behavior fixture-backed.
- Write a failing test before production behavior.
- Unknown, malformed, duplicate, or unauthorized input fails closed.
- Do not change unrelated retirement-diff paths.
- Inspect the active policy sources, candidate state, and named verification
  before editing.
- Commit a work slice as soon as it is verified: the full gate (`make test`)
  passes, the change is confined to the task's stated scope, docs/records are
  updated, the first-commit message matches the slice, and the working tree
  carries no unrelated changes. Verified commits need no prior operator
  instruction, and may be pushed to the configured `origin` remote
  (`git@github.com:boundring/hngh.git`). Altering provider configuration or
  enabling a service still requires a current policy certificate or an
  explicit operator instruction naming the exact action and target.
- Record architecture-relevant work in `CHANGELOG.md` and `docs/records/`.
- Repo-root `scripts/` is kernel code surface: machine-session commits
  there require the ceremony label (`hngh: candidate <hash>`); the
  automation free-commit rule covers `automation/` only.

### v1 working rules the repo enforces nowhere else

These four were being re-explained in session after session and existed only as
prose in a handoff. They are enforced by convention, not by tooling — which is
exactly why they belong in this file. (The machine-readable equivalents live in
`automation/scripts/lint-home-paths.py` and the `.beads/hooks/pre-commit` that
runs it; if a rule here must actually be enforced, it needs a `lint-*.sh`, not
a reader of this file.)

1. **Verify against the machine before writing a claim into a document.**
   `disk-headroom.sh` and the retired `doc-suite-update.sh` were both documents
   that outran their evidence. If you cannot re-run the measurement, say the
   number is unverified rather than carrying it forward.

2. **A destructive action routes through one chokepoint and has a dry run.**
   The existing good instance is `automation/jobs/disk-headroom.sh`'s single
   `prune()` chokepoint driven by `HNGH_OPT_DRY_RUN=1`. New destructive code
   follows that shape: one function, one env-var dry run, no `rm -rf` at a call
   site.

3. **Never `grep -rln` unscoped over `~/Projects/etc/`.** It walks cistern's
   164 G `target/debug/deps` and times out. Always scope, and always exclude:
   `--exclude-dir=target --exclude-dir=node_modules --exclude-dir=venv
   --exclude-dir=.venv --exclude-dir=__pycache__`.

4. **Commit by explicit pathspec, never `-A`.** This one has bitten twice:
   cadence jobs stage files into the index on their own schedule, so a bare
   `git commit` sweeps in whatever a background job staged since your last
   command. When a commit picks up unexpected files, `git reset -q` first, then
   re-`add` explicit paths. (`git status --cached` is not a command; it is
   `git diff --cached --name-status`.)

### v1 path seams and the systemd deploy

Every cross-project path default resolves through `ETC_ROOT` and `CISTERN_ROOT`,
declared **once** in `automation/lib/common.sh`. Two scripts that must survive a
mid-move tree declare their own instead — `automation/jobs/disk-headroom.sh` and
`automation/jobs/omarchy-config-adopt.sh`. If you are adding a tenth call site,
you have missed the seam; if you are editing one of those two, you are editing a
deliberate exception, and the comment above it says why.

**No systemd unit in `automation/systemd/` names a repo path.** Every
`ExecStart`/`ExecStartPost` is a shim under `~/.hngh/bin/`, because systemd does
not expand environment variables in the executable position of `ExecStart` —
only `%h` works. `WorkingDirectory=` is therefore absent from every unit; the
shims reproduce it. Deploy with
`bash automation/jobs/systemd-units.sh apply`, which also removes any deployed
`hngh-*` unit that has no repo counterpart — the check that stops a retired unit
from being re-armed by hand. The hourly reconciler
`automation/cadence/hour/16a-systemd-units.sh` runs `status` and only applies on
drift.

## Jcode orientation addendum

@docs/agent-notes/jcode-orientation.md

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:46cd31e7 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
