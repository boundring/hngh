#!/usr/bin/env bash
# test-omarchy-unattended-install.sh -- hermetic proofs for
# jobs/omarchy-unattended-install.sh. PATH-stub style like
# test-omarchy-boot-build.sh / test-omarchy-boot-provision.sh: every
# external command the job may run is a stub that records its argv on
# $HNGH_STUB_LOG. No real qemu, sudo, genisoimage, unsquashfs, ssh,
# lsblk, or disk is ever touched.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/jobs/omarchy-unattended-install.sh"
fails=0
ok() { printf 'ok %s\n' "$1"; }
bad() {
  printf 'FAIL %s: %s\n' "$1" "${2:-}"
  fails=$((fails + 1))
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SHIM="$WORK/shim"
SECRETS="$WORK/secrets"
UDIR="$WORK/seeded"
LOGS="$WORK/logs"
OVMF_CODE="$WORK/OVMF_CODE.fd"
OVMF_VARS="$WORK/OVMF_VARS.fd"
KVM="$WORK/kvm"
ISO="$WORK/omarchy.iso"
STUB_LOG="$WORK/stub-invocations.log"
mkdir -p "$SHIM" "$SECRETS" "$UDIR/cidata" "$LOGS"
: >"$STUB_LOG"
printf 'OVMF CODE\n' >"$OVMF_CODE"
printf 'OVMF VARS\n' >"$OVMF_VARS"
: >"$KVM"
printf 'padhsqs\n' >"$ISO"
: >"$UDIR/cidata.iso"
printf 's\n' >"$UDIR/cidata/user_configuration.json"
printf '{"users": [{"username": "omarchy"}]}\n' >"$UDIR/cidata/user_credentials.json"

# ---- PATH stubs: each logs "<name> <argv>" on $HNGH_STUB_LOG ----
cat >"$SHIM/lsblk" <<'SH'
#!/bin/sh
printf 'lsblk %s\n' "$*" >>"$HNGH_STUB_LOG"
case "$*" in
  *-bno*) printf '%s\n' "${HNGH_STUB_DISK_BYTES:-42949672960}";;
  *MOUNTPOINT*) [ -n "${HNGH_STUB_MOUNTED:-}" ] && printf '%s\n' "$HNGH_STUB_MOUNTED";;
  *PKNAME*) printf '%s\n' "${HNGH_STUB_PKNAME:-sda}";;
esac
exit 0
SH
cat >"$SHIM/findmnt" <<'SH'
#!/bin/sh
printf 'findmnt %s\n' "$*" >>"$HNGH_STUB_LOG"
printf '%s\n' "${HNGH_STUB_ROOTSRC:-/dev/sda1}"
exit 0
SH
cat >"$SHIM/pgrep" <<'SH'
#!/bin/sh
printf 'pgrep %s\n' "$*" >>"$HNGH_STUB_LOG"
if [ -f "$HNGH_STUB_LOG.qemuproc" ]; then
  printf '12345 qemu-system-x86_64 %s\n' "$(cat "$HNGH_STUB_LOG.qemuproc")"
  # one-shot observation: the daemonized install VM powers off at install
  # end, so the next poll finds nothing (models the run -> verify hand-off)
  rm -f "$HNGH_STUB_LOG.qemuproc"
  exit 0
fi
if [ "${HNGH_STUB_QEMU_ALIVE:-}" = "1" ]; then
  printf 'qemu-system-x86_64 -drive file=%s,if=virtio\n' "${HNGH_STUB_QEMU_CMD:-/dev/nvme0n1}"
  exit 0
fi
exit 1
SH
cat >"$SHIM/qemu-img" <<'SH'
#!/bin/sh
printf 'qemu-img %s\n' "$*" >>"$HNGH_STUB_LOG"
for last do :; done
: >"$last"
exit 0
SH
chmod +x "$SHIM"/lsblk "$SHIM"/findmnt "$SHIM"/pgrep "$SHIM"/qemu-img
cat >"$SHIM/qemu-system-x86_64" <<'SH'
#!/bin/sh
printf 'qemu-system-x86_64 %s\n' "$*" >>"$HNGH_STUB_LOG"
ser=""
for a in "$@"; do
  case "$a" in
    file:*) ser="${a#file:}";;
  esac
done
if [ -n "$ser" ]; then
  {
    printf 'BdsDxe boot\n'
    printf 'Reached target SSH Access Available\n'
    i=0
    while [ "$i" -lt 430 ]; do printf 'x'; i=$((i + 1)); done
    printf '\n'
  } >"$ser"
fi
printf '%s\n' "$*" >"$HNGH_STUB_LOG.qemuproc"
exit 0
SH
cat >"$SHIM/genisoimage" <<'SH'
#!/bin/sh
printf 'genisoimage %s\n' "$*" >>"$HNGH_STUB_LOG"
prev=""
for a in "$@"; do
  [ "$prev" = "-output" ] && : >"$a"
  prev="$a"
done
exit 0
SH
cat >"$SHIM/unsquashfs" <<'SH'
#!/bin/sh
printf 'unsquashfs %s\n' "$*" >>"$HNGH_STUB_LOG"
dst=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d) dst="$2"; shift 2;;
    -o) shift 2;;
    -*) shift;;
    *) break;;
  esac
done
shift
for p in "$@"; do
  mkdir -p "$dst/$(dirname "$p")" 2>/dev/null
  case "$p" in
    */omarchy-cidata-load)
      printf '# stub loader\n# consumes "enc_password" "username" "root_enc_password"\n' >"$dst/$p";;
    *)
      printf '# stub %s\n# consumes "kernels"\n' "$p" >"$dst/$p";;
  esac
done
exit 0
SH
cat >"$SHIM/ssh" <<'SH'
#!/bin/sh
printf 'ssh %s\n' "$*" >>"$HNGH_STUB_LOG"
exit 0
SH
cat >"$SHIM/df" <<'SH'
#!/bin/sh
printf 'df %s\n' "$*" >>"$HNGH_STUB_LOG"
free_kb=$(( ${HNGH_STUB_FREE_GB:-100} * 1048576 ))
printf 'Filesystem 1024-blocks Used Available Use%% Mounted\n'
printf 'overlay 100000000 %s %s 50%% /work\n' "$((100000000 - free_kb))" "$free_kb"
exit 0
SH
cat >"$SHIM/sudo" <<'SH'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$HNGH_STUB_LOG"
case "$1" in
  -v|kill) exit 0;;
esac
exec "$@"
SH
cat >"$SHIM/sleep" <<'SH'
#!/bin/sh
printf 'sleep %s\n' "$*" >>"$HNGH_STUB_LOG"
exit 0
SH
chmod +x "$SHIM"/qemu-system-x86_64 "$SHIM"/genisoimage "$SHIM"/unsquashfs \
  "$SHIM"/ssh "$SHIM"/df "$SHIM"/sudo "$SHIM"/sleep

# ---- run helper: answers on stdin; gate '' = no HNGH_BOOT_CONFIRM ----
run_job() {
  ans="$1"
  gate="$2"
  shift 2
  rm -f "$STUB_LOG".qemuproc*
  printf '%s' "$ans" | env HNGH_BOOT_CONFIRM="$gate" \
    HNGH_STUB_LOG="$STUB_LOG" \
    HNGH_SECRETS_HOME="${SECRETS2:-$SECRETS}" \
    HNGH_UNATTENDED_DIR="$UDIR" \
    HNGH_BOOT_LOGDIR="$LOGS" \
    HNGH_OVMF_CODE="$OVMF_CODE" HNGH_OVMF_VARS="$OVMF_VARS" \
    HNGH_KVM_DEVICE="$KVM" \
    HNGH_BOOT_BUILD="${BOOT_BUILD_STUB:-}" \
    HNGH_VERIFY_INTERVAL=1 HNGH_VERIFY_TIMEOUT=5 \
    HNGH_PILOT_MIN_FREE_GB="${FREE_GB:-30}" \
    HNGH_STUB_DISK_BYTES="${STUB_BYTES:-42949672960}" \
    HNGH_STUB_MOUNTED="${STUB_MOUNTED:-}" \
    HNGH_STUB_QEMU_ALIVE="${STUB_QEMU_ALIVE:-}" \
    HNGH_STUB_FREE_GB="${STUB_FREE_GB:-100}" \
    PATH="$SHIM:$PATH" bash "$SCRIPT" "$@" 2>&1
}

# ---- 1: syntax ----
if bash -n "$SCRIPT" 2>/dev/null; then
  ok "1 job script parses (bash -n)"
else
  bad "1 job script parses (bash -n)"
fi

# ---- 2: help lists phases and flags ----
out="$(run_job '' '' help)"
rc=$?
if [ "$rc" -eq 0 ] &&
  case "$out" in *seed*run*verify*) true;; *) false;; esac &&
  case "$out" in *--disk*--iso*--credentials-hash*) true;; *) false;; esac &&
  case "$out" in *--defer-provisioning*--pilot*--real-disk*) true;; *) false;; esac &&
  case "$out" in *--config-sample*--authorized-keys*--user*) true;; *) false;; esac; then
  ok "2 help lists phases and flags"
else
  bad "2 help lists phases and flags" "rc=$rc out=$out"
fi

# ---- 3: seed happy path (no ISO, no sample): pair + encrypt-false + redaction ----
printf -v H86 'A%.0s' {1..86}
HASH='$6$saltsalt1234$'"$H86"
SECRETS2="$(mktemp -d "$WORK/secrets3.XXXXXX")"
out="$(run_job '' YES seed --disk /dev/nvme0n1 --user omarchy \
  --hostname omarchy-hngh --timezone America/New_York --keyboard us \
  --credentials-hash "$HASH" --yes)"
rc=$?
cfg="$(ls "$SECRETS2"/*/cidata/user_configuration.json 2>/dev/null | head -n 1)"
creds="$(ls "$SECRETS2"/*/cidata/user_credentials.json 2>/dev/null | head -n 1)"
enc="$(ls "$SECRETS2"/*/cidata/user_encrypt_installation.txt 2>/dev/null | head -n 1)"
if [ "$rc" -eq 0 ] && [ -n "$cfg" ] && [ -n "$creds" ] && [ -n "$enc" ]; then
  ok "3a seed writes config+credentials+encrypt marker"
else
  bad "3a seed writes config+credentials+encrypt marker" "rc=$rc cfg=$cfg creds=$creds"
fi
if [ -n "$cfg" ] && grep -q '/dev/vda' "$cfg" && grep -q '"hostname": "omarchy-hngh"' "$cfg" &&
  grep -q '"kb_layout": "us"' "$cfg" && grep -q '"timezone": "America/New_York"' "$cfg"; then
  ok "3b config carries flags and guest device /dev/vda"
else
  bad "3b config carries flags and guest device /dev/vda"
fi
if [ -n "$creds" ] && grep -q '"username": "omarchy"' "$creds" &&
  grep -q '"enc_password":' "$creds" && grep -q '"root_enc_password":' "$creds" &&
  grep -q '"sudo": true' "$creds" && [ "$(cat "$enc")" = "false" ]; then
  ok "3c credentials schema + encrypt marker is false"
else
  bad "3c credentials schema + encrypt marker is false"
fi
if grep -q 'genisoimage' "$STUB_LOG" && grep -q -- '-volid cidata' "$STUB_LOG"; then
  ok "3d genisoimage builds cidata.iso with -volid cidata"
else
  bad "3d genisoimage builds cidata.iso with -volid cidata"
fi
if case "$out" in *"$HASH"*) false;; *) true;; esac &&
  case "$out" in *redacted*) true;; *) false;; esac &&
  ! grep -qF "$HASH" "$LOGS"/seed-*.log 2>/dev/null; then
  ok "3e hash never printed: stdout and stage log REDACTED"
else
  bad "3e hash never printed: stdout and stage log REDACTED"
fi
if case "$out" in *SCHEMA-UNVERIFIED*) true;; *) false;; esac; then
  ok "3f no ISO/sample -> loud SCHEMA-UNVERIFIED warning"
else
  bad "3f no ISO/sample -> loud SCHEMA-UNVERIFIED warning" "out=$out"
fi

# ---- 4: seed refuses without a credentials source ----
out="$(run_job '' YES seed --disk /dev/nvme0n1 --user omarchy --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*credentials*) true;; *) false;; esac; then
  ok "4 seed without --credentials-hash or --defer-provisioning exits 2"
else
  bad "4 seed without --credentials-hash or --defer-provisioning exits 2" "rc=$rc out=$out"
fi

# ---- 5: defer-provisioning -> marker file, NO user_credentials.json ----
SECRETS2="$(mktemp -d "$WORK/secrets5.XXXXXX")"
out="$(run_job '' YES seed --disk /dev/nvme0n1 --defer-provisioning --yes)"
rc=$?
dfile="$(ls "$SECRETS2"/*/cidata/defer-provisioning 2>/dev/null | head -n 1)"
if [ "$rc" -eq 0 ] && [ -n "$dfile" ] && [ ! -s "$dfile" ] &&
  [ -z "$(ls "$SECRETS2"/*/cidata/user_credentials.json 2>/dev/null)" ]; then
  ok "5 defer-provisioning writes empty marker, no user_credentials.json"
else
  bad "5 defer-provisioning writes empty marker, no user_credentials.json" "rc=$rc dfile=$dfile"
fi

# ---- 6: seed --iso extracts the loader and proves key parity ----
SECRETS2="$(mktemp -d "$WORK/secrets6.XXXXXX")"
out="$(run_job '' YES seed --disk /dev/nvme0n1 --user omarchy \
  --credentials-hash "$HASH" --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'unsquashfs' "$STUB_LOG" &&
  case "$out" in *'schema parity: verified'*) true;; *) false;; esac &&
  case "$out" in *'consumed keys: enc_password kernels root_enc_password username'*) true;; *) false;; esac; then
  ok "6a ISO loader extracted, consumed keys verified in emitted JSON"
else
  bad "6a ISO loader extracted, consumed keys verified in emitted JSON" "rc=$rc out=$out"
fi
if ! case "$out" in *SCHEMA-UNVERIFIED*) true;; *) false;; esac; then
  ok "6b verified schema emits no SCHEMA-UNVERIFIED warning"
else
  bad "6b verified schema emits no SCHEMA-UNVERIFIED warning" "out=$out"
fi
if grep -q 'bare sfs-relative' <<<"$out" || grep -q 'usr/local/bin/omarchy-cidata-load' "$STUB_LOG"; then
  ok "6c extraction uses bare sfs-relative patterns (no squashfs-root prefix)"
else
  bad "6c extraction uses bare sfs-relative patterns (no squashfs-root prefix)"
fi

# ---- 7: mutually exclusive / missing / unknown inputs refuse exit 2 ----
out="$(run_job '' YES seed --disk /dev/nvme0n1 --user omarchy \
  --credentials-hash "$HASH" --defer-provisioning --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*) true;; *) false;; esac; then
  ok "7a --credentials-hash with --defer-provisioning refuses exit 2"
else
  bad "7a --credentials-hash with --defer-provisioning refuses exit 2" "rc=$rc"
fi
out="$(run_job '' YES seed --disk /dev/nvme0n1 --credentials-hash "$HASH" --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*) true;; *) false;; esac; then
  ok "7b --credentials-hash without --user refuses exit 2"
else
  bad "7b --credentials-hash without --user refuses exit 2" "rc=$rc"
fi
out="$(run_job '' YES seed --disk /dev/nvme0n1 --no-such-flag 1 --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*) true;; *) false;; esac; then
  ok "7c unknown flag refuses exit 2"
else
  bad "7c unknown flag refuses exit 2" "rc=$rc"
fi
out="$(run_job '' '' run --disk /dev/nvme0n1 --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*'no TTY'*) true;; *) false;; esac; then
  ok "7d --yes with no TTY and no HNGH_BOOT_CONFIRM refuses exit 2"
else
  bad "7d --yes with no TTY and no HNGH_BOOT_CONFIRM refuses exit 2" "rc=$rc out=$out"
fi

# ---- 8: run --yes pilot (default): overlay install, manifest, detection ----
: >"$STUB_LOG"
out="$(run_job 'y
' YES run --disk /dev/nvme0n1 --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 0 ] &&
  grep -q "qemu-img create -f qcow2 -b /dev/nvme0n1 -F raw $UDIR/pilot.qcow2" "$STUB_LOG"; then
  ok "8a pilot overlay created against the untouched backing disk"
else
  bad "8a pilot overlay created against the untouched backing disk" "rc=$rc log=$(cat "$STUB_LOG")"
fi
qlog="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | tail -n 1)"
if case "$qlog" in *'-enable-kvm'*'-cpu host'*'-m 4096'*'-smp 4'*'-vga std'*) true;; *) false;; esac &&
  case "$qlog" in *"file=$UDIR/pilot.qcow2,if=virtio,format=qcow2"*) true;; *) false;; esac &&
  case "$qlog" in *"file=$UDIR/cidata.iso,if=virtio,format=raw,readonly=on"*) true;; *) false;; esac &&
  case "$qlog" in *"-cdrom $ISO"*) true;; *) false;; esac &&
  case "$qlog" in *'if=pflash,format=raw,readonly=on,file='"$OVMF_CODE"*) true;; *) false;; esac &&
  case "$qlog" in *'if=pflash,format=raw,file='"$UDIR/OVMF_VARS.copy"*) true;; *) false;; esac &&
  case "$qlog" in *"-serial file:$UDIR/serial-install.log"*) true;; *) false;; esac &&
  case "$qlog" in *'-display none'*'-daemonize'*) true;; *) false;; esac; then
  ok "8b install VM shape: pflash pair + cdrom ISO + cidata virtio readonly + pilot qcow2"
else
  bad "8b install VM shape" "qlog=$qlog"
fi
if ! case "$qlog" in *hostfwd*) true;; *) false;; esac; then
  ok "8c run VM exposes no hostfwd (forwarding belongs to verify only)"
else
  bad "8c run VM exposes no hostfwd" "qlog=$qlog"
fi
sv_line="$(grep -n '^sudo -v$' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
q_line="$(grep -n '^sudo qemu-system-x86_64' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
n_sv="$(grep -c '^sudo -v$' "$STUB_LOG")"
if [ "$n_sv" -eq 1 ] && [ -n "$sv_line" ] && [ -n "$q_line" ] && [ "$sv_line" -lt "$q_line" ]; then
  ok "8d sudo -v exactly once, before the qemu launch"
else
  bad "8d sudo -v exactly once, before the qemu launch" "n_sv=$n_sv sv=$sv_line q=$q_line"
fi
man="$UDIR/run-manifest"
if [ -f "$man" ] && grep -q '^mode=pilot$' "$man" &&
  grep -q "^target=$UDIR/pilot.qcow2\$" "$man" &&
  grep -q '^backing=/dev/nvme0n1$' "$man" &&
  grep -q "^iso=$ISO\$" "$man" && grep -q '^user=omarchy$' "$man"; then
  ok "8e run-manifest threads mode/target/backing/iso/user"
else
  bad "8e run-manifest threads mode/target/backing/iso/user" "man=$(cat "$man" 2>/dev/null)"
fi
if case "$out" in *'watch -n 10'*) true;; *) false;; esac &&
  case "$out" in *'qemu-img info'*) true;; *) false;; esac &&
  case "$out" in *'~10 minutes'*'NOT consumed'*) true;; *) false;; esac; then
  ok "8f detection proof printed: watch command + 10-minute fallback"
else
  bad "8f detection proof printed: watch command + 10-minute fallback" "out=$out"
fi

# ---- 9: run --yes --real-disk: own gate names the disk + FORMATTED ----
: >"$STUB_LOG"
out="$(run_job 'y
y
' YES run --disk /dev/nvme0n1 --iso "$ISO" --real-disk --yes)"
rc=$?
qlog="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | tail -n 1)"
if [ "$rc" -eq 0 ] &&
  case "$qlog" in *"file=/dev/nvme0n1,if=virtio,format=raw"*) true;; *) false;; esac &&
  ! case "$qlog" in *pilot.qcow2*) true;; *) false;; esac &&
  ! grep -q '^qemu-img create' "$STUB_LOG"; then
  ok "9a real-disk run writes the raw disk, no overlay"
else
  bad "9a real-disk run writes the raw disk, no overlay" "rc=$rc qlog=$qlog"
fi
if case "$out" in *FORMATTED*'/dev/nvme0n1'*) true;; *) false;; esac ||
  case "$out" in *'/dev/nvme0n1'*FORMATTED*) true;; *) false;; esac; then
  ok "9b real-disk gate names the disk and states it will be FORMATTED"
else
  bad "9b real-disk gate names the disk and states it will be FORMATTED" "out=$out"
fi
if grep -q '^mode=real-disk$' "$man" && grep -q '^target=/dev/nvme0n1$' "$man"; then
  ok "9c manifest records mode=real-disk target=$man backing"
else
  bad "9c manifest records mode=real-disk" "man=$(cat "$man")"
fi

# ---- 10: run refuses a mounted backing disk (pilot mode included) ----
out="$(STUB_MOUNTED=/mnt run_job '' YES run --disk /dev/nvme0n1 --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*mounted*) true;; *) false;; esac; then
  ok "10 run refuses when any partition of the backing disk is mounted"
else
  bad "10 run refuses when any partition of the backing disk is mounted" "rc=$rc out=$out"
fi

# ---- 11: run refuses when another qemu already holds the disk ----
out="$(STUB_QEMU_ALIVE=1 run_job '' YES run --disk /dev/nvme0n1 --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*qemu*) true;; *) false;; esac; then
  ok "11 run refuses when pgrep -af qemu-system shows the disk basename"
else
  bad "11 run refuses when pgrep -af qemu-system shows the disk basename" "rc=$rc out=$out"
fi

# ---- 12: pilot warns when the workdir filesystem is tight ----
: >"$STUB_LOG"
out="$(STUB_FREE_GB=5 run_job 'y
' YES run --disk /dev/nvme0n1 --iso "$ISO" --yes)"
rc=$?
if [ "$rc" -eq 0 ] && case "$out" in *free*space*|*space*free*) true;; *) false;; esac &&
  grep -q '^mode=pilot$' "$man"; then
  ok "12 pilot warns under the free-space floor but still proceeds"
else
  bad "12 pilot warns under the free-space floor but still proceeds" "rc=$rc out=$out"
fi

# ---- 13: verify --yes boots the manifest target disk-only ----
: >"$STUB_LOG"
out="$(run_job 'y
' YES verify --yes)"
rc=$?
qlog="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | tail -n 1)"
if [ "$rc" -eq 0 ] &&
  case "$qlog" in *"file=$UDIR/pilot.qcow2,if=virtio,format=qcow2"*) true;; *) false;; esac &&
  ! case "$qlog" in *-cdrom*) true;; *) false;; esac &&
  case "$qlog" in *'-nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22'*) true;; *) false;; esac &&
  case "$qlog" in *"-serial file:$UDIR/serial-verify.log"*) true;; *) false;; esac; then
  ok "13a verify boots the manifest pilot target, disk-only, with hostfwd"
else
  bad "13a verify boots the manifest pilot target, disk-only, with hostfwd" "rc=$rc qlog=$qlog"
fi
if grep -q "ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 omarchy@127.0.0.1 true" "$STUB_LOG"; then
  ok "13b ssh probe arg shape matches the verdict contract"
else
  bad "13b ssh probe arg shape matches the verdict contract" "log=$(cat "$STUB_LOG")"
fi
if case "$out" in *'verdict: BOOTED+SSH'*'proven complete'*) true;; *) false;; esac; then
  ok "13c verdict table reports BOOTED+SSH proven complete"
else
  bad "13c verdict table reports BOOTED+SSH proven complete" "out=$out"
fi
if grep -q '^sudo kill ' "$STUB_LOG"; then
  ok "13d verify VM is killed on exit (cleanup trap)"
else
  bad "13d verify VM is killed on exit (cleanup trap)" "log=$(cat "$STUB_LOG")"
fi

# ---- 14: verify refuses while any qemu is alive (never double-open) ----
out="$(STUB_QEMU_ALIVE=1 run_job '' YES verify --yes)"
rc=$?
if [ "$rc" -eq 2 ] && case "$out" in *refused:*qemu*) true;; *) false;; esac; then
  ok "14 verify refuses while a qemu process is alive"
else
  bad "14 verify refuses while a qemu process is alive" "rc=$rc out=$out"
fi

# ---- 15: verify without a run-manifest fails closed ----
mv "$man" "$man.saved"
out="$(run_job '' YES verify --yes)"
rc=$?
mv "$man.saved" "$man"
if [ "$rc" -eq 2 ] && case "$out" in *'run phase first'*) true;; *) false;; esac; then
  ok "15 verify without run-manifest exits 2 (run phase first)"
else
  bad "15 verify without run-manifest exits 2 (run phase first)" "rc=$rc out=$out"
fi

# ---- 16: dry-run plans everything and invokes no stub at all ----
: >"$STUB_LOG"
out1="$(run_job '' '' seed --disk /dev/nvme0n1 --defer-provisioning --dry-run)"
rc1=$?
out2="$(run_job '' '' run --disk /dev/nvme0n1 --iso "$ISO" --dry-run)"
rc2=$?
out3="$(run_job '' '' verify --dry-run)"
rc3=$?
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && [ "$rc3" -eq 0 ] && [ ! -s "$STUB_LOG" ] &&
  case "$out2" in *qemu-system-x86_64*) true;; *) false;; esac; then
  ok "16 dry-run prints full plans and invokes zero external stubs"
else
  bad "16 dry-run prints full plans and invokes zero external stubs" "rc=$rc1/$rc2/$rc3 stubs=$(cat "$STUB_LOG")"
fi

# ---- 17: full pilot chain calls seed -> run -> verify in order ----
: >"$STUB_LOG"
SECRETS2="$(mktemp -d "$WORK/secrets17.XXXXXX")"
out="$(run_job 'y
y
' YES full --disk /dev/nvme0n1 --iso "$ISO" --user omarchy \
  --credentials-hash "$HASH" --yes)"
rc=$?
g_line="$(grep -n '^genisoimage ' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
qi_line="$(grep -n '^qemu-img create' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
in_line="$(grep -n '^qemu-system-x86_64 .*serial-install.log' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
vf_line="$(grep -n '^qemu-system-x86_64 .*serial-verify.log' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
ssh_line="$(grep -n '^ssh ' "$STUB_LOG" | head -n 1 | cut -d: -f1)"
n_q="$(grep -c '^qemu-system-x86_64 ' "$STUB_LOG")"
in_qlog="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | head -n 1)"
if [ "$rc" -eq 0 ] && [ -n "$g_line" ] && [ -n "$qi_line" ] && [ -n "$in_line" ] &&
  [ -n "$vf_line" ] && [ -n "$ssh_line" ] && [ "$n_q" -eq 2 ] &&
  [ "$g_line" -lt "$qi_line" ] && [ "$qi_line" -lt "$in_line" ] &&
  [ "$in_line" -lt "$vf_line" ] && [ "$vf_line" -lt "$ssh_line" ]; then
  ok "17 full pilot chain calls seed -> run -> verify in order"
else
  bad "17 full pilot chain calls seed -> run -> verify in order" "rc=$rc g=$g_line qi=$qi_line in=$in_line vf=$vf_line ssh=$ssh_line n_q=$n_q"
fi

# ---- 18: the pilot chain stops green at the real-disk gate (exit 0) ----
if [ "$rc" -eq 0 ] &&
  case "$out" in *"pilot green: $UDIR/pilot.qcow2 proved the install"*) true ;; *) false ;; esac &&
  case "$out" in *'full --yes --go-real'*) true ;; *) false ;; esac &&
  case "$in_qlog" in *'pilot.qcow2,if=virtio,format=qcow2'*) true ;; *) false ;; esac &&
  case "$out" in *FORMATTED*) false ;; *) true ;; esac then
  ok "18 pilot chain stops at the real-disk gate (message + exit 0, gate never fired)"
else
  bad "18 pilot chain stops at the real-disk gate (message + exit 0, gate never fired)" "rc=$rc out=$out"
fi

# ---- 19: full --go-real without a pilot run-manifest fails closed ----
mv "$man" "$man.saved"
: >"$STUB_LOG"
out="$(run_job '' YES full --yes --go-real --disk /dev/nvme0n1 --iso "$ISO" --user omarchy)"
rc=$?
mv "$man.saved" "$man"
if [ "$rc" -eq 2 ] &&
  case "$out" in *'pilot run-manifest'*) true ;; *) false ;; esac &&
  case "$out" in *'run the pilot chain first'*) true ;; *) false ;; esac &&
  ! grep -q '^qemu-system-x86_64 ' "$STUB_LOG"; then
  ok "19 full --go-real without pilot run-manifest exits 2 (pilot first)"
else
  bad "19 full --go-real without pilot run-manifest exits 2 (pilot first)" "rc=$rc out=$out stubs=$(cat "$STUB_LOG")"
fi

# ---- 20: full --go-real happy path: real gates + entry block hand-off ----
: >"$STUB_LOG"
BOOT_BUILD_STUB="$WORK/boot-build-stub"
cat >"$BOOT_BUILD_STUB" <<'SH'
#!/bin/sh
printf 'boot-build %s\n' "$*" >>"$HNGH_STUB_LOG"
[ "$1" = "emit-entry" ] || exit 2
printf '%s\n' '/Omarchy 4.0.4 (chainload nvme0n1 ESP)' '    protocol: efi' \
  '    path: guid(TEST-PARTUUID):/EFI/BOOT/BOOTX64.EFI'
exit 0
SH
chmod +x "$BOOT_BUILD_STUB"
out="$(run_job 'y
y
y
' YES full --yes --go-real --disk /dev/nvme0n1 --iso "$ISO" --user omarchy)"
rc=$?
q1="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | head -n 1)"
q2="$(grep '^qemu-system-x86_64 ' "$STUB_LOG" | tail -n 1)"
prompts="$(grep -o '\[y/N\]' <<<"$out" | wc -l)"
if [ "$rc" -eq 0 ] &&
  case "$q1" in *'file=/dev/nvme0n1,if=virtio,format=raw'*serial-install.log*) true ;; *) false ;; esac &&
  case "$q2" in *'file=/dev/nvme0n1,if=virtio,format=raw'*serial-verify.log*) true ;; *) false ;; esac &&
  ! grep -q '^qemu-img create' "$STUB_LOG"; then
  ok "20a full --go-real installs onto the real disk and verifies it (no pilot overlay)"
else
  bad "20a full --go-real installs onto the real disk and verifies it (no pilot overlay)" "rc=$rc q1=$q1 q2=$q2 stubs=$(cat "$STUB_LOG")"
fi
if [ "$rc" -eq 0 ] && [ "$prompts" -eq 3 ] &&
  case "$out" in *'REAL DISK: /dev/nvme0n1 will be FORMATTED'*) true ;; *) false ;; esac then
  ok "20b the real-disk FORMATTED y/N gate still asks exactly once"
else
  bad "20b the real-disk FORMATTED y/N gate still asks exactly once" "rc=$rc prompts=$prompts out=$out"
fi
if [ "$rc" -eq 0 ] &&
  case "$out" in *'omarchy-boot-build.sh emit-entry'*) true ;; *) false ;; esac &&
  case "$out" in *'chainload nvme0n1 ESP'*) true ;; *) false ;; esac &&
  case "$out" in *'/boot/EFI/limine/limine.conf'*'duplicate title'*) true ;; *) false ;; esac &&
  case "$out" in *'limine.conf.bak-'*) true ;; *) false ;; esac then
  ok "20c prints the emit-entry block + hand-edit steps for limine.conf"
else
  bad "20c prints the emit-entry block + hand-edit steps for limine.conf" "rc=$rc out=$out"
fi

# ---- 21: full --go-real reuses the seed (idempotent skip) ----
if [ "$rc" -eq 0 ] && ! grep -q '^genisoimage ' "$STUB_LOG" &&
  case "$out" in *'idempotent skip'*) true ;; *) false ;; esac then
  ok "21 full --go-real reuses the seeded workdir (idempotent skip, no new cidata)"
else
  bad "21 full --go-real reuses the seeded workdir (idempotent skip, no new cidata)" "rc=$rc out=$out stubs=$(cat "$STUB_LOG")"
fi

if [ "$fails" -eq 0 ]; then
  echo "test-omarchy-unattended-install: all proofs passed"
  exit 0
fi
echo "test-omarchy-unattended-install: $fails proof(s) FAILED"
exit 1
