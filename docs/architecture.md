# Architecture

Hngh begins as a compact kernel.

- `work` validates work intent and local receipts.
- `agents` validates adapter contracts; it never starts agents.
- `machine` validates approved machine operations; it never self-activates.
- `observe` renders local evidence without changing state.

A profile is an ordered, duplicate-free list of these modes. Unknown modes fail
closed. The kernel has no scheduler, socket listener, systemd unit, MCP server,
or implicit state root.
