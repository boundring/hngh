# 2026-09-06 — Deck phase 1 admission: steamdeck as pinned federation peer

## Scope

Admits the Steam Deck (`steamdeck`, tailnet 100.79.162.3, user `deck`)
as a pinned federation peer for Phase 1 only: read-only observation
facts pulled by the desktop, no model endpoint, no deck-side
execution. The mutation is the pins-file registry change the
compute-lending study (docs/research/2026-09-06-deck-node-compute-
lending.md, section 4) names: exactly one new pin row.

The run is the first admission executed with no operator at a
keyboard. The desktop's hour cadence
(hngh-automation/cadence/hour/32-deck-facts.sh) stages and runs a
one-shot producer inside the deck's user `$HOME` (`~/hngh-deck/`,
pure stdlib, no daemons, no timers, no packages, no sudo) and pulls
the facts back as JSONL; the deck stays passive between pulls.

## Decision

1. **Transport-trust pin, declared deviation.** The study's check
   demanded a deck-generated ed25519 attestation keypair and a signed
   bundle verified through `verify-attestation`. With no operator, no
   key ceremony can happen deck-side, so Phase 1 pins the deck's ssh
   host key instead (ED25519, fingerprint
   `SHA256:Hj31/4hV42VQFYVU/FIIfbp5r1oYx6dIRnx3oWG1TAg`, captured at
   admission time from the desktop's `known_hosts` via
   `ssh-keygen -lf`). The pinned key file is the PKCS8 PEM extracted
   from that pinned known_hosts entry, so the pin is directly usable
   by `verify-attestation` once a signed bundle exists. A dedicated
   attestation key and signed-bundle verification is the declared
   Phase-1.5 upgrade.
2. **No deck-side kernel gate, declared deviation.** The study's check
   demanded `make test` green on the deck. Phase 1 puts no kernel code
   on the deck (stdlib producer only), so the gate does not apply; any
   later phase that puts kernel code on the deck inherits the gate by
   construction.
3. **Pin format and trust-anchor location.** The pin row is
   `steamdeck<TAB>$HOME/.hngh-automation/pins/steamdeck-hostkey.pem<TAB>ed25519`
   — one row, as the check requires; `list-pins` renders it with
   algorithm ed25519. The pins file lives beside the pinned key in the
   operator store (`~/.hngh-automation/pins/`), not in the repository:
   the pins parser requires an absolute key path in every row, while
   the candidate verifier (scripts/verify-candidate.py) refuses any
   candidate file containing an absolute user-home path — a pins
   file inside the repo can therefore never pass the ceremony. The
   registry is operator-local trust-anchor material by design (rung
   12); this landing records that boundary instead of working around
   it. The pinned key file is the PKCS8 PEM of the deck's ssh host
   key, so `verify-attestation ... pins=<file>` is directly usable
   once a signed bundle exists.

## Evidence

- ssh host-key fingerprint: `ssh-keygen -lf ~/.ssh/known_hosts` for
  100.79.162.3 → `SHA256:Hj31/4hV42VQFYVU/FIIfbp5r1oYx6dIRnx3oWG1TAg`
  (ED25519).
- Pinned PEM verified readable by openssl
  (`openssl pkey -pubin -text`: ED25519 Public-Key).
- `list-pins ~/.hngh-automation/pins/pins.tsv` renders the single
  steamdeck row, algorithm ed25519.
- First live facts pull through the machine-runnable lane, 2026-09-07
  UTC (`hngh-automation/deck-facts/`): peer steamdeck, uname
  `Linux steamdeck 6.16.12-valve24.5-1-neptune ...`, MemTotal
  15160364 kB, tailscale 100.79.162.3, no error field; producer-run
  and facts-pulled breadcrumbs in hngh-automation/STATE.md. Deck-side
  footprint verified as exactly `~/hngh-deck/` (script + facts +
  manifest).
- Desktop gate (`make test` in hngh-automation) green before the
  automation landing; kernel gate (`make test` in this repo) green
  before this candidate.

## Remaining unknowns

- The pinned host key proves the machine, not a signer: no
  attestation envelope has been verified through `verify-attestation`
  yet. Phase 1 evidence remains the desktop-pulled facts lane; the
  signed-bundle rung is deliberately deferred (Phase 1.5) and needs
  the deck to hold a key it can sign with.
- `~/hngh` exists on the deck from the earlier operator-runbook era
  and is not used by Phase 1; cleanup is left to the operator
  (nothing in Phase 1 reads it).
