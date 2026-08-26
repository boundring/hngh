# 2026-08-25 — Rung 15: network claim method (http-claim)

## Scope

Adds the network claim method to the federation port: `:http-claim`
joins `:carrier-bundle` in the closed `+federation-methods+` set, and
`fetch-evidence` accepts `method=carrier-bundle|http-claim` (default
carrier-bundle). The method reaches the injected `fetch-remote`
transport on the request; the peer remains a plain bounded identifier
and endpoint resolution stays transport-owned — no default wire.

## Decision

1. `+federation-methods+` is now `(:carrier-bundle :http-claim)`;
   any other token still refuses at request construction.
2. `fetch-evidence` gains the closed `method=` option; an unadmitted
   method is malformed (exit 2) before any gather work.
3. The transport callback sees `federation-request-method` on its
   request, so a caller may route the same bounded document fetch over
   HTTP without changing the closed bundle contract or the claim-state
   mapping.
4. No default transport exists: plain `scripts/hngh` still refuses
   `no-federation-transport` unless federation ports are injected.

## Evidence

- Tests first, red (`federation method must be a closed member:
  :HTTP-CLAIM`), then green: `make test` passes 8 reader guards and
  2719 checks (+6: method admission, transport-visible method, dispatch
  plumbing, unadmitted-method refusal).
- Live proof over a real wire: a local `python3 -m http.server` served
  the carrier-bundle document; `gather-federated-evidence` with
  `:method :http-claim` through an injected urllib transport returned
  `status=COMPLETE facts=3 states=(:CURRENT :CURRENT :UNVERIFIABLE)`.
- Committed through the self-governed validation loop: proposal admitted
  10/10, certificate bound to real evidence, `git add` + `git commit`
  executed as `hngh: candidate 9719f324…` (`14e8e95`), pushed; gate
  green after the mutation.
- README, changelog, roadmap, and this record updated; the README
  `Not yet` list drops the network-claim clause.

## Remaining unknowns

- Review-fed policy profiles remain the standing next slice.
- A default HTTP transport is deliberately absent; endpoint resolution
  is caller-provided until a transport-admission design exists.