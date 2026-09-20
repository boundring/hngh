<!-- Jcode orientation addendum for hngh. Operator-directed 2026-09-14,
     docs/records/2026-09-14-jcode-primary-harness-admission.md, plan step 1.
     Jcode sessions in this repo read this via AGENTS.md import. -->

## hngh orientation brief (Jcode sessions)

You are working in the hngh repository: a side-effect-free Common Lisp
kernel plus an edge-tier automation surface, governed by a
certificate-bound ceremony. Read `AGENTS.md` at repo root first; it is
binding. This addendum is the Jcode-equivalent of the omp plugin's
orientation injection.

### One-shot orientation (do not re-walk)

Run once, act on it, do not re-run orientation reads before acting:

    python3 scripts/omp-bridge --orient

Returns: queue next, roadmap next, working tree, last ceremony commit.
`scripts/omp-bridge` is harness-neutral despite the name (the name
predates the Jcode admission); a `scripts/jcode-bridge` alias is a
plan-step candidate, not yet landed.

### Read order (bounded)

1. `AGENTS.md` (repo root) - boundaries, engineering rules.
2. `docs/README.md` - the map; start at "Start here".
3. `docs/project/roadmap.md` - the staged route; work rides named
   stages, nothing skips the gates.

### Standing rules for any session here

- Every mutation is certificate-bound: propose → issue-cert →
  mutation-check. No certificate path → park it on the operator.
- Machine sessions do not touch kernel `src/`, `tests/`, `Makefile`,
  `hngh.asd` outside the certificate lane.
- `automation/` is the free-commit surface; repo-root `scripts/`
  commits need the ceremony label (`hngh: candidate <hash>`).
- Userspace data lives in `~/.hngh/` (never committed); secrets in
  `~/.hngh-automation/` via the 1Password seam. Two homes, never mixed.
- Write the failing test first; fail closed on unknown input; commit a
  verified slice as soon as `make test` is green and scope is confined.
- Always answer the operator in English/ASCII.

### Beads cwd guard (2026-09-20)

`bd` resolves its store from the **current working directory**: from outside a
`.beads`-bearing repo it silently targets the home-level store `~/.beads`
(dolt-embedded, not a git repo, no remote, never synced). Census
(2026-09-20): it already holds 11 absorbed probe/test issues
(`tmp_CJynXp14cN-*`) and a half-materialized `embeddeddolt/hngh` db with the
real hngh dolt remote configured. Rule: run `bd` only from a cwd whose git
root contains `.beads` (hngh: `~/Projects/etc/hngh`); never
create/close issues from `$HOME` or unrelated cwds. Optional `~/.bashrc`
guard:

```bash
bd() {
  local root; root=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" || ! -d "$root/.beads" ]]; then
    echo "bd: refusing: cwd has no .beads-bearing git root (would hit ~/.beads)" >&2
    return 1
  fi
  command bd "$@"
}
```

Note: every bd invocation also appends telemetry to `~/.beads/eventsData/`
regardless of cwd; that is a known side channel, not issue data. Do not
delete or reuse `~/.beads` casually — it is evidence of absorbed writes.
Census detail: `docs/agent-notes/briefs/2026-09-20-home-beads-census.md`.

### Reading hngh state (prefer MCP/read-only)

MCP server `hngh` (stdio, landed): `hngh_present`, `hngh_status`,
`queue_report`, `dashboard_readout`, `research_lines` - all read-only.
Dashboard: `http://127.0.0.1:8890/`. Remote:
`github.com/boundring/hngh`.
