# The wiki surface (display alias: the Athenaeum)

Status: adopted 2026-09-07. Lexicon row added to
[descent.md](descent.md). Companion layers: the Mirror
([operator-mirror.md](operator-mirror.md)) and the Compass
([context-manager.md](context-manager.md)).

Canonical term: **wiki surface**. Display alias: **the Athenaeum**.
Same scope rules as every design-layer alias: kernel records, CLI
verbs, and report fields say `wiki`, `vault`, `registry`; the flavor
name appears in operator-facing prose and dashboards only.

## Topology: two vaults, one division of labor

The llm-wiki extension (@zosmaai/pi-llm-wiki, installed globally under
~/.omp/plugins) owns every vault's `raw/` and `meta/`. Those
directories are capture packets, the registry, the index, backlinks,
and the event log -- extension property, read-only to everyone else.
The `wiki/` directory holds the rendered pages.

Two vaults exist and they are not interchangeable:

- **Personal vault** (`~/.llm-wiki`): the operator's cross-project
  memory -- the Mirror's corpus layer. 51/51 sources indexed, hand
  -written pages included after the 2026-09-07T02:13Z rebuild.
- **Project vault** (`~/Projects/etc/llm-wiki/.llm-wiki`): the Hngh /
  portfolio research corpus. It holds the Cistern lessons
  (`cases/cistern-emacs-rewrite.md`,
  `sources/cistern-project-findings.md`,
  `concepts/emacs-symbol-fontset-bypass.md`,
  `concepts/llm-upstream-idle-timeout-incremental-writes.md`,
  `syntheses/delegated-subagent-steering.md`) -- currently UNINDEXED:
  meta froze 2026-08-19, so 92 pages sit on disk against 26 in the
  registry. One rebuild fixes the class, not any single page.

## Hngh's three roles

**CONSUME.** The research machine reads the vaults. The hour research
beat (`automation/cadence/hour/33-research-beat.sh`) greps a
bounded prior-art block out of both vaults' `meta/index.md` --
deterministic word overlap with the line's id and question, capped at
6 lines / 600 bytes -- and hands the same excerpt to the demand
synthesizer as prior art. Read-only pointers, never decisions: a
lesson informs a research line, it does not gate one. Existing
read-only consumers (`jobs/kb-feed.py`, `jobs/research-feed.py`,
`jobs/refresh-dashboard.sh`) stay display-layer.

**PRODUCE.** Surviving lessons and design docs earn wiki pages by the
house hand-write conventions (frontmatter `type`/`title`/`created`/
`updated`, sources pointing at the hngh docs paths). The extension
indexes hand-written pages on its next rebuild -- proven 2026-09-07
when the personal rebuild picked up all 22. Until a rebuild lands, an
unindexed page is an honest gap the health probe reports, not a
defect to hide. First production artifact: the weekly seed renders
the kernel's `docs/project/lessons-index.md` table into the project
vault as `wiki/concepts/hngh-lessons-current.md` (idempotent,
own-file-only), making Hngh's lessons citable the way the Cistern
lessons are.

**MANAGE.** The week probe
(`automation/cadence/week/04-wiki-health.sh`, model-free,
fail-closed) compares pages-on-disk against the registry `.pages`
count and the `meta/index.md` age per vault, and files one
identity-deduped alert per unhealthy vault -- `healthy | UNINDEXED |
STALE | SPLIT` -- carrying the counts and the exact fix. Hngh never
rebuilds meta itself; detection and alerting is the whole of its
authority here.

## The boundary law

- Wiki pages are derived data. The kernel's docs and the City's
  digests are the record; the wiki is a lens on them. Mirror law
  applies: the surface informs, the operator decides.
- No secret values ever enter a wiki page. Same rule as every
  surfaced artifact.
- The operator's other-project lessons (the personal vault, and any
  project corpus Hngh did not produce) are READ-ONLY to Hngh unless
  the operator points at them. Hngh writes only its own pages in the
  project vault, by the conventions above.
- Hngh never writes `meta/` or `raw/` in any vault. The fix for
  staleness is the extension's own rebuild, run from an omp session.

## The one outstanding action

Discharged 2026-09-07: the project vault's rebuild ran as designed --
an omp one-shot session with cwd `/home/bricker/Projects/etc/llm-wiki`
invoked the extension's `wiki_rebuild_meta` tool, reindexed all 93
pages (registry 26 -> 93), and cleared the SPLIT verdict the health
probe had been filing. The action is now owned by the automated cycle
below, not by any operator todo.

### Continual optimization (2026-09-07)

The outstanding action is now automated as a measured, tunable cycle,
not a fixed automation. `cadence/day/25-wiki-health.sh` (automation/)
probes both vaults daily; each unhealthy vault with `wiki-auto-rebuild`
armed gets ONE bounded omp one-shot rebuild attempt per UTC day (the
rebuild still happens inside the omp session -- the boundary law holds;
Hngh only spawns the session and reads the result).

- Telemetry: every attempt emits one `kind=wiki-rebuild` event
  (identity = vault, `wall_s`, outcome `unfrozen|still-unhealthy|
  attempt-failed`, before/after page-vs-registry counts). This is what
  makes the cycle optimizable: attempts, costs, and success rates are
  visible over time.
- Knobs: `wiki-auto-rebuild` (default 1; 0 = never attempt) and
  `wiki-rebuild-timeout` (default 240 s), both in the Inventory with
  env overrides (`WIKI_AUTO_REBUILD`, `WIKI_REBUILD_TIMEOUT`).
- Efficacy: alert and ok rows carry the vault's 7d rebuild history
  (attempts / unfrozen) from the same telemetry, so a vault that
  repeatedly fails rebuilds is a visible pattern, not a repeated
  surprise. Torch's weekly audit reads the same telemetry stream.
- Failure routing: two consecutive daily non-unfrozen attempts on a
  vault file a research subject (`ctx-wiki-rebuild-<vault>`) -- the
  cycle's own failures become research demand, per the house loop.

## Lexicon row

| Flavor name | Canonical term | Scope |
|---|---|---|
| the Athenaeum | wiki surface | design layer; display alias ([wiki-surface.md](wiki-surface.md)) |

Backlog row: "Memory surface (llm-wiki integration)" in
[backlog.md](../project/backlog.md).
