#!/usr/bin/env bash
# test-model-zai-noproxy.sh — the zai leg's curl bypasses HTTPS_PROXY:
# a local filtering proxy (127.0.0.1 MITM) breaks TLS to api.z.ai, so the
# zai leg must pass --noproxy api.z.ai to curl. Other legs (kimi/ocgo/
# remote) keep proxying: their curl args must NOT carry the flag. Hermetic:
# stub curl on PATH records its args and returns a canned completion.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/bin" "$sb/lib"
: >"$sb/curl-args.log"
cat >"$sb/bin/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$sb/curl-args.log"
# write a canned completion to the -o target so _post_chat parses it
prev=
for a in "\$@"; do
  [ "\$prev" = "-o" ] && printf '{"choices":[{"message":{"content":"ok"}}]}' >"\$a"
  prev="\$a"
done
printf '200 0.1'
STUB
chmod +x "$sb/bin/curl"

run_zai() { # extra env -> zai_chat stdout with stubbed transport
 env -i PATH="$sb/bin:/usr/bin:/bin" HOME="$sb" \
  AUTOMATION_ROOT="$root" HNGH_TELEMETRY_DB="$sb/none.db" \
  Z_AI_API_KEY=stubkey ZAI_MODEL=stub-model MODEL_TIMEOUT=5 \
  HTTPS_PROXY=http://127.0.0.1:1 HTTP_PROXY=http://127.0.0.1:1 \
  bash -c '. "'"$root"'/lib/model.sh";
   zai_pace_blocked() { return 1; }
   printf "hi" | zai_chat "hi" 8'
}

fails=0
out="$(run_zai)" || {
 echo "FAIL: zai_chat errored"
 exit 1
}
grep -q -- '--noproxy api.z.ai' "$sb/curl-args.log" &&
 echo "ok: zai curl carries --noproxy api.z.ai" || {
 echo "FAIL: zai curl args lack --noproxy: $(cat "$sb/curl-args.log")"
 fails=1
}
[ "$out" = "ok" ] || {
 echo "FAIL: unexpected zai_chat output [$out]"
 fails=1
}

: >"$sb/curl-args.log"
env -i PATH="$sb/bin:/usr/bin:/bin" HOME="$sb" \
 AUTOMATION_ROOT="$root" HNGH_TELEMETRY_DB="$sb/none.db" MODEL_TIMEOUT=5 \
 KIMI_API_KEY=stubkey KIMI_MODEL=stub-model KIMI_URL="$sb/nohost.test/v1" \
 HTTPS_PROXY=http://127.0.0.1:1 \
 bash -c '. "'"$root"'/lib/model.sh"; printf "hi" | kimi_chat "hi" 8' >/dev/null 2>&1
if grep -q -- '--noproxy' "$sb/curl-args.log"; then
 echo "FAIL: kimi leg unexpectedly proxied-off: $(cat "$sb/curl-args.log")"
 fails=1
else
 echo "ok: kimi leg keeps the proxy (no --noproxy)"
fi
exit $fails
