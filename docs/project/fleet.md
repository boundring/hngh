# Fleet — observed helper devices and mesh facts

Dated observations from `scripts/fleet-manager --record`. This file is
an operator-side record, never an authority: a node named here becomes
a trusted peer only after the operator pins it through the existing
governance (the `attestation.lisp` registry is source and is never
edited by a script).

The `NAME=MAC` lines below are the wake-on-LAN ledger; wake is a
bounded convenience (one magic packet to the /24 broadcast) that
refuses any unpinned or malformed MAC.

## MAC pin ledger (operator-owned)

# steam-deck=AA:BB:CC:DD:EE:FF