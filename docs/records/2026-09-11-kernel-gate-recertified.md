# Kernel gate recertified: post-purge exemption re-keying + purge-proof safeguards

Date: 2026-09-11. Status: executed. Operator approved both decisions of
docs/research/2026-09-11-kernel-gate-cure.md; machine-driven ceremony
exactly per the e79ed08 precedent.

## What the ceremony re-keyed

The 10:57 secret-scrub filter-branch purge orphaned the declared
exemption hashes (a2f4d0e, 31768d2) and re-keyed their descendants
(572d3e2, adb0307): same subjects, same author dates, identical
patch-ids. This ceremony re-keyed the two KNOWN_EXEMPTIONS entries to
the post-purge hashes (572d3e2, adb0307), each annotated "hash
post-purge (2026-09-11 secret-scrub filter-branch), same patch-id as
the declared original", and appended the supersede note to
docs/project/decisions.md (2026-09-11 declaration entry stands; no
governance change).

One further entry, operator-approved into the same batch: `41f646a`
(auto-unpark blocker cooldown + README daily dispatch frame, committed
2026-09-11 16:05 after the memo) touched repo-root
`scripts/generate-publication` under the automation free-commit rule
without the candidate label — the same violation class. Declared
post-hoc (patch-id d72c1f2c...); AGENTS.md's engineering rules now
state that repo-root `scripts/` is kernel code surface and
machine-session commits there require the ceremony label.

## Safeguards baked in (Option C)

1. Exemption-reachability self-check
   (tests/scripts/test-loop-history-guard.py): every registered hash
   must resolve in reachable history (`git merge-base --is-ancestor`);
   a dangling hash fails with a self-naming message directing to the
   re-declaration ceremony. Unit-proven against both a deterministic
   dangling fixture and the real orphan a2f4d0e.
2. Purge-proof keying: KNOWN_EXEMPTIONS entries carry a patch-id
   (git show <hash> | git patch-id --stable); the guard matches by hash
   first, patch-id second — patch-ids survive descendant rewrites, so a
   purge no longer silently invalidates declarations. Verified live:
   the orphaned a2f4d0e/31768d2 patch-ids equal the registered
   572d3e2/adb0307 patch-ids (558c84f7..., 697027ae...). Tests:
   tests/scripts/test-loop-history-guard-safeguards.py.

Purge runbook: docs/research/2026-09-11-kernel-gate-cure.md section 8.

## Gate and push

Post-ceremony the loop-history guard reports zero violations and the
kernel `make test` gate is green. Push of origin/main was driven by the
ceremony's certificate-gated push step.
