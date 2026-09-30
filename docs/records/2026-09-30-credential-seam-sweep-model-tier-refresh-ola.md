# Credential-seam sweep + model-tier refresh cadence (governed-fleet slice E)

## Question

Did the slice-E surface (governed-fleet.md:248-251) land as designed:
stat-mode-only token verification per model-chain seam, the fresh
configured-peer-pin half of peer admission, and a standing model-tier
refresh cadence?

## Evidence read

- Design: docs/design/governed-fleet.md:248-251 (slice E definition).
- Prior rung: queue.md:17-18 (key-rotation-freshness landed 2026-09-23,
  lib/credential-evidence.py + credential-health.sh sections 7-8);
  docs/records/2026-09-16-credential-freshness-rung-dead-legs.md.
- Route-review contract: backlog.md:670-684 (quarterly re-bench + route
  review OLA; report row naming workhorse/runner-ups/drops).
- In-flight automation surface (pre-existing in the working tree,
  verified unchanged then landed by commit afe632e7):
  jobs/credential-health.sh +81 lines (sweep_seam sections 9-10),
  cadence/calendar/monthly/02-model-tier-refresh.sh (new, 66 lines),
  cadence-params.tsv model-tier-refresh-ola=7776000 quarterly OLA,
  Makefile:221 wiring, tests/test-slice-e-seam-surface.sh (27 checks).

## Doctrine applied

Two-home split and credential boundary (training: token values never
read or echoed; the sweep is stat-mode-only on declared file surfaces;
live probing stays in credential-health.sh sections 1-6). Failure-mode
bestiary: the obsolete-class death of this lane (state/beat-blockers.tsv
blk-20260930) was answered by re-deriving live state before acting and
adopting the in-flight artifacts instead of recreating them. Ceremony
for kernel docs: the four kernel-doc writes (this record, plan
execution note, queue.md:75 flip, CHANGELOG) ride the certificate loop;
the automation surface landed as a free commit with both gates green.

## Findings

- Both gates green at landing: bash
  automation/tests/test-slice-e-seam-surface.sh (27 checks, all pass,
  stub-binary hermetic, no token values), automation `make test` rc=0,
  kernel `make test` rc=0.
- Sweep shape: every model-chain leg seam swept token-only (unsloth
  TOKEN_FILE/REFRESH_FILE, remote REMOTE_TOKEN_FILE at model.sh:465,
  kimi at model.sh:735); mode-600 else fail-closed alert. Never values.
- Peer-pin freshness half: configured PEER_TOKEN_FILE gets stale/unseen
  alerts; unconfigured stays silent by design (peer registry row is
  slice F, not this slice).
- Cadence: monthly drop-in emits a route row with the OLA read from
  cadence-params.tsv (quarterly, 7776000s); absent/unknown OLA is a
  fail-open alert (drop-in exits 0), never a crash.
- Queue.md:75 backlog-model-tier-refresh-cadence flips to done citing
  this record and backlog.md:670-684.

## Recommended next line

Slice F (node-lattice admission): register the first peer through the
same gate, which is the first caller that arms PEER_TOKEN_FILE and the
freshness half.
