#!/usr/bin/env bash
# Hermetic proofs for jobs/cachyos-optimize.sh (read-only posture tool).
# The script is dry-by-construction: census and zswap never mutate, never
# sudo. A zram-enable path would violate the operator constraint
# (docs/design/cachyos-optimization.md section 0) — its absence is pinned
# here.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/jobs/cachyos-optimize.sh"
fails=0
ck() { # label want got
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$2' got '$3')"; fi
}
ok() { echo "ok: $*"; }
bad() {
  echo "FAIL $*"
  fails=$((fails + 1))
}

SB="$(mktemp -d)"
SHIMDIR="$SB/bin"
LOGDIR="$SB/logs"
mkdir -p "$SHIMDIR" "$LOGDIR"
trap 'rm -rf "$SB"' EXIT

run() { # args...
  env -u SUDO \
    HNGH_OPT_LOGDIR="$LOGDIR" \
    HNGH_OPT_ZSWAP_SYS="$SB/zswap-params" \
    PATH="$SHIMDIR:$PATH" \
    bash "$SCRIPT" "$@" 2>&1
}

# sudo shim: RECORDS any invocation; the suites assert it stays silent
# (dry/census/zswap never escalate).
printf '#!/bin/sh\nprintf "%%s\\\\n" "$*" >>"%s/sudo.argv"\nexit 99\n' "$SB" >"$SHIMDIR/sudo"
chmod +x "$SHIMDIR/sudo"

# stub zramctl: no devices
printf '#!/bin/sh\ncase "$1" in --output*) echo name; exit 0;; esac; exit 0\n' >"$SHIMDIR/zramctl"
chmod +x "$SHIMDIR/zramctl"

seed_posture() { # enabled compressor
  mkdir -p "$SB/zswap-params"
  printf '%s\n' "$1" >"$SB/zswap-params/enabled"
  printf '%s\n' "$2" >"$SB/zswap-params/compressor"
  printf '%s\n' 30 >"$SB/zswap-params/max_pool_percent"
  printf '%s\n' Y >"$SB/zswap-params/shrinker_enabled"
  printf 'NAME       TYPE SIZE USED PRIO\n/swap/swapfile file 33G 10G -1\n' >"$SB/swapon-stub"
  printf '#!/bin/sh\ncat "%s/swapon-stub"\n' "$SB" >"$SHIMDIR/swapon"
  chmod +x "$SHIMDIR/swapon"
}

# 1. syntax
bash -n "$SCRIPT" && ok "bash -n" || bad "bash -n"

# 2. help lists both stages
out="$(run --help)" && hrc=0 || hrc=$?
ck "help rc" 0 "$hrc"
case "$out" in *census*zswap* | *zswap*census*) ok "help lists stages" ;; *) bad "help stages" "$out" ;; esac

# 3. unknown arg refused
out="$(run frobnicate)" && rc=0 || rc=$?
ck "unknown arg rc" 2 "$rc"

# 4. default census: rc 0, posture lines, NO sudo, stage log with header
rm -f "$SB/sudo.argv"
seed_posture Y zstd
out="$(run census)" && crc=0 || crc=$?
if [ "$crc" -eq 0 ]; then ok "census rc"; else bad "census rc" "rc=$crc out=$out"; fi
case "$out" in *"evidence, not a lease"*) ok "census posture line" ;; *) bad "census posture" "$out" ;; esac
case "$out" in *"zswap: enabled=Y"*) ok "census reports zswap block" ;; *) bad "census zswap" "$out" ;; esac
case "$out" in *"zram off (operator posture)"* | *"operator posture"*) ok "census names zram-off as posture" ;; *) bad "census zram posture" "$out" ;; esac
[ ! -e "$SB/sudo.argv" ] && ok "census runs no sudo" || bad "census runs no sudo" "sudo shim used"
sleep 0.3 # tee lag lesson
logf="$(ls "$LOGDIR"/cachyos-census-*.log 2>/dev/null | head -1)"
if [ -n "$logf" ] && grep -q "^== cachyos-optimize.sh stage=census" "$logf"; then
  ok "census stage log header"
else
  bad "census stage log header" "logf=$logf"
fi

# 5. zswap ok path: posture satisfied -> rc 0, nothing-to-apply, no sudo
rm -f "$SB/sudo.argv" "$LOGDIR"/cachyos-zswap-*.log
out="$(run zswap)" && zrc=0 || zrc=$?
ck "zswap ok rc" 0 "$zrc"
case "$out" in *"nothing to apply"*) ok "zswap ok message" ;; *) bad "zswap ok msg" "$out" ;; esac
[ ! -e "$SB/sudo.argv" ] && ok "zswap runs no sudo" || bad "zswap runs no sudo" "sudo shim used"

# 6. zswap miss path: disabled -> rc 1, names the operator migrate tool
seed_posture N lz4
out="$(run zswap)" && mrc=0 || mrc=$?
ck "zswap miss rc" 1 "$mrc"
case "$out" in *cachyos-zswap-migrate*) ok "miss names migrate tool" ;; *) bad "migrate pointer" "$out" ;; esac

# 7. zswap miss: zram device active -> posture violation named
seed_posture Y zstd
printf '#!/bin/sh\ncase "$1" in --output*) echo name; echo zram0; exit 0;; esac; exit 0\n' >"$SHIMDIR/zramctl"
out="$(run zswap)" && rrc=0 || rrc=$?
ck "zram-active rc" 1 "$rrc"
case "$out" in *"posture violated"*) ok "zram-active flagged" ;; *) bad "zram flag" "$out" ;; esac

# 8. no zram-enable contract anywhere in the script
if grep -q "zram-generator.conf" "$SCRIPT" && grep -q "systemd-zram-setup\|mkfs\|swapon /dev/zram" "$SCRIPT"; then
  bad "no zram-enable contract" "script contains zram setup verbs"
else
  ok "no zram-enable contract"
fi

echo
if [ "$fails" = 0 ]; then
  echo "test-cachyos-optimize: all proofs passed"
  exit 0
fi
echo "test-cachyos-optimize: $fails check(s) red"
exit 1
