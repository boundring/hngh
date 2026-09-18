<!-- plan: status=held risk=normal accepted=- cause=missing-design held=2026-09-18T01:40:53Z -->
# 2026-09-18 — Backlog P1 completions bundle (BACKLOG.md TIER 2)

Governance completion: close the open P1 audit chains. Do not re-derive specs;
sources of truth:

- `~/.jcode/scratch/BACKLOG.md` TIER 2 (items 2a-2d)
- `~/.jcode/scratch/identity-census/poodle-slug-truncation-findings.md`
  (sections (a)(b)(c), PRECISION CORRECTION, and the Scorpion precision notes
  banked 14:32Z 2026-09-17, which pin G1 = STATE.md breadcrumb ledger as
  ground truth and G4's narrowed residual question)

Kernel boundary: `src/`, `tests/`, `Makefile`, `hngh.asd` are ceremony-only.
This bundle is docs/, automation/, and read-only probing. No live-model
re-probing of kimi or any lane (G1 rule). Execute in order; 2d probes are all
read-only and parallel-safe.

## Steps

- [ ] 2a. Decision-inventory absorb + ts-integration-assessment synthesis doc: absorb the hngh-decision-inventory parent using the landed children's findings, then write the ts-integration-assessment synthesis doc under docs/design/ (file ts-integration-assessment.md) from the banked ts-* children artifacts (no new analysis, synthesis only); record the absorb decision in docs/project/decisions.md
      Verification: `grep -ril "ts-integration" docs/design/` finds the new doc; docs/project/decisions.md diff shows the absorb entry; `make test` at repo root passes

- [ ] 2b. G2 reviewer-lane-attribution-mechanism: reconcile telemetry-vs-STATE.md breadcrumb ledger counts for the kimi/unsloth lanes. Scorpion spec (banked 14:32Z): STATE.md breadcrumb ledger is ground truth for lane fall-through counts; `automation/lib/model.sh:_model_emit` is success-only telemetry and structurally undercounts misses. Do NOT live-probe kimi.
      Verification: reconciliation table committed (automation/ or docs/records/) citing exact breadcrumb ledger lines; verdict on whether telemetry can be corrected at the `model.sh:_model_emit` emission site stated in the record

- [ ] 2b. G3 malformed-rows-consumers: correct the malformed-rows census and build a per-consumer table of short-row behavior for the consumer population of `automation/research-lines.tsv` and `automation/config/unsloth-contexts.tsv` (find every TSV reader via grep over automation/scripts/)
      Verification: corrected census numbers committed in a record; per-consumer behavior table cites each consumer's exact parse line (file:line) and its observed short-row outcome

- [ ] 2b. G4 fixture-identity-fanout (narrowed): census kernel-side docs commits authored by Fixture OUTSIDE the two declared guard exemptions ba6b3905 and d2d8f51, i.e. commits touching `src/`, `tests/`, repo-root `scripts/`, `Makefile`, or `hngh.asd`. Read-only `git log --author -- <paths>` analysis; no mutations. Residual question only per scorpion note (identity-seam-reconciliation record already covers the 566+2 ambient census).
      Verification: verdict recorded (breach / sanctioned / needs-cert-attestation) citing the exact commit hashes found and the `git log` invocation used

- [ ] 2b. G5 review corroborator: sidecar transcript existence check for the review turn(s) cited by the decide-reviewer-attribution gate (verify each claimed review artifact exists at its recorded sidecar path; list missing ones as evidence gaps). Fold in the review-sidecar drain check from BACKLOG.md mouse-gate findings: confirm whether the post-migration intent for the RESEARCH-REVIEW sidecar write (never migrated at line 824 of the migration commit 10aa98ea; cited userspace record deleted 09-17 in 2966e3f8) is documented anywhere
      Verification: per-sidecar existence table committed (exists / missing / gc-gone); explicit yes/no answer on sidecar-intent documentation with grep evidence over AGENTS.md, docs/README.md, automation/README.md, SKILL.md

- [ ] 2b. Tigress 3 gaps (one pass): (1) duplicate-lids audit of contradictory verdicts, (2) kimi-telemetry-contradiction reconcile using the same STATE.md-ledger ground truth as G2, (3) pin-kimi-403-test-vacuity - add the missing kimi-403 test coverage as a session-layer test (no kernel src/). Cite the three tiger banked specs in the step's work log.
      Verification: (1)(2) verdicts recorded citing the contradictory row/commit ids; (3) `make test` at repo root passes with the new test present (`grep -r "403" tests/ automation/` shows it)

- [ ] 2c. Rot/wiki front closures (collapsed): run the rot-sep11 t1-t4 quick probes (commit-chain, counter-evidence, relay-channel, burst-lane) and the g1i focused probes (doctrine-scope, producer-fix-design, test-fixture-impact, target-shape-validation, out-of-repo-exposure) as evidence-source-named probes in one session; include the kernel-home gate check (the two-home split per AGENTS.md boundary: nothing kernel under ~/.hngh, kernel state stays in ~/.hngh-automation) and refresh the gate-inventory surface (docs/design/gate-inventory.md) against current gates; carry the rot-sep11/home-bricker exposure chain (rename decision for the two bricker-bearing research filenames per poodle findings section (c) follow-up candidates); on completions write the rot-sep11 machine-run synthesis canvas, then absorb governance-full-records-sweep using the canvas + freshness evidence
      Verification: t1-t4, g1i, kernel-home-gate, and exposure-chain probe dispositions present in the research-dispositions ledger; canvas doc committed; gate-inventory.md diff reflects current gate set; parent absorb outcome marked; `make test` at repo root passes

- [ ] 2d. ACP audit leftovers, READ-ONLY probes (no writes to the audited system, no live-model re-probes, state budget respected). Evidence sources to probe: (1) acp-audit-02-threatmodel: MITRE ATLAS pin verification via the pinned public corpus only; (2) acp-audit-07-and-demo: dossier/07 line-by-line evidence replay off the banked dossier; (3) gap-g5-87-composition: canonical 87 decomposition against the banked canonical-87 spec; (4) acp-g1-release-leftovers: GitHub Releases API listing + test-output.txt dating; (5) acp-audit-perf-art-corpus: ART/external-corpus reality check against the banked corpus manifest; (6) acp-audit-v3-sandbox-escape: evidence-vs-reality gap where the plug shows official-response evidence; (7) acp-audit-v7-process-compromise: leak/persistence unverified (muted plug, recorded not extended); (8) suppressed residual acp-audit-v1/v2/peck rows: recon batch estate state only
      Verification: one probe-log per item appended under a single audit findings doc (research-ledger or docs/records/), each entry giving the exact source opened and the verdict (evidence-gap confirmed / muted / N/A); zero mutations (`git status` shows only the findings doc); findings doc committed

## Notes

- Max 10 steps kept by collapsing sibling probes: canvas step (2c) names 9
  probe heads; 2d step names 8 probe families with their evidence sources.
- Gates status at authoring time (2026-09-18T00:59Z): `make test` FAILS.
  Therefore status stays `proposed` and `accepted=-`. Re-run `make test` after
  the bundle lands; only a full gate pass justifies flipping to
  `accepted=<UTC ts>` (needs coordinator action, not auto-acceptance).
- Do not delete or rewrite the userspace two-home split or STATE.md tracking.
