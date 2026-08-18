# Roadmap

## Direction

Hngh is being rebuilt as a small, predictable core that decides what is valid, with the messy outside world — files, Git, models, terminals — plugged in later at the edges. Each step of the rebuild exists for a reason: evidence comes before claims, so nothing is believed without a record; permission is re-checked at the moment of action, so a certificate is never a free pass; and reviewers advise but never decide, so a model can suggest, but only a policy verdict can admit. The path runs from the pure kernel, to a read-only evidence adapter, to a mutation executor, to bounded model review and agent workers behind ports — all under policy verdicts and one-action certificates. For the vision in full, read [the intent document](../intent.md).

## Now

Current frontier: the clean-slate baseline. The retired daemon and plugin system is archived and not part of the active product. The active kernel contains pure profile and run-domain policy, five fake-backed application use cases, and governance C0–C3: the proposal-evidence ledger, deterministic principle evaluation, the failure-disposition policy, and the candidate authorization certificate.

### Completed

- Sealed the retirement boundary with a read-only archive verifier (`make check-archive`); retired the obsolete Mission Control desktop launcher, preserving its bytes and parent configuration in a supplemental archive receipt.
- Published the Clean Architecture charter, component map, test boundary, and presentation boundary; added fixture guards for inward dependency direction and renderer-only reference lexicons.
- Specified and tested the pure run domain: closed lifecycle, typed refusal, validated mission/role/loadout values, and non-authoritative evidence values.
- Added the read-only reader guard to the fast gate (`make test` runs 8 reader-guard checks plus the domain suite).
- Added the five fake-backed application use cases, each recording one atomic run-and-receipt pair and refusing anything outside its closed contract:
  - `create-run` with capability-specific fake ports and closed callback refusals;
  - `arm-run` with four closed admission facts, so only full confirmation can create an armed replacement run;
  - `start-run`, so only the application boundary can make an armed run running;
  - `checkpoint`, so only passed verification and complete manifest evidence can advance a running run;
  - `close-run`, policy-gated, so a run reaches a terminal state (`:cancelled`, `:evacuated`, or `:dead`) only under an `:admitted` policy verdict, with closed transition refusals and no certificate for run-state transitions.
- Added a read-only candidate evidence bundle (`make verify-candidate`): explicit manifest admission, candidate-local policy scans, fixed local evidence commands, and closed status output; it observes whole-tree state without inferring scope or mutating Git.
- Added governance C0–C3:
  - the proposal-evidence ledger;
  - deterministic principle evaluation — one `policy-verdict` per proposal with ten matrix-ordered principle results and closed refusals for missing, stale, malformed, conflicting, or unverifiable evidence;
  - the closed failure-disposition policy — one deterministic disposition per failure category, refusing unknown categories;
  - a non-mutating candidate authorization certificate binding one closed action to the admitting verdict and facts, issued by a mechanical pure issuer (action-admission policy deferred to the executor).
- Published source-grounded autonomous development policy, the closed principle and certificate vocabulary, and a human-approval deployment profile — documentation only, no execution added.

## Next

1. **Read-only evidence adapter (promotion rung 4).** Fixed local evidence commands and repository facts feed the proposal ledger. Why it matters: evidence before claims — the kernel can only decide on records it actually has, and this rung gathers them without changing anything.
2. **Mutation executor (promotion rung 5).** Rechecks every certificate fact immediately before its named action, refusing changed content, unexpected paths, stale base revision, expired certificate, malformed input, command failure, and disabled action classes. Why it matters: permission re-checked at the moment of action — a certificate is not a free pass.
3. **Bounded model-review adapters.** Added only after the lower contracts exist. Why it matters: reviewers advise, never decide — a model can propose and comment, but the policy verdict stays in the kernel.

No daemon, provider, watcher, scheduler, dashboard, adapter, or mutation executor is admitted by this roadmap stage.
