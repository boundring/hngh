# Repo topology — merging hngh-automation into hngh

Status: CONSIDERATION — 2026-09-07. No decision made. Written for the
operator's question: if the automation is part of Hngh, why is it a
separate repo? All counts were measured (`git grep`, `git log`), not
estimated.

## Current topology

Two public repos, one machine. `hngh` is the kernel and its record:
side-effect-free Common Lisp, commit ceremony, loop-history guard over
CODE_SURFACE (`src/ tests/ scripts/ Makefile hngh.asd`), plus the docs
tree. `hngh-automation` is the operational tier: bash/python (lib/
jobs/ cadence/ scripts/ systemd/ tests/), the dashboard, and machine
data swept into git hourly. They talk through `HNGH_HOME` (automation
-> kernel) and `../hngh-automation` (kernel docs -> machine); the
publication pipeline reads only the kernel root but cites the
automation repo 277 times.

| Lives in | What | Scale (measured) |
|---|---|---|
| hngh | kernel, ceremony, docs tree, publication pipeline | 676 commits, 3.6 MiB pack |
| hngh-automation | operational code, ~248 files (lib/jobs/cadence/scripts/systemd/tests/docs) | 498 commits, 23.2 MiB pack |
| hngh-automation | machine data, 272 tracked files (digest/, dashboard/, logs/, stats/, snapshots/, archive/, STATE.md, ledgers) | hourly sweep commits |
| hngh-omp (third repo) | npm bridge plugin | references only `HNGH_HOME` |

Seams, with reference counts:
- hngh -> automation: 856 lines in 133 files; only ~25 live (README
  "Live operation", docs/README.md, ~15 design docs, STATE-OF-PROJECT,
  backlog/queue/reports/lessons-index, 6 scripts). The rest — records/,
  journal/, plans/, CHANGELOG, book.md (277 lines) — is historical or
  published text, never to be rewritten.
- automation -> kernel: 180 lines in ~80 files, ~94 of them code once
  `dashboard/sessions.json` (86, machine data) is excluded —
  `HNGH_HOME`/`HNGH_CLI` in `config.env`, the BRIDGE path in
  `lib/launch-session.sh`, `HNGH_AUTOMATION_ROOT` in `accept-plans.py`,
  `16-remote-push.sh`, `03-gate-check.sh`.
- systemd: 37 unit files with absolute
  `/home/bricker/Projects/etc/hngh-automation` paths.
- Churn (last 7 days): automation 238 commits, 170 hourly sweeps — one
  sweep = 18 files, ~10k lines, binary `telemetry.db`, an 18.5k-line
  `sessions.json`. hngh: 90 commits, 25 `machine ledger sync` — the
  automation already writes curated truth into hngh docs hourly
  (`cadence/hour/30-kernel-ledger-sync.sh`).

## The case for merging (steelman)

One repo is one clone, one push, one URL — and the automation is part
of Hngh's story, not scaffolding: the Descent, the disposition spine,
the watchdog are the machine the project's own design docs describe as
product. The docs cross-link constantly (856 lines), and the relative
links are dead on GitHub today: the kernel README's
`../hngh-automation/README.md` resolves outside the repo and 404s, as
do the links in all 133 files. Onboarding needs a "there is a second
repo" step; the
publication pipeline's citations don't resolve; gates already unify
(`03-gate-check.sh` runs `make test` in both). The loop-history guard
extends naturally: CODE_SURFACE is prefix-scoped, so an `automation/`
tree sits outside the guarded surface by construction — both
disciplines coexist on one history with no guard change. And the trend
line points here: the kernel docs already receive hourly machine-ledger
syncs — the narrative has merged; only code and raw data lag.

## The case against (steelman)

The disciplines differ for a reason: kernel commits ride certificates,
automation commits land free behind `make test`. The prefix scoping
avoids guard-vs-cadence collision, but the git log becomes a mixed
stream — a candidate certificate between two sweep commits. Sweeps are
the decisive weight: ~24 noise commits a day in the kernel's public
history, a pack bloating from 3.6 to 27+ MiB, binary blobs, and
`generate-publication --daily`/`--check` counting machine commits in
every journal day. The kernel's identity law ("side-effect-free local
kernel", AGENTS.md line 17) reads cleanly because the repo contains
nothing that runs; merge it and every reader re-derives where that
boundary sits. Co-locating budget ledgers and telemetry with the
kernel makes it the one-stop profile for the machine's guts. And
standing pain is zero — migration risk buys coherence, not correctness.

## Middle paths

### (a) MERGE with machine-data quarantine

Operational code moves to `hngh/automation/`; machine data (STATE.md,
dashboard/, digest/, logs/, stats/, snapshots/, archive/, handoffs,
ledgers, telemetry.db) leaves git entirely — gitignored
`automation/data/` (optionally symlinked to `~/.hngh-automation/data`).
The sweep job retires; public digests move into the curated sync channel.
- Mechanics: `git subtree add --prefix=automation <remote> main`
  preserves all 498 commits; data blobs ride in history (~23 MiB —
  acceptable; an optional filter-repo data-strip is cosmetic).
- Touch surface: the ~94 live automation->kernel ref lines collapse to
  `$HNGH_HOME/automation` defaults (`HNGH_AUTOMATION_HOME` dies); 37
  systemd units rewritten + `daemon-reload`; ~25 live kernel-doc files
  and 6 scripts get path fixes. Historical text untouched.
- Risk: mid-flight cadence breakage — mitigated by cutover commit,
  unit rewrite, gate green, then old units disabled. Near-one-way
  after push.

### (b) Submodule

`hngh/automation/` as a git submodule. Mechanics: `git submodule add`,
pin, swap README link. Touch surface: near-zero. Risk: standing cost —
drift, double-fetch clones, push ordering; "one URL" half-met.
Reversible trivially.

### (c) MONOREPO-lite

Keep both histories; one wrapper script clones/pulls/pushes/gates
both. Touch surface: one script. Risk: none. Verdict: clone ergonomics
only, none of the narrative problems.

### (d) Status quo + tighter cadence

Keep split; prune sweep noise (sweep on real change only, drop the
binary). Touch surface: one script. Risk: none. Verdict: fixes noise,
not coherence.

## Recommendation

Merge, via path (a), gated on one operator decision: after quarantine,
raw operational data (dashboard JSON, digests, telemetry) leaves the
public git surface — only curated syncs remain. Deciding factors:
(1) the sweeps must die either way — 170 commits/7d and a committed
binary telemetry.db is debt independent of topology; (2) the
operator's goal is portfolio presentation and a single-source
narrative, which only (a) delivers; (3) the guard is prefix-scoped, so
ceremony cost is near zero — the real cost is 37 systemd units and one
cutover day. If operational data should stay public, stay split and do
(d) — a coherent alternative, not a failure mode.

Phased plan (P0 is the decision record in `docs/project/decisions.md`;
quarantine precedes migration, so the history that moves is already
quiet):
- P1 — quarantine: gitignore machine data under `data/`, retire the
  sweep job; both gates green.
- P2 — history migration: `git subtree add --prefix=automation`, drop
  the old tree, verify `make test` and both gates.
- P3 — env seam collapse: `AUTOMATION_ROOT` ->
  `$HNGH_HOME/automation`; `HNGH_AUTOMATION_HOME` removed;
  `HNGH_HOME` covers all.
- P4 — systemd cutover: rewrite the 37 units, `make enable`, one
  cadence hour green before old units are disabled.
- P5 — doc/path sweep: ~25 live kernel-doc files, 6 scripts, README;
  `doc-suite-check` verifies moved links; old remote archived
  read-only with a redirect note; push script single-repo.

Touch surface: ~250 automation files moved, 37 systemd units, ~94 live
ref lines in automation, ~25 live docs + 6 scripts in hngh, one gate
script, one push script. Historical text is untouched.

P2 landed (subtree import b881186), P3 landed (env seam collapse
bfaedf0), P4 landed (systemd paths 83e1d35), P5 landed (this doc
update). Status: MERGED.
