# 2026-09-15 - Doctrine reconciliation: kernel-gates operator-only vs flexibility doctrine 2a

## The apparent tension

Two records read as if they disagree:

1. `docs/records/2026-09-12-privilege-model.md` (schema v1): the host
   config declares `"kernel-gates": "operator-only"` as "the ONLY
   admitted value" - certificate ceremony; kernel `src/`, `tests/`,
   `Makefile` are never hngh-discretion.
2. `docs/records/2026-09-09-operator-flexibility-doctrine.md`, as
   amended by `docs/records/2026-09-13-wake-mutation-lane-landing.md`
   (section 2a): machine sessions MAY mutate kernel surface when a
   slice has a certificate path (propose -> issue-cert ->
   mutation-check); "a parked queue item with an open certificate path
   is a routing defect, not governance."

## Reconciliation

They operate on different layers and are consistent:

- The privilege model's `kernel-gates: operator-only` describes the
  HOST GRANT boundary: what the OS-level machine identity may do
  without the governance loop. It forbids direct/discretionary kernel
  edits - exactly what both records intend. Nothing in the flexibility
  doctrine bypasses this: doctrine 2a mutations are not
  host-discretion actions; each one carries a fresh certificate
  issued through the closed loop, bound to a content hash, and is
  committed only on a green gate (2026-09-15 gave two live
  demonstrations: ceremony content-hashes 2f9e618f and 7fac729e).
- Doctrine 2a describes the AUTHORIZATION ROUTING layer: when the
  operator has pre-authorized a class (or the certificate path exists
  for a slice), parking the item for a human is a defect. The operator
  remains the class authorizer; the ceremony is the per-instance
  enforcer.

Stated as one rule: **operator-only at the host grant layer; class-
authorized, certificate-enforced at the mutation layer.** The privilege
model string stays as-is (it is the machine-readable host boundary);
no schema change is required.

## Vestigial constant

`docs/records/2026-09-12-privilege-model.md` section 5 also carries a
legacy session-cap constant of 4 (superseded by the 2026-09-09 ceiling
move to 200, per the budget-governance record). It is historical
narrative in that record, not a live config; no action needed. Noted
here so the zoom-gating inertia flag is closed with evidence.

## Disposition

Both inertia flags from the 2026-09-15 zoom-gating review are closed:
the tension is documented as layered-not-contradictory, and the
vestigial constant is confirmed inert. No code or config changes.
