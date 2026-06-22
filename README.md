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

## Roadmap

- **Milestone 0 — Foundation**: Core image skeleton, end-to-end validation
- **Milestone 1 — The Harness (v0.1)**: Full system harness with AI orchestration
- **Milestone 2 — The Companion (v0.2)**: Graphical buddies, passive observation, cost optimization
- **Milestone 3 — The Network (v0.3)**: Remote instance coordination, knowledge sharing

See [`docs/project/roadmap.md`](docs/project/roadmap.md) for details.

## License

AGPL-3.0-or-later. See [`LICENSE`](LICENSE).

## Contributing

Human directs and decides; AI assistants draft and implement. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).