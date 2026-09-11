# 2026-09-11 — Kernel gate red: two omp-bridge loop-history misses

## Question

Why is the kernel gate (`make test` rc=2) red since 2026-09-09, and can
the breaking commits be cured through the loop without rewriting
history? (Subject fail-20260911-overnight-plan-accept-gate-kernel; the
red gate blocked kernel plan acceptance — alert identity
`overnight:plan-accept-gate:kernel` routed daily — and origin push.)

## Findings

F1. The failure is the loop-history guard
(tests/scripts/test-loop-history-guard.py), not the Lisp suite: every
code-surface commit after the restatement (1915713) must be
`hngh: candidate <hash>` or a named rule-based exemption. Two commits
violated it:

- `a2f4d0e` 2026-09-10 — "feat: omp-bridge --propose and --plan-status
  (plan step 3)" — touches `scripts/omp-bridge` + tests, no label.
- `31768d2` 2026-09-10 — "fix: omp-bridge --plan-status accepts bare
  slug or date-prefixed stem" — same file, no label.

Both landed machine-side during the fully-executed 2026-09-09
integration plan (11/11 steps) — real feature work that missed the
ceremony, not hidden behavior changes.

F2. The guard is doing its job: the red gate surfaced within
overnight plan acceptance and blocked push, exactly as designed. The
block persisted two days because kernel `tests/` is machine-forbidden
except through the certificate ceremony, so prior sessions parked
instead of curing (7 router cycles of `overnight:plan-accept-gate`).

F3. The cure is pre-decided by repo precedent: decisions.md 2026-09-06
("a post-guard miss is declared, cured through the loop, never
rewritten", the 526cd3f generate-publication case). Machine work may
touch the code surface through the certificate ceremony per the
operator-flexibility doctrine (2026-09-09, §2).

## Fix (landed 2026-09-11, candidate f2f04e3)

1. Declared: `KNOWN_EXEMPTIONS` in the guard lists both commits with
   reasons; the rule for future commits is untouched.
2. Cured through the loop: one ceremony run (omp-bridge --ceremony →
   ceremony-drive: create-run → admit-transport → propose
   (10-principle verdict) → issue-cert → mutation-check prepare + commit)
   bound the final `scripts/omp-bridge` content, the guard declaration,
   decisions.md entry, cure record
   (docs/records/2026-09-11-omp-bridge-post-hoc-certification.md), and
   CHANGELOG entry into candidate `f2f04e3`
   (`hngh: candidate 8ce5af35…`). No revert/re-apply dance: unlike
   526cd3f the content was already final, so the certification binds
   what ships and the guard covers history.

## Verification

- `make test` green: 2889 checks passed (was rc=2 for ~2 days).
- Guard: "87 code-surface commits checked, 4 named exemption(s),
  0 violations".
- Post-fix plan acceptance unblocked (kernel-gate-red-rc2 cause gone).

## Residual

- Origin push remains blocked by GitHub push protection — an
  OpenRouter API key in docs/research/2026-09-10-lobehub-api-research.md
  lines 11+81 (pre-existing commits 13007a8/857d1de, in the unpushed
  range). Operator action (rotate key, redact, allowlist) is tracked by
  plan 2026-09-10-routed-push-blocked-openrouter-key-hngh; tonight's
  ceremony push refusal adds the unblock URL
  https://github.com/boundring/hngh/security/secret-scanning/unblock-secret/3J97gRRoN8mSiEknkAf2IST0yZa
  as fresh evidence. Not machine-fixable: credential rotation is
  operator-owned.
