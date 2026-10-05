# CachyOS host optimization — evidence and applicable findings

Status: proposed 2026-10-05 (operator program m10884 item 7). Real system
changes ride `automation/jobs/cachyos-optimize.sh` and need the operator's
`--yes` consent; nothing here is applied by landing the doc.

## 1. Host evidence (measured 2026-10-04/05)

| Area | Measured | Verdict |
|---|---|---|
| zram | `zram-generator 1.2.1` installed, `/etc/systemd/zram-generator.conf` exists but is EMPTY (0 B), `zramctl` empty, `systemd-zram-setup@zram0` inactive, zram module not loaded | **gap — not configured** |
| Swap | `/swap/swapfile` 33G on `/swap`, **12.1G used**, prio -1 | real pressure under llama residency; every fault pays NVMe swap-in latency |
| RAM | 30951 MiB total, ~13.5G used, buff/cache ~6G, 12G in swap at peak | anon-heavy workload (model weights + KV), swap is load-bearing |
| vm.swappiness | 60 (default) | with zram active the CachyOS default posture is 100 — anon pages should prefer compressed RAM over the disk file |
| NVMe scheduler | `kyber` active (of none/mq-deadline/kyber/adios/bfq) | already optimal for this class of device — no change |
| CPU freq | `amd-pstate-epp`, governor `powersave`, EPP `balance_performance` | sane default; no latency complaint measured — no change |
| Repos | `cachyos-znver4` (+core/extra) repos active, `ParallelDownloads=10`, `Color` | already optimized |
| Services | `ananicy-cpp 1.2.0` + `cachyos-ananicy-rules` installed and running | already optimized |

## 2. Finding Z1 — zram swap is configured-and-off

The one material gap. The box swaps gigabytes to an NVMe file while the
installed zram-generator sits unconfigured. Proposed state:

```ini
# /etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 16384)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
```

- 16G cap (half of 30951 MiB rounded down): enough to absorb the current
  12G swap working set at ~3:1 zstd anon compression without pinning an
  unbounded chunk of RAM.
- priority 100 > swapfile's -1: zram serves hot swapped pages; the disk
  file demotes to overflow for pages that do not compress.
- Rollback: stop `systemd-zram-setup@zram0.service`, `swapoff /dev/zram0`,
  empty the conf — the swapfile never left the pool, so rollback is
  lossless by construction.
- Risk: mis-sized zram + swapfile both full = OOM earlier than today.
  Mitigated by the 16G cap and by keeping the 33G file; the census stage
  re-reads live swap pressure before any change (REQ-I23 posture: census
  is evidence, not a lease).

## 3. Finding Z2 — swappiness posture

With Z1 active, `vm.swappiness = 100` (persisted in
`/etc/sysctl.d/90-zram-posture.conf`) matches the CachyOS zram posture:
anonymous pages rotate through compressed RAM quickly instead of
languishing in page cache until the disk file takes them. Without Z1
applied, leave 60 — raising swappiness toward a spinning/NVMe file only
adds IO. Z2 is gated on Z1 in the script (it refuses to raise swappiness
while `zramctl` is empty).

## 4. Non-findings (leave alone)

kyber scheduler, EPP balance_performance, znver4 repos, ananicy-cpp,
ParallelDownloads — all already in their best measured state. Listed so
the next pass does not re-derive them.

## 5. Application path

`automation/jobs/cachyos-optimize.sh` — same discipline as
`omarchy-boot-build.sh`:

- `census` (default, dry, no sudo): prints the evidence table above from
  the live host; exit 0. The run's stdout is the review artifact.
- `zram` / `swappiness` / `all --yes`: real changes, root via sudo, gated
  on a TTY or `HNGH_OPT_CONFIRM=YES` (refused exit 2 otherwise, fail
  closed). Re-runs are idempotent: an already-satisfied stage is a no-op
  line, never a rewrite.
- every run appends a per-stage log under `${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}`
  (REQ-I26 posture shared with the installer).
