# Stage-4 governed package upgrade runbook (design)

- Authored: 2026-09-03 staging plan step 6 (research beat; landed 2026-09-09).
- Status: **design-only, execution parked as operator-supervised.** No package
  command was run by this step and none may be run by a machine session; see
  [Boundary](#boundary-machine-forbidden-operator-supervised).
- Feeds: roadmap stage-4 exit criterion "a governed package upgrade runs
  start-to-finish through the certificate loop on this host"; the dashboard
  System-tab governed-lanes view (2026-09-04 plan step 4) renders this same
  sequence — that doc owns the view, this doc owns the execution sequence.

## Grounding

- Roadmap stage-4 row (docs/project/roadmap.md): "package-manager integration
  (updates inventory → certificate-gated upgrades) … first managed service:
  local Unsloth/llama-server"; exit criterion "a governed package upgrade runs
  start-to-finish through the certificate loop on this host; config lanes
  declaratively listed and backed up on cadence". State: **queued**.
- Backlog row `config-manager`: certificate-bound apply; "the apply must
  recheck every evidence fact at the moment of mutation, and the revert path
  must exist without an untracked daemon"; review trigger = applied+reverted
  config binds to evidence facts and drift refuses.
- Backlog row "System controls → governed package operations": v1 safe ops
  landed; next is "governed package upgrades ride the certificate loop
  (proposal → verdict → executor runs the update in a declared window with
  rollback evidence)"; risk line: "unattended upgrades break running work —
  upgrades are certificate-gated, declared-window, rollback-evidenced, never
  ambient"; review trigger = "one governed upgrade executes end-to-end with
  pre/post manifests and rollback evidence".
- Inventory feed (system-ops v1, landed): `hngh-automation/jobs/system-feed.py`
  (read-only, fail-closed; `updates: {count, packages}` from `pacman -Qu
  --quiet`, plus orphans, units, disk, journal), mounted 30m via
  `cadence/30m/10-system-feed.sh` into `dashboard/system-ops.json`; the
  dashboard `POST /system` refresh re-runs the same script.
- Certificate loop verbs (kernel `scripts/hngh`): `propose`, `review`,
  `issue-cert`, `mutation-check`, `checkpoint`, `close-run` (full verb list
  verified from `hngh` usage at authoring time).
- Service restart after update: `scripts/service-ctl.sh` allowlist
  (llama-server/unsloth-warm/unsloth-studio; standing operator grant recorded
  in decisions.md 2026-09-07); enable/disable/unit-file edits stay
  critical-class.

## Boundary (machine-forbidden, operator-supervised)

- Kernel-side governed update lanes are **FORBIDDEN to machine sessions**.
  Every prior plan states it the same way (2026-08-30-overnight-continuity:
  "Kernel-side stage-4 work (config-manager governed lanes, package inventory
  → governed update lanes): forbidden to machine sessions. Parks.").
- The machine's permitted roles in this runbook: producing evidence
  (read-only feed), drafting the proposal, preparing the verdict packet, and
  recording dispositions. The machine **never** invokes pacman/yay, never
  restarts a unit outside the service-ctl allowlist, and never holds the
  mutation step.
- The operator is the only actor who may execute the upgrade and the only
  issuer of the verdict that arms the certificate. This runbook is parked
  until the operator runs it once supervised; after that first supervised
  execution the backlog review trigger can be claimed.

## Runbook outline

Each phase names the actor, the artifact, and the failure path.

### Phase 0 — Declared maintenance window (operator)

The operator declares a window (start, expected duration) in the run record
before anything binds. The backlog risk line requires a declared window;
upgrades are "never ambient". Long-running delegated overnight sessions are
paused or drained first — an unattended upgrade must not break running work.

### Phase 1 — Package inventory feed (machine, read-only)

Machine refreshes the system-ops v1 feed (`jobs/system-feed.py`, the same
read-only probe the 30m cadence and the dashboard refresh endpoint run) and
extracts `updates.packages` — the exact pending `pacman -Qu --quiet` list.
This list is the proposal's evidence payload. A feed failure (probe omitted,
fail-closed) stops the run: no inventory, no proposal.

### Phase 2 — Proposal binding the exact package list (machine)

Machine drafts the certificate-loop proposal (`hngh propose`, key=value
pieces) whose payload pins the verbatim package list from Phase 1, the feed
timestamp, and the declared window. Scope: normal-risk repo updates only in
v1; kernel/gpu/firmware-family packages (linux, mesa, vulkan, nvidia-class)
are listed but marked operator-eyes — the proposal may exclude them or flag
them, decided at proposal time, never silently.

### Phase 3 — Model review + operator verdict (machine, then operator)

The run's model review scores the proposal (advisory); the operator reads the
review and writes the verdict file (accept/reject/trim). The operator may
trim packages from the list — a trimmed list becomes the certificate's list.
No certificate issues without an operator verdict; the machine cannot
self-approve its own proposal.

### Phase 4 — Certificate issuance (operator verdict → machine binding)

`hngh issue-cert ACTION RUN VERDICT-FILE [PATH...]` binds the certificate to
the operator-verified verdict and the exact evidence paths (the feed snapshot
containing the package list). The certificate's payload is the package list;
that binding is what the fresh-evidence recheck in Phase 5 checks against.

### Phase 5 — Fresh-evidence recheck, immediately before the mutation (machine)

Seconds before the upgrade, the machine re-runs the feed and diffs the fresh
`updates.packages` against the certificate's bound list. This is the
config-manager risk line made concrete: "the apply must recheck every
evidence fact at the moment of mutation". Mismatch → the certificate is void,
the run parks with an alert row, and the loop restarts at Phase 1 with the
new inventory. A match → the operator is cleared to mutate. The recheck is
read-only and always machine-executable; it is the last thing before human
hands touch pacman.

### Phase 6 — The upgrade (operator)

The operator, inside the declared window, runs the upgrade by hand (plain
`pacman -Syu` / their usual `yay` flow) against the certificate's package
list. The operator supervises any interactive prompts. The machine witnesses
only: it records run-start before and reads the post state after. v1 has no
executor that runs pacman — the "executor" in the backlog row's
proposal→verdict→executor chain is, for this first run, the operator.

### Phase 7 — Post-run manifest + checkpoint (machine, then operator)

Machine re-runs the feed and the `-Q` queries to build the post manifest
(versions after, orphans introduced, units failed, disk delta); together with
the Phase 1 snapshot these are the pre/post manifests the backlog review
trigger requires. Machine records `hngh checkpoint RUN VERIFICATION MANIFEST`;
the operator closes the run (`close-run`) after eyeballing the manifest.

### Phase 8 — Rollback / reversibility

- Package-level: pacman's package cache retains prior versions; rollback is a
  `pacman -U /var/cache/pacman/pkg/<pkg>-<oldver>.pkg.tar.zst` downgrade per
  affected package, identified by diffing pre/post manifests. (Operator
  checks cache-retention policy — e.g. `CleanMethod`/paccache retention — in
  Phase 0; if the cache is thin, snapshot first.)
- Service-level: if an allowlisted unit misbehaves after upgrade,
  `scripts/service-ctl.sh <unit> restart` is the sanctioned path (standing
  grant, decisions.md 2026-09-07); anything beyond the allowlist parks
  critical-class.
- Config-level: the config-backup lanes (30m cadence) already snapshot
  declared config lanes; restore from the pre-upgrade backup row if a
  package upgrade rewrote a tracked config.
- No daemon required: every revert path is an operator-invoked one-shot —
  matching the config-manager dependency note ("the revert path must exist
  without an untracked daemon").

## Operator supervision gate (who issues what)

| Artifact | Issuer | Where it lands |
|---|---|---|
| Declared maintenance window | Operator | Run record (Phase 0) |
| Inventory snapshot + proposal draft | Machine | Run evidence paths |
| Model review | Machine reviewer | Run review transition |
| Verdict (accept/reject/trim) | **Operator only** | Verdict file, referenced by `issue-cert` |
| Certificate | `hngh issue-cert`, bound to operator verdict | Run ledger |
| Mutation clearance | Phase 5 recheck pass | Run record; mismatch = alert row |
| The upgrade itself | **Operator's hands only** | Live host, inside the window |
| Pre/post manifests + checkpoint + close | Machine (checkpoint) + operator (close) | Run ledger |

Machine-session short-circuit: any beat that reaches for pacman/yay or a
non-allowlisted unit action parks with an alert row naming the forbidden
boundary — the same pattern the wake-mutation lane uses at its kernel-src
boundary.

## Parked-execution note

**Execution is parked as operator-supervised.** The runbook does not self-
execute and no machine session may run it. Unparking requires exactly one
operator-supervised pass through Phases 0–7; after that pass, the backlog
"System controls → governed package operations" review trigger ("one
governed upgrade executes end-to-end with pre/post manifests and rollback
evidence") can be claimed, and the stage-4 exit criterion has its witness.
This step ran no package command — the only commands executed were doc
grounding reads and the kernel test suite.

## Not established / open items

- Whether `hngh mutation-check`'s evidence-gathering covers a host-level
  (non-repo) mutation like a package upgrade, or whether the first supervised
  run binds via a record/checkpoint only — to be resolved at run time by the
  operator with the actual CLI in hand.
- AUR/foreign packages (`pacman -Qqm` count in the feed) are out of v1 scope;
  the v1 upgrade list is repo packages only.
- pacman cache retention on this host (affects Phase 8 rollback coverage) —
  operator check at Phase 0.

## Verification statement

This document exists per the plan's verification clause; no package command
was run; kernel `make test` was executed green after this doc landed (see the
step's completion record).
