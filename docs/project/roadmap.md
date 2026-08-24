# Roadmap

## Direction

Hngh is being rebuilt as a small, predictable core that decides what is valid, with the messy outside world — files, Git, models, terminals — plugged in later at the edges. Each step of the rebuild exists for a reason: evidence comes before claims, so nothing is believed without a record; permission is re-checked at the moment of action, so a certificate is never a free pass; and reviewers advise but never decide, so a model can suggest, but only a policy verdict can admit. The path runs from the pure kernel, to a read-only evidence adapter, to a mutation executor, to bounded model review and agent workers behind ports — all under policy verdicts and one-action certificates. For the vision in full, read [the intent document](../intent.md).

## Now

Current frontier: the clean-slate baseline. The retired daemon and plugin system is archived and not part of the active product. The active kernel contains pure profile and run-domain policy, five fake-backed application use cases, governance C0–C3: the proposal-evidence ledger, deterministic principle evaluation, the failure-disposition policy, and the candidate authorization certificate, plus the read-only evidence adapter (promotion rung 4), the fixture-backed mutation executor (promotion rung 5), the bounded model-review adapter (promotion rung 6), the composition root and operator-visible presentation (promotion rung 7), and the operator-facing command surface with local filesystem transport admission (promotion rung 8).
### Completed

- Sealed the retirement boundary: the archived prior system is external and
  no longer verified (`make check-archive` retired 2026-08-19); the obsolete
  Mission Control desktop launcher was retired, its bytes preserved in a
  supplemental archive receipt.
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
- Added the read-only evidence adapter (promotion rung 4): a fixed, enumerable set of read-only local evidence commands — repository revision, whole-tree working-tree status, and file content hashing — gathered through an injected process transport and mapped to domain evidence facts and source manifest entries with closed states. Unknown commands, malformed output, escaping or option-like paths, and duplicate evidence fail closed; the kernel stays pure and the adapter never decides policy.
- Added the mutation executor (promotion rung 5): `hngh.adapters.mutation` accepts a current certificate and fresh evidence, rechecks repository identity, base revision, candidate paths, content and evidence hashes, principle verdicts, source manifest, review findings, policy profile, and expiry, then issues only the certificate-bound fixed Git action through an injected transport. `:none`, action escalation, stale facts, malformed evidence, command failures, and transport faults refuse without a mutation.
- Added the bounded model-review adapter (promotion rung 6): `hngh.adapters.review` turns a closed review request — candidate paths, content hash, and policy-context labels — into one fixed prompt, sends it through an injected reviewer transport, and maps the structured output into immutable finding labels and citations plus one deterministic domain evidence fact. Missing, malformed, unsafe, duplicate, or oversized output refuses closed; a failed review call becomes an `:unverifiable` fact; reviewers advise and never decide, and no default provider transport exists.
- Added the composition root and operator-visible presentation (promotion rung 7): `hngh.presentation` renders application results, runs, receipts, evidence facts, policy verdicts, candidate certificates, and adapter results into plain factual strings without mutating canonical state or importing any adapter; the optional reference lexicon supplies display copy only at a named surface and can never carry canonical control. `hngh.main` composes the five use cases into one `run-harness` with injected or fail-closed default port adapters, wires the installed evidence, mutation, and review adapters through injected transports, keeps an operator-visible in-memory record root, and renders every result through presentation. No daemon, provider, watcher, or background execution.
- Added the operator-facing command surface and transport admission (promotion rung 8, 2026-08-24): `hngh.application:admit-transport` admits closed transport kinds (`:filesystem`) under mission/loadout authorization; `hngh.adapters.filesystem` records canonical run-and-receipt lines under an explicit root path; `hngh.main:dispatch-command` and `scripts/hngh` expose the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a strict exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault). Persistence occurs only under an explicit `--store=PATH`.

## Next

1. **Dogfood development loop.** The operator surface commands have landed: `propose`, `issue-cert`, `mutation-check` in `scripts/hngh` run the proposal-to-verdict-to-certificate-to-preflight pipeline in-process with fixture-gated evidence and injected ports (promotion rung 9, 2026-08-24). Next: exercise the complete kernel, evidence adapter, model review adapter, and mutation executor in a self-governed loop where Hngh proposes, reviews, and commits changes to its own repository under verified certificates.
2. **Bounded agent worker transports.** Admit real model and terminal transport implementations behind explicit run loadout configurations.
3. **Distributed attestation & evidence federation.** Paper-first design for remote evidence ports and cross-machine certificate verification.

No daemon, provider, watcher, scheduler, dashboard, or unbounded mutation is admitted by this roadmap stage.
