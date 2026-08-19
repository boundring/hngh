# Task: README harness-framing and positioning record

## Scope

Documentation-only revision to the root `README.md`. Rewrites the `Why`
section to compare Hngh's approach with the open-source agent-harness
mainstream, and rewrites the `Where this is going` section to frame Hngh as
a growing system harness that routes local and remote models, priced routes,
and eventually pooled hardware through one bounded, recorded, human-closable
cycle. No source, test, gate, or runtime change.

## Decision

The prior Why stated the trust problem in two sentences. The prior
Where-this-is-going listed rungs without naming the destination. Both read
narrower than the intent and the roadmap, and both left the reader guessing
whether Hngh is a small library or the early skeleton of a harness.

The revision:

- Expands Why into a contrast with the harness mainstream: throughput- and
  autonomy-first frameworks against Hngh's record- and boundary-first
  posture. The claimed inversion is grounded in external evidence, not
  rhetoric.
- Keeps the honest "library with fixture tests, not a finished tool" status
  and the four verify commands verbatim.
- Reframes Where-this-is-going as a corridor: Hngh grows harness capability
  (transports, replaceable worker, cross-route cost, pooled hardware) while
  holding the rule that the kernel never guesses at the outside and the
  harness always rebuilds around it.
- Keeps the no-daemon/no-provider/no-watcher/no-scheduler admission line
  verbatim. Nothing unbuilt is implied to exist.

## Comparison evidence

The Why comparison cites one external study and one protocol trend; both
verified by reading primary sources this session:

- Hu Wei, "Architectural Design Decisions in AI Agent Harnesses"
  (arXiv 2604.18071, April 2026; https://arxiv.org/abs/2604.18071), an
  empirical study of 70 public agent-system projects. Its stated findings
  ground HnGH's position:
  intermediate isolation (sandboxing) is common, but high-assurance audit is
  rare; capability growth does not reliably co-occur with governance
  maturity; MCP- and plugin-oriented tool systems are emerging alongside
  registry-dominant ones.
- The Model Context Protocol specification update of 2026-07-28 moved MCP's
  core to stateless, HTTP-routable operation. That is the ecosystem's own
  drift toward a session-free, boundary-shaped tool layer, close in spirit
  to the run-fresh, fail-closed kernel Hngh already enforces.

The comparison is deliberately measured: it does not assert Hngh is
categorically unlike every harness, only that its ordering of priorities
(capability vs. audit before capability) is reversed from the mainstream.
Hngh is still small; the claim is about ordering, not scale.

## Register

The revision also sets the public voice, per operator direction:

- The megastructure is a threaded motif, not a one-off line: planted in
  `What Hngh is` ("paperwork is the building material"), echoed through the
  `Why` walk-back image, and closed in `Where this is going` ("the
  megastructure is mostly paperwork").
- The harness comparison is fair-deadpan: it credits the mainstream
  (a furnace "gets hot, and that is useful") before stating the axis
  difference (a building you can walk and point at a fire door in).
- Em-dashes are banned from the README; prose uses commas, colons, and
  periods.
- Dry beats land at four points (opening plant, furnace riff, archive
  line in Verify, and the closing stretch line). Contract text stays
  factual; none of the humor trades on false claims.

## Evidence

- `README.md` — Why and Where-this-is-going rewritten per the framing
  contract above, plus `What Hngh is` motif planting and `Verify`
  closeness; What/How/Status/Verify preserved in substance and facts.
- `make test` still reports 8 reader guard checks plus 1137 checks — the
  change is source-neutral.

## Remaining unknowns

No new technical unknowns. Real transports, the Pi worker, and pooled
hardware remain future roadmap rungs, admitted only under separately
approved run profiles, as recorded in `docs/project/roadmap.md`.