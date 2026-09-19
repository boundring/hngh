# Hngh agent notes

- Always respond to the operator in English: every message, summary,
  annotation, and title is English/ASCII, regardless of prompt language
  or conversation content (bilingual-model language drift renders as
  unreadable CJK in the operator's terminal).

## Start here

1. Read `docs/README.md`.
2. Read `docs/project/roadmap.md` and the record relevant to the task.
3. Inspect `git status --short` before editing.
4. Run the smallest named verification before reporting a result.

## hngh brief: start oriented, do not re-walk

Run `python3 scripts/omp-bridge --orient` once for the current-state brief
(queue next, roadmap next, working tree, last ceremony commit), then act on
it -- do not re-run orientation reads (queue/roadmap files) before acting.
If your assignment already carries a pre-digested context pack or brief, use
that and skip `--orient`. Read-only hngh state is also exposed as MCP tools
(server `hngh`: `hngh_present`, `hngh_status`, `queue_report`,
`dashboard_readout`, `research_lines`) -- prefer those over opening repo
files for hngh-state questions.

## Current boundary

Hngh is a side-effect-free local kernel. Do not start a daemon, service,
provider, watcher, scheduler, agent, or process.

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

## Engineering rules

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
