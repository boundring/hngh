<!-- plan: status=accepted risk=normal accepted=2026-10-15T11:06:40Z routed-from=review-finding:2026-10-15:dashboard-server-py-keeps-the-constant-n -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-22T11:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-15:dashboard-server-py-keeps-the-constant-n`
at 2026-10-15T11:00:12Z. Alert text: dashboard-server.py keeps the constant named `OMARCHY_UPSTREAM` while it now resolves to the runtime checkout — the rename was done in every comment/remediation string but not the identifier, so the ambiguity the commit exists to kill survives in the API surface (`_desk_probe_clone`, the 409 handler). fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
