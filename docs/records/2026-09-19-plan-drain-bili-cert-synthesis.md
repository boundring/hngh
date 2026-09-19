# 2026-09-19 — plan-drain synthesis: bili-cert family

## Family scope

Certificate lifecycle in the hngh kernel: minting, ephemerality,
disposition surfaces, and the per-client trust audit (bili-cert branch
of the deep plan, ~200 nodes).

## Completed children banked

- `docs/records/2026-09-17-certificate-ephemerality-of-record.md`:
  kernel mints each certificate in memory, renders to stdout once,
  destroys it; no store path writes a certificate. Commit subject
  `hngh: candidate <64hex>` is the only durable trace (299 labeled
  commits on main at record time).
- `docs/records/2026-09-17-cert-disposition-surface-closure.md`:
  no ledger tracks certs; orphaned certs (declared only on dangling
  commits, e.g. `a3286b78`) are moot by mechanism — no second record
  to correct.
- `docs/records/2026-09-17-candidate-reconciliation-closure.md`:
  census of store/queue/dashboard found zero certificate rows;
  feasible rung is label-to-content recomputation from git alone.
- Per-client trust matrix + CA hardening probes (bili-cert-client-*,
  bili-ca-* nodes): completed probes live in records and patrol
  checks; remaining open gate nodes are blocked on provider routes,
  not on kernel work.

## Park decision

The bili-cert audit is closed as an audit: ephemerality is a recorded
design gap (no persistence decision exists in decisions.md or design/),
and the mitigation is the patrol label-recomputation check, not a
kernel change (kernel `src/` is staging-frozen). Any future cert
persistence proposal goes through the ceremony (propose ->
issue-cert -> mutation-check), not through graph nodes.

## Follow-ups (bead)

Filed as bead `hngh-bilicert-follow` (placeholder — see implement step):
cert-persistence design proposal via ceremony; keep patrol
label-recomputation check green.
