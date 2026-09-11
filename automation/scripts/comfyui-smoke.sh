#!/usr/bin/env bash
# comfyui-smoke.sh -- one-shot verify: POST workflow, poll /history, fetch /view.
# usage: comfyui-smoke.sh [workflow_json] [poll_seconds]
set -u
wf="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/comfyui-smoke-workflow.json}"
poll_s="${2:-900}"
base="${IMAGEGEN_URL:-http://127.0.0.1:8188}"

code="$(curl -sS --max-time 30 -o /tmp/smoke-post.json -w '%{http_code}' \
  -H 'Content-Type: application/json' -d "{\"prompt\": $(cat "$wf")}" "$base/prompt")" || code=000
echo "POST /prompt -> $code"
[ "$code" = 200 ] || {
  cat /tmp/smoke-post.json
  exit 1
}
pid="$(jq -r .prompt_id /tmp/smoke-post.json)"
echo "prompt_id=$pid"

deadline=$(($(date +%s) + poll_s))
while [ "$(date +%s)" -lt "$deadline" ]; do
  curl -sS "$base/history/$pid" -o /tmp/smoke-hist.json || true
  st="$(jq -r --arg p "$pid" '.[$p].status.status_str // "running"' /tmp/smoke-hist.json 2>/dev/null)"
  [ "$st" = "success" ] && break
  if [ "$st" = "error" ]; then
    echo "GENERATION ERROR"
    jq '.[$p]' --arg p "$pid" /tmp/smoke-hist.json | head -40
    exit 1
  fi
  sleep 10
done
[ "$st" = "success" ] || {
  echo "TIMEOUT status=$st"
  exit 1
}

fn="$(jq -r --arg p "$pid" '.[$p].outputs | to_entries[0].value.images[0] | "\(.filename) \(.subfolder) \(.type)"' /tmp/smoke-hist.json)"
file="$(printf '%s' "$fn" | cut -d' ' -f1)"
sub="$(printf '%s' "$fn" | cut -d' ' -f2)"
echo "image=$file sub=$sub"
curl -sS --fail -G "$base/view" --data-urlencode "filename=$file" \
  --data-urlencode "subfolder=$sub" --data-urlencode "type=output" \
  -o /tmp/smoke-out.png && file /tmp/smoke-out.png && ls -l /tmp/smoke-out.png
