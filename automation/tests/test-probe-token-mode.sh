#!/usr/bin/env bash
# test-probe-token-mode.sh — credential-health probe_token must gate the
# unsloth token file on mode 600 before reading or sending it (the kimi
# leg's stat -c %a shape): too-open -> the literal http code "too-open"
# (a non-2xx/3xx code like any failure, flowable through the job's ok()
# classification), the file never read, no curl spawned, no value sent.
# A 600 file still probes authenticated. Mirrors
# tests/scripts/test-probe-model-route.py ProbeTokenMode (f809a05f).
# Hermetic: fake curl records argv+stdin; no network.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
mkdir -p "$sb/bin"
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# fake curl: records argv and stdin, never touches the network.
cat >"$sb/bin/curl" <<EOF
#!/usr/bin/env bash
printf 'ARGV:%s\n' "\$*" >>"$sb/curl-argv.log"
cat - >>"$sb/curl-stdin.log"
printf '200'
exit 0
EOF
chmod +x "$sb/bin/curl"
: >"$sb/curl-argv.log"; : >"$sb/curl-stdin.log"

# extract probe_token from the job (single source of truth, no copied
# logic): from its header comment through the function's closing brace.
job="$sb/job.sh"
sed -n '/^# authenticated probe of the unsloth/,/^}/p' \
  "$root/jobs/credential-health.sh" >"$job"
# shellcheck disable=SC1090
. "$job"
type probe_token >/dev/null 2>&1 || { echo "FAIL: probe_token not extracted"; exit 1; }

run_probe() { # -> stdout of probe_token
  (
    export PATH="$sb/bin:$PATH"
    export TOKEN_FILE="$1"
    export UNSLOTH_URL=http://127.0.0.1:1
    probe_token
  )
}
tok="$sb/unsloth.token"
printf 'unsloth-secret-1\n' >"$tok"

# 1. 0644: refused as "too-open" before any read or send.
chmod 644 "$tok"
: >"$sb/curl-argv.log"; : >"$sb/curl-stdin.log"
out="$(run_probe "$tok")"
ck "0644: reported as too-open" "too-open" "$out"
ck "0644: curl never spawned" "0" "$(wc -l <"$sb/curl-argv.log" | tr -d ' ')"
grep -q 'unsloth-secret' "$sb/curl-argv.log" "$sb/curl-stdin.log" 2>/dev/null &&
  got=leaked || got=never-read
ck "0644: value never read or sent" "never-read" "$got"

# 2. the 0600 control: authenticated probe proceeds (fake curl answers).
chmod 600 "$tok"
: >"$sb/curl-argv.log"; : >"$sb/curl-stdin.log"
out="$(run_probe "$tok")"
ck "0600: probe answered" "200" "$out"
ck "0600: curl spawned once" "1" "$(wc -l <"$sb/curl-argv.log" | tr -d ' ')"
grep -q 'unsloth-secret' "$sb/curl-stdin.log" && got=sent || got=missing
ck "0600: key reached the request" "sent" "$got"

# 3. missing file: existing "missing" contract pinned.
out="$(run_probe "$sb/absent.token")"
ck "absent: reported missing" "missing" "$out"

[ "$fails" = 0 ] && echo "test-probe-token-mode: all pass" || {
  echo "test-probe-token-mode: $fails failure(s)"
  exit 1
}
