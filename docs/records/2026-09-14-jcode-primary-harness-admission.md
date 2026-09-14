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

## Step 3 exit evidence (2026-09-14)

- Witnessed delegation cycle (SDK shim): budget row
  `overnight|jcode-witness | session-run | model=jcode/zai/sdk`;
  bounded read-only prompt answered correctly; rc 0. A parallel lane
  witnessed the same through the `jcode run` CLI branch
  (`model=jcode/zai`); budget row and wrapper prose committed 820aa22.
- Witnessed seeded-stall auto-replace (governed-fleet §4): live
  supervision tick against a sandbox bridge store with a seeded
  non-terminal run — stall flagged, `close-run dead` accepted, record
  rotated to a timestamped subdir, `auto-replace` run-start
  re-provisioned the same mission. Required fix landed:
  `automation/jobs/agent-supervision.py` default hngh/omp-bridge paths
  (ROOT/../scripts; the old ROOT/../hngh/scripts default was
  nonexistent — bare-env ticks could never close a run).
- Fail-closed surface: worker refuses an unpinned or unsafe instance
  home (exit 2); `launch_session` jcode branch order is SDK shim ->
  CLI `jcode run` -> omp, each leg taken only when the previous is
  unavailable, breadcrumb per hop.

## Step 4 exit evidence (2026-09-14)

- Certificate bridge on the worker lane: `lib/launch-jcode.sh`
  refuses `JCODE_WORKER_APPROVE=1` (rc 75, before any child spawns)
  unless `JCODE_WORKER_CERT` is a readable JSON scope file —
  `{"actions": [...], "expires": "<ISO-8601>"}` — that parses, names
  a non-empty action list, and is unexpired. `jcode/worker.mjs`
  re-validates the scope, denies every `permission_request` in an
  uncertified lane (never parks a prompt), allows exactly the tool
  names inside the certified action list, and writes an allow/deny
  audit line to stderr per decision. Blanket `autoApprove` is removed
  from the run path.
- Verified hermetically: `tests/test-launch-jcode.sh` cases 8-13 —
  approve without cert, expired, malformed, and empty-actions
  certificates all refused 75; a valid certificate passes the wrapper
  gate; source greps pin the audit lines. Green inside the automation
  `make test` gate (rc 0). Commit 4eaf1f0 (changelog 485a0a2).
- Scope of the rung: the gate is the automation-tier scope file the
  launching lane captures; binding it to a kernel-issued rendered
  certificate record (the `scripts/hngh issue-cert` one-liner,
  `action=`/`expiry=`/`policy-profile=real`) is the named follow-up if
  kernel-grade binding is demanded — the kernel ceremony itself closes
  issue-cert -> mutation-check inside one invocation and never hands
  a certificate to a child process.

## Honest unknowns

- The SDK is Node 20+; the automation tier is Python/bash. The worker driver
  needs either a Node shim or the `jcode` CLI invoked directly (it is on
  PATH). Decision deferred to plan step 2 with a named verification.
- Windows support in the SDK is untested upstream; irrelevant to this host,
  relevant to the eventual public-release installer lane only.
- Multi-agent swarm/spawn depth limits inside Jcode are not yet verified
  against the local build; plan step 2 includes the verification read.
