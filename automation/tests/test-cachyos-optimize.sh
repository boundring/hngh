#!/usr/bin/env bash
# test-cachyos-optimize.sh -- hermetic proofs for jobs/cachyos-optimize.sh.
# No real root, no real systemd: dry paths print only; real paths ride an
# HNGH_OPT_SUDO shim that records argv, plus stub zramctl/sysctl in a
# stub PATH. Conf target is redirected into the sandbox.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/jobs/cachyos-optimize.sh"
fails=0
ok() { printf 'ok %s\n' "$1"; }
bad() {
 printf 'FAIL %s: %s\n' "$1" "${2:-}"
 fails=$((fails + 1))
}
SB="$(mktemp -d)"
SHIMDIR="$SB/shim"
STUBBIN="$SB/stubbin"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SHIMDIR" "$STUBBIN" "$SB/state"
CONF="$SB/state/zram-generator.conf"
LOGDIR="$SB/logs"

# sudo shim: records argv; emulates tee (stdin -> file) so real-path
# byte assertions work without root
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$SB_DIR/sudo.argv"\nif [ "$1" = "tee" ] && [ -n "$2" ]; then cat >"$2"; fi\nexit 0\n' >"$SHIMDIR/sudo"
sed -i "s|\$SB_DIR|$SB|" "$SHIMDIR/sudo"
chmod +x "$SHIMDIR/sudo"
# stub zramctl: reports an active zram0 (real-path gating for swappiness)
printf '#!/bin/sh\ncase "$1" in --help) exit 0;; esac\necho "NAME ALG DISKSIZE DATA COMPR TOTAL STREAMS MOUNTPOINT"\necho "zram0 zstd 16G 4G 3.1G 1.1G 16 [SWAP]"\n' >"$STUBBIN/zramctl"
chmod +x "$STUBBIN/zramctl"
# stub sysctl: no-op success
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/sysctl.argv"\nexit 0\n' "$SB" >"$STUBBIN/sysctl"
chmod +x "$STUBBIN/sysctl"

run() { # extra env as K=V...; stage as last two args
 local confirm="${CONFIRM:-}"
 env -u SUDO \
  HNGH_OPT_ZRAM_CONF="$CONF" \
  HNGH_OPT_LOGDIR="$LOGDIR" \
  HNGH_OPT_SUDO="$SHIMDIR/sudo" \
  HNGH_OPT_CONFIRM="$confirm" \
  HNGH_OPT_SWAPPINESS_CONF="$SB/state/90-zram-posture.conf" \
  PATH="$STUBBIN:$PATH" \
  bash "$SCRIPT" "$@" 2>&1
}

# 1. syntax
if bash -n "$SCRIPT"; then ok "bash -n"; else bad "bash -n" "syntax error"; fi

# 2. --help rc 0 lists stages
out="$(bash "$SCRIPT" --help)" && hrc=0 || hrc=$?
if [ "$hrc" -eq 0 ]; then ok "--help rc"; else bad "--help rc" "rc=$hrc"; fi
for s in census zram swappiness all; do
 case "$out" in *"$s"*) ok "--help lists $s" ;; *) bad "--help lists $s" "missing" ;; esac
done

# 3. unknown argument: refused rc=2
out="$(bash "$SCRIPT" nonsense 2>&1)" && brc=0 || brc=$?
if [ "$brc" -eq 2 ]; then ok "unknown arg rc=2"; else bad "unknown arg rc=2" "rc=$brc"; fi
case "$out" in *refused*) ok "unknown arg message" ;; *) bad "unknown arg message" "$out" ;; esac

# 4. dry census: rc 0, evidence lines, no sudo, stage log with header
rm -f "$SB/sudo.argv"
out="$(run census)" && crc=0 || crc=$?
if [ "$crc" -eq 0 ]; then ok "census rc"; else bad "census rc" "rc=$crc"; fi
case "$out" in *"evidence, not a lease"*) ok "census posture line" ;; *) bad "census posture" "$out" ;; esac
case "$out" in *"configured-and-off"*) ok "census finds zram gap" ;; *) bad "census zram gap" "$out" ;; esac
[ ! -e "$SB/sudo.argv" ] && ok "census runs no sudo" || bad "census runs no sudo" "sudo shim used"
sleep 0.3 # tee lag lesson
logf="$(ls "$LOGDIR"/cachyos-census-*.log 2>/dev/null | head -1)"
if [ -n "$logf" ] && grep -q "^== cachyos-optimize stage=census" "$logf"; then
 ok "census stage log header"
else
 bad "census stage log header" "logf=$logf"
fi

# 5. zram dry: prints the would-be conf, writes nothing, no sudo
rm -f "$CONF" "$SB/sudo.argv"
out="$(run zram)" && zrc=0 || zrc=$?
if [ "$zrc" -eq 0 ]; then ok "zram dry rc"; else bad "zram dry rc" "rc=$zrc"; fi
case "$out" in *"dry: would write"*) ok "zram dry prints plan" ;; *) bad "zram dry plan" "$out" ;; esac
case "$out" in *"zram-size = min(ram / 2, 16384)"*) ok "zram dry conf text" ;; *) bad "zram conf text" "$out" ;; esac
[ ! -e "$CONF" ] && ok "zram dry writes nothing" || bad "zram dry wrote conf" "$CONF"
[ ! -e "$SB/sudo.argv" ] && ok "zram dry runs no sudo" || bad "zram dry sudo" "shim used"

# 6. zram --yes without TTY or knob: refused rc=2
out="$(run zram --yes </dev/null)" && yrc=0 || yrc=$?
if [ "$yrc" -eq 2 ]; then ok "zram --yes no-confirm rc=2"; else bad "zram --yes refusal rc" "rc=$yrc"; fi
case "$out" in *"HNGH_OPT_CONFIRM=YES"*) ok "zram --yes refusal names knob" ;; *) bad "refusal knob" "$out" ;; esac

# 7. zram --yes with knob + shims: conf written, unit started, zram0 active
rm -f "$CONF" "$SB/sudo.argv"
out="$(CONFIRM=YES run zram --yes </dev/null)" && rrc=0 || rrc=$?
if [ "$rrc" -eq 0 ]; then ok "zram real rc"; else bad "zram real rc" "rc=$rrc out=$out"; fi
grep -q "zram-size = min(ram / 2, 16384)" "$CONF" 2>/dev/null &&
 ok "zram real conf written" || bad "zram real conf" "$(cat "$CONF" 2>/dev/null)"
grep -q "swap-priority = 100" "$CONF" &&
 ok "zram real priority above swapfile" || bad "zram priority" "missing"
if [ -e "$SB/sudo.argv" ] && grep -q "daemon-reload" "$SB/sudo.argv" &&
 grep -q "start systemd-zram-setup@zram0" "$SB/sudo.argv"; then
 ok "zram real reloads + starts unit"
else
 bad "zram real unit start" "$(cat "$SB/sudo.argv" 2>/dev/null)"
fi
case "$out" in *"zram0 active"*) ok "zram real activation proof" ;; *) bad "zram activation" "$out" ;; esac

# 8. idempotent second real run: no rewrite, no restart
: >"$SB/sudo.argv"
out="$(CONFIRM=YES run zram --yes </dev/null)" && irc=0 || irc=$?
if [ "$irc" -eq 0 ] && [ ! -s "$SB/sudo.argv" ]; then
 ok "zram idempotent: no sudo on satisfied stage"
else
 bad "zram idempotent" "rc=$irc argv=$(cat "$SB/sudo.argv" 2>/dev/null)"
fi
case "$out" in *"already applied"*) ok "zram idempotent message" ;; *) bad "idempotent msg" "$out" ;; esac

# 9. swappiness real without zram: refused rc=2 (stub zramctl removed)
out="$(PATH="$SHIMDIR:/usr/bin:/bin" CONFIRM=YES HNGH_OPT_ZRAM_CONF="$CONF" \
 HNGH_OPT_LOGDIR="$LOGDIR" HNGH_OPT_SUDO="$SHIMDIR/sudo" \
 bash "$SCRIPT" swappiness --yes </dev/null 2>&1)" && src=0 || src=$?
if [ "$src" -eq 2 ]; then ok "swappiness gates on zram rc=2"; else bad "swappiness gate rc" "rc=$src"; fi
case "$out" in *"needs active zram"*) ok "swappiness gate message" ;; *) bad "gate msg" "$out" ;; esac

# 10. swappiness real with zram active: drop-in written, sysctl applied
rm -f "$SB/sudo.argv"
out="$(CONFIRM=YES run swappiness --yes </dev/null)" && wrc=0 || wrc=$?
if [ "$wrc" -eq 0 ]; then ok "swappiness real rc"; else bad "swappiness real rc" "rc=$wrc out=$out"; fi
grep -q "tee .*90-zram-posture.conf" "$SB/sudo.argv" 2>/dev/null &&
 ok "swappiness drop-in argv" || bad "drop-in argv" "$(cat "$SB/sudo.argv" 2>/dev/null)"
grep -q "sysctl -q -w vm.swappiness=100" "$SB/sudo.argv" 2>/dev/null &&
 ok "swappiness live apply argv" || bad "sysctl argv" "$(cat "$SB/sudo.argv" 2>/dev/null)"

# 11. dry swappiness never needs zram or sudo
rm -f "$SB/sudo.argv"
out="$(PATH="$SHIMDIR:/usr/bin:/bin" HNGH_OPT_ZRAM_CONF="$CONF" \
 HNGH_OPT_LOGDIR="$LOGDIR" HNGH_OPT_SUDO="$SHIMDIR/sudo" \
 bash "$SCRIPT" swappiness </dev/null 2>&1)" && drc=0 || drc=$?
if [ "$drc" -eq 0 ] && [ ! -e "$SB/sudo.argv" ]; then
 ok "swappiness dry: rc 0, no sudo"
else
 bad "swappiness dry" "rc=$drc sudo=$(cat "$SB/sudo.argv" 2>/dev/null)"
fi

# summary
if [ "$fails" -eq 0 ]; then
 echo "test-cachyos-optimize: all proofs passed"
else
 echo "test-cachyos-optimize: $fails check(s) red"
 exit 1
fi
