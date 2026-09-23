# 2026-09-23 — home-path scrub (tree + history)

Directive (operator, 2026-09-23): local absolute home paths
(`/home/<user>/...`) must never appear in Hngh project files — they do
not work for later users. Historical instances are not exempt; the git
history is scrubbed too ("if the git history needs to get scrubbed, it
does"). Completes the remediation line opened by
[2026-09-17-research-doc-writer-redaction.md](2026-09-17-research-doc-writer-redaction.md)
(729 occurrences across 144 tracked research docs de-identified in the
tree) — the tree was clean of the family in those paths, the rest of the
repo and all of history still carried it.

## Tree sweep (this commit)

Three parallel slices, zero exceptions (every occurrence):

- **Code** (bash/python, incl. test fixtures): behavioral paths resolve
  through `$HOME` / `os.path.expanduser`, reusing the existing override
  idiom (`HNGH_HOME`, `HNGH_REPO`, `HNGH_HOME_DIR`) — nothing invented,
  precedence unchanged. Test fixtures derive the same values, so
  behavior on this machine is byte-identical.
- **systemd units** (`automation/systemd/*.service|timer`, ~40 hits):
  the systemd-native `%h` specifier (`ExecStart=%h/...`,
  `WorkingDirectory=%h/...`). Units do not shell-expand `$HOME` — a
  reader must not "fix" `%h` back.
- **MCP/agent configs** (`opencode.jsonc`,
  `automation/config/opencode/opencode.jsonc`, `.mcp.json`,
  `.omp/mcp.json`): command arrays wrap in
  `["sh", "-c", "exec ... \"$HOME/...\""]` so every MCP host resolves
  the path regardless of tilde/env expansion support (opencode expands
  `~/` in file resolution only — the MCP spawn path is client-owned).
  `automation/config.env`: `${HNGH_HOME:-$HOME/Projects/etc/hngh}`;
  `automation/config/hngh-packages.tsv` install-path column: `~/...`
  (consumer check: `jobs/graph-data.py`, `jobs/patrol.py`
  `check_package_ghosts` read rows; column is display-level evidence).
- **Docs**: 79 files / 129 lines to `~/...` (byte-exact re-derivation
  against `HEAD`: only declared substitutions changed). Six
  defect/literal-token records where the raw path IS the subject render
  `/home/$USER/...` so the raw-vs-tilde lesson survives
  (`automation/CHANGELOG.md` README-sweep item,
  `automation/docs/bili-omp-jcode-config-fix.md` "never hardcode" rule).
- **omp plugin sources** `~/.omp/plugins/hngh-bridge/src/*.ts`:
  `process.env.HOME ?? homedir()` (outside this repo — machine-local,
  carried by the operator's agent-configs backup).

Verification: kernel gate `make test` — 2934 checks passed; automation
gate `make test` green; `git grep -n '/home/<user>'` (the literal login
form of the pattern) empty across tracked and untracked-non-ignored
files.

## History scrub (follows this commit)

- Tool: `git filter-repo --replace-text` + `--replace-message`, rule
  `regex:/home/<operator-login>==>~` (run with the literal login);
  full `git bundle` backup taken first and kept in
  `~/.hngh-automation/scrub/`; `main` force-pushed to
  `git@github.com:boundring/hngh.git`.
- Counts at scrub time: 474 commits carried the literal in blobs or
  messages (5 message-body hits, 0 subjects).
- Consequences accepted (same class as the 2026-09-20 secret scrub,
  tag `pre-scrub-backup-20260920`): every commit hash changes, so
  hash citations in records/ledgers name pre-scrub history preserved in
  the backup bundle; candidate content-hashes in
  `hngh: candidate <hash>` messages name blobs that differ in rewritten
  pre-scrub commits. Post-scrub verification notes are appended below.

## Residual (not scrubbed, by design or operator lane)

- Bare `bricker` username/hostname tokens (`brickertop`,
  `bricker@brickertop`): the project's de-id verdict scopes the family
  to `/home/<user>` paths and excludes name/hostname mentions
  (2026-09-17-research-doc-writer-redaction.md).
- Research-line ID stems and artifact filenames containing
  `home-bricker-...` — renaming tracked research artifacts is an
  operator-lane decision (`automation/CHANGELOG.md` 2026-09-18 note),
  tracked in [2026-09-18-tracked-remediation-plan.md](2026-09-18-tracked-remediation-plan.md).
- Gitignored scratch (`.agent-scratch/`, deliberate CI-repro fixture
  copies) — not project files.
- Origin refs `__dolt_remote_info__` / `dolt-data-check` (beads Dolt
  namespace) are outside `filter-repo`'s reach; parked on the operator.

## Post-scrub verification

- Two passes over `refs/heads/main` (2,134 commits parsed):
  1. `--replace-text` + `--replace-message` with the rules file;
  2. `--blob-callback` zip-member rebuild (fail-closed: only blobs
     that parse as zip are rewritten) — one binary carrier found: the
     first `docs/publication/hngh-memoir.epub` blob (added by the
     portfolio-surface commit; the tip epub had already been
     regenerated clean, so the tree needed no change).
- Verified empty: `git log -S'/home/<user>'` (pickaxe), commit-message
  bodies, and a byte-level scan of every tracked file at tip (raw
  bytes + every zip member). The rebuilt historical epub is a valid
  5-member zip with zero residual.
- Rewritten head at push time: `2b7c95e0` (`docs: machine ledger sync`)
  over `97e0f7fe` (this slice's sweep commit). Every earlier hash also
  changed (two rewrite passes): hash citations in records and ledgers
  name pre-scrub history, recoverable from the backup bundle
  `~/.hngh-automation/scrub/pre-path-scrub-20260923.bundle` (36M, all
  refs).
- Force-pushed to `git@github.com:boundring/hngh.git` (forced update
  `92893e2c...2b7c95e0`).
- Local-only refs deliberately out of the rewrite (`--refs`-scoped):
  `refs/omp-undo-redo/*` (omp edit snapshots), `refs/dolt/*` (beads
  Dolt namespace), local tag `pre-scrub-backup-20260920` — none are
  pushed to origin.

## Automatic defense (landed same day)

Operator directive after the scrub: this must never be re-added to the
remote — by anyone, including agents. Invariant enforced: **the real
local home (`/home/<actual login>`) never enters tracked content.**
Deliberately legal: fake-login fixtures (`/home/aubergine`,
`/home/testuser`, `/home/bri`, … — the scrubber's test vocabulary) and
URL/UNC wire data (`https://x.io/home/u/f`) that must survive
scrubbing. The rule is therefore login-derived at runtime, not a
blanket `/home/...` ban (a blanket rule flags 194 legitimate fixture
and wire-data locations in this tree).

Enforcement at three points, one checker
(`automation/scripts/lint-home-paths.py`, stdlib):

- `automation/Makefile` test gate — every gated push (the machine's
  push path gates on `make test`) and every agent verification loop;
- `.beads/hooks/pre-commit` — `--staged` mode; a violation aborts the
  commit where the action happens;
- `.beads/hooks/pre-push` — full tree of every pushed rev; a violation
  aborts the push. This is the client-side remote boundary. Ceiling:
  `git push --no-verify` bypasses client hooks (a git limitation) —
  the machine's own push path gates on `make test` and never passes
  `--no-verify`; a server-side content rule would need CI, deferred.

The checker scans bytes and zip members (the memoir-epub class above;
an unparseable `PK` payload fails closed). Pattern boundary:
`/home/` + `pathlib.Path.home().name`, not followed by
`[A-Za-z0-9._-]`. Ceiling (`# ponytail:` in the script): the running
account's home basename only — widen to `pwd.getpwall()` if
multi-account leaks ever appear. Red-first test:
`automation/tests/test-lint-home-paths.py`, which constructs its
violation string at runtime (a hardcoded login in the test would trip
the rule itself).
