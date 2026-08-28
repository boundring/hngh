# 2026-08-28 — lessons consolidation

Scope: review 2026-08-27 and 2026-08-28 work (records, review digest,
report-ledger alerts, plan ledgers, automation breadcrumbs) for
actionable process lessons and fold each into its correct home. Not a
bench record; every lesson cites landed evidence. Landing mechanism:
the certificate ceremony (`scripts/ceremony-drive`) on this day, with a
green `make test`; the commit hash is the certificate content hash in
`git log`.

## Source material

- `2026-08-27-{dashboard-evolution-gbd-retirement,operator-items-closeout,acceleration-wave,p2-design-contracts}.md`
- `2026-08-28-{self-improvement-cadence,automation-advancement}.md`
- hngh-automation: `digest/REVIEW-2026-08-28.md`, report-ledger alert
  rows 2026-08-27/28, `STATE.md` breadcrumbs, plan ledger
  (overnight-continuity, remote-hardening, device-pairing).
- Watchdog session-drop ledger (overnight rc=124 rows).

## Lessons and where each landed

1. **Gate-check coverage asymmetry — the automation repo's own gate has
   no checker.** With the kernel gate green, hngh-automation `make
   test` sat red on HEAD (3 lint-identifiers problems) and no alert
   fired, because `cadence/day/03-gate-check.sh` sweeps only the
   kernel. → backlog row "Cadence watch fixes — gated red, recorded
   not landed (2026-08-28)". The implied mechanical fixes (gate both
   repos; remove dead `TS_SUBNET`) were NOT landed in hngh-automation
   because its gate is red on HEAD — recorded with evidence instead of
   half-landed, per the no-speculative-commits rule.
2. **lint-identifiers does not track heredoc-scoped definitions.**
   deck-setup.sh's `$DESK_LAN_IP`/`$DESK_TS_IP` are defined (line 180)
   inside the `cat > ~/.local/bin/hngh-connect <<'C'` heredoc; the
   scanner flags their heredoc-internal uses as referenced-never-
   defined. Two of today's three lint failures are scanner blind spot,
   not shell bug; the third (`TS_SUBNET`, hngh-ufw-manage.sh) is a
   genuinely dead variable. → same backlog row.
3. **Expected-dirty ledger paths are not skew.** The oversight
   tree-skew probe fired x64 (row 96bd99de) on the machine's own
   uncommitted append files. → governance lesson in
   `docs/design/autonomous-development-control.md` § Ceremony-loop
   lessons; forward fix in the backlog row.
4. **Timeout-split ceremonies hand off through a runbook.** Three
   overnight runs died at the 1,800 s cap (rc=124, watchdog rows
   03:29Z/05:00Z/07:00Z) with candidates staged and only the
   certificate loop remaining; the runbook
   (`2026-08-28-overnight-continuity.ceremony-runbook.md`) closed it on
   the next loop. → governance doc, same section.
5. **Refusal surfaces carry the refusal reason.** Alert a1fde252
   ("omp-bridge: create-run refused (exit 1)", 03:19:56Z) named no
   cause, so the parked work could not be triaged from the alert
   alone. Extends the self-improvement cadence record's lesson 2
   (refusals name the fallback) from ceremony refusals to alert
   surfaces. → governance doc. The kernel-side sharpening of
   omp-bridge's refusal text is not built here: it is a src/tests
   change (failing-test-first), which parks under the plans' autonomy
   rule.
6. **Ledger appends are structure-bound.** The fresh-eyes review's
   open hngh P1 (digest/REVIEW-2026-08-28.md; report row 31527cac,
   09:06:56Z): `docs/project/reports.md`'s table header row appeared
   twice with the ledger title inserted between them — an inserting
   writer broke the single-header invariant. → repair landed here
   (review-digest-driven: the fix is traceable to alert 31527cac) plus
   the append-invariant bullet in `docs/design/ledger-and-records-spec.md`
   §3.
7. **Alert dedup needs escalation caps.** The xN occurrence marker
   grows unbounded and a permanently-deduped alert stops being
   information (stale-store spam x12 per id, rows 0582c2ca/4b0abe9a;
   dash-selfreview summary x18, row f438818b). Already observed as
   ledger lesson row b185ea3c; not-yet-admitted work → backlog row
   "report-queue escalation caps".
8. **Fresh-eyes digests ship the prompt echo.** REVIEW-2026-08-28.md
   is 1,100+ lines of echoed prompt and raw diffs; the findings are
   the last few lines. → same backlog row as item 1 (digest hygiene).
9. **Operator goals as design pressure.** Self-funding runway: the
   publications pipeline exists (`scripts/generate-publication
   --ebook/--site`) and the crystallized `docs/research/` lines are
   its feedstock; the admission path is the existing backlog rows
   (ebook-longform, public-surface, royalty-pipeline, funding-rails).
   Steam Deck: paired and hardened (hngh-automation `6688280`,
   `db2f60c`, `286b87f`; REMOTE-ACCESS.md); deck-as-node federation
   stays in the device-fleet/node-lattice backlog rows. Remote access:
   the remaining step is operator-side (`sudo tailscale serve --bg
   8890`), documented and never automated. → closing paragraph of
   `docs/project/roadmap.md` Next.

## Deliberately not folded

- Self-improvement cadence lessons 1–6: already recorded in
  `2026-08-28-self-improvement-cadence.md`; extended (not duplicated)
  by lesson 5 above.
- data.json stale nested digest (review P1, row 5c530858): already
  fixed at the root (hngh-automation `be984d2`).
- ui-audit transient crash ("Passed function cannot be serialized!",
  row 98c4f43a): not reproducible in later runs (fresh run 0
  violations 08:55Z); recorded here, no row.
- Overnight budget sizing (1,800 s vs full-plan ceremonies): the cap,
  the store sweep, and the selector timeout already landed
  (hngh-automation `933c7c5`, `448e2d5`); lesson 4 records the
  handoff pattern the cap implies.
- hngh-automation mechanical fixes (gate-both-repos, heredoc lint,
  TS_SUBNET): recorded in backlog with evidence, not landed — its
  `make test` is red on HEAD today; landing would violate the
  gated-green rule.

## Ceremony notes

Candidate sweep: this record plus the edits above, and the
machine-maintained ledger files left dirty by the day's cadence jobs
(reports.md appends, ui-grades.md, current-overlay.json,
device-pairing.plan.md status transition) land in the same certificate,
per the ceremony-runbook precedent — which also clears today's
tree-skew class at the source. No deletions beyond the one-line header
repair inside a candidate file, so the manual `docs:` commit fallback
(c0c0bd5 precedent) was not needed.
