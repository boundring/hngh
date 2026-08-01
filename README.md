# Hngh

> *Hosting Now, GPU Hereafter — or whatever you like; the acronym is deliberately
> open-ended.*

**A system harness for CachyOS/Arch Linux that orchestrates configuration, package
management, GPU/runtime management, and generative AI agents. Emacs-like extensibility
applied to the entire operating system.**

Hngh is a system-level agentic operating layer that takes advantage of existing
agentic coding tools (Opencode, oh-my-claudecode, oh-my-codex, Pi, Cecli, Claude
Code, Codex, Gemini-CLI) as its execution substrate. It does not reimplement agentic
harnesses — it coordinates between them, informs their behavior task-specifically,
and manages the inter-tool boundary.

## Current state (2026-07-31)

The harness runs. M0–M6.2 are done and verified: the core image boots with
eleven plugins, the event loop drives a persistent task queue through a
scheduler-ticked driver, and tasks execute on local models at $0 — text via
`:local-openai-api` (unsloth :8888) and file-writing agentic work via
`opencode run` on the free local model. Mission control (`mc`) opens a tiled
tmux session with the services dashboard, the daemon, the queue watcher, and
summonable agent panes. 888 tests green.

- **Run the daemon**: `make run` (or `hngh --once` for a single driver cycle)
- **Queue a task**: `(hngh.plugins.ai-orchestrator:submit-task "..." :policy '(:prefer-tool :local-openai-api))` — or agentic: `'(:prefer-tool :opencode)`
- **Watch everything**: `mc` (tiled tmux), or `hngh-status` for the one-glance view
- **Guide**: [`docs/guides/mission-control.md`](docs/guides/mission-control.md)
- **Session history**: [`docs/project/work-sessions.md`](docs/project/work-sessions.md) (M2–M6.2, per-model attributed)

## Core Principles

1. **Dogfooding Substrate**: The agentic tools Hngh uses at runtime are the same
   tools used to develop Hngh. The boundary between "Hngh using tools" and "Hngh
   being developed by tools" dissolves.

2. **Self-Improvement Loop**: Hngh can spawn an agentic tool session to improve its
   own code, because that's the same thing it does for users. When Hngh identifies
   a UX bottleneck, it generates a plugin or shortcut; the plugin enters the review
   pipeline; if approved, it's integrated.

## Architecture

Microkernel-style image (SBCL Common Lisp) with an event bus, a supervisor, and a
procedural-first threat detection system. Everything else is a plugin. A small,
stateless C daemon handles privileged operations via dbus. The AI never runs as root.

- **Core Image**: plugin host, event bus, state store, resource manager, scheduler,
  supervisor, procedural threat detection (7 components)
- **First-Party Plugins**: package manager, AI orchestrator, AI tool hub, model
  runtime manager, threat detector, hnghbeats, backup manager, secrets manager,
  dashboard TUI, KDE integration, knowledge base, dbus bridge, system config
  (13 components)
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
| **Emacs mission-control dashboard** (panels, commands) | [`emacs/README.md`](emacs/README.md) |

## Roadmap

- **Milestone 0 — Foundation**: ✅ Core image, end-to-end validation
- **Milestone 1 — The Harness (v0.1)**: ✅ System harness, AI orchestration (M1.0–M1.10)
- **Milestone 2 — The Dogfooding Loop** ✅ (2026-07-31): M2 local OpenAI-compatible endpoints, M3 event loop + task driver, M4 unsloth lifecycle (systemd-respecting), M5 first $0 dogfood loop, M6.1 mission control, M6.2 agentic file-editing loops
- **Milestone 3 — The Network (v0.3)**: planned — client/server daemon mode (Emacs-style headless + extensible clients), model-management plugin (selection, sourcing, benchmark harness, unsloth/llama.cpp/ollama routing), remote instance coordination, knowledge sharing

Detailed session history: [`docs/project/work-sessions.md`](docs/project/work-sessions.md). Program plan: `~/Projects/etc/sysconfig_mgmt/.omc/plans/hngh-gbd-dogfood-program.md`.

## License

AGPL-3.0-or-later. See [`LICENSE`](LICENSE).

## Contributing

Human directs and decides; AI assistants draft and implement. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).