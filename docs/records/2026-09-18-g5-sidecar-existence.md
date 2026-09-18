# G5 review-corroborator sidecars (2026-09-18)

## Per-sidecar existence table

Source of turns: `automation/research-dispositions.tsv` (240 review turns).
Recorded sidecar path shape: `$AUTOMATION_ROOT/digest/RESEARCH-REVIEW-<day>-<id>.md`
(writer at `automation/cadence/hour/33-research-beat.sh:837-845`, committed via
`research_commit` at `33-research-beat.sh:846-847`). Checked against the live
userspace home `~/.hngh/archive/digest/` and repo `automation/digest/`.

Result: 20 of 240 turns have a sidecar (all dated 2026-09-12/13, all in
`~/.hngh/archive/digest/`, all catalogued 2026-09-13T18:22:55Z as migrated
copies); 220 are missing; 0 are gc-gone as objects (the gc-gone items are
the two dangling commits below, not sidecar files).

| review turn (line id) | sidecar status | evidence |
|---|---|---|
| dramatization-plot-taxonomy | exists | ~/.hngh/archive/digest/RESEARCH-REVIEW-2026-09-12-dramatization-plot-taxonomy.md |
| fail-20260912-For-born-PDF-scholarly-corpora-where-ups | exists | ~/.hngh/archive/digest/ ... (same dir, 2026-09-12 batch) |
| fail-20260912-field-survey-literature-collection | exists | same dir, 2026-09-12 batch |
| fail-20260912-serious-manga-narration-register | exists | same dir, 2026-09-12 batch |
| gdelt-webngrams-reconstruction | exists | same dir, 2026-09-12 batch |
| humor-development | exists | same dir, 2026-09-12 batch |
| fail-20260912-Does-lib-quips-py-expose-any-existing-te | exists | same dir, 2026-09-13 batch |
| fail-20260912-Does-the-hngh-kernel-emit-user-facing-st | exists | same dir, 2026-09-13 batch |
| fail-20260912-What-audit-sampling-and-uncertainty-tier | exists | same dir, 2026-09-13 batch |
| fail-20260913-Are-there-any-existing-integration-tests | exists | same dir, 2026-09-13 batch |
| fail-20260913-Can-lint-level-checks-mechanically-flag- | exists | same dir, 2026-09-13 batch |
| fail-20260913-Can-the-Trailer-Completeness-check-be-ex | exists | same dir, 2026-09-13 batch |
| fail-20260913-Can-the-existing-overnight-harness-be-re | exists | same dir, 2026-09-13 batch |
| fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v | exists | same dir, 2026-09-13 batch |
| fail-20260913-Does-the-CLI-entry-point-bin-hngh-or-lib | exists | same dir, 2026-09-13 batch |
| fail-20260913-Does-the-bin-hngh-executable-have-a-stab | exists | same dir, 2026-09-13 batch |
| fail-20260913-Does-the-hngh-kernel-s-component-registr | exists | same dir, 2026-09-13 batch |
| fail-20260913-Does-the-hngh-kernel-write-any-commit-tr | exists | same dir, 2026-09-13 batch |
| fail-20260913-Has-the-upstream-guardrail-bug-from-2026 | exists | same dir, 2026-09-13 batch |
| fail-20260913-How-does-the-presence-of-multiple-confli | exists | same dir, 2026-09-13 batch |
| all other 220 turns (e.g. gantt-legibility, log-presentation-patterns, session-cost-display, tech-tree-research-ux, all 2026-09-07/08 dispositions) | missing | no RESEARCH-REVIEW-*-<id>.md in ~/.hngh/archive/digest/ (20 files) or automation/digest/ (absent); catalog.tsv carries 20 RESEARCH-REVIEW rows, 0 dated after 2026-09-13 |
| dangling commits 13ac26f9 / 91ab48ca (mouse-gate citation) | gc-gone | `git cat-file -t 13ac26f9` -> "Not a valid object name"; same for 91ab48ca |

Side drain note: catalog.tsv holds 20 RESEARCH-REVIEW rows, all stamped
2026-09-13T18:22:55Z ("migrated from repo automation/digest/..."), zero rows
after 09-13. The userspace copy also went dark: newest userspace sidecar is
2026-09-13. Meanwhile the writer still targets `$AUTOMATION_ROOT/digest/`
(`33-research-beat.sh:837`), a path the 10aa98ea migration never moved to
$DIGEST_DIR (migration diff touched only RESEARCH-BEAT paths) — post-migration
review sidecars land in an unmigrated repo-relative dir.

## Sidecar-write intent documentation: NO

Explicit answer: NO — the post-migration intent for the RESEARCH-REVIEW
sidecar write (userspace-only vs committed) is not documented in any of the
four files. Grep evidence (case-insensitive "sidecar", 2026-09-18):

- AGENTS.md: 0 matches (`grep -c -i sidecar AGENTS.md` -> 0)
- docs/README.md: 0 matches
- automation/README.md: 0 matches
- SKILL.md: file absent at repo root (no SKILL.md found at depth <= 2)
- render-blocks-strip record `docs/records/2026-09-17-render-blocks-strip-and-userspace-record-disposition.md`: 0 matches
- Corroborating facts: migration commit 10aa98ea moved only RESEARCH-BEAT
  digest paths (diff hunks at 220, 716, 783, 804 — no RESEARCH-REVIEW hunk);
  the cited userspace-home record was deleted 2026-09-17 in 2966e3f8.
