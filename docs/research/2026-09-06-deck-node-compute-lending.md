# Deck node compute-lending study -- steamdeck as a ledgered Hngh node

Status: study, 2026-09-06. Question: the Steam Deck is paired and
hardened (REMOTE-ACCESS.md, 2026-08-28) -- what does it take to advance
it to a ledgered fellow Hngh node that communicates, coordinates, and
lends compute/RAM/VRAM over LAN/tailscale?

Every hardware claim below comes from live read-only SSH probes run
2026-09-06 (`ssh deck@100.79.162.3`, key `id_ed25519_hngh`, access
documented in hngh-automation/REMOTE-ACCESS.md). Every file claim names
its path. Estimates are marked as such.

## 1. What the deck actually is

| Probe | Result |
|---|---|
| `uname -a` | Linux steamdeck 6.16.12-valve24.5-1-neptune x86_64 |
| `/etc/os-release` | SteamOS, codename holo |
| `lspci` | AMD/ATI "Sephiroth [AMD Custom GPU 0405]" -- 8 CU RDNA2 iGPU, the Van Gogh APU |
| `lscpu` | 8 threads, "AMD Custom APU 0932" |
| `free -h` | 14 GiB RAM usable, 8.2 GiB swap (16 GiB device) |
| `mem_info_vram_total` | 1073741824 -- 1 GiB carved VRAM (SteamOS default; BIOS allows up to 4 GiB) |
| `df -h /home` | 939G volume, 344G free |
| `command -v sbcl ollama llama-server llama-cli gcc make` | all absent |
| `command -v python3 git jq` | python3 3.13.5, git 2.50.1, jq present |
| `pacman -Si sbcl` | sbcl 2.5.7-1, repository extra-3.8.1x -- installable |
| `lsattr -d /usr` | rootfs carries the immutable bit -- SteamOS read-only root |
| tailscale `status` | steamdeck 100.79.162.3, brickertop 100.83.36.27 `active; direct` |

Two consequences:

- **The kernel can run there, but not yet.** SBCL is in the pacman
  repos, but installing it requires `sudo steamos-readonly disable`
  (operator step; a SteamOS update reverts it). No build tools
  (gcc/make) are present, so building llama.cpp on-device needs
  `base-devel` or a prebuilt binary.
- **The transport is already the lattice transport.** Tailscale runs in
  userspace mode (`~/.local/bin/tailscaled` via a user service,
  REMOTE-ACCESS.md), survives SteamOS updates, and the deck-to-desktop
  link is `active; direct`. One limit from REMOTE-ACCESS.md: the
  tailscaled user service runs while a desktop-mode session is logged
  in; linger is the follow-up. A deck node is therefore an
  intermittent peer today, not an always-on one.

## 2. What a minimal ledgered node runs

The control-plane invariant (hngh docs/design/descent.md section Invariants):
the control plane stays model-free; models fill content. A deck node
that only holds content roles (evidence facts, model serving) never
threatens that invariant -- it must never run routing, acceptance, or
dispositioning.

Candidates, cheapest first:

- **Observation tier subset (Phase 1).** Not the desktop's feeds or
  watchdog -- those observe desktop sessions (jobs/agent-watchdog.sh,
  jobs/*.py read AUTOMATION_ROOT state the deck does not have). The
  deck's observation tier is deck-local facts: uptime, memory, GPU
  carve, tailscale reachability, model-endpoint health. These are the
  bounded facts the fleet vision names: "uptime, load, network state"
  (hngh docs/project/backlog.md, device-fleet entry).
- **Research beat (Phase 3).** The automation research beat
  (hngh-automation/cadence/day/05-research-beat.sh) is model-fed and
  deterministic-shelled; it could run deck-side once the kernel and
  repos are cloned there. Not before the deck holds its own SBCL and
  `make test` green.
- **Model endpoint (Phase 2, the lending leg).** The deck's GPU is 8
  RDNA2 CUs with 1 GiB carved VRAM backed by 14 GiB shared RAM
  (probes above). Realistic llama.cpp/vulkan payload on that APU: a
  7-8B model at Q4_K_M quantization -- a roughly 4.5-5 GB file served
  from the 344G free /home. Vulkan on RDNA2 can allocate beyond the
  1 GiB carve from shared system memory (the carve is a floor, not a
  ceiling, on Linux), and ~5-10 tok/s for a 7-8B Q4 on the deck is the
  community-reported range -- estimate, not a probe; the admission
  record should demand one measured number before the leg is enabled.
  Serving model: `llama-server --host 100.79.162.3 --port 8081` with
  `--alias deck`, no auth, reachable only over the tailnet (ufw on the
  desktop blocks LAN :8890 by the same logic -- the deck port must ride
  WireGuard too). The model-chain leg that consumes it is now in
  hngh-automation/lib/model.sh `deck_chat`: gated on the cadence-params
  row `deck-model-endpoint`, empty by default, so the leg does not
  exist until this study's Phase 2 completes.

RAM/VRAM lending beyond the model endpoint (e.g. the desktop offloading
batch work to deck RAM) is not proposed here: no consumer exists in
either repo, and the backlog's resource-pool view (backlog.md
resource-pool-view) only asks for a *view* of pooled capability, not
ambient sharing.

## 3. Coordination without a daemon

The Hngh way is evidence first, then a place (hngh docs/intent.md, mesh
paragraph): what a node learns is "written down as a fact a neighbor
can cite, not buried in a ledger only one wall will ever read". No
daemon means no ambient process on either side; every exchange is an
explicit, recorded, human-closable step (backlog.md node-lattice
admission rung).

What exists in the kernel today (hngh README.md, operator command
surface `scripts/hngh`):

- `admit-transport ... :federation` -- the run admits federation
  requests (rung 11, `hngh.adapters.federation`).
- `fetch-evidence RUN method=carrier-bundle|http-claim` -- gathers a
  peer's carrier-bundle claims into evidence facts (rung 15 added the
  http-claim method).
- `verify-attestation RUN envelope pins=PATH` -- verifies one envelope
  signature through a single bounded openssl invocation against the
  operator's pins file (rungs 12/14: rsa-sha256 and ed25519 admitted).
- `list-pins`, `wake-peer` (rung 17; wake rides the pins registry).

So the deck can join **today** as follows, with zero new kernel code:

1. Operator generates (or reuses) an ed25519 key on the deck.
2. Operator adds the deck's public key to the pins file --
   `list-pins` renders it; the pin IS the admission evidence
   (README rung 17: "the pins registry is the admission evidence").
3. Deck-side script (a one-shot, timer-invoked, ~30 lines of shell)
   collects the observation facts into a closed bundle document,
   signs it (ed25519), and leaves the bundle where a fetch can pick
   it up -- a git push to the shared remote, or `scp` to the desktop.
   No listener, no daemon.
4. Operator (or a desktop-side timer tick) runs
   `fetch-evidence` + `verify-attestation` against the pins file. The
   deck's facts become citable evidence facts in the store.

What needs building (honest list):

- The deck-side bundle producer script (small, one-shot).
- A scheduled-but-single-tick pattern for it: a `systemd --user`
  timer firing a oneshot -- the same operator-installed single-tick
  pattern every hngh-automation timer already uses (Makefile
  enable/disable targets).
- http-claim endpoint: only if git/scp transport proves too clumsy;
  the rung-15 `:http-claim` method already accepts a peer HTTP
  endpoint, and the deck's llama-server would already be one listener
  -- but that is Phase 2+ and a boundary amendment, not Phase 1.
- Key rotation and evidence freshness: the backlog names these as
  prerequisites for *unattended* peers (backlog.md device-fleet risk:
  "unattended low-power peers need the evidence-freshness /
  key-rotation story first"). The deck as run here is operator-backed,
  not unattended -- the risk does not block Phase 1, and the runbook
  marks the rotation as an open operator duty.

## 4. The admission path

A node is admitted "the only way anything is ever admitted here:
through a proposal, a check, and a record" (intent.md, mesh
paragraph). Draft, matching the lifecycle of intent.md's run section:

**Proposal.** Create a run (`scripts/hngh create-run`):
objective "admit steamdeck as pinned federation peer (phase 1:
observation facts only)", role operator, loadout limits per
config.env (`HNGH_LOADOUT`). Attach the evidence: this study, the
probe outputs above, and REMOTE-ACCESS.md as the pairing record.

**Check.** The verification the run demands before the mutation:

- the pins file contains exactly one new row: the deck's ed25519
  public key, fingerprint recorded at add time;
- one signed bundle from the deck verifies through
  `verify-attestation ... pins=PATH` (verdict: verified, no
  unpinned-key refusals);
- `list-pins` renders the new pin with algorithm ed25519;
- on the deck itself: `make test` green after SBCL install (the same
  gate every kernel change passes -- the deck runs the same rulebook).

**Record.** `issue-cert` binds the check to the candidate; the
mutation is the pins-file commit plus the ledger row naming: peer
id `steamdeck`, tailnet address 100.79.162.3, transport
carrier-bundle-over-git (no listener), first-evidence timestamp, and
the pin fingerprint. `close-run` closes; the run record is the
admission record. Nothing about the deck is trusted that is not in
that row -- "no wall stands that does not say who raised it"
(intent.md).

## 5. Phased plan

**Phase 1 -- deck as read-only observation node + evidence sync.**
Operator runs hngh-automation/docs/DECK-NODE.md top to bottom: clone
repos, install SBCL, `make test` green on deck, import the deck-side
sync units (git pull/push one-shots; no daemon), add the pin, produce
and verify the first signed bundle. Exit criterion: a verified
attestation from the deck exists in the operator's store and
`list-pins` shows `steamdeck`.

**Phase 2 -- deck as model-chain leg (VRAM lending).** Install
llama.cpp (prebuilt vulkan binary or containerized build), download a
7-8B Q4_K_M GGUF, start `llama-server` on 100.79.162.3:8081, measure
tok/s, set the cadence-params row `deck-model-endpoint` to the URL.
Exit criteria: `hngh-automation/jobs/credential-health.sh` reports the
endpoint ok when up and stays quiet when the deck is off; one real
model_call lands on the deck leg (MODEL_USED `deck:*`) after the
upstream legs fail; the measured tok/s is recorded in the ledger row.

**Phase 3 -- deck runs its own beat tier.** SBCL installed (Phase 1),
kernel testable on-device, model endpoint proven (Phase 2): move the
research beat (cadence/day/05-research-beat.sh) to a deck-side timer,
writing to the deck's clone and syncing over git like the evidence
bundle. Exit criterion: a research digest produced deck-side, synced,
and filed by the desktop-side oversight without operator hand-carry.
The backlog items this ladder climbs are device-fleet,
node-lattice-admission, and resource-pool-view (backlog.md); the
resource-pool row for steamdeck should cite only pinned, verified
facts per that entry's review trigger.

## Sources

- hngh-automation/REMOTE-ACCESS.md -- pairing topology, tailscale
  userspace mode, sshd key-only posture, known limits.
- Live probes 2026-09-06 over `ssh deck@100.79.162.3` (commands and
  outputs quoted in section 1).
- hngh docs/intent.md -- mesh horizon; proposal/check/record admission.
- hngh docs/design/descent.md -- control-plane invariant.
- hngh docs/design/writing-register.md -- prose register.
- hngh README.md -- federation verbs, rungs 11-18.
- hngh docs/project/system-harness-roadmap.md -- Rung A/B; "what is not
  admitted".
- hngh docs/project/backlog.md -- node-lattice admission rung;
  device-fleet; resource-pool-view; key-rotation-freshness.
- hngh docs/research/2026-08-29-remote-access-patterns.md -- tailnet as
  transport boundary, not blanket trust.
- hngh docs/research/2026-09-01-self-hosting-prior-art.md -- evidence
  ledgers append-only; the tooling tests the tooling.
- hngh-automation/lib/model.sh (`deck_chat`), cadence-params.tsv row
  `deck-model-endpoint`, jobs/credential-health.sh probe-deck,
  docs/DECK-NODE.md -- the automation-side leg and runbook.
