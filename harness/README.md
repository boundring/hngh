# The hngh harness — operator guide

`harness/` is the current iteration of hngh: CLI tools layered over what the
operator already runs — oh-my-pi sessions, Tern tabs, the unsloth studio,
git. Each tool is a foreground command. It runs, it reports, it exits.
**No daemon, and none may be started.**

This guide is the operational view: the tool inventory, the state roots, the
gates, the fill funnel, the routing fleet, and a quickstart. The doctrine
lives next door. `PRINCIPLES.md` holds 11 rules. `CANON.md` holds 12
principles, each with its adversarial guard. `ROUTE-v0.md` holds the router
design and the measured fleet. `ROADMAP.md` holds where v2 stands and what
comes next. The working contract is `../AGENTS.md`.

## Quickstart

```bash
# 1. Orient: what to read, what is open, what is blocked.
hngh-orient

# 2. See the whole portfolio in one screen.
hngh-overview

# 3. List the tools.
ls ~/Projects/hngh/bin

# 4. Verify a tool (the house verification step — not a manual re-run).
bash ~/Projects/hngh/bin/hngh-fill-selfcheck

# 5. Submit and drain a fill item.
hngh-plan validate plan.yaml     # OK/REFUSED per session
hngh-plan queue plan.yaml        # materialize queued/<id>/
hngh-fill drain                  # local coder fills; the tests judge
hngh-fill status                 # one line per item

# 6. Refresh the quota meter before trusting a number.
hngh-quota-refresh --source omp-usage
hngh-quota
```

`harness/bin/` mirrors the canonical working tree at `~/Projects/hngh`. The
tools are symlinked into `~/.local/bin/`.

## Tool inventory

`harness/bin/` holds 43 scripts, plus `hngh-pointer`, which the harness
`Makefile` builds from `harness/src/hngh-pointer.c`. Where a `-selfcheck`
sibling exists, it is the verification for that tool.

| Tool | Purpose |
|---|---|
| `hngh-orient` | Context assembler: briefs to read first, latest handoff, open gates, active sessions |
| `hngh-overview` | One-command portfolio snapshot (quota ledger, digest, job registry, posture) |
| `hngh-agents` | Read-only enumeration of live/recent omp agent transcripts |
| `hngh-agent-spawn` | Spawns a role-primed omp slot from a `roles/*.yml` manifest; registers it at spawn time |
| `hngh-sessions` | Read-only fold of the session ledger (`sessions/feed.jsonl`) |
| `hngh-session-note` | Appends one milestone to the session ledger (the audit trail writer) |
| `hngh-digest` | Read-only fold of the digest ledger, latest record per key |
| `hngh-digest-note` | Appends one digest record to the digest ledger |
| `hngh-digest-refresh` | Folds the harness CLIs' `--json` output into one digest record |
| `hngh-digest-rollup` | Folds the digest ledger by day (first/last record and the deltas) |
| `hngh-digest-moved` | "What moved in words": per-day movement plus session events |
| `hngh-job` | Read-only fold of the job registry |
| `hngh-job-note` | Appends a job event (`started` / `gate` / `outcome`) |
| `hngh-quota` | Read-only fold of the quota ledger |
| `hngh-quota-note` | Appends one quota reading to the quota ledger |
| `hngh-quota-refresh` | Reads a service's live quota and appends it (browser relay for xiaomi, `omp usage` for the rest) |
| `hngh-status` | Consolidated status writer; folds sessions, agents, dashboard feed, posture into `status.json` |
| `hngh-state` | State store (Silent tier, writes only its own flags); also generates Hyprland-requireable Lua modules |
| `hngh-sense` | Sensor bus: one total-function posture blob, every source capped, failures degrade to null |
| `hngh-plan` | PLAN stage: validate / queue / status a `plan.yaml` against the local-safe contract |
| `hngh-fill` | Local-fill runner: drains queued items, applies the patch, runs the tests |
| `hngh-route` | Duty-routed dispatcher for the studio-hosted models (submit / drain / status / loaded-models) |
| `hngh-vram-gate` | Hard VRAM admission gate for local model loads (exit 0 = may load, 1 = refuse) |
| `hngh-act` | Actuation broker — the only writer besides `hngh-state`'s own flags; enforces the authority tiers at call time |
| `hngh-cu` | Human/agent-facing computer-use entry point; plans and delegates to `hngh-act` |
| `hngh-grim` | Screen-capture producer (the sanctioned entry is `hngh-act screen.capture`) |
| `hngh-look` | Grounding reader for a screenshot PNG (lanes: local / ocr / cloud) |
| `hngh-look-laneprobe` | Probes the cloud vision lanes with a synthetic PNG and records the result |
| `hngh-artifact` | Writer for the content-addressed artifact store (sha256 + per-domain index) |
| `hngh-corpus` | Transcript → Q/A training-data builder with secret screening at write time |
| `hngh-pointer` | uinput pointer writer (C; built by the harness `Makefile`) — one op per process, `--dry-run` never opens a device |
| `hngh-dashboard` | Renders dashboard feeds, newest first |
| `hngh-dashboard-feed` | Appends one item to a dashboard namespace feed |
| `hngh-tui` | Operator cockpit (posture strip, agents, file changes, live stream, ledger Gantt) |
| `hngh-hud` | Game-style operations HUD terminal view, redrawn on an interval |
| `hngh-cockpit` | Toggles the dashboard tab in the Tern window (focus-and-raise, else recreate) |
| `hngh-observe` | Opens the observation tabs (agents, slot transcript, ledger) in the Tern window |
| `hngh-tail` | Live, syntax-highlighted stream of agent session transcripts |
| `hngh-tern-capture` | Reads a Tern pane's text (read-only observation lane) |
| `hngh-watch-agents` | Live agent overview (wraps `hngh-agents --follow`) |
| `hngh-watch-ledger` | Live milestone ledger plus the sessions dashboard feed |
| `hngh-watch-slot` | Live view of the most recently active slot transcript |
| `omp-session-index` | Persistent index of omp agent transcripts (SQLite) |
| `systemone-research` | Eval-matrix runner for local decision models against the studio |

39 of the 44 have a `-selfcheck` sibling in `harness/bin/`. `hngh-route`
carries its selfcheck as the `hngh-route selfcheck` subcommand. The tools
without one: the three `hngh-watch-*` wrappers and `hngh-look-laneprobe`.

## State roots

Live state is under `~/.local/state/hngh/`:

| Root | Holds |
|---|---|
| `fill/` | the fill funnel: `queued/`, `filled/`, `escalate/`, `superseded/`, `log.jsonl` |
| `route/` | the `hngh-route` queue and results |
| `quotas/` | quota ledger rows and pause markers |
| `sessions/` | the session feed |

Ledgers are append-only JSONL. Fold views are derived; nobody hand-edits one.
One writer per ledger file. Two writers produce split-brain diagnostics, not
a merge.

## The fill funnel

The factory. A remote lane authors structure only: the SPEC, plus the tests
that define done. A local coder fills the file. The tests are the judge.

    hngh-plan validate -> hngh-plan queue -> hngh-fill drain
      -> filled/<id>/ (proposal)  |  escalate/<id>/ (remote review)

Queue root: `~/.local/state/hngh/fill/`.

    queued/<id>/SPEC.md    remote-authored spec
    queued/<id>/tests/     remote-authored definition of done
    queued/<id>/item.json  {id, test_cmd, workdir_rel}
    queued/<id>/workdir/   what the local model completes
    filled/<id>/           green; result.json + test_out.log written
    escalate/<id>/         still red after the attempt cap (2 by default)
    log.jsonl              one line per transition

`hngh-plan` is deterministic. No model is contacted. Nothing is pushed. No
path outside the queue root and the plan's own files is written. Existing
items are never deleted. An item owns exactly one source file, except a
`pure_function` item, which may own none. A `modify` item must name its
callers and a regression.

### Guards

A green is only trusted if all of these hold:

- shrink — the patched file did not lose half its size. A green whose filled
  file shrank below half the original is a full-file rewrite, not a patch.
  Measured 2026-10-30: LFM2.5/QAT replaced a 491-line engine with toys and
  the tests still went green.
- tests-bite — the tests must FAIL on the pre-fill state. A green the tests
  already produced proves nothing about the patch.
- growth-stop — a diff that doubles while the tests stay red escalates
  instead of burning the remaining attempts.
- language lint — a patch that adds Python markers to an owned shell script
  is rejected before it is applied.
- recount normalizer — small coders write correct hunks with wrong `@@`
  counts. The headers are recounted in place instead of rejecting the patch.
  Measured 2026-10-30, Nemotron E4B.
- header-path rewrite — diff headers pointing at the spec's repo paths are
  rewritten to the workdir basename when it matches, so the patch applies.
- unfenced full-file mapping — a language-labelled fence (```` ```python ````)
  or a bare full file with no fence at all maps to the single owned file.
- VRAM admission gate — the load is admitted by `hngh-vram-gate` before the
  attempt. The guard covers the attempt, not just the explicit load POST.

### Proposals, not edits

Fill output is a proposal. Integration is explicit, and it needs the
operator's go: copy into the target repo by **explicit pathspec** (never
`-A`, never a bare `git commit`), run the target's own gate, commit. Pushes
need the go too. A proposal the operator has not integrated stays a
proposal. Do not "helpfully" apply it.

## The routed fleet

`hngh-route` dispatches by duty class against the studio
(`http://127.0.0.1:8888`). Duty table measured 2026-10-30; override with
`HNGH_ROUTE_MODEL_<CLASS>`.

| Duty | Default | Note |
|---|---|---|
| router / summarizer | `LiquidAI/LFM3-1.7B-GGUF` | 130 tok/s, best summary fidelity, 131k ctx ceiling |
| coder | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | the 4 GB Q4_K_M E4B was the only small model that applied diffs correctly |
| decider | `laya-multilingual` (studio `/v1/systemone`) | flag-free; kev-4b and julia-1 are the alternates |

`StartLux-Decision-v1.1-2B-Instant` Q8_0 measured 57.5 decisions/s
sustained, 100% parse on the decider duty. The vendor package
(`startlux-decide`) is mandatory for those GGUFs. Plain chat does not
produce decisions from them. The studio catalog (laya/kev/lev/julia) needs
no manual llama-server flags. Weights are CC-BY-NC, fine for internal duty
and not servable in a paid offering.

Queue semantics: patient. 600 s timeout, 30 s backoff ×3 on busy or
unreachable, then `failed:busy`. The caller's request never errors
mid-queue. It waits, or it fails explicitly at the end. Provenance lands in
`results.jsonl` (`{id, model, latency_s, status}`).

Not in v0, on purpose: no daemon, no priority preemption, no GPU
partitioning, no vision routing (unmeasured), no remote-lane routing.

## Gates

Actions are tiered (`~/AGENTS.md` §11). `hngh-act` enforces the tier at
call time from the manifest, and logs every refusal.

| Tier | Consent | Examples |
|---|---|---|
| Silent | never asks | read-only state probes; dry-runs |
| Confirm | once per domain | default handlers, editing an instruction file, enabling a service |
| Presence-gated | observe-only while the operator is at the machine; actuation needs an idle window or an explicit go | anything that steals focus, moves the pointer, or types |
| Forbidden | explicit per-action approval, every time | deletion, `pacman`, `/usr/share/**`, secrets, the 2TB drive |

"May I act" and "is now a safe moment to act" are different questions.
Default posture: everything Confirm+ is dry-run unless its gate passes.

### VRAM

- Every load carries an **explicit** `max_seq_length`, never an
  auto-derived one (`max_seq_length_auto_derived=false`). Auto-fit
  contexts have twice killed this desktop.
- `hngh-vram-gate` admits a load only when current residency + the
  studio's estimate stays at or below the budget (17 GB default,
  `HNGH_VRAM_BUDGET`). It is wired into `hngh-fill`'s preload and
  `hngh-route`'s dispatch.
- The desktop lives on the iGPU (display on card0); the dGPU is
  inference-only (card1). After every reboot, verify display on card0.
- Qwen3.8-27B is banned on this machine — it hangs the GPU.

## Quota pacing

- Daily allowance = **remaining × 0.8 ÷ remaining days**. The burn rate is
  what matters, not the session count.
- Tiered slowdown at **60% / 80% / 95%** of a lane's window.
- Refresh the meter before trusting a number:
  `hngh-quota-refresh --source omp-usage`. A stale row reads as false
  headroom.
- Analysis tasks are budgeted. An unbounded analysis is a quota leak.

Cadence: ~5 min machine probes, hourly progression checks during work
blocks, daily funnel cycles, weekly retrospective review.

## Roles

`harness/roles/*.yml` describes a slot for `hngh-agent-spawn`. The manifest
carries the model per duty class (`task`, `reviewer`, `scout`, `librarian`),
the fallback chain per model, the project lines the slot touches, its
`consent_ceiling`, the directories it may add, the
briefs/handoffs/plans/kb to prime, and the paths it owns.

Shipped manifests: `cistern-dev.yml`, `manga-dev.yml`, `webgame-dev.yml`,
`smoke-probe.yml`.

The `consent_ceiling` names the authority tier the slot acts under. It is
passed to the job registry (`--tier`) and stated in the slot's brief.
Human gates are presented to the operator; the slot never self-authorizes.

## House rules

- Every tool has a `-selfcheck` sibling. A tool without one is not landed.
  Run the selfcheck as the verification step.
- Config and env over code. Model pins, contexts, quotas and paths come from
  env files and overlay yaml. The seams are `HNGH_FILL_DIR`,
  `HNGH_ROUTE_DIR`, `HNGH_QUOTAS_DIR`, `HNGH_SESSIONS_DIR`,
  `HNGH_JOBS_DIR`, `HNGH_DIGESTS_DIR`, `HNGH_ARTIFACTS_DIR`,
  `HNGH_VRAM_BUDGET` and friends.
- Credential values are read from the house env files
  (`~/.config/environment.d/70-unsloth.conf`) and **never printed**.
- Small blast radius. A hngh bug may never take the desktop or live sessions
  down.
- `harness/Makefile` builds the one C tool. `make` builds `bin/hngh-pointer`.
  `make check` builds, then runs the pointer selfcheck — it never opens
  `/dev/uinput`. `make install` symlinks into `~/.local/bin/`. `make clean`.
