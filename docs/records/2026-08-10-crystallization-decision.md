# 2026-08-10 — crystallization decision

Scope: choose Hngh's next architecture direction without authorizing an unbounded rewrite, storage-engine migration, retention policy invention, or a bypass of the current delivery sequence.

## Decision

The operator accepted **Option B: profiled image with internal modes and narrow adapters**.

Hngh will evolve from one serial all-feature image into a compact kernel composed from explicit in-repository modes. Profiles select modes before boot. First-party implementation is governed by the mode registry, not dynamic plugin discovery. ACP, MCP, Hermes/OpenCode, local runtimes, systemd/dbus, and Emacs remain bounded adapters. An adapter translates an external protocol; it does not own work policy, record authority, or an independent lifecycle.

## Evidence

- `hngh.asd` currently loads the entire image serially, including 15 core files and 36 first-party plugin files.
- `src/core/main.lisp` directly initializes roughly 30 components, so the existing plugin host is not the actual boot authority.
- The initial state tree eagerly creates 21 directories and spreads durable, runtime, journal, lock, transcript, and component state across many paths.
- The accepted implementation plan is `.hermes/plans/2026-08-10_232312-hngh-crystallization.md`.
- The operator selected Option B in the 2026-08-10 session.

## Consequences

1. The target product contract is a small kernel, explicit `work`, `agents`, `machine`, and `observe` modes, and validated `minimal`, `operator`, `agent-control`, `maintenance`, and `observer` profiles.
2. The current `plugin-host` cannot remain a second internal boot authority. Its final disposition is constrained external-adapter loading or removal from the boot path, proved by fixtures.
3. No mode, watcher, provider route, daemon, or system adapter may start merely because its source was loaded.
4. Source moves follow contract and ASDF-closure tests. Directory renames alone are not a success metric.
5. Card 127 remains the next delivery gate after accepted card 147. Crystallization work is sequenced through bounded, fixture-first cards; it does not supersede the control-plane frontier.

## Deferred decisions

- The durable-store engine is not yet selected. SQLite is the preferred candidate only if a fixture comparison with a compacted Lisp-record store proves lower file count plus atomic migration, recovery, backup, and inspectability.
- Retention ceilings for transcripts, attachments, observations, records, exports, and backups remain operator decisions. No duration or deletion rule is inferred from this decision.
- `operator` is the proposed default profile. It becomes the default only after profile-boot fixtures demonstrate its exact mode, process, and adapter closure.
- Any public third-party extension contract needs an explicit card. The present decision concerns first-party source composition only.

## Revisit condition

Revisit if a fixture-based profile closure, state migration comparison, or adapter contract demonstrates that this arrangement increases—not reduces—measured load, runtime, storage, or operator complexity.

Attribution: operator decision recorded by Hermes Agent — openai/gpt-5.6-terra via openai-api, Hermes TUI; cost unknown.
