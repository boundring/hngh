<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - backlog P2/P3 coverage bundle (maintenance/cadence-grade, read-only probes)

Synthesized from `~/.jcode/scratch/BACKLOG.md` TIER 3 (P2 coverage
deepening) + TIER 4 (P3 backlog) combined into one coverage plan.

**HOLD — do not accept/execute without promotion.** This plan is
deliberately left `status=proposed` even if preflight reads green. The
P2/P3 items are maintenance/cadence-grade niceties that rank behind the
open P0 (security/correctness) and P1 (governance completion) chains;
promotion to executed must be an explicit operator or later-session act
after the TIER 1/TIER 2 plans land. Nothing in this plan mutates
behavior: nearly all steps are read-only probes whose only writable
output is a record/notes file under `docs/records/` or `automation/`
notes; the bypass-surface steps are the only ones that may touch
`automation/` code, and each still ends in probes + a record, not a
feature.

Grain: batched probes per step, cap 8 steps. Each step's Verification
names an existing gate (repo-root `make test`, which includes
scripts/lint-parens.py) or a record-cite
(post/handoff in `docs/records/`). Effort class S/M per the BACKLOG
conventions.

## Steps

- [ ] Identity/provenance deep dives (TIER 3a, batch of 5 read-only probes): run identity-literal-provenance, cibo-identity-disposition, state-md-timeline, gap-expected-counts-reconcile, and sweep-record-census-recount; write one consolidated findings note per probe with pinned refs.
  Verification: record cite — findings posted to docs/records/ and cross-linked from the STATE/session handoff row; each probe output includes commit hashes reproducible via `git log`/`git show`.

- [ ] Evidence-family gaps (TIER 3b, batch of 6 read-only probes): run evidence-g7 through evidence-g12 against their named evidence families; bank each verdict (confirmed/refuted/inconclusive) into a single batch record.
  Verification: record cite — batch verdict table committed in docs/records/; no automation/ or src/ diff in the step's commit.

- [ ] Bypass-surface completion: bypass-j-b-push-credential (M) — characterize the push-credential bypass surface end to end (credential source, trigger conditions, exposure window) and record the verdict; may add a note or minimal assertion in automation/ if surface behavior differs from prior findings.
  Verification: record cite — verdict record in docs/records/ plus `make test` green if automation/ was touched.

- [ ] Bypass-surface completion: bypass-j-c-governance (M) — characterize the governance-side bypass surface (what governance checks bypass-j-c is routed around, the residual risk, and whether any certificate path exists); record verdict.
  Verification: record cite — verdict record in docs/records/ plus `make test` green if automation/ was touched.

- [ ] Bypass-surface completion: bypass-j-inbound-ssh-receive (M) — map the inbound SSH receive path for bypass exposure (auth seam, receive hook coverage, race or downgrade windows); record verdict; may add a test or fixture note in automation/ confirming the observed behavior.
  Verification: `make test` (automation/ tests) plus record cite in docs/records/.

- [ ] Bypass-surface completion: bypass-j-push-surface-completeness + bypass-j-identity-verdict-reconciliation (M pair, one step) — finish the push-surface enumeration (which channels/protocols remain uncovered by prior bypass-j steps, including ssh-transport-hardening-gap, relay-trigger-surface-gap, receive-race-window-gap, github-access-surface-completion as read-only sub-checks) and reconcile the accumulated identity verdicts across bypass-j-* probes into one table.
  Verification: record cite — reconciliation table in docs/records/; `make test` green if automation/ was touched.

- [ ] Governance-map leftovers (TIER 3d, one sweep step, read-only): sweep a4d-g2-* children, a4f-log-sweep reflog children, a4f-rehearsal-seam-hardening, a4e-cert-store-reconciliation, a4d-large-surface-autocure, a4-governance-gap, a1-cosmetic-fix, kernel-ceremony-semantics, host-invocation-reality, heartbeat-next-marker, worker-driver-internals; produce a single disposition table (probe done / probe blocked / superseded by P0-P1 work) with pinned refs.
  Verification: record cite — disposition table committed to docs/records/; zero behavioral diffs; `make test` green.

- [ ] P3 batch (TIER 4, one step, read-only): run novel-blob-content-pattern-scan, gep-gap-book-publication-staleness, second-actor-probe-commit-reconciliation, and telemetry-db-coverage; one collective record with per-item verdicts and any follow-up candidates for a future cycle.
  Verification: record cite — collective verdict record in docs/records/; no code or automation/ diffs.

## Execution notes

- Every step output is reference-pinned (commit SHA, file:line, or
  catalog row) so absent findings are still falsifiable.
- No kernel `src/`, `Makefile`, or `hngh.asd` contact anywhere in this
  plan; its file surface is `docs/records/` and at most `automation/`
  notes/tests.
- If a probe surfaces a live defect, stop and file a separate park note
  for the operator instead of fixing inside this coverage plan.
