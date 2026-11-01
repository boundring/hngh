# Hngh — a thin harness for the operator's own tools

Hngh has had two iterations. The current one, **v2**, is a set of CLI
tools wrapped around what the operator already runs: oh-my-pi sessions,
Tern tabs, the unsloth studio, git. The tools have entry points, they
keep ledgers, they stop at gates. There is no framework and no daemon.

The earlier iteration, **v1**, was a side-effect-free Common Lisp kernel
with a federal edge. It is archived, not deleted — see
[Archived v1](#archived-v1-the-lisp-kernel) below.

    v2 in one line: shepherd the tools the operator already runs; never
    replace them, never run a daemon.

## The v2 boundary

Every tool is a foreground command. It runs, it reports, it exits. There is
no daemon, no service, no provider, no watcher, no scheduler, no agent,
no background process — and a tool may not start one.

Every tool has a `-selfcheck` sibling. A tool without one is not landed.
The selfcheck is the verification step; you do not re-run the tool by
hand to check it.

Ledgers are append-only JSONL. Fold views are derived from them and are
never hand-edited. Exactly one writer per ledger file.

Model pins, contexts, quotas, and paths come from env files and overlay
yaml, not from hardcoded values.

Live state lives under `~/.local/state/hngh/`: `fill/`, `route/`,
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
| `docs/`, `src/`, `scripts/`, `automation/` | the archived v1 generation |

`harness/` mirrors the canonical working tree `~/Projects/hngh`. The tools
are symlinked into `~/.local/bin/`.

## The local-first fill funnel

The funnel is the factory. A remote lane authors structure only: a SPEC
and the tests that define done. A local coder fills the file, and the
tests are the judge.

    hngh-plan validate/queue  ->  hngh-fill drain  ->  filled/  ->  operator integrates

Queue root: `~/.local/state/hngh/fill/`.

    queued/<id>/SPEC.md    remote-authored spec
    queued/<id>/tests/     remote-authored definition of done
    queued/<id>/item.json  {id, test_cmd, workdir_rel}
    queued/<id>/workdir/   what the local model completes
    filled/<id>/           green; result.json + test_out.log written
    escalate/<id>/         still red after N attempts (remote review queue)
    log.jsonl              one line per transition

A green counts only if the checks pass.

The shrink check rejects a patched file that lost half its size, which is
a full-file rewrite wearing a disguise. The tests-bite check requires the
tests to FAIL on the pre-fill state: a green the tests already produced
proves nothing about the patch. Growth-stop escalates a diff that doubles
while the tests stay red, rather than burning the remaining attempts on
it. Language lint keeps Python out of an owned shell script. The recount
normalizer fixes small coders that emit correct hunks with wrong `@@`
counts — the `@@` headers are recounted in place instead of rejecting the
patch. Header-path rewrite turns diff headers that point at the spec's
repo paths into the workdir basename when they match. Unfenced full-file
mapping maps a language-labelled fence, or a bare full file with no fence
at all, to the single owned file. And no load happens unless
`hngh-vram-gate` admits it.

Output lands in `filled/` as a proposal. Integration is an explicit act
under the operator's go: copy by explicit pathspec (never `-A`), run the
target's own gate, commit. A proposal that was not integrated stays a
proposal.

## The duty-routed model fleet

`hngh-route` dispatches by duty class. The table is measured, not assumed
(2026-10-30 sweep; `harness/ROUTE-v0.md` has the full note):

| Duty | Model | Why |
|---|---|---|
| router / summarizer | `LiquidAI/LFM3-1.7B-GGUF` | 130 tok/s, best summary fidelity |
| coder | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | the measured fleet sweep found the 4 GB Q4_K_M E4B the only small model that applied diffs correctly, and names the 12 GB E4B as the fill coder |
| decider | `laya-multilingual` via the studio's `/v1/systemone` | flag-free, no manual llama-server flags |

The sweep also measured `StartLux-Decision-v1.1-2B-Instant` Q8_0 at **57.5
decisions/s sustained, 100% parse** on the decider duty. The studio
catalog (laya/kev/lev/julia) stays the flag-free alternative, with no
manual llama-server flags to set.

The queue is patient: 600 s timeout, 30 s backoff ×3. It never errors
mid-queue — the call waits, or fails explicitly at the end. Provenance
lands in `results.jsonl`. Every class is overridable with
`HNGH_ROUTE_MODEL_<CLASS>`.

`hngh-fill` has its own default coder model, `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF`,
and `--model` overrides it per drain.

## Doctrine

`harness/PRINCIPLES.md` holds the 11 v2 rules: shepherd don't replace;
every tool has a selfcheck; ledgers are the audit trail; gates at
operator presence; config and env over code; measure before features;
boring shapes; small blast radius; never discard work without measuring
it; decisions get briefs, not binaries; admission before load.

`harness/CANON.md` holds 12 principles crystallized from the operator's
pantheon-annotated classics, each shipping with its own adversarial
guard. A few of them: pacing is margin, not a ceiling; verify dispatches
yourself; calibrate the cadence of correction; timing is policy.

`harness/ROUTE-v0.md` holds the router design, the measured fleet, and
the decisions that are explicitly out of scope for v0.

`AGENTS.md` is the working contract: state roots, the four authority
tiers, VRAM rules, quota pacing.

## Operator standing rules

Daily allowance = remaining × 0.8 ÷ remaining days. Pacing the burn rate
matters more than the session count. A lane slows down at 60% / 80% / 95%
of its window. Refresh the meter before trusting a number:
`hngh-quota-refresh --source omp-usage`. A lane hitting 100% before reset is
a defect, not bad luck.

Cadence layers: ~5 min machine probes (liveness, watchers), hourly
progression checks during work blocks, daily funnel cycles, weekly
retrospective review.

Multiple models may stay resident when they FIT. Every load passes the
VRAM admission gate with an explicit context, and nothing loads unless it
fits. The desktop lives on the iGPU (display on card0); the dGPU is
inference-only (card1). After every reboot, verify display on card0.

Never discard work without measuring it. A shipped implementation and a
proposed one are compared by behaviour on identical inputs, not by diff
size.

Decisions get briefs, not binaries: benefits, drawbacks, cost, risk, and
a recommendation with measurements.

The four authority tiers come from `~/AGENTS.md` §11. *Silent* never
asks. *Confirm* asks once per domain. *Presence-gated* needs an idle
window or an explicit go before actuating. *Forbidden* needs explicit
approval every time. "May I act" and "is now a safe moment to act" are
different questions, and `hngh-act` is the only actuation writer; it
enforces the tiers at call time.

GLM 5.3 Flash is the coordination lane. The shipped role manifests put
`zai/glm-5.3-flash` on the `task` and `scout` duties, with
`minimax-code/MiniMax-M3.1-Flash-Preview` and `opencode-go/glm-5.3-flash`
as its fallback chain (`harness/roles/cistern-dev.yml`).

## Quickstart

Orientation first, then the fill selfcheck, then the queue and the drain,
then the quota meter:

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
is already in main's ancestry.

Its tree (`docs/`, `src/` (Lisp), `scripts/`, `automation/`) stays in the
repo as the authoritative record of the refactor. The rules in `AGENTS.md`
for v1-era trees still apply there, but they do not describe how v2 tools
behave.

Two homes from the v1 era still hold: `~/.hngh/` for userspace data
(never committed) and `~/.hngh-automation/` for secrets and kernel stores.

Read `AGENTS.md` before working here; it is the current contract.
