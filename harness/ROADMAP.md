# hngh v2: current state and roadmap

Every number below came from a command run against this repo, a live state root, or a
figure the repo already records.

## Where v2 stands today

The harness is a set of foreground CLI tools over sessions, Tern tabs, the unsloth
studio and git.

Every tool runs, reports and exits.

| Measure | Count |
|---|---|
| entries in `harness/bin/` | 86 |
| tool scripts in `harness/bin/` | 43 |
| `-selfcheck` siblings in `harness/bin/` | 43 |
| tools, counting `hngh-pointer` | 44 |
| tools with no selfcheck at all | 0 |

`hngh-pointer` is not in `harness/bin/`. The Makefile builds it from
`harness/src/hngh-pointer.c`, so the tool count is 44 and the script count stays 43.
`hngh-route` carries its own as the `hngh-route selfcheck` subcommand.
Coverage is 44 of 44 tools: 42 script siblings, the route subcommand and
`hngh-pointer-selfcheck`. The four that had none until 2026-11-01 are
`hngh-look-laneprobe`, `hngh-watch-agents`, `hngh-watch-ledger` and
`hngh-watch-slot`.

`hngh-route` is 391 lines of bash and curl. It dispatches by duty class against the
studio on 127.0.0.1:8888, and the duty table came from a fleet sweep on 2026-10-30.

| Duty | Model | Measured note |
|---|---|---|
| router / dispatcher + summarizer | `LiquidAI/LFM3-1.7B-GGUF` | 130 tok/s, 131k ctx |
| coder | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | the 12 GB E4B, the fill coder |
| decider | `laya-multilingual` | via the studio's `/v1/systemone` |

`StartLux-Decision-v1.1-2B-Instant` Q8_0 is the measured local alternative for the
decider duty, MEASURED PASS on the 2026-10-30 sweep: 57.5 decisions/s sustained, 100%
parse, 8/10 state-reaction, order-invariant.

| Fill state | Items |
|---|---|
| `~/.local/state/hngh/fill/queued/` | 0 |
| `~/.local/state/hngh/fill/filled/` | 7 |
| `~/.local/state/hngh/fill/escalate/` | 0 |
| `~/.local/state/hngh/fill/superseded/` | 9 |
| `~/.local/state/hngh/fill/log.jsonl` | 99 lines |

The seven filled items are `demo-json-001`, `demo-json-002`,
`manga-artwave-fingerprint`, `v3-core-walk-math`, `v3-render-camera`,
`v3-render-inspector` and `v3-render-voxel-models`. The 2026-10-31 differential review
kept the shipped code: `src/core/walk.ts` and `src/render/inspector.ts` beat their
local-model fills, `src/render/camera.ts` came out at parity, and the fills stay as
evidence.

The default fill coder is `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF`. The escalation
coder, used after the default coder fails twice, is
`unsloth/Qwen-AgentWorld-35B-A3B-GGUF`: 12,251,290,880 B of weights, context 98304, a
30000 token completion budget, priced at 14.75 GB against a 19.98 GiB card.

Eight guards decide whether a green counts: shrink check, tests-bite check, growth-stop,
language lint, recount normalizer, header-path rewrite, unfenced full-file mapping, and
`hngh-vram-gate` admission.

`HNGH_VRAM_BUDGET` defaults to 17,000,000,000 and `HNGH_FILL_CTX` defaults to 32768,
with `hngh-vram-gate` as the admission point. The dGPU card1 reports 21,458,059,264
bytes in total.

Quota is paced. The daily allowance is remaining × 0.8 ÷ remaining days, and a lane
slows at 60% / 80% / 95% of its window. `hngh-quota-refresh --source omp-usage`
refreshes the meter. The zai weekly lane carried 50,146/60,000 = 83.58% when the meter
was repaired, as `CHANGELOG.md` records. The 2026-11-01T20:26:01Z reading shows zai:1w
4/60,000, zai:5h 4/12000, minimax-code:5h 35/100 and minimax-code:7d 15/100.

## What the next stretch of work is

Three stretches first, then the exclusions. The selfcheck stretch landed on
2026-11-01 and is recorded above.

### The cistern-web v3 economy slice set

The slice set is six items wide: `v3-core-town-state`, `v3-core-town-map`,
`v3-core-job-executor`, `v3-core-townsfolk-needs`, `v3-core-shop-stock` and
`v3-game-actions`. The SPEC set landed on 2026-11-01 in
`/home/bricker/Work/sessions/2026-11-01-cistern-economy-spec/`, against the frozen port
contract and the donor simulation sources. `hngh-plan` refuses an item that does not
declare the existing file state, and `hngh-plan validate plan.yaml` prints `OK` for all
six and exits 0.

What is left is the fill. The local coder runs the six items, and integration copies by
explicit pathspec and runs the repo's own gate, `npm test`. Every suite is proven RED
against the workdir content the harness stages — the shipped port file for the three
`modify` items, an empty placeholder for the three `add` items — so a green means the
fill landed and not that the test was written to pass.

One constraint shapes the fill: the harness imports the model's `.ts` file directly and
Node v26.8.2 strips types natively, so the file the coder writes must be erasable. The
shipped `src/core/sim.ts:51` uses a parameter property, which strip-only mode rejects
(`SyntaxError [ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX]`), and the `v3-core-town-state` SPEC
names the rewrite the fill has to make. `src/core/town.ts` and `src/core/townsfolk.ts`
are clean.

Measured dependency: `npm test` builds with `tsc` and runs `node --test tests/` over 12
test files, and `src/core` holds 11 TypeScript modules. The charter at
`/home/bricker/Work/sessions/2026-11-01-cistern-economy-spec/CHARTER.md` fixes the
deliverable set and the stop condition.

### Manga ch-05 and the methods charter

ch-05 does not exist yet. `works/rainholder/arcs/arc-01/chapters/` holds ch-01, ch-02,
ch-02a, ch-02b, ch-03 and ch-04, and ch-02 carries no art-order file. Art orders are
authored upstream in `art-orders/art-orders.json`, with the count kept in the file: 27
for ch-01, 26 for ch-02a, 27 for ch-02b, 26 for ch-03, 24 for ch-04.

Rendering sits downstream. `manga_render_trigger.sh` scans
`works/*/arcs/*/chapters/*/art-orders/art-orders.json`, renders a batch through
`tools/art_wave.py`, ingests the PNGs with `hngh-artifact ingest --domain manga`, and
writes `report.generated.md`. A wave whose fingerprint `meta.batch_sha256_16` still
matches the orders is already rendered. Five waves exist today.

Done looks like this: ch-05 has its art orders authored upstream, the trigger renders
and ingests that batch, and the store addresses land in the wave report.

The methods charter at
`/home/bricker/Projects/omp-work/PLANS/2026-10-29-manga-methods-pantheon.md` is still
PROPOSED, so it needs the operator's go, then one design slot and one pipeline slot. Its
build order runs five slices and registers three gates, G-C1 profiles, G-C2
relationships and G-C3 legibility.

Measured dependency: the art-order schema `cistern.manga.art-orders/1` and the trigger's
fingerprint rule, which decides whether a batch needs a render.

### Router v1 candidates, waiting for queue data

The data does not exist yet. `harness/ROUTE-v0.md` names three v1 candidates: class
weights, load-balancing between two residents of the same class, and an admission rule
tied to the quota-pacing doctrine. All three wait for a week of queue data.

Measured dependency: `~/.local/state/hngh/route/queue.jsonl` holds 0 rows and
`results.jsonl` holds 1, a single router dispatch at 13 s.

Done looks like this: a week of queue rows carrying class, model and outcome, then one
candidate designed against those rows, landed with its own selfcheck and a changelog
note.

### Excluded from this stretch

No daemon, no priority preemption, no GPU partitioning, no vision routing, no
remote-lane routing. The reasons follow in the next section.

## What is deliberately not planned

Five reasons, one per exclusion.

No daemon. The v2 boundary in `AGENTS.md` forbids the service, provider, watcher,
scheduler, agent and background process a daemon would need.

No priority preemption. A dispatch waits 600 s, backs off 30 s three times over, then
fails as `failed:busy`. The route queue holds 0 rows today.

No GPU partitioning. The dGPU is inference-only and the desktop lives on the iGPU, so
the card is not shared. `hngh-vram-gate` already refuses a load that will not fit.

No vision routing. It is unmeasured. `hngh-look-laneprobe` probes the cloud vision lanes
with a synthetic PNG, which is a probe rather than a routing rule.

No remote-lane routing. Daily lane sessions are manual and sit inside the daily quota
allowance, with the weekly review as the retrospective layer.

## Where the rules live

- `harness/PRINCIPLES.md` holds the 11 v2 rules.
- `harness/CANON.md` holds the 12 principles, each with its adversarial guard.
- The router design and the measured fleet live in `harness/ROUTE-v0.md`.
- `AGENTS.md` is the operator contract.
