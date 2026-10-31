# Hngh — a thin harness for the operator's own tools

Hngh is one project with two iterations. The current one (**v2**) is a
thin, operator-facing harness of CLI tools over what the operator already
runs: oh-my-pi sessions, Tern tabs, the unsloth studio, and git. CLI entry
points, ledgers, gates. No framework, no daemon.

The earlier iteration (**v1**) was a side-effect-free Common Lisp kernel
with a federal edge. It is archived, not deleted — see
[Archived v1](#archived-v1-the-lisp-kernel) below.

    v2 in one line: shepherd the tools the operator already runs; never
    replace them, never run a daemon.

## The v2 boundary

- Every tool is a **foreground command** that runs, reports, and exits.
  There is no daemon, service, provider, watcher, scheduler, agent, or
  background process, and none may be started.
- Every tool has a **`-selfcheck` sibling**. A tool without one is not
  landed. The selfcheck is the verification step — you do not re-run the
  tool by hand.
- Ledgers are **append-only JSONL**. Fold views are derived, never
  hand-edited. Exactly one writer per ledger file.
- Model pins, contexts, quotas, and paths come from **env files and
  overlay yaml**, not from hardcoded values.
- Live state lives under `~/.local/state/hngh/`: `fill/`, `route/`,
  `quotas/`, `sessions/`. Nothing under it is committed here.

## Layout

| Path | What it is |
|---|---|
| `harness/bin/` | the v2 tools (43 scripts) and their selfchecks |
| `harness/roles/` | role manifests for `hngh-agent-spawn` |
| `harness/src/` | `hngh-pointer.c`, the uinput pointer writer |
| `harness/PRINCIPLES.md` | the 11 v2 rules |
| `harness/CANON.md` | 12 principles crystallized from the pantheon classics |
| `harness/ROUTE-v0.md` | the router design and the measured fleet |
| `harness/README.md` | the harness operator guide (tool table, quickstart) |
| `AGENTS.md` | agent notes, state roots, gates, quota pacing |
| `docs/`, `src/`, `scripts/`, `automation/` | the **archived v1** generation |

`harness/` is a mirror of the canonical working tree `~/Projects/hngh`;
the tools are symlinked into `~/.local/bin/`.

## The local-first fill funnel

The funnel is the factory. A remote lane authors **structure only** — a
SPEC and the tests that define done. A **local** coder fills the file.
The tests are the judge.

    hngh-plan validate/queue  ->  hngh-fill drain  ->  filled/  ->  operator integrates

Queue root: `~/.local/state/hngh/fill/`.

    queued/<id>/SPEC.md    remote-authored spec
    queued/<id>/tests/     remote-authored definition of done
    queued/<id>/item.json  {id, test_cmd, workdir_rel}
    queued/<id>/workdir/   what the local model completes
    filled/<id>/           green; result.json + test_out.log written
    escalate/<id>/         still red after N attempts (remote review queue)
    log.jsonl              one line per transition

A green is only trusted if the guards hold:

- **shrink** — the patched file did not lose half its size (no full-file
  rewrite in disguise).
- **tests-bite** — the tests FAIL on the pre-fill state. A green the tests
  already produced proves nothing about the patch.
- **growth-stop** — a diff that doubles while the tests stay red escalates
  instead of burning the remaining attempts.
- **language lint** — the patch does not add Python to an owned shell script.
- **recount normalizer** — small coders emit correct hunks with wrong `@@`
  counts; the `@@` headers are recounted in place instead of rejecting the
  patch.
- **header-path rewrite** — diff headers pointing at the spec's repo paths
  are rewritten to the workdir basename when they match.
- **unfenced full-file mapping** — a language-labelled fence, or a bare
  full file with no fence at all, maps to the single owned file.
- **VRAM admission gate** — no load happens unless `hngh-vram-gate` admits it.

Output lands in `filled/` as a **proposal**. Integration is an explicit
act under the operator's go: copy by explicit pathspec (never `-A`), run
the target's own gate, commit. A proposal that was not integrated stays a
proposal.

## The duty-routed model fleet

`hngh-route` dispatches by duty class. The table is measured, not assumed
(2026-10-30 sweep; `harness/ROUTE-v0.md` has the full note):

| Duty | Model | Why |
|---|---|---|
| router / summarizer | `LiquidAI/LFM3-1.7B-GGUF` | 130 tok/s, best summary fidelity |
| coder | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | the measured fleet sweep found the 4 GB Q4_K_M E4B the only small model that applied diffs correctly, and names the 12 GB E4B as the fill coder |
| decider | `laya-multilingual` via the studio's `/v1/systemone` | flag-free, no manual llama-server flags |

`StartLux-Decision-v1.1-2B-Instant` Q8_0 measured **57.5 decisions/s
sustained, 100% parse** on the decider duty; the studio catalog
(laya/kev/lev/julia) stays the flag-free alternative. The queue is patient
(600 s timeout, 30 s backoff ×3) and never errors mid-queue: the call
waits or fails explicitly at the end. Provenance lands in
`results.jsonl`. Every class is overridable with
`HNGH_ROUTE_MODEL_<CLASS>`.

`hngh-fill`'s own default coder model is `gemma-4-12B-coder…`, overridable
per drain with `--model`.

## Doctrine

- `harness/PRINCIPLES.md` — the 11 v2 rules: shepherd don't replace;
  every tool has a selfcheck; ledgers are the audit trail; gates at
  operator presence; config and env over code; measure before features;
  boring shapes; small blast radius; never discard work without measuring
  it; decisions get briefs, not binaries; admission before load.
- `harness/CANON.md` — 12 principles crystallized from the operator's
  pantheon-annotated classics, each shipping with its own adversarial
  guard. (Pacing is margin, not a ceiling; verify dispatches yourself;
  calibrate the cadence of correction; timing is policy; and so on.)
- `harness/ROUTE-v0.md` — the router design, the measured fleet, and the
  decisions that are explicitly out of scope for v0.
- `AGENTS.md` — the working contract: state roots, the four authority
  tiers, VRAM rules, quota pacing.

## Operator standing rules

- **Quota pacing.** Daily allowance = remaining × 0.8 ÷ remaining days.
  Pacing the burn rate matters more than the session count. Tiered slowdown
  at 60% / 80% / 95% of a lane's window. Refresh the meter before
  trusting a number: `hngh-quota-refresh --source omp-usage`. A lane
  hitting 100% before reset is a defect, not bad luck.
- **Cadence layers.** ~5 min machine probes (liveness, watchers), hourly
  progression checks during work blocks, daily funnel cycles, weekly
  retrospective review.
- **Admission before load.** Multiple models may stay resident when they
  FIT. Every load passes the VRAM admission gate with an explicit
  context; nothing loads unless it fits. The desktop lives on the iGPU
  (display on card0), the dGPU is inference-only (card1); after every
  reboot, verify display on card0.
- **Never discard work without measuring it.** A shipped implementation
  and a proposed one are compared by behaviour on identical inputs, not by
  diff size.
- **Decisions get briefs, not binaries.** Benefits, drawbacks, cost, risk,
  and a recommendation with measurements.
- **The four authority tiers** (from `~/AGENTS.md` §11): *Silent* (never
  asks), *Confirm* (once per domain), *Presence-gated* (actuation needs an
  idle window or an explicit go), *Forbidden* (explicit approval every
  time). "May I act" and "is now a safe moment to act" are different
  questions. `hngh-act` is the only actuation writer and enforces them at
  call time.
- **GLM 5.3 Flash is the coordination lane.** The shipped role manifests
  put `zai/glm-5.3-flash` on the `task` and `scout` duties, with
  `minimax-code/MiniMax-M3.1-Flash-Preview` and `opencode-go/glm-5.3-flash`
  as its fallback chain (`harness/roles/cistern-dev.yml`).

## Quickstart

```bash
hngh-orient                       # what to read and what is open
hngh-overview                     # portfolio snapshot in one screen
bash ~/Projects/hngh/bin/hngh-fill-selfcheck   # the verification step
hngh-plan validate plan.yaml && hngh-plan queue plan.yaml
hngh-fill drain                   # local coder fills, tests judge
hngh-quota-refresh --source omp-usage
```

The full tool table and the per-tool notes live in
[`harness/README.md`](harness/README.md).

## Archived v1 (the Lisp kernel)

The v1 iteration — the Common Lisp kernel, the beads/records tree, the
automation edge, the ceremony — is history, not the current boundary. It
is preserved on the local `archive/v1` branch, and its committed history
is already in main's ancestry. Its tree (`docs/`, `src/` (Lisp),
`scripts/`, `automation/`) stays in the repo as the authoritative record of
the refactor; the rules in `AGENTS.md` for v1-era trees still apply there
but do not describe how v2 tools behave.

Two homes from the v1 era still hold: `~/.hngh/` for userspace data
(never committed) and `~/.hngh-automation/` for secrets and kernel stores.

Read `AGENTS.md` before working here; it is the current contract.
