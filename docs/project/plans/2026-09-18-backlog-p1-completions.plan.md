<!-- plan: status=proposed risk=normal accepted=- cause=missing-design held=2026-09-18T01:40:53Z -->
# 2026-09-18 — Backlog P1 completions bundle (BACKLOG.md TIER 2)

Governance completion: close the open P1 audit chains. Do not re-derive specs;
sources of truth:

- `/home/bricker/.jcode/scratch/BACKLOG.md` TIER 2 (items 2a-2d)
- `/home/bricker/.jcode/scratch/identity-census/poodle-slug-truncation-findings.md`
  (sections (a)(b)(c), PRECISION CORRECTION, and the Scorpion precision notes
  banked 14:32Z 2026-09-17, which pin G1 = STATE.md breadcrumb ledger as
  ground truth and G4's narrowed residual question)

Kernel boundary: `src/`, `tests/`, `Makefile`, `hngh.asd` are ceremony-only.
This bundle is docs/, automation/, and read-only probing. No live-model
re-probing of kimi or any lane (G1 rule). Execute in order; 2d probes are all
read-only and parallel-safe.

## Steps

- [x] 2a. Decision-inventory absorb + ts-integration-assessment synthesis doc: DONE 2026-09-18. Beads hngh-4m1 (absorb, decisions.md entry) + hngh-ypb (docs/design/ts-integration-assessment.md, commit 6334f5bd) closed.
      Verification: `grep -ril "ts-integration" docs/design/` finds the new doc; docs/project/decisions.md diff shows the absorb entry; `make test` at repo root passes

- [x] 2b. G2 reviewer-lane-attribution-mechanism: DONE 2026-09-18 (record 3294b858, STATE.md ledger ground truth, no emit correction). Evidence stands; bead hngh-4j4 re-close gated on hngh-uro verdict.
      Verification: reconciliation table committed (automation/ or docs/records/) citing exact breadcrumb ledger lines; verdict on whether telemetry can be corrected at the `model.sh:_model_emit` emission site stated in the record

- [x] 2b. G3 malformed-rows-consumers: DONE 2026-09-18 (record eafc0ba3, zero malformed, per-consumer table). Evidence stands; bead hngh-4j4 re-close gated on hngh-uro verdict.
      Verification: corrected census numbers committed in a record; per-consumer behavior table cites each consumer's exact parse line (file:line) and its observed short-row outcome

- [x] 2b. G4 fixture-identity-fanout (narrowed): DONE 2026-09-18 read-only (record 4a1579df, sanctioned, 20/18 covered). Evidence stands; bead hngh-4j4 re-close gated on hngh-uro verdict.
      Verification: verdict recorded (breach / sanctioned / needs-cert-attestation) citing the exact commit hashes found and the `git log` invocation used

- [x] 2b. G5 review corroborator: DONE 2026-09-18 (record 551dc129: 20/240 sidecars exist, intent docs NO). Sidecar work landed; remaining hngh-4j4 gate is hngh-uro verdict only.
      Verification: per-sidecar existence table committed (exists / missing / gc-gone); explicit yes/no answer on sidecar-intent documentation with grep evidence over AGENTS.md, docs/README.md, automation/README.md, SKILL.md

- [x] 2b. Tigress 3 gaps (one pass): DONE 2026-09-18, bead hngh-6io CLOSED (verdicts 65036365: dupe-lids 27 reviewed; kimi-403 test 36b43f72 landed, suite green; kimi-telemetry no-contradiction).
      Verification: (1)(2) verdicts recorded citing the contradictory row/commit ids; (3) `make test` at repo root passes with the new test present (`grep -r "403" tests/ automation/` shows it)

- [ ] 2c. Rot/wiki front closures (collapsed): OPEN. No t1-t4/g1i probe dispositions in research-dispositions.tsv, no canvas doc, gate-inventory.md unrefreshed, governance-full-records-sweep unabsorbed.
      Verification: t1-t4, g1i, kernel-home-gate, and exposure-chain probe dispositions present in the research-dispositions ledger; canvas doc committed; gate-inventory.md diff reflects current gate set; parent absorb outcome marked; `make test` at repo root passes

- [ ] 2d. ACP audit leftovers, READ-ONLY probes: OPEN. No probe-log findings doc landed; only acpkernel-boundary-model rows exist in the ledger (prior work, not this bundle's 8 probe families).
      Verification: one probe-log per item appended under a single audit findings doc (research-ledger or docs/records/), each entry giving the exact source opened and the verdict (evidence-gap confirmed / muted / N/A); zero mutations (`git status` shows only the findings doc); findings doc committed

## Notes

- Max 10 steps kept by collapsing sibling probes: canvas step (2c) names 9
  probe heads; 2d step names 8 probe families with their evidence sources.
- Gates status at authoring time (2026-09-18T00:59Z): `make test` FAILS.
  Therefore status stays `proposed` and `accepted=-`. Re-run `make test` after
  the bundle lands; only a full gate pass justifies flipping to
  `accepted=<UTC ts>` (needs coordinator action, not auto-acceptance).
- Do not delete or rewrite the userspace two-home split or STATE.md tracking.
