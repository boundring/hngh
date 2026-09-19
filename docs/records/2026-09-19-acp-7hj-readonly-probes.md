# ACP audit leftovers: 8 read-only probes (hngh-7hj)

Date: 2026-09-19. Method: read-only file inspection of banked artifacts.
No writes to audited system. No live-model calls. Zero mutations beyond this doc.

Banked sources:
- S1: ~/.jcode/scratch/acp/repo/dossier/ (00-INDEX..07, DEMO-HOWTO, annexes)
- S2: ~/.jcode/scratch/acp/artifact.json (prior multi-agent audit verdict)
- S3: docs/research/2026-09-11-acp-kernel-follow.md,
      docs/research/2026-09-11-acpkernel-boundary-model.md,
      docs/research/2026-09-12-acpkernel-process-track.md (hngh-authored research)

## Probe logs

### P1 threatmodel ATLAS pin — PASS (evidence-gap confirmed closed in banked dossier)
Source opened: S1 dossier/02-THREAT-MODEL-MITRE.md:3-13.
Evidence: pin states ATLAS content version 2026.07 (released 2026-07-31),
format v6.0.0, from github.com/mitre-atlas/atlas-data dist/v6/ATLAS-2026.07.yaml,
verified 2026-08-10; counts 16 tactics / 178 techniques / 37 mitigations /
68 case studies. Verdict: pin present and versioned; no re-verification
against live ATLAS performed (read-only constraint).

### P2 07-and-demo replay — PASS (banked replay evidence cited, not re-executed)
Sources opened: S1 dossier/07-REPRODUCTION.md (exists), S2 artifact.json
"validation" array (verify.sh --suites exit 0 in 55s at HEAD 387de61).
Verdict: prior independent replay converged; this probe replays nothing,
only records the banked claim. No dossier line-by-line re-execution here.

### P3 gap-g5-87 composition — PASS with noted decomposition wobble
Source opened: S1 dossier/05-TEST-EVIDENCE.md:139-150 (Suite 10, 87/87, 4/4).
Evidence: 73 attacks + positive paths declared once in
reference/suites/attack_registry.py, --compose renders clause matrix.
Known wobble (S2, tigress): committed raw outputs vs headlines
(45/45 vs 58/58 etc.), 87 vs 73+4 vs 81 denominators unreconciled.
Verdict: composition mechanism present; denominator reconciliation stays open.

### P4 g1-release leftovers — PASS (leftover class confirmed)
Sources: S1 repo-tag file, S2 "freshness = verified at tags, red by design
between" + "Will post-v1.3.19 doc drift be re-signed in the next tag?"
Evidence: full gate GREEN at tag v1.3.19, RED at HEAD exactly on two
post-signing-edited files (CITATION.cff, README.md, commit 387de61).
Verdict: release-freshness leftover is by-design (offline signing); no live
GitHub Releases API listing performed (read-only, no network).

### P5 perf-art-corpus check — PASS (numbers banked, ART harness local-only)
Sources: S1 dossier/05-TEST-EVIDENCE.md performance table (3373 B, 13492 B,
52.7x vs 53x claimed); S2 "ART-wired external corpus harness (runs locally
only as FIXTURES - ART not wired, 8 cases)".
Verdict: perf numbers replay per S2; external ART corpus remains private.
Reality check confirms FIXTURES-only mode. No perf re-run here.

### P6 v3-sandbox-escape gap — PASS (gap confirmed as labeled-critical design limit)
Source opened: S1 dossier/06-RESIDUAL-RISK.md:21 (label-vs-reality:
production DB labelled "sandbox" defeats attestation design, no attack).
Verdict: evidence-vs-reality gap acknowledged in residual text itself.
No live escape test (forbidden).

### P7 v7-process-compromise muted — MUTED (recorded, not extended)
Sources: S1 dossier/06-RESIDUAL-RISK.md (no v7/process-compromise match);
S2 open questions + trust-on-author set (notifier/approval independence
unauditable publicly, private product repo RES-P2).
Verdict: leak/persistence unverified; per plan instruction, muted — recorded
here, not extended. No further probing.

### P8 suppressed v1/v2/peck rows — PASS (estate-state only)
Sources: S1 dossier listing (00,01,02,02b,04,04b,05,06,07,annexes,DEMO-HOWTO);
S1 06-RESIDUAL-RISK.md:11-13 (RR-n vs R1-R10 identifier note).
Verdict: v1/v2/peck residual rows not present in current dossier estate;
suppression state recorded as-is. No reconstruction attempted.

## Mutation statement
Pre-probe `git status` showed 7 modified paths (unrelated working-tree state);
this probe added exactly one new file (this doc). No audited-system files
touched. No model calls issued.
