# CachyOS host optimization — evidence and applicable findings

Status: amended 2026-10-05 (operator directive: zram is contraindicated on
this host; zswap is the house posture). Read-only verification lives in
`automation/jobs/cachyos-optimize.sh`; real swap-posture mutations belong
to the operator's own migration tool
(github.com/boundring/cachyos-zswap-migrate), never to this script.

## 0. Operator constraint (binding)

AMD desktops on CachyOS fail to suspend/wake under zram memory pressure
(CachyOS wiki "switching from zram to zswap"; the operator lived it on
this machine class — GPU hardware issues until zram was disabled in favor
of zswap). The operator's `cachyos-zswap-migrate` encodes the sanctioned
migration: zram removed, zswap enabled with a hibernation-capable
swapfile. zram must NOT be re-enabled here, whatever the generic CachyOS
guidance says.

## 1. Host evidence (measured 2026-10-04/05)

| Area | Measured | Verdict |
|---|---|---|
| zram | `zram-generator` installed, `/etc/systemd/zram-generator.conf` EMPTY (0 B), `zramctl` empty, module not loaded | **correct posture — zram off by operator history, not a gap** |
| zswap | `enabled=Y`, `compressor=zstd`, `max_pool_percent=30`, `shrinker_enabled=Y` | **active — the house posture is already in place** |
| Swap | `/swap/swapfile` 33G on NVMe, 10-12G used, prio -1 | zswap's backing store, load-bearing under llama residency |
| vm.swappiness | 60 (default) | with zswap+file backing, no evidence-based change; raising it only adds NVMe IO — leave |
| NVMe scheduler | `kyber` active | already optimal — no change |
| CPU freq | `amd-pstate-epp`, governor `powersave`, EPP `balance_performance` | sane default — no change |
| Repos | `cachyos-znver4` (+core/extra), `ParallelDownloads=10`, `Color` | already optimized |
| Services | `ananicy-cpp` + `cachyos-ananicy-rules` running | already optimized |

## 2. Finding — posture verified, nothing to apply

The one candidate gap from the first census (empty zram-generator.conf)
inverts under the operator constraint: zram-off + zswap-on + swapfile
backing is exactly the end state `cachyos-zswap-migrate` produces. There
is no applicable system change left on this host.

- If a future census finds `zswap enabled=N` or the swapfile gone, the
  fix is the operator's migrate tool (inspect → plan → apply, reversible,
  backed up) — not an ad-hoc rewrite here.
- The empty `/etc/systemd/zram-generator.conf` file is inert detritus;
  removing it is an optional cosmetic mutation needing consent. Leave it.

## 3. Non-findings (leave alone)

kyber scheduler, EPP balance_performance, znver4 repos, ananicy-cpp,
ParallelDownloads, swappiness=60 — all already in their best measured
state. Listed so the next pass does not re-derive them.

## 4. Verification path

`automation/jobs/cachyos-optimize.sh` — read-only by construction:

- `census` (default): prints the evidence table from the live host,
  including the zswap parameter block; exit 0.
- `zswap`: asserts the house posture (zswap enabled, zstd, zram absent,
  swapfile present); a miss prints the migrate-tool pointer and exits 1
  (fail closed) — it never mutates.
- every run appends a per-stage log under
  `${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}` (REQ-I26 posture
  shared with the installer); the log is the review artifact.
- superseded: the earlier `zram`/`swappiness` apply stages (and their
  `--yes` consent machinery) were removed with this amendment — the
  posture they applied is contraindicated on this host.
