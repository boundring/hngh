<!-- plan: status=accepted risk=normal accepted=2026-09-08T08:01:31Z -->
# 2026-09-08 — operator procedural unblocks + capabilities completion

Authorization: operator-directed 2026-09-03, recorded faithfully in
docs/records/2026-09-03-capabilities-direction.md. This plan completes
the 2026-09-03-capabilities plan (steps 8, 9) and unblocks the
2026-09-03-staging plan via operator procedural steps.

Sources: docs/project/plans/README.md (the contract this file obeys);
docs/project/plans/2026-09-03-capabilities.plan.md (steps 8, 9 complete);
docs/project/plans/2026-09-03-staging.plan.md (7 steps blocked on operator install);
docs/research/2026-09-08-queue-drain-verification.md (this plan's evidence);
docs/research/2026-09-08-credential-redaction-audit.md (step 4 audit record).

Grounding notes:
- The 2026-09-03-capabilities plan is 44% complete (4/9 steps). Steps 4, 5, 7 parked due to missing `op` CLI and playwright/chromium.
- The 2026-09-03-staging plan is 0% complete (0/7 steps). All 7 steps blocked on operator install of playwright + chromium.
- Daily throughput is rising (138.0 rows/day recent mean vs 112.6 overall mean).
- The highest-leverage fix is the operator procedural steps: install `op` CLI, sign in, install playwright + chromium.

## Steps

- [ ] 1. RESEARCH — operator procedural unblock. Document the exact operator steps needed to unblock the 2026-09-03-staging and 2026-09-03-capabilities plans. The steps are:
  - Install 1Password CLI (`op`) and sign in (`op signin`)
  - Install playwright (`npm install -g playwright`) and chromium (`playwright install chromium`)
  - Load SMTP credential into 1Password (`op item create --vault=<vault> --title=<title> email <user> password <pass>`)
  Verification: a research note (docs/research/2026-09-08-operator-procedural-unblocks.md) with the exact operator steps quoted, the current state of each prerequisite, and a verdict on whether the operator can proceed autonomously or needs human intervention.
- [ ] 2. GROW — capabilities plan completion. Complete the remaining steps of the 2026-09-03-capabilities plan (steps 8, 9):
  - Step 8: queue-drain verification beat (already authored: docs/research/2026-09-08-queue-drain-verification.md)
  - Step 9: wrap, lessons, author-next-plan (this plan file)
  Verification: the 2026-09-03-capabilities plan file updated with step 8 checked, step 9 unchecked (pending this plan's completion).
- [ ] 3. GROW — staging plan unblock. Once the operator has installed `op` CLI and playwright + chromium, re-run the 2026-09-03-staging plan steps 1-7 (bench calibration, stage sweeps, unsloth recovery note, package-upgrade runbook). Each step verifies on its own.
  Verification: all 7 steps of the 2026-09-03-staging plan checked.

## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. Do not wait for or ask for human approval. hngh-automation commits are free. hngh changes land via the certificate ceremony ONLY with a green `make test`. hngh kernel src/, tests/, Makefile, and hngh.asd changes are FORBIDDEN this session — if a step requires one, stop that step, note it in the plan file, and move to the next step. Never touch provider or credential configuration, systemd unit state, tracked deletions outside the 48h prune, or secrets. If blocked, write what blocked you into the plan file and move on; other work always exists.

## Parked (not in this plan, recorded for the operator)

- The unsloth token-pair migration into 1Password — LAST in the migration order (credentials-posture.md §3), only after the refresh path is proven against the vault; requires the operator's `op item create` for the pair.
- Architecture A (CDP attach to the operator's running browser) — rejected for now on security-posture grounds (research doc §2); revisiting it is critical-class and operator-decided.
- Discord and WhatsApp channels — behind Google Messages proving the pattern; each adds ToS/fragility surface.
- `enable`/`disable` posture changes for the allowlisted units (e.g. enabling llama-server at boot) — critical-class under the amended grant; operator-decided.
- Config-manager implementation beyond the first declared lane — stage-4 row territory; the launch-config lane research (step 2) feeds it.
