#!/usr/bin/env bash
# omarchy-unattended-install.sh -- stock Omarchy unattended install onto
# the target SSD via Omarchy's own ISO installer plus a cidata drive
# (user_configuration.json + user_credentials.json pair), driven from
# your own terminal. Runbook:
# docs/agent-notes/2026-10-05-omarchy-limine-boot-runbook.md
#
# Usage: omarchy-unattended-install.sh <seed|run|verify|help> [flags] [--dry-run|--yes]
#   --dry-run is the DEFAULT: the full plan is printed and nothing is
#   written. --yes executes; every privileged action still asks y/N
#   (default N) on the operator's TTY. HNGH_BOOT_CONFIRM=YES authorizes
#   --yes without a TTY (scripted run).
#
#   seed   build the cidata dir + cidata.iso under the SECRETS home
#   run    preflight + launch the unattended install VM
#   verify boot the installed target disk-only and judge the outcome
#
# Flags:
#   --disk DISK             target disk (REQUIRED seed/run; verify
#                           cross-checks it against the run-manifest)
#   --iso PATH              Omarchy install ISO (REQUIRED run; on seed it
#                           is the schema-provenance source)
#   --config-sample FILE    wizard-written reference config (seed, the
#                           other schema-provenance source)
#   --hostname NAME         default omarchy-hngh        (seed)
#   --timezone TZ           default America/New_York    (seed)
#   --keyboard LAYOUT       default us                  (seed)
#   --user NAME             installed account (REQUIRED with
#                           --credentials-hash; run reads it from the
#                           baked creds when omitted)
#   --credentials-hash HASH operator-generated `openssl passwd -6`
#                           output; this script NEVER generates one
#                           (seed; mutually exclusive with --defer)
#   --defer-provisioning    no-credentials install, first-boot user
#                           creation (seed)
#   --authorized-keys FILE  public keys for the installed user (seed)
#   --pilot | --real-disk   run target: pilot (DEFAULT) installs into a
#                           qcow2 overlay over DISK (backing untouched);
#                           --real-disk installs onto DISK and will be
#                           FORMATTED (its own y/N gate)
#
# Hard rules (fail-closed):
#   - secrets home split: the cidata dir + cidata.iso carry the
#     credentials hash and live under ~/.hngh-automation/omarchy-
#     unattended/<UTC-ts>/ (HNGH_SECRETS_HOME), NEVER under the repo or
#     ~/.hngh; the hash is REDACTED from every printed/logged line;
#   - schema is verified against the ISO's own omarchy-cidata-load (or a
#     --config-sample) when available; otherwise a loud SCHEMA-UNVERIFIED
#     warning names exactly what was not verified;
#   - an unmounted backing disk is REQUIRED (pilot mode included); a live
#     qemu on the disk is refused (never double-open);
#   - verify kills its VM on exit and never leaves a disk-only VM around.
#
# Env knobs:
#   HNGH_SECRETS_HOME   secrets home (default ~/.hngh-automation/omarchy-unattended)
#   HNGH_UNATTENDED_DIR cidata workdir (default: newest <UTC-ts> dir
#                       under the secrets home that holds cidata.iso)
#   HNGH_OVMF_CODE      default /usr/share/edk2/x64/OVMF_CODE.4m.fd
#   HNGH_OVMF_VARS      default /usr/share/edk2/x64/OVMF_VARS.4m.fd
#   HNGH_KVM_DEVICE     default /dev/kvm
#   HNGH_BOOT_LOGDIR    stage-log dir (default ~/.hngh/installer-logs)
#   HNGH_VERIFY_TIMEOUT   seconds (default 300)
#   HNGH_VERIFY_INTERVAL  seconds (default 10)
#   HNGH_PILOT_MIN_FREE_GB pilot free-space floor (default 30)
set -u

SECRETS_HOME="${HNGH_SECRETS_HOME:-$HOME/.hngh-automation/omarchy-unattended}"
UNATTENDED_DIR="${HNGH_UNATTENDED_DIR:-}"
OVMF_CODE="${HNGH_OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS="${HNGH_OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"
KVM_DEVICE="${HNGH_KVM_DEVICE:-/dev/kvm}"
VTIME="${HNGH_VERIFY_TIMEOUT:-300}"
VINT="${HNGH_VERIFY_INTERVAL:-10}"
PILOT_MIN_GB="${HNGH_PILOT_MIN_FREE_GB:-30}"

PHASE=""
DRY=1
DISK=""
ISO=""
SAMPLE=""
HOST_NAME=""
TZ=""
KB=""
USER_NAME=""
HASH=""
AKEYS=""
DEFER=0
REALDISK=0
WORKDIR=""

say() { printf '%s\n' "$*"; }
refuse() {
  printf 'omarchy-unattended-install: refused: %s\n' "$*" >&2
  exit 2
}
cannot() {
  printf 'omarchy-unattended-install: cannot %s (fail-closed)\n' "$*" >&2
  exit 2
}
confirm() {
  printf 'omarchy-unattended-install: %s [y/N] ' "$1"
  read -r ans || ans=""
  case "$ans" in
    y | Y | yes | YES) return 0;;
  esac
  say "aborted: $1 (operator answered no)"
  return 1
}
gate() {
  [ "$DRY" -eq 1 ] && return 0
  [ "${HNGH_BOOT_CONFIRM:-}" = "YES" ] && return 0
  [ -t 0 ] && return 0
  refuse "--yes but no TTY; set HNGH_BOOT_CONFIRM=YES to authorize non-interactive execution"
}
uuid4() { read -r u </proc/sys/kernel/random/uuid; printf '%s\n' "$u"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY=1
      shift;;
    --yes)
      DRY=0
      shift;;
    --help | -h)
      PHASE="help"
      break;;
    --disk | --iso | --config-sample | --hostname | --timezone | --keyboard | --user | --credentials-hash | --authorized-keys)
      opt="$1"
      [ $# -ge 2 ] || refuse "missing value for $opt"
      case "$opt" in
        --disk) DISK="$2";;
        --iso) ISO="$2";;
        --config-sample) SAMPLE="$2";;
        --hostname) HOST_NAME="$2";;
        --timezone) TZ="$2";;
        --keyboard) KB="$2";;
        --user) USER_NAME="$2";;
        --credentials-hash) HASH="$2";;
        --authorized-keys) AKEYS="$2";;
      esac
      shift 2;;
    --defer-provisioning)
      DEFER=1
      shift;;
    --pilot)
      REALDISK=0
      shift;;
    --real-disk)
      REALDISK=1
      shift;;
    -*)
      refuse "unknown flag $1 (see help)";;
    *)
      [ -z "$PHASE" ] || refuse "unexpected argument $1 (phase is already $PHASE)"
      PHASE="$1"
      shift;;
  esac
done

case "$PHASE" in
  help | '')
    if [ -z "$PHASE" ]; then
      refuse "missing phase (seed|run|verify|help)"
    fi
    ;;
esac

case "$PHASE" in
  seed | run | verify) ;;
  help) ;;
  *) refuse "unknown phase $PHASE (seed|run|verify|help)";;
esac

if [ "$PHASE" = "seed" ] || [ "$PHASE" = "run" ]; then
  [ -n "$DISK" ] || refuse "missing required --disk"
fi
if [ -n "$DISK" ]; then
  [[ "$DISK" =~ ^/dev/[a-zA-Z0-9/_-]+$ ]] || refuse "malformed --disk $DISK"
fi
[ -z "$HOST_NAME" ] || [[ "$HOST_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || refuse "malformed --hostname $HOST_NAME"
[ -z "$TZ" ] || [[ "$TZ" =~ ^[A-Za-z0-9_+/-]+$ ]] || refuse "malformed --timezone $TZ"
[ -z "$KB" ] || [[ "$KB" =~ ^[a-z0-9-]+$ ]] || refuse "malformed --keyboard $KB"
if [ -n "$USER_NAME" ]; then
  [[ "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || refuse "malformed --user $USER_NAME"
fi
if [ -n "$HASH" ]; then
  [[ "$HASH" =~ ^\$6\$[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$ ]] ||
    refuse "malformed --credentials-hash (expecting openssl passwd -6 output)"
fi

if [ "$PHASE" = "seed" ]; then
  [ "$REALDISK" -eq 0 ] || refuse "--real-disk does not apply to seed (it selects the run target)"
  [ -z "$ISO" ] || [ -f "$ISO" ] || refuse "--iso $ISO does not exist"
  [ -z "$SAMPLE" ] || [ -f "$SAMPLE" ] || refuse "--config-sample $SAMPLE does not exist"
  [ -z "$AKEYS" ] || [ -f "$AKEYS" ] || refuse "--authorized-keys $AKEYS does not exist"
  if [ -n "$HASH" ] && [ "$DEFER" -eq 1 ]; then
    refuse "--credentials-hash and --defer-provisioning are mutually exclusive"
  fi
  if [ -n "$HASH" ] && [ -z "$USER_NAME" ]; then
    refuse "--credentials-hash requires --user"
  fi
  if [ -z "$HASH" ] && [ "$DEFER" -eq 0 ]; then
    refuse "credentials source missing: give --credentials-hash with --user, or --defer-provisioning"
  fi
fi
if [ "$PHASE" = "run" ]; then
  for tok in "$SAMPLE" "$HASH" "$AKEYS" "$HOST_NAME" "$TZ" "$KB"; do
    [ -z "$tok" ] || refuse "seed-only flags do not apply to run (see help)"
  done
  [ "$DEFER" -eq 0 ] || refuse "--defer-provisioning does not apply to run (it is a seed input)"
  [ -n "$ISO" ] || refuse "missing required --iso"
  [ -f "$ISO" ] || refuse "--iso $ISO does not exist"
fi
if [ "$PHASE" = "verify" ]; then
  for tok in "$ISO" "$SAMPLE" "$HASH" "$AKEYS" "$USER_NAME" "$HOST_NAME" "$TZ" "$KB"; do
    [ -z "$tok" ] || refuse "verify reads the run-manifest only; seed/run flags do not apply"
  done
  [ "$DEFER" -eq 0 ] || refuse "--defer-provisioning does not apply to verify"
fi

# ---- schema provenance: the ISO's own omarchy-cidata-load is the
# ground truth for the cidata file pair and the JSON keys it consumes.
# Extraction uses BARE sfs-relative patterns (usr/... -- never
# squashfs-root/ prefixed); the file must appear under the extract dir.
extract_loader() {
  extract_iso="$1"
  extract_dst="$2"
  while IFS= read -r extract_off; do
    [ -n "$extract_off" ] || continue
    if unsquashfs -o "$extract_off" -d "$extract_dst" "$extract_iso" \
      usr/local/bin/omarchy-cidata-load \
      usr/share/omarchy-iso/orchestrator >/dev/null 2>&1; then
      [ -f "$extract_dst/usr/local/bin/omarchy-cidata-load" ] && return 0
    fi
  done <<EOF
$(grep -abo hsqs "$extract_iso" 2>/dev/null | cut -d: -f1)
EOF
  return 1
}

# consumed keys = quoted lower-case identifiers the consumer files
# reference (file names are dotted, so they never match).
consumed_keys() {
  cat "$@" 2>/dev/null |
    grep -oE "['\"][a-z_][a-z0-9_]*['\"]" |
    tr -d "'\"" |
    grep -v '^cidata$' |
    sort -u
}

emitted_keys() {
  grep -hoE '"[a-z_][a-z0-9_-]*"[[:space:]]*:' "$@" 2>/dev/null |
    tr -d '" :' |
    sort -u
}

join_lines() {
  join_out="$(cat)"
  printf '%s' "${join_out//$'\n'/ }"
}
# ---- phase: seed -- bake the cidata file pair in the secrets home ------
phase_seed() {
  [ -z "$HOST_NAME" ] && HOST_NAME="omarchy-hngh"
  [ -z "$TZ" ] && TZ="America/New_York"
  [ -z "$KB" ] && KB="us"

  if [ "$DRY" -eq 1 ]; then
    say "+ mkdir -p $SECRETS_HOME (0700) + workdir <utc timestamp> (0700)"
    say "+ probe $DISK size (lsblk -bno SIZE); main btrfs = size - 2148532224 - 1048576 (GPT reserve)"
    say "+ write cidata/user_configuration.json (guest device /dev/vda; 2GiB ESP + btrfs @ @home @log @pkg)"
    if [ "$DEFER" -eq 1 ]; then
      say "+ write empty cidata/defer-provisioning marker (no user_credentials.json)"
    else
      say "+ write cidata/user_credentials.json (password hashes REDACTED in all output)"
    fi
    say "+ schema provenance: extract omarchy-cidata-load from --iso, or --config-sample, else SCHEMA-UNVERIFIED"
    say "+ genisoimage -quiet -volid cidata -output <workdir>/cidata.iso <workdir>/cidata/"
    return 0
  fi

  mkdir -p "$SECRETS_HOME" 2>/dev/null
  chmod 700 "$SECRETS_HOME" 2>/dev/null
  seed_ts="$(date -u +%Y%m%dT%H%M%SZ)"
  WORKDIR="$SECRETS_HOME/$seed_ts"
  seed_try=0
  while ! mkdir "$WORKDIR" 2>/dev/null; do
    seed_try=$((seed_try + 1))
    [ "$seed_try" -le 9 ] || cannot "create a workdir under $SECRETS_HOME"
    WORKDIR="$SECRETS_HOME/$seed_ts-$seed_try"
  done
  chmod 700 "$WORKDIR"
  cidata="$WORKDIR/cidata"
  mkdir "$cidata"

  disk_bytes="$(lsblk -bno SIZE "$DISK" 2>/dev/null | head -n 1 | tr -d ' ')"
  [[ "$disk_bytes" =~ ^[0-9]+$ ]] || cannot "resolve $DISK size (lsblk -bno SIZE)"
  gap=1048576
  esp_size=2147483648
  esp_start=1048576
  main_start=2148532224
  main_size=$((disk_bytes - main_start - gap))
  [ "$main_size" -gt 1073741824 ] || cannot "fit a 2GiB ESP + root on $DISK ($disk_bytes bytes)"
  obj_esp="$(uuid4)"
  obj_root="$(uuid4)"

  # user_configuration.json: key-for-key what the omarchy-iso configurator
  # emits (archinstall 3.0.9 shape; disk_config carries NO disk_encryption
  # key). Guest device is always /dev/vda -- virtio is the only disk bus.
  defer_json=false
  [ "$DEFER" -eq 1 ] && defer_json=true
  config="$cidata/user_configuration.json"
  cat >"$config" <<JSON
{
    "app_config": null,
    "archinstall-language": "English",
    "auth_config": {},
    "audio_config": { "audio": "pipewire" },
    "bootloader_config": { "bootloader": "Limine", "uki": false, "removable": false },
    "custom_commands": [],
    "omarchy_install": {
        "mode": "full_disk",
        "defer_provisioning": $defer_json,
        "target_mount": "/mnt",
        "boot": {
            "esp_mount": "/boot",
            "esp_path": "/EFI/limine",
            "efi_binary": "limine_x64.efi",
            "enable_fallback": true
        },
        "storage": { "kernel": "linux-omarchy" }
    },
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/vda",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": null,
                        "flags": [ "boot", "esp" ],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "$obj_esp",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $esp_size },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $esp_start },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [
                            { "mountpoint": "/", "name": "@" },
                            { "mountpoint": "/home", "name": "@home" },
                            { "mountpoint": "/var/log", "name": "@log" },
                            { "mountpoint": "/var/cache/pacman/pkg", "name": "@pkg" }
                        ],
                        "dev_path": null,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": [ "compress=zstd" ],
                        "mountpoint": null,
                        "obj_id": "$obj_root",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $main_size },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $main_start },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    },
    "hostname": "$HOST_NAME",
    "kernels": [ "linux-omarchy" ],
    "network_config": { "type": "iso" },
    "ntp": true,
    "parallel_downloads": 8,
    "script": null,
    "services": [],
    "swap": true,
    "timezone": "$TZ",
    "locale_config": { "kb_layout": "$KB", "sys_enc": "UTF-8", "sys_lang": "en_US.UTF-8" },
    "mirror_config": {
        "custom_repositories": [],
        "custom_servers": [
            {"url": "https://mirror.omarchy.org/\$repo/os/\$arch"},
            {"url": "https://mirror.rackspace.com/archlinux/\$repo/os/\$arch"},
            {"url": "https://geo.mirror.pkgbuild.com/\$repo/os/\$arch"}
        ],
        "mirror_regions": {},
        "optional_repositories": []
    },
    "packages": [
        "base-devel",
        "git",
        "omarchy-keyring",
        "omarchy-settings",
        "omarchy"
    ],
    "profile_config": { "gfx_driver": null, "greeter": null, "profile": {} },
    "version": "3.0.9"
}
JSON

  # user_credentials.json: same shape the configurator writes. defer mode
  # writes NO credentials -- the empty marker below selects the no-password
  # path and first-boot provisioning picks up from live SSH.
  if [ "$DEFER" -eq 1 ]; then
    : >"$cidata/defer-provisioning"
  else
    creds="$cidata/user_credentials.json"
    cat >"$creds" <<JSON
{
    "root_enc_password": "$HASH",
    "users": [
        {
            "enc_password": "$HASH",
            "groups": [],
            "sudo": true,
            "username": "$USER_NAME"
        }
    ]
}
JSON
    printf 'Omarchy User\n' >"$cidata/user_full_name.txt"
    printf '\n' >"$cidata/user_email_address.txt"
  fi
  printf 'false\n' >"$cidata/user_encrypt_installation.txt"
  if [ -n "$AKEYS" ]; then
    cp "$AKEYS" "$cidata/authorized_keys"
  fi

  # ---- schema provenance (addendum): the ISO's own omarchy-cidata-load
  # is the ground truth. expected = the JSON keys that loader consumes.
  expected=""
  src_names=""
  if [ -n "$ISO" ]; then
    extract_loader "$ISO" "$WORKDIR/iso-extract" ||
      cannot "extract omarchy-cidata-load from $ISO (schema provenance)"
    loader="$WORKDIR/iso-extract/usr/local/bin/omarchy-cidata-load"
    orch="$WORKDIR/iso-extract/usr/share/omarchy-iso/orchestrator"
    if [ -f "$orch" ]; then
      expected="$(consumed_keys "$loader" "$orch")"
    else
      expected="$(consumed_keys "$loader")"
    fi
    src_names="ISO loader"
  fi
  if [ -n "$SAMPLE" ]; then
    expected="$(printf '%s\n%s\n' "$expected" "$(consumed_keys "$SAMPLE")" | sort -u)"
    src_names="$src_names + config sample"
  fi
  expected="$(printf '%s\n' "$expected" | sort -u)"

  if [ -z "$expected" ]; then
    printf 'omarchy-unattended-install: SCHEMA-UNVERIFIED: no --iso loader and no --config-sample was readable; the emitted user_configuration.json / user_credentials.json key names were NOT verified against the omarchy-cidata-load consumer\n' >&2
  else
    if [ -n "${creds:-}" ]; then
      emitted="$(emitted_keys "$config" "$creds")"
    else
      emitted="$(emitted_keys "$config")"
    fi
    missing=""
    for key in $expected; do
      if printf '%s\n' "$emitted" | grep -qx "$key"; then
        continue
      fi
      # defer mode emits no user_credentials.json by design (the loader
      # tolerates that); its keys cannot be parity-checked.
      if [ "$DEFER" -eq 1 ]; then
        case " root_enc_password enc_password username sudo groups " in
          *" $key "*) continue;;
        esac
      fi
      missing="$missing $key"
    done
    [ -z "$missing" ] ||
      cannot "emit a seed matching the loader schema; consumed but not emitted:$missing"
    say "schema parity: verified against$src_names (consumed keys: $(printf '%s\n' "$expected" | join_lines))"
  fi

  genisoimage -quiet -volid cidata -output "$WORKDIR/cidata.iso" "$cidata" >/dev/null 2>&1 ||
    cannot "build $WORKDIR/cidata.iso (genisoimage failed)"
  chmod 700 "$WORKDIR/cidata.iso" 2>/dev/null
  say "seed complete"
  say "  workdir: $WORKDIR"
  say "  config: $config"
  if [ "$DEFER" -eq 1 ]; then
    say "  credentials: none (defer-provisioning marker present)"
  else
    say "  credentials: $creds (enc_password=<redacted> root_enc_password=<redacted>)"
  fi
  say "  cidata iso: $WORKDIR/cidata.iso"
  say "next: omarchy-unattended-install.sh run --disk $DISK --iso <iso> --pilot"
}

# ---- phase: run -- install VM (pilot overlay by default) --------------
run_workdir() {
  if [ -n "$UNATTENDED_DIR" ]; then
    printf '%s' "$UNATTENDED_DIR"
    return 0
  fi
  run_newest=""
  for run_d in "$SECRETS_HOME"/*/; do
    [ -f "$run_d/cidata.iso" ] || continue
    run_newest="${run_d%/}"
  done
  [ -n "$run_newest" ] || cannot "find a seeded workdir under $SECRETS_HOME (seed first)"
  printf '%s' "$run_newest"
}

run_plan() {
  say "+ preflight: refuse if $DISK has mounted partitions, hosts the running system, or is held by qemu"
  say "+ check cidata.iso + iso sha256 + tools + $KVM_DEVICE + OVMF pair"
  if [ "$REALDISK" -eq 1 ]; then
    say "+ y/N gate: $DISK will be FORMATTED (no overlay; the installer writes the real disk)"
    say "+ sudo qemu-system-x86_64 ... -drive file=$DISK,if=virtio,format=raw ..."
  else
    say "+ warn if the workdir filesystem has under $PILOT_MIN_GB GiB free (space)"
    say "+ sudo qemu-img create -f qcow2 -b $DISK -F raw <workdir>/pilot.qcow2 (backing untouched)"
    say "+ sudo qemu-system-x86_64 ... -drive file=<workdir>/pilot.qcow2,if=virtio,format=qcow2 ..."
  fi
  say "+ sudo -v once; daemonize with -serial file:<workdir>/serial-install.log"
  say "+ write <workdir>/run-manifest and print the cidata detection watch"
}

phase_run() {
  if [ "$DRY" -eq 1 ]; then
    run_plan
    return 0
  fi
  gate
  WORKDIR="$(run_workdir)"
  [ -f "$WORKDIR/cidata.iso" ] || cannot "find $WORKDIR/cidata.iso (seed first)"
  [ -f "$ISO" ] || cannot "read --iso $ISO"

  mp="$(lsblk -no MOUNTPOINT "$DISK" 2>/dev/null | tr -d ' \n')"
  [ -z "$mp" ] ||
    refuse "$DISK has mounted partitions ($mp) -- unmount them; the backing disk must be idle (pilot mode included)"
  for probe_mp in / /boot; do
    probe_src="$(findmnt -n -o SOURCE "$probe_mp" 2>/dev/null)"
    [ -n "$probe_src" ] || continue
    probe_pk="$(lsblk -no PKNAME "$probe_src" 2>/dev/null | head -n 1 | tr -d ' ')"
    [ -n "$probe_pk" ] || probe_pk="${probe_src##*/}"
    [ "$probe_pk" = "${DISK##*/}" ] &&
      refuse "$probe_mp lives on $DISK (via $probe_src) -- refusing to touch the host system disk"
  done
  if pgrep -af qemu-system 2>/dev/null | grep -F "${DISK##*/}" >/dev/null 2>&1; then
    refuse "another qemu already uses ${DISK##*/} (pgrep -af qemu-system) -- stop it first"
  fi

  if [ ! -f "$ISO.sha256" ]; then
    say "# warning: $ISO.sha256 not found -- the iso checksum is not verified"
  fi
  for tool in qemu-system-x86_64 qemu-img; do
    command -v "$tool" >/dev/null 2>&1 || cannot "find $tool in PATH"
  done
  [ -r "$KVM_DEVICE" ] || cannot "read $KVM_DEVICE (hardware virtualization unavailable)"
  [ -f "$OVMF_CODE" ] || cannot "read OVMF_CODE $OVMF_CODE"
  [ -f "$OVMF_VARS" ] || cannot "read OVMF_VARS $OVMF_VARS"

  if [ "$REALDISK" -eq 1 ]; then
    confirm "REAL DISK: $DISK will be FORMATTED and overwritten (no pilot overlay)" || return 1
  fi

  vars_copy="$WORKDIR/OVMF_VARS.copy"
  if [ "$REALDISK" -eq 1 ]; then
    target="$DISK"
    drive_fmt="raw"
  else
    free_kb="$(df -Pk "$WORKDIR" 2>/dev/null | awk 'NR==2 {print $4}')"
    if [ -n "$free_kb" ] && [ "$free_kb" -lt $((PILOT_MIN_GB * 1048576)) ] 2>/dev/null; then
      say "# warning: only $((free_kb / 1048576)) GiB free for the pilot overlay (under $PILOT_MIN_GB GiB); the workdir filesystem is tight on space"
    fi
    target="$WORKDIR/pilot.qcow2"
    drive_fmt="qcow2"
    confirm "create the pilot overlay $target on top of $DISK (backing untouched) and launch the install VM" || return 1
    sudo -v || exit $?
    sudo qemu-img create -f qcow2 -b "$DISK" -F raw "$target" >/dev/null ||
      cannot "create the pilot overlay $target"
  fi
  if [ "$REALDISK" -eq 1 ]; then
    confirm "write the unattended install to $DISK and launch the install VM" || return 1
    sudo -v || exit $?
  fi
  cp "$OVMF_VARS" "$vars_copy" || cannot "stage the OVMF vars copy $vars_copy"
  serial="$WORKDIR/serial-install.log"
  sudo qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4 -vga std \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$vars_copy" \
    -cdrom "$ISO" \
    -drive "file=$target,if=virtio,format=$drive_fmt" \
    -drive "file=$WORKDIR/cidata.iso,if=virtio,format=raw,readonly=on" \
    -display none -daemonize -serial "file:$serial" ||
    cannot "launch the install VM (qemu-system-x86_64)"

  M_USER=""
  if [ -f "$WORKDIR/cidata/user_credentials.json" ]; then
    M_USER="$(grep -oE '"username"[[:space:]]*:[[:space:]]*"[^"]+"' \
      "$WORKDIR/cidata/user_credentials.json" | head -n 1 | cut -d'"' -f4)"
  fi
  manifest="$WORKDIR/run-manifest"
  cat >"$manifest" <<MAN
mode=$([ "$REALDISK" -eq 1 ] && printf real-disk || printf pilot)
target=$target
backing=$DISK
iso=$ISO
cidata=$WORKDIR/cidata.iso
install_serial=$serial
verify_serial=$WORKDIR/serial-verify.log
user=$M_USER
MAN
  chmod 700 "$manifest" 2>/dev/null

  say ""
  say "install VM daemonized (serial: $serial)"
  say "cidata consumption proof (host-side): the partition layout must APPEAR"
  say "on the target within minutes -- an unconsumed cidata leaves the wizard"
  say "interactive forever, so the layout change IS the detection signal (the"
  say "serial stays tiny, ~425 bytes). Watch it with:"
  if [ "$REALDISK" -eq 1 ]; then
    say "  watch -n 10 lsblk -o NAME,SIZE,FSTYPE $DISK"
  else
    say "  watch -n 10 'qemu-img info $target | grep -E \"virtual size|disk size\"'"
  fi
  say "no layout after ~10 minutes means the cidata was NOT consumed: check the"
  say "seed files under $WORKDIR/cidata (SCHEMA-UNVERIFIED seeds first)."
  say "next: omarchy-unattended-install.sh verify --yes"
}

# ---- phase: verify -- boot the target disk-only and prove it ----------
verify_cleanup() {
  while IFS= read -r vline; do
    [ -n "$vline" ] || continue
    vpid="${vline%% *}"
    say "# verify cleanup: stopping the verify VM (pid $vpid)"
    sudo kill "$vpid" 2>/dev/null
  done <<CLEAN
$(pgrep -af qemu-system 2>/dev/null | grep -F "${vars_copy:-__none__}")
CLEAN
}

verify_plan() {
  say "+ read $WORKDIR/run-manifest (mode/target/backing/verify_serial/user)"
  say "+ refuse if any qemu is alive or the backing disk has mounted partitions"
  say "+ y/N gate + sudo -v once"
  say "+ sudo qemu-system-x86_64 ... -drive file=<manifest target>,if=virtio,format=<fmt> -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 ..."
  say "+ poll the serial (boot marker + ssh probe) and print the verdict table"
  say "+ kill the verify VM on exit (cleanup trap; never leave it running)"
}

phase_verify() {
  if [ "$DRY" -eq 1 ]; then
    verify_plan
    return 0
  fi
  gate
  WORKDIR="$(run_workdir)"
  manifest="$WORKDIR/run-manifest"
  [ -f "$manifest" ] || cannot "find $WORKDIR/run-manifest -- run phase first"
  m_mode="$(grep -E '^mode=' "$manifest" | head -n 1 | cut -d= -f2-)"
  m_target="$(grep -E '^target=' "$manifest" | head -n 1 | cut -d= -f2-)"
  m_backing="$(grep -E '^backing=' "$manifest" | head -n 1 | cut -d= -f2-)"
  m_serial="$(grep -E '^verify_serial=' "$manifest" | head -n 1 | cut -d= -f2-)"
  m_user="$(grep -E '^user=' "$manifest" | head -n 1 | cut -d= -f2-)"
  case "$m_mode" in
    pilot) vfmt="qcow2";;
    real-disk) vfmt="raw";;
    *) cannot "read mode=$m_mode from $manifest (expecting pilot or real-disk)";;
  esac
  [ -n "$m_target" ] || cannot "read target= from $manifest"
  [ -n "$m_backing" ] || cannot "read backing= from $manifest"
  [ -n "$m_serial" ] || cannot "read verify_serial= from $manifest"
  if [ -n "$DISK" ] && [ "$DISK" != "$m_backing" ]; then
    refuse "--disk $DISK does not match the manifest backing $m_backing"
  fi

  mp="$(lsblk -no MOUNTPOINT "$m_backing" 2>/dev/null | tr -d ' \n')"
  [ -z "$mp" ] || refuse "$m_backing has mounted partitions ($mp) -- the backing disk must be idle"
  if [ "$m_mode" = "pilot" ] && [ ! -f "$m_target" ]; then
    cannot "find the pilot overlay $m_target (run phase first)"
  fi
  if pgrep -af qemu-system >/dev/null 2>&1; then
    refuse "a qemu process is alive (pgrep -af qemu-system) -- never double-open the target; stop it first"
  fi
  for tool in qemu-system-x86_64 ssh; do
    command -v "$tool" >/dev/null 2>&1 || cannot "find $tool in PATH"
  done
  [ -f "$OVMF_CODE" ] || cannot "read OVMF_CODE $OVMF_CODE"
  [ -f "$OVMF_VARS" ] || cannot "read OVMF_VARS $OVMF_VARS"

  confirm "boot the target $m_target disk-only and verify the unattended install" || return 1
  sudo -v || exit $?
  vars_copy="$WORKDIR/OVMF_VARS.copy"
  cp "$OVMF_VARS" "$vars_copy" || cannot "stage the OVMF vars copy $vars_copy"
  trap verify_cleanup EXIT
  sudo qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 4 -vga std \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$vars_copy" \
    -drive "file=$m_target,if=virtio,format=$vfmt" \
    -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
    -display none -daemonize -serial "file:$m_serial" ||
    cannot "launch the verify VM (qemu-system-x86_64)"

  # Poll until ssh proves the first boot or the deadline passes. The serial
  # crosses the 425-byte floor once the guest really writes it; the marker
  # proves the boot chain reached multi-user.
  deadline=$((SECONDS + VTIME))
  verdict="TIMEOUT"
  while [ "$SECONDS" -lt "$deadline" ]; do
    ser_size="$(wc -c <"$m_serial" 2>/dev/null || printf 0)"
    if [ "$ser_size" -gt 425 ] 2>/dev/null; then
      if grep -q 'Reached target SSH Access Available' "$m_serial" 2>/dev/null ||
        grep -q 'SSH-' "$m_serial" 2>/dev/null; then
        verdict="BOOT_ONLY"
        if [ -n "$m_user" ] &&
          ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 "$m_user@127.0.0.1" true 2>/dev/null; then
          verdict="BOOTED+SSH"
          break
        fi
      fi
    fi
    sleep "$VINT"
  done

  say ""
  say "verdict: $verdict"
  case "$verdict" in
    BOOTED+SSH)
      say "proven complete: boot chain + kernel + initramfs + ssh first boot all green"
      say "serial: $m_serial"
      return 0;;
    BOOT_ONLY)
      say "booted but no ssh: check the cidata authorized_keys / user credentials"
      say "serial: $m_serial";;
    *)
      say "TIMEOUT after ${VTIME}s: serial stayed under the 425-byte floor"
      say "serial: $m_serial"
      say "tail: $(tail -n 5 "$m_serial" 2>/dev/null)";;
  esac
  return 1
}

usage() {
  cat <<USAGE
omarchy-unattended-install.sh -- unattended stock Omarchy reinstall (cidata)

usage: omarchy-unattended-install.sh <seed|run|verify|help> [flags] [--dry-run|--yes]

phases:
  seed    bake the cidata file pair + cidata.iso in the secrets home
  run     launch the install VM (pilot qcow2 overlay by default)
  verify  boot the target disk-only and prove the install

flags:
  --disk PATH              target disk (required for seed/run)
  --iso PATH               Omarchy ISO (run; seed reads its schema from it)
  --credentials-hash HASH  openssl passwd -6 hash (seed; REDACTED everywhere)
  --defer-provisioning     empty marker instead of credentials (seed)
  --config-sample FILE     wizard-written user_configuration.json reference (seed)
  --authorized-keys FILE   ssh public key file (seed)
  --user NAME              login user for the hash (seed)
  --hostname NAME          guest hostname (seed; default omarchy-hngh)
  --timezone TZ            guest timezone (seed; default America/New_York)
  --keyboard LAYOUT        guest keyboard (seed; default us)
  --pilot                  qcow2 overlay install (DEFAULT; backing untouched)
  --real-disk              install straight onto --disk (FORMATTED; own y/N gate)
  --dry-run                print the plan, touch nothing (DEFAULT)
  --yes                    attended run: one sudo -v + y/N confirmations

hard rules: secrets live in the secrets home (HNGH_SECRETS_HOME), never the
repo or the installer log dir; hashes are REDACTED in all output; the cidata
schema is verified against the ISO's own omarchy-cidata-load or loudly
SCHEMA-UNVERIFIED; the backing disk must be unmounted and qemu-free; verify
always kills its VM on exit; nothing ever reboots the host or touches NVRAM.
USAGE
}

# ---- live stage log: every run mirrors stdout+stderr to a timestamped
# log (tee flushes per line). Dry-runs log too -- the plan IS the review
# artifact. help prints below and writes no log.
mode=dry-run
[ "$DRY" -eq 0 ] && mode=REAL
case "$PHASE" in
  seed | run | verify)
    now="$(date -u +%Y%m%dT%H%M%SZ)"
    logdir="${HNGH_BOOT_LOGDIR:-$HOME/.hngh/installer-logs}"
    if mkdir -p "$logdir" 2>/dev/null && [ -d "$logdir" ]; then
      exec > >(tee -a "$logdir/$PHASE-$now.log") 2>&1
      say "== omarchy-unattended-install phase=$PHASE mode=$mode $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
    fi
    ;;
  *) ;;
esac

case "$PHASE" in
  help | '') usage;;
  seed) phase_seed;;
  run) phase_run;;
  verify) phase_verify;;
esac
exit $?
