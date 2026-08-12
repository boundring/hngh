# Architecture

Hngh begins as a compact, side-effect-free kernel.

## Current kernel

- `work` validates work intent and local receipts.
- `agents` validates adapter contracts; it never starts agents.
- `machine` validates approved machine operations; it never self-activates.
- `observe` renders local evidence without changing state.

A profile is an ordered, duplicate-free list of these modes. Malformed, unknown,
or duplicate input fails closed. The active source has no scheduler, socket
listener, systemd unit, MCP server, adapter, or implicit state root.

## Planned boundaries

The next components are policy boundaries, not active runtime packages:

```text
hngh.main -> hngh.presentation / hngh.adapters.*
          -> hngh.application
          -> hngh.domain
```

The dependency direction, promotion ladder, and composition rule live in the
[Clean Architecture charter](core/clean-architecture-charter.md). The public
responsibilities and allowed dependencies live in the
[component map](core/component-map.md). Tests and presentation data follow the
[test boundary](core/test-boundary.md) and
[presentation boundary](design/presentation-boundary.md).
