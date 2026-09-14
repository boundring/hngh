# 2026-09-14 — Jcode as primary agent harness: admission and staged integration

Operator-directed (2026-09-14, verbatim intent: "introduction of Jcode to be
prioritized and advanced to precede most other work"). Jcode
(github.com/1jehuang/jcode, installed locally at v0.84.0-dev) is admitted as
operator-directed design pressure, replacing oh-my-pi as the primary agent
harness, under the same precedent as the 2026-09-09 omp integration admission
and the 2026-09-11 design-pressure admissions (operator-mirror, keyring,
OS-harness vision).

## Why Jcode fits Hngh's architecture

- **Stable versioned protocol.** The TypeScript SDK
  (`@1jehuang/jcode-sdk`) speaks protocol v1 with handshake major-version
  negotiation and bidirectional schema-drift tests. This is the property the
  governed-fleet design demands of any delegation transport: a peer that
  refuses to half-work.
- **Two explicit modes match Hngh's two consumers.** `launch()` (private
  instance, own state home, `close()` reaps) is the shape for governed worker
  lanes; `connect()` (attach to the operator's live jcode) is the shape for
  the nerve center's session observatory and operator-facing surfaces.
- **Permissions are a protocol event**, not a config flag:
  `permission_request` → `respondToPermission(allow|allow_always|deny)` maps
  directly onto the certificate loop's "re-checked at the moment of action"
  law. `run(autoApprove)` is reserved for lanes whose certificate already
  authorizes the exact action class.
- **Mirroring properties already named in research.** The 2026-09-12
  harness-delegation research line independently identified jcode's
  mode-gated spawn depth and single-writer plan slot as transferable
  supervision patterns. Those claims were [external] then; this admission
  authorizes verified reads going forward.
- **Clean-architecture fit.** All Jcode-facing code is edge-tier:
  `automation/` adapters and SDK consumers. The kernel's dependency law
  (docs/core/clean-architecture-charter.md) is untouched — the kernel never
  learns jcode exists; adapters call the hngh CLI inward.

## Architecture constraint (same as the omp admission)

- No Jcode code in kernel `src/`, `tests/`, `Makefile`, or `hngh.asd`
  outside the certificate-bound ceremony lane.
- hngh-side adapters live in `automation/` (Python/TS), wrap read-only
  kernel CLI, and fail closed.
- Dependency direction: automation adapters call hngh inward; the kernel
  knows nothing of Jcode.
- Credential policy: `launch({ inheritLogins: false })` for any lane running
  non-operator-initiated work; secrets ride the 1Password service-account
  seam (2026-09-09 record), never linked credential directories.

## Staged route (full plan: docs/project/plans/2026-09-14-jcode-primary-harness.plan.md)

1. **Adapter parity** — port the hngh MCP/bridge surface from omp to Jcode:
   the MCP server already registered for omp serves Jcode unchanged
   (stdio MCP is a shared standard); add a Jcode `AGENTS.md`/rules package
   equivalent to the omp plugin's orientation skills.
2. **Governed worker lane** — a `launch()`-based worker driver in
   `automation/` wrapped `--run-start` → observatory `working` →
   `--run-end`, honoring the governed-fleet stage-3 delegation pattern
   (seeded stall auto-replace as exit evidence).
3. **Permission bridge** — Jcode `permission_request` events routed to the
   certificate loop: deny by default, allow only against a live mutation
   certificate; `autoApprove` forbidden except in lanes with a certificate
   scoped to the exact action class.
4. **Observatory integration** — nerve-center Sessions tab observes Jcode
   sessions through `connect()`/`peekSession` (preview without disturb),
   reusing the transcript-supervision pattern proven in stage 1.
5. **Config + installer lane** — `~/.jcode` config as the declared agent
   config under the governed-fleet config lanes; Hngh installer gains a
   Jcode install option (back-burnered behind the stage-3 package-registry
   rungs, per the 2026-09-11 OS-harness ladder).
6. **Omp coexistence and retirement** — omp surfaces remain until each has a
   Jcode equivalent passing the same verification; retirement is a named
   record, not a default.

## Prioritization

Per operator directive, this route precedes discretionary queue work
wherever scheduling latitude exists, mirroring the omp plan's 2026-09-09
priority directive. Stages 2 and 3 (the current landing stages) are not
preempted: the Jcode worker lane lands *as* governed-fleet stage-3 evidence
(one witnessed delegation cycle), so the two advance together.

## Honest unknowns

- The SDK is Node 20+; the automation tier is Python/bash. The worker driver
  needs either a Node shim or the `jcode` CLI invoked directly (it is on
  PATH). Decision deferred to plan step 2 with a named verification.
- Windows support in the SDK is untested upstream; irrelevant to this host,
  relevant to the eventual public-release installer lane only.
- Multi-agent swarm/spawn depth limits inside Jcode are not yet verified
  against the local build; plan step 2 includes the verification read.
