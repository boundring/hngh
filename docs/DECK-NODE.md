# DECK-NODE.md -- admit the Steam Deck as a ledgered Hngh node (Phase 1)

Runbook, 2026-09-06 (machine-runnable redesign; original operator-runbook
version retired the same day). The deck (`steamdeck`, tailnet
100.79.162.3, user `deck`) is already paired and hardened per
[REMOTE-ACCESS.md](../REMOTE-ACCESS.md). This runbook advances it to
Phase 1 of docs/research/2026-09-06-deck-node-compute-lending.md (in
the hngh repo): read-only observation node with evidence sync -- with
**no operator at any keyboard**. Phase 2 (model endpoint) and Phase 3
(research beat) are appended as separate sections; do not run them
until Phase 1's admission record exists.

The key inversion: the deck is **passive**. Nothing runs on the deck
between pulls -- no daemons, no timers, no repos, no packages. The
desktop's existing hour cadence ssh'es in (non-interactive, key-only),
stages and runs a one-shot producer script inside the deck's user
`$HOME`, and pulls the facts back. Deck-side footprint: exactly one
directory, `~/hngh-deck/`, containing one script, facts files, and a
manifest. No sudo, no SteamOS root changes, no installed packages.

## Phase 1 -- observation node + evidence sync (zero operator)

### 1. What runs where

- **Deck:** `~/hngh-deck/deck-producer.sh` (staged fresh each pull from
  the desktop's `hngh-automation/jobs/deck-producer.sh`), one-shot,
  pure stdlib (bash + python3, both present on SteamOS; no sbcl/gcc/
  make needed or touched). It writes `~/hngh-deck/facts/facts-<UTCts>.json`
  (uname, MemTotal/MemAvailable, loadavg, uptime-since, df -h /home,
  GPU/drm + hwmon summary, tailscale ip4 when the userspace CLI
  answers, current clock, disk free of `~/hngh-deck`), appends a
  sha256 line per facts file to `~/hngh-deck/manifest.txt` (kept to
  the last 64), and keeps only the last 24 facts files. It exits 0
  always; errors land in the JSON `error` field and every probe is
  timeout-bounded so it can never hang.
- **Desktop:** `hngh-automation/cadence/hour/32-deck-facts.sh`, mounted
  by the hour-tier tick (`jobs/cadence-tick.sh TIER=hour`) in lexical
  order after `31-heartbeat`. Gated by the cadence-params row
  `deck-node-enabled` (env `DECK_NODE_ENABLED` overrides). Every ssh
  is non-interactive (`BatchMode=yes`, `ConnectTimeout=10`, the
  documented `id_ed25519_hngh` key) so no password prompt is ever
  possible; an auth failure is just an unreachable breadcrumb.

Per hour, the step: probes the staged producer and re-stages it via
stdin redirect when missing or drifted; runs it under a hard
`timeout 120`; fetches the newest facts file; validates it with
python3; appends one compact JSON line to
`hngh-automation/deck-facts/deck-facts-<date>.jsonl` (staged by
`jobs/sweep-artifacts.sh` like every other artifact surface).

### 2. Reachability semantics (the deck is an intermittent peer)

The deck being off or wall-sleeping is **normal**: the step writes the
breadcrumb `deck unreachable (normal)` and exits 0 -- no alert. An
alert row (`report-queue --add alert`, identity `deck-unreachable-<date>`,
24h dedup) is filed only when the deck answered earlier the same UTC
day and then stopped answering: that is a real regression signal, not
a sleep schedule. The next hourly tick picks the pull back up.

### 3. Which existing units must NOT run on the deck

Nothing from `hngh-automation/systemd/` runs on the deck, ever, in any
phase -- the deck hosts no systemd units, timers, or daemons of ours.
The desktop's cadence is the only clock in the system.

### 4. Not required for Phase 1 (retired operator steps)

The original Phase-1 runbook required operator steps that Phase 1 no
longer needs. None of these are needed to pull observation facts:

- **SBCL via pacman** (`sudo steamos-readonly disable` +
  `pacman -Sy sbcl` + re-enable): not needed -- no sbcl/kernel runs on
  the deck in Phase 1. SBCL lands only if a later phase needs the
  kernel on-device, and it is an operator decision at that point
  (SteamOS updates wipe /usr; that drift risk is the reason it stays
  out of the machine-runnable path).
- **Deck-side `make test`:** not needed -- the deck runs no kernel
  code in Phase 1. The deck runs the same rulebook or none; today it
  is none (pure stdlib observation only), so the kernel gate does not
  apply. A later phase that puts kernel code on the deck inherits the
  gate by construction.
- **Deck-side systemd --user timer + linger:** not needed -- no deck-
  side timers exist; the desktop cadence drives everything. Linger
  (`sudo loginctl enable-linger deck`) remains an operator follow-up
  solely for the deck's own tailscaled user service uptime, not for
  us; the pull treats a sleeping deck as normal (section 2).
- **Deck-side git clones:** not needed -- the producer carries no
  repos; facts travel desktop-ward over the pull channel.

### 5. Admission: proposal, check, record

All commands ran on the **desktop** (the deck never touches `~/.hngh`
stores). This is the deck's first proposal/check/record, per hngh
docs/intent.md (mesh paragraph) and the run lifecycle.

**Proposal.** `scripts/hngh create-run "admit steamdeck as pinned
federation peer (phase 1)" operator` with the automation loadout keys
(config.env `HNGH_LOADOUT`), then `admit-transport <run> filesystem
repository`. Objective: pin the deck as a federation peer whose
observation facts may be cited as evidence.
Run as landed: `run-1` in the dedicated store
`~/.hngh-automation/store-deck` (the shared automation store keeps a
`run-1` from an old probe and the per-harness identifier generator
always names the first run `run-1`, so a dedicated store is the
honest fix).

**Check.** The verification the run demands before the mutation:

- the deck's ssh host key fingerprint, captured at admission time from
  the desktop's `known_hosts` (`ssh-keygen -lf`):
  `SHA256:Hj31/4hV42VQFYVU/FIIfbp5r1oYx6dIRnx3oWG1TAg` (ED25519,
  100.79.162.3);
- the pins file contains exactly one row: `steamdeck`, the deck's
  ed25519 host key (PKCS8 PEM extracted from the pinned known_hosts
  entry), algorithm `ed25519`;
- the first real facts pull landed through the desktop-pull lane
  (deck-facts/ JSONL, producer-run breadcrumb);
- deviation from the study's check, declared: no deck-generated
  ed25519 attestation keypair and no signed bundle yet -- with no
  operator, the transport-trust pin (ssh host key) is the admission
  evidence; a dedicated attestation key + `verify-attestation` bundle
  is the Phase-1.5 upgrade once the deck can hold a key safely.
- deviation from the study's check, declared: no deck-side `make test`
  (section 4).
- refusal resolved inside the ceremony: the pins registry lives in
  the operator trust-anchor directory
  (`~/.hngh-automation/pins/pins.tsv` + `steamdeck-hostkey.pem`), not
  in the repo -- the pins parser requires an absolute key path per
  row while the candidate verifier refuses any candidate file
  carrying an absolute user-home path, so a repo-resident pins file
  can never pass `verify-candidate.py`. The registry is operator-
  local trust-anchor material by design (kernel rung 12); the
  admission record in the hngh repo documents this boundary.

**Record.** `issue-cert prepare-candidate` + `mutation-check` (git
add), then `issue-cert commit` + `mutation-check` (fixed-message
`git commit hngh: candidate <content-hash>`) over the admission
record (docs/records/2026-09-06-deck-phase-1-admission.md in the hngh
repo). The ledger row names: peer id `steamdeck`, tailnet
100.79.162.3, transport desktop-pull-over-ssh (no listener, deck
passive), pin fingerprint, first-evidence timestamp, the Phase-1
scope (facts only, no model endpoint yet).
As landed: the ceremony ran end to end and the candidate commit
`245ef50 hngh: candidate f14f73e3...` carries the admission record
alone. Two corrections to the draft above: the mutation covers the
admission record only (the pins file and key live outside the repo,
per the refusal note above), and the run is deliberately left open --
`close-run` accepts only the failure dispositions
`cancelled|evacuated|dead`, and closing a successful admission with a
failure label would falsify the record. The open run plus its bound
certificate is the admission record.

## Phase 2 -- model endpoint (VRAM lending) -- LANDED 2026-09-07

Landed under explicit operator direction (2026-09-07: "the deck is
available any time it's not in use, desktop mode, screen locking
blocked, available for delegating tasks overnight + further
integration"). Phase 1's passive-deck rule is amended by this phase:
the deck now deliberately hosts one llama.cpp server as a systemd
**--user** unit. No sudo, no packages, no rootfs changes; footprint is
`~/hngh-deck/` plus `~/.config/systemd/user/llama-server.service`.

### What runs

- **Binary**: llama.cpp release `b10830` prebuilt
  `llama-b10830-bin-ubuntu-vulkan-x64.tar.gz` (v0.4.0-dev, commit
  465e49b9c), downloaded directly on the deck into
  `~/hngh-deck/bin/llama-b10830/`. `--version` verified on the deck
  immediately after download; all shared libs resolve against SteamOS
  holo glibc 2.41 (no musl fallback needed).
- **Model**: bartowski `Qwen2.5-7B-Instruct-GGUF`, file
  `Qwen2.5-7B-Instruct-Q4_K_M.gguf`, 4,683,074,240 bytes, sha256
  `65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423`
  (matched against the Hugging Face LFS oid), at
  `~/hngh-deck/models/`. Download took ~4.5 min at ~16.6 MB/s.
- **Unit** `~/.config/systemd/user/llama-server.service` (enabled,
  WantedBy=default.target):

    [Unit]
    Description=llama.cpp server (deck-7b, Qwen2.5-7B-Instruct Q4_K_M)
    After=network.target

    [Service]
    WorkingDirectory=%h/hngh-deck/bin/llama-b10830
    Environment=LD_LIBRARY_PATH=%h/hngh-deck/bin/llama-b10830
    ExecStart=%h/hngh-deck/bin/llama-b10830/llama-server --host 0.0.0.0 --port 8082 -m %h/hngh-deck/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf --alias deck-7b -c 2048 -ngl 999
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=default.target

- **Port 8082, not 8081**: the designed 8081 is already held on the
  deck by a foreign service (wildcard `*:8081` listener, root-owned --
  unidentifiable without sudo and out of our footprint by
  constraint). llama-server failed to bind there; we rebound to 8082.
- **Backend**: Vulkan offload CONFIRMED, not CPU -- amdgpu fdinfo for
  the server pid shows ~4.3 GiB resident VRAM (`drm-total-vram`), and
  the 1 GiB VRAM carve is not a hard limit on the APU (shared memory
  architecture; the driver allocates beyond the carve). Model load
  ~6 s after start.

### Measured performance (2026-09-07)

- Desktop -> deck over tailscale, 32-token chat completion: 0.68 s
  wall (0.75 s on-deck; tailscale direct adds nothing measurable).
- Sustained generation: 81 tokens in 6.4 s ~= **12.6 tok/s**
  (better than the 5-10 tok/s Phase 2 estimate).

### Chain activation (desktop)

`config.env` exports (env overrides the deliberately empty
cadence-params `deck-model-endpoint` row; the row stays empty by
design -- do not fill it):

    DECK_URL="${DECK_URL:-http://100.79.162.3:8082}"
    DECK_MODEL="${DECK_MODEL:-deck-7b}"

Note `DECK_URL` carries NO `/v1` suffix: `lib/model.sh deck_chat`
appends `/v1/chat/completions` itself. End-to-end proof: model_call
with unsloth/ollama/openrouter legs pointed at dead ports returned
`content=Acknowledged`, `MODEL_USED=deck:deck-7b`. The leg test
`tests/test-model-deck-leg.sh` covers the sandbox paths (unset row,
stub answer, dead URL, MODEL_TIMEOUT).

### Rollback (one command, run on the deck or over ssh)

    ssh deck@100.79.162.3 'systemctl --user disable --now llama-server'

(plus, to fully remove: delete
`~/.config/systemd/user/llama-server.service`, `~/hngh-deck/bin/`,
`~/hngh-deck/models/` and drop the two config.env lines -- frees
~9 GB.)

### Deck-not-running behavior (normal)

The deck being off/suspended is a normal state, not an alert: with no
listener at `100.79.162.3:8082`, `deck_chat` gets HTTP 000 inside
MODEL_TIMEOUT, writes the breadcrumb `| model | deck | HTTP 000 ->
next backend`, and the chain falls through to lobehub/archive-only.
The hourly facts sync keeps its own independent deck-unreachable
semantics (Phase 1 section 2).

### Persistence caveat (operator note)

The user unit survives reboots only while the deck user session
autologins into desktop mode -- true here (screen locking blocked per
operator direction). After a full power-off + cold boot, no extra
step is needed; after a SteamOS update wipes desktop-mode autologin,
log into desktop mode once and the unit comes back. `loginctl
enable-linger deck` (needs sudo) would remove even that dependency --
follow-up, not required today.

## Phase 3 -- deck-side research beat

Run only after Phase 2 is measured. **[operator]** installs a deck-side
unit that runs `cadence/hour/33-research-beat.sh` from the
deck's clone against the deck-local model endpoint, pushing its digest
by explicit path like the facts sync. Workbeat/overnight launches stay
desktop-side permanently. Exit criterion: a research digest produced
deck-side and filed by desktop oversight without hand-carry.

## Verification checklist

- [ ] `ssh -o BatchMode=yes deck@100.79.162.3` works key-only, no
      prompt (REMOTE-ACCESS.md key).
- [ ] `cadence/hour/32-deck-facts.sh` ran via the hour tick;
      `deck-facts/deck-facts-<date>.jsonl` has real deck rows.
- [ ] Deck footprint is `~/hngh-deck/` (Phase 1: script + facts +
      manifest; Phase 2 amendment: plus `bin/` and `models/`); no
      clones, no unit files outside `~/.config/systemd/user/` and
      `~/.local/bin/` helpers.
- [ ] cadence-params row `deck-node-enabled` is `1`; env
      `DECK_NODE_ENABLED=0` no-ops the step (gated both ways).
- [ ] Admission run `run-1` present in `~/.hngh-automation/store-deck`
      with its certificate bound to the `hngh: candidate` commit.
- [ ] `~/.hngh-automation/pins/pins.tsv` has exactly the steamdeck
      row; `list-pins` renders it (ed25519).
- [ ] No unit from hngh-automation/systemd/ on the deck; no deck-side
      timers (the deck stays passive except the Phase 2 llama-server
      user unit, which is deliberately ours and documented above).
- [ ] Cadence-params row `deck-model-endpoint` stays empty
      permanently -- the leg is activated by the `DECK_URL` config.env
      export, not the row (env wins by design; `make test` green
      proves the row-empty path).
