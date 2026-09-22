# 2026-09-22 — wiki-boundary verdict: no in-repo wiki, canon stays in docs/ (wiki-boundary)

Plan: docs/project/plans/integration-fold plan (integration-fold slice A,
2026-09-22). This record captures the wiki-boundary decision that
previously lived nowhere in the repo.

## Scope

Decide and record where the project's wiki boundary sits: whether an
in-repo llm-wiki vault exists, what the canon surfaces are, how inbound
recall works today, and what remains unlanded (federal-branch canon
file, missing vault page, db-migration roadmap adjacency).

## Evidence command

```
ls ~/.hngh/wiki/ 2>/dev/null
sed -n '495,520p' automation/cadence/hour/33-research-beat.sh
ls docs/project/charter.md
git log --oneline -1 docs/project/plans/2026-09-20-federal-charter.plan.md
grep -rln 'hngh-ceremony-loop-mechanics' docs/ automation/ | wc -l
sed -n '221,228p' docs/project/roadmap.md
```

## Observed result

- No in-repo llm-wiki vault exists (`~/.hngh/wiki/` is empty/absent).
  `docs/records/` and `docs/research/` remain the canon surfaces.
- Inbound recall is the deterministic `prior_art` word-overlap grep in
  `automation/cadence/hour/33-research-beat.sh` (function `prior_art`,
  ~lines 501-515): it reads vault `meta/index.md` files when present and
  degrades to no-op when the vault is absent — the beat never blocks on
  the vault. This wiring stays unchanged.
- Embeddings-backed recall stays deferred until measured degradation of
  the word-overlap grep, not adopted preemptively.
- Federal-branch canon (`docs/project/charter.md`) does not exist yet;
  it is a proposal rider on the federal-charter plan
  (`docs/project/plans/2026-09-20-federal-charter.plan.md`, status
  accepted 2026-09-20T17:35:00Z). The boundary verdict does not
  pre-create the file.
- The missing vault page `hngh-ceremony-loop-mechanics` is referenced
  from 21 files (3 under `docs/`, 18 under `automation/`; e.g.
  `docs/research/2026-09-14-transaction-certificate-system-mutations.md`).
  Any vault write needs an operator go first; until then this record
  notes the dangling references.
- DB-migration track adjacency: the roadmap has no db-migration item;
  the nearest anchor is the third-evening intake fold
  (`docs/project/roadmap.md` lines 221-228). The db-migration track
  (brief: docs/agent-notes/briefs/2026-09-22-database-migration-investigation.md)
  waits there until a roadmap slot opens.

## Remaining unknowns

- Whether/when the operator greenlights a vault write for
  `hngh-ceremony-loop-mechanics` (operator go required).
- Whether the federal-charter plan later promotes
  `docs/project/charter.md` into existence (rider still pending landing).
- Whether the db-migration track gets its own roadmap item at the next
  roadmap revision or rides the third-evening intake fold.