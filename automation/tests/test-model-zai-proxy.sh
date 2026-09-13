#!/usr/bin/env bash
# test-model-zai-proxy.sh — the zai leg rides the operator's bili compression
# proxy: when the combined CA file exists, the primary curl attempt carries
# --cacert <combined-ca.pem> and NO --noproxy; if the proxied attempt fails at
# the transport layer (bili not running), the leg falls back ONCE to the old
# direct attempt (--noproxy api.z.ai). Without the CA file (bili not
# installed) the leg keeps the direct bypass. BILI_CA_FILE overrides the CA
# path. Other legs (kimi/ocgo/remote) keep plain proxying: their curl args
# must carry neither flag. Hermetic: stub curl on PATH records its args.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/bin" "$sb/lib" "$sb/.local/share/billion-context/ca"
: >"$sb/curl-args.log"
cat >"$sb/bin/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$sb/curl-args.log"
mode="\$(cat "$sb/curl-mode" 2>/dev/null || printf ok)"
if [ "\$mode" = failproxied ] && ! printf '%s\n' "\$*" | grep -q -- '--noproxy'; then
  # proxied attempt: transport-level failure (bili down)
  printf '000 0'
  exit 0
fi
prev=
for a in "\$@"; do
  [ "\$prev" = "-o" ] && printf '{"choices":[{"message":{"content":"ok"}}]}' >"\$a"
  prev="\$a"
done
printf '200 0.1'
STUB
chmod +x "$sb/bin/curl"
cafile="$sb/.local/share/billion-context/ca/combined-ca.pem"
touch "$cafile"

run_zai() { # extra env... -> zai_chat stdout with stubbed transport
 env -i PATH="$sb/bin:/usr/bin:/bin" HOME="$sb" \
  AUTOMATION_ROOT="$root" HNGH_TELEMETRY_DB="$sb/none.db" \
  Z_AI_API_KEY=stubkey ZAI_MODEL=stub-model MODEL_TIMEOUT=5 \
  HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1 "$@" \
  bash -c '. "'"$root"'/lib/model.sh";
   zai_pace_blocked() { return 1; }
   printf "hi" | zai_chat "hi" 8'
}
assert() { # label pattern file
 if grep -q -- "$2" "$3"; then echo "ok: $1"; else
  echo "FAIL: $1 — args: $(cat "$sb/curl-args.log")"
  return 1
 fi
}
fails=0

# 1. CA file present: primary attempt rides the proxy with the combined CA,
#    no --noproxy, and zai_chat answers from it.
printf ok >"$sb/curl-mode"
: >"$sb/curl-args.log"
out="$(run_zai)" || {
 echo "FAIL: zai_chat errored (proxied)"
 exit 1
}
assert "zai curl carries --cacert (combined CA)" "--cacert $cafile" "$sb/curl-args.log" || fails=1
[ "$(grep -c -- '--cacert' "$sb/curl-args.log")" = 1 ] || {
 echo "FAIL: expected a single primary attempt, got: $(cat "$sb/curl-args.log")"
 fails=1
}
grep -v -- '--noproxy' "$sb/curl-args.log" | grep -q -- '--cacert' || {
 echo "FAIL: primary attempt unexpectedly bypasses proxy: $(cat "$sb/curl-args.log")"
 fails=1
}
[ "$out" = "ok" ] || {
 echo "FAIL: unexpected output [$out]"
 fails=1
}

# 2. BILI_CA_FILE override wins over the default path.
rm -f "$cafile"
ca2="$sb/alt-ca.pem"
touch "$ca2"
printf ok >"$sb/curl-mode"
: >"$sb/curl-args.log"
run_zai BILI_CA_FILE="$ca2" >/dev/null || {
 echo "FAIL: zai_chat errored (override)"
 fails=1
}
assert "BILI_CA_FILE override honored" "--cacert $ca2" "$sb/curl-args.log" || fails=1
grep -q -- '--noproxy' "$sb/curl-args.log" && {
 echo "FAIL: proxied attempt unexpectedly bypasses: $(cat "$sb/curl-args.log")"
 fails=1
}
touch "$cafile"

# 3. Proxied attempt fails at transport layer (bili down): exactly one
#    fallback to the direct --noproxy attempt, which serves the answer.
printf failproxied >"$sb/curl-mode"
: >"$sb/curl-args.log"
out="$(run_zai)" || {
 echo "FAIL: zai_chat errored (fallback)"
 exit 1
}
[ "$(grep -c -- '--noproxy api.z.ai' "$sb/curl-args.log")" = 1 ] || {
 echo "FAIL: expected exactly one direct fallback attempt: $(cat "$sb/curl-args.log")"
 fails=1
}
[ "$(grep -c -- '--cacert' "$sb/curl-args.log")" = 1 ] || {
 echo "FAIL: expected exactly one proxied attempt before fallback"
 fails=1
}
[ "$out" = "ok" ] || {
 echo "FAIL: fallback did not serve the answer [$out]"
 fails=1
}
printf ok >"$sb/curl-mode"

# 4. No CA file (bili not installed): direct bypass, no --cacert.
rm -f "$cafile"
: >"$sb/curl-args.log"
out="$(run_zai)" || {
 echo "FAIL: zai_chat errored (no CA)"
 exit 1
}
assert "no-CA: zai curl bypasses via --noproxy api.z.ai" "--noproxy api.z.ai" "$sb/curl-args.log" || fails=1
grep -q -- '--cacert' "$sb/curl-args.log" && {
 echo "FAIL: no-CA run unexpectedly carries --cacert: $(cat "$sb/curl-args.log")"
 fails=1
}
touch "$cafile"

# 5. kimi leg keeps plain proxying: neither flag.
: >"$sb/curl-args.log"
env -i PATH="$sb/bin:/usr/bin:/bin" HOME="$sb" \
 AUTOMATION_ROOT="$root" HNGH_TELEMETRY_DB="$sb/none.db" MODEL_TIMEOUT=5 \
 KIMI_API_KEY=stubkey KIMI_MODEL=stub-model KIMI_URL="$sb/nohost.test/v1" \
 HTTPS_PROXY=http://127.0.0.1:1 \
 bash -c '. "'"$root"'/lib/model.sh"; printf "hi" | kimi_chat "hi" 8' >/dev/null 2>&1
grep -q -- '--noproxy' "$sb/curl-args.log" && {
 echo "FAIL: kimi leg unexpectedly bypasses proxy: $(cat "$sb/curl-args.log")"
 fails=1
}
grep -q -- '--cacert' "$sb/curl-args.log" && {
 echo "FAIL: kimi leg unexpectedly carries --cacert"
 fails=1
}

exit $fails
