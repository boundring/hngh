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
