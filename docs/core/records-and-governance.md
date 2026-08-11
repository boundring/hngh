# Hngh records and governance

**Status:** DESIGN
**Authority:** documentation topology, record ownership, retention, journal, archive, and backlog rules.

## 1. One fact, one home

| Fact | Home | Update trigger |
|---|---|---|
| product purpose, scope, authority | `core/charter.md` | approved scope or stakeholder change |
| stable product/architecture boundary | `core/system-design.md` | accepted architecture decision |
| session control and model economy | `core/session-operations.md` | accepted lifecycle/policy change |
| delivery structure and active sequence | `core/delivery.md` | accepted frontier/dependency change |
| project history and individual events | `records/` | work session or closeout |
| raw/restricted evidence | runtime/workbench store | execution or collection event |
| detailed prior designs/research | legacy source or archive | cited only by a bounded task |

No current rule is copied into several documents. A short link is better than a divergent summary.

## 2. Record classes and retention

| Class | Meaning | Rule |
|---|---|---|
| core | current normative record | concise, reviewed, linked from `docs/README.md` |
| record | journal, manifest, backlog, decision, receipt index | append or bounded update; date and attribution required |
| review | fixed scope assessment | immutable after verdict except an explicit correction record |
| archive | preserved historical content | content unchanged; no execution authority |
| runtime evidence | state, logs, lanes, receipts | preserve by retention class; never silently turn public |
| restricted | secrets, raw transcript, personal/private text | exclude from public repository; redact before derivative use |

## 3. Archive rule

Archive by move, not rewrite. Every archived item has a manifest row with:

```text
source path | archive path | content digest | reason | authority replacement | recovery path | reviewer
```

An archive move preserves Git history and file bytes. A compatibility path, source-link update, or deliberate broken historical link must be recorded; it is never accidental.

## 4. Journal

The journal records what happened, not what an agent believes happened. One entry covers one coherent transaction.

```markdown
# YYYY-MM-DD — short title

Scope:
Evidence observed:
Changes made:
Verification:
Unknowns / holds:
Next factual action:
Attribution: agent, actual model/provider, harness, cost if known.
```

Do not rewrite prior journal entries to make the past look cleaner. Corrections are new dated entries linking to the original.

## 5. Backlog and decision discipline

- A backlog item is a question or potential outcome, not a promise.
- A decision records options, evidence, authority, consequences, and revisit conditions.
- A lesson records incident, source, counterexample, remedy, disposition, and expiry/revisit condition.
- A review records an exact artifact identity and what it did not establish.
- A receipt records actual execution information and may contain `UNKNOWN` fields.

## 6. Update triggers

| Event | Required record update |
|---|---|
| accepted architecture/policy change | affected core document and dated journal |
| code/config change | task evidence, journal, changelog when user-visible/architectural |
| terminal session | terminal receipt, claim reconciliation, handoff/lesson disposition |
| new idea | backlog intake only |
| document consolidation move | manifest, archive index, journal, link audit |
| review hold | review record and active frontier |

## 7. Context hygiene

A fresh agent reads the core set, current hold, one task card, and only named source excerpts. Archive and raw evidence are retrieved by need. The project does not load its entire history into every model as a substitute for a current task contract.
