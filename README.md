# Hngh!

> *Hngh Network. Goes Hngh.*
Alternative meanings:
- Hngh Never Goes Hngh.
- Hngh Needs to Grow Hngh.
- Hngh Network Gathers Hngh.
- Hngh Network Grows Hngh.

**A system harness for CachyOS/Arch Linux that orchestrates configuration, package
management, GPU/runtime management, and generative AI agents. Emacs-like extensibility
applied to the entire operating system.**

Hngh is a system-level agentic operating layer that drives existing agentic tools as its
execution substrate. Today that means **Hermes Agent** (the attendant session in which
Hngh's own development happens) and **Opencode** (the primary agentic CLI), with the
oh-my-* orchestration wrappers layered on Opencode-side tools. Pi, Cecli, Agent-Zero and
any ACP-compatible agents are targeted for integration via plugin.

Hngh coordinates and orchestrates agentic harnesses, meta-automating the kinds of
optimizing and streamlining and manual prompt-writing and manual agent-steering and
correction cycles users find themselves falling into. Eventually, Hngh may help alleviate
any variety of repetitive delays a user may face in software in general, freeing up the time
and effort they find themselves putting into typing and clicking for activities and purposes
that are not artistic, not journaling, not personal communications. Perhaps important typing,
sometimes, and important mouse-clicking, but not anything that respectable people would
bother with if it were simply automated out of their way.

Agentic software like Hermes or Opencode, they're truly incredible and amazing tools,
things that most folks could put to any number of uses and purposes in their lives,
supporting their livelihoods and hobbies and interests and capabilities in an ever-expanding
field. In the modern era, these tools and the kinds of things people can get done with them,
this is a frontier that most normal folks are not at all prepared for, with complex requirements
for any of the working parts. What can you do for those folks? Help them automate whatever
they want. Give them arms and legs and boats and cars, self-improving ones, structures to use
as seeds for their own purposes.

## Current state (2026-08-09)

> **Pre-alpha — half-working, under active continual development.** hngh is
> built partly by automated low-resource "night-ralphing" loops that notice,
> log, and address repository interactions (stars, forks, PRs) and plan
> countermeasures against malicious external data (context hijacking, secret
> exfiltration, malware dependency suggestions). Expect rough edges.

The harness runs. M0–M6.3 + M-sentry (procedural safeguards: secret-guard,
context-watch) + MC-2 (six-panel emacs dashboard) + the M7 client-server
daemon (Emacs-style headless core + clients over a Unix socket, systemd
units) are done and verified. A $0 overnight local-model loop
(night-run/night-ralph) does slow planning, docs, and training-set generation
on local models.

M9 squad autonomy is well into its build-out. Wave 1–4 shipped: AGENTS.md
discovery/merge, questionnaire-from-AGENTS.md, resource-gate preflight, the
W5 prompt matrix (`generate-prompt`, 36 skeletons, bone/flesh pass,
D-040 model selection, prompt cache), and the wave 2–4 plugins (file-watcher,
squad-dispatch, beans, squad-resources) wired into the daemon. Free-tier model
routing was refreshed against live OpenRouter catalog IDs, with a benchmark-
sourcing design brief + a working probe runner. Wave C shipped the safety
layer: hashed action log (card 94), bwrap sandbox (card 96), native tool
scoping (card 97), the `:operation` human gate (card 99), and the ACP
pipe-flake fix (card 100).

The **ACP layer** ships (A1–A4): Hngh drives or serves any ACP-capable agent
(client over newline-framed JSON-RPC, dispatch driver, scored steering,
server). On top of that, the **L2/L3 auto-steering brain** is built (steps 1–5):
8 Tier-0 procedural situation detectors feeding an L3 scorer with a
recovery-stage tracker and progressive gate-lowering, mapped to the A3
actuator, the Tier-1 semantic judge (cheap/local model, pluggable
backend, watchdog budget, offline calibration before live use), and the
persistent case-base/review loop. Full design:
`docs/design/situation-scoring.md`. Step 6 (cross-agent normalization)
remains.

**956/956 fast tests green** (`make test`, FiveAM). Current sessions:
`docs/project/work-sessions.md`.
Changelog at `CHANGELOG.md`. Detailed roadmap at `docs/project/roadmap.md`.

- **Run the daemon**: `make run` (or `hngh --once` for a single driver cycle)
- **Queue a task**: `(hngh.plugins.ai-orchestrator:submit-task "..." :policy '(:prefer-tool :local-openai-api))` — or agentic: `'(:prefer-tool :opencode)`
- **Watch agent sessions**: tmux (seats run as normal Hermes sessions; the mission-control dashboard is under active design — card 102)
- **Probe local models**: `scripts/fetch-model-benchmarks.sh` (catalog + leaderboards) and the probe suite in `data/model-probes.lisp` (`run-probe-suite`, `write-benchmark-snapshot`)
- **Guide**: [`docs/guides/mission-control.md`](docs/guides/mission-control.md)
- **Session history**: [`docs/project/work-sessions.md`](docs/project/work-sessions.md) (M2–M7/M9, per-model attributed)

## Core Principles

1. **Dogfooding Substrate**: The agentic tools Hngh uses at runtime are the same
   tools used to develop Hngh. The boundary between "Hngh using tools" and "Hngh
   being developed by tools" dissolves.

2. **Self-Improvement Loop**: Hngh can spawn agentic sessions to improve its
   own code, because that's the same thing it does for users. When Hngh identifies
   a UX bottleneck, it generates a plugin or shortcut; the plugin enters the review
   pipeline; if approved, it's integrated.

## Architecture

Microkernel-style image (SBCL Common Lisp) with an event bus, a supervisor, and a
procedural-first threat detection system. Everything else is a plugin. A small,
stateless C daemon handles privileged operations via dbus. The AI never runs as root.

- **Core Image**: plugin host, event bus, state store, resource manager, scheduler,
  supervisor, procedural threat detection (13 components total)
- **First-Party Plugins**: package manager, AI orchestrator, AI tool hub, model
  runtime manager, threat detector, hnghbeats, sentry, backup manager, secrets
  manager, dashboard TUI, KDE integration, knowledge base, dbus bridge, system
  config, mission control, emacs daemon, maintenance coordinator, config watcher,
  file watcher, fragment journal, agents-md, squad resources, squad dispatch,
  beans, hngh-up (24 components)
- **External Process**: system daemon (C, root, stateless, ~500 LoC)

See [`docs/design/hngh-design-spec.md`](docs/design/hngh-design-spec.md) for the
complete design specification.

## Documentation

| What you need | Where to look |
|---|---|
| **Design specification** (source of truth) | [`docs/design/hngh-design-spec.md`](docs/design/hngh-design-spec.md) |
| **Architecture decisions** (11 locked ADRs) | [`docs/design/architecture-decision-record.md`](docs/design/architecture-decision-record.md) |
| **Component catalog** (21 components) | [`docs/design/components.md`](docs/design/components.md) |
| **Integration & data flows** (8 sequence diagrams) | [`docs/design/integrations.md`](docs/design/integrations.md) |
| **Roadmap & milestones** | [`docs/project/roadmap.md`](docs/project/roadmap.md) |
| **Work session plan** | [`docs/project/work-sessions.md`](docs/project/work-sessions.md) |
| **Changelog** | [`CHANGELOG.md`](CHANGELOG.md) |
| **Auto-steering (L2/L3)** | [`docs/design/situation-scoring.md`](docs/design/situation-scoring.md) |
| **Public vetting (pre-public)** | [`docs/design/public-vetting.md`](docs/design/public-vetting.md) |
| **ACP — agent client protocol** | [`docs/design/agent-client-protocol.md`](docs/design/agent-client-protocol.md) |
| **Emacs mission-control dashboard** (panels, commands) | [`emacs/README.md`](emacs/README.md) |

## Roadmap

- **Milestone 0 — Foundation**: ✅ Core image, end-to-end validation
- **Milestone 1 — The Harness (v0.1)**: ✅ System harness, AI orchestration (M1.0–M1.10)
- **Milestone 2 — The Dogfooding Loop** ✅ (2026-07-31): M2 local OpenAI-compatible endpoints, M3 event loop + task driver, M4 unsloth lifecycle (systemd-respecting), M5 first $0 dogfood loop, M6.1 mission control, M6.2 agentic file-editing loops
- **Milestone 7 — The Companion (v0.2)**: ✅ Session lifecycle, window management, config watcher, cascading restart, TUI QoL
- **Milestone 8 — Model Routing** ✅ (2026-08-05): model-pareto, cost routing, fallback chains synced with the D-040 model mandate
- **Milestone 9 — Squad Autonomy** 🔄 in progress: recursive planner cycle, squad dispatch/work queue, prompt matrix (36 skeletons, bones/flesh), AGENTS.md discovery, resource-gated preflight, PM-first-prompt generator, benchmark sourcing + probe runner; **ACP layer (A1–A4) + L2/L3 auto-steering (Tier-0 detectors + L3 scorer + semantic judge + persistent case-base) shipped**; Wave C safety layer landed (hash-chained log, bwrap sandbox, native scoping, `:operation` human gate); C4 start-now/pause-on-cause, C6 planner emit-cron, C8/C9 benchmark loop, and L2/L3 step 6 (cross-agent normalization) design-only or unstarted
- **Milestone 3 — The Network (v0.3)**: planned — client/server daemon mode (Emacs-style headless + extensible clients), model-management plugin (selection, sourcing, benchmark harness, unsloth/llama.cpp/ollama routing), remote instance coordination, knowledge sharing

Detailed session history: [`docs/project/work-sessions.md`](docs/project/work-sessions.md). Program plan: `~/Projects/etc/sysconfig_mgmt/.omc/plans/hngh-gbd-dogfood-program.md`.

## License

AGPL-3.0-or-later. See [`LICENSE`](LICENSE).

## Contributing

Human directs and decides; AI assistants draft and implement. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).
