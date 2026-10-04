# jevify — subsystem inventory (2026-10-03)

Rubric: frozen in harness-skeleton program plan Phase A. Bulk classification: typesafe/jev-1.13.0 via judge_batch (28 rows, job jdgb-15986c22bef81869).
Rows marked **[override]**: model verdict contradicted file evidence; evidence wins per plan contingency.

| # | Subsystem | Files | Verdict | Basis / anchor |
|---|-----------|-------|---------|----------------|
| 1 | src/ + hngh.asd + Makefile | 29 | ceremony-gate | Kernel surface; AGENTS.md staging boundary; certificate lane only |
| 2 | tests/ (kernel) | 78 | ceremony-gate | Kernel-owned; runs under make test gate |
| 3 | scripts/ (repo root) | 26 | ceremony-gate | AGENTS.md: "Repo-root scripts/ is kernel code surface"; `hngh: candidate <hash>` label (scripts/omp-bridge, scripts/ceremony-drive) |
| 4 | automation/tests/ | 215 | **keep** [override: model ceremony-gate 0.28] | automation is the free-commit surface (AGENTS.md); this IS the gate (automation/Makefile `test:` recipe list) |
| 5 | automation/cadence/ | 77 | keep | 4-tier engine + 76 drop-ins; jobs/cadence-tick.sh lexical execution |
| 6 | automation/jobs/ | 73 | keep | Feed producers (operator-items-feed.py, newspaper-compose.py, kb-feed.py, history-feed.py, dashboard-introspect.py) |
| 7 | automation/lib/ | 55 | keep | common.sh, hngh_home.py, crumbs-db.py, scrub.py |
| 8 | automation/dashboard/ | 37 | transform | Phase C control-room refactor target; features jevified separately |
| 9 | automation/scripts/ | 32 | keep | Harness helpers incl. newspaper-compose.py |
| 10 | automation/systemd/ | 27 | keep | Units + linger + tier-migrate (test-proven seams) |
| 11 | automation/docs/ | 25 | keep | Harness documentation |
| 12 | automation/iso/ | 24 | keep | mkarchiso + omarchy tail + adopt + AUR no-sudo seam; feeds Phase E |
| 13 | automation/config/ + tsv tables | 29 | keep | cadence-params.tsv, news-feeds.tsv, research-lines.tsv — config-as-table convention |
| 14 | automation/ng/ | 11 | keep | Executive beat loop (cadence.py, jev.py, contract.py, guards) + own tests |
| 15 | automation/handoff_briefs/ | 8 | archive-note | Session churn; freeze growth |
| 16 | automation/{omp-plugin,omarchy-plugin,deck,jcode,mcp,prompts}/ | 17 | keep | Harness adapters |
| 17 | automation/--model | 1 | **retire** (conf 1.0) | Contains "session output" — accidental artifact tracked by d1953b7b cadence churn; `git rm` |
| 18 | automation/{bootstrap.sh,config.env,env.example,package.json+lock,state/,REMOTE-ACCESS.md,.lesson-harvest-handoffs} | 8 | **keep** [override: model flag-only 0.52] | bootstrap = install entry, package.json = view-test node deps; only .lesson-harvest-handoffs is machine churn (do not commit) |
| 19 | docs/project/plans/ | 809 | **keep** [override: model archive-note 0.41] | ACTIVE ceremony ledger (propose/acceptance machinery auto-accepts; principle-line enforcement); growth concern real → executed-plan archival policy goes to Phase D design, not a freeze |
| 20 | docs/research/ | 398 | keep | Phase B seeds 12 category docs here |
| 21 | docs/records/ | 295 | **keep, append-only** [override: model archive-note 0.94] | AGENTS.md: "Record architecture-relevant work in docs/records/" — append-only by design, never frozen |
| 22 | docs/design/ | 69 | keep | Triple-kernel + sim + federation designs land here (Phases D/F) |
| 23 | docs/journal/ | 38 | archive-note | Dated entries; session-scoped |
| 24 | docs/media/ | 32 | keep | Images/attachments |
| 25 | docs/agent-notes/ | 21 | archive-note | Session-scoped briefs; jevify outputs land here by convention |
| 26 | docs/{core,publication,top-level md} | 16 | keep | README/architecture/intent |
| 27 | .beads .github .omp prompts opencode.jsonc install.sh top-level | 24 | **keep** [override: model ceremony-gate 0.36] | Tracker export + CI + agent config; not kernel surface, normal commits |
| 28 | untracked machine churn | — | ephemeral [override: model archive-note] | Untracked + regenerated (plan ticks, lessons-YYYY-MM-DD.md); rule = never commit, no archive action |

Exceptions carried to the operator: none — every override is backed by repo rules quoted above.

Immediate action out of this inventory: `git rm automation/--model` (row 17).
