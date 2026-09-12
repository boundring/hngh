# comfyui.sh -- transient ComfyUI lifecycle helpers (hngh-operated
# per-run managed start; operator directive 2026-09-12 supersedes the
# operator-run posture). Spawn -> poll /health -> use -> stop, all
# inside the imagegen-submit run process; never a daemon, no systemd
# unit. Fail-closed: a failed start returns nonzero and the caller
# falls back to the free bootstrap leg -- the managed server is an
# upgrade, never a dependency.
#
# VRAM interplay: the caller runs the single authoritative VRAM/load
# gate (imagegen-submit) BEFORE calling comfyui_start -- one gate
# decides "can we run imagegen at all"; no second check here.
#
# Test seams: COMFYUI_DIR, COMFYUI_PY, COMFYUI_PORT, COMFYUI_START_TIMEOUT
# (default 90s: torch import + model wiring measured ~30-90s),
# COMFYUI_POLL_INTERVAL (default 2s), COMFYUI_LOG. curl stubbed via PATH.
set -u

ch="${HOME:-/nonexistent}"
COMFYUI_DIR="${COMFYUI_DIR:-/opt/comfyui}"
COMFYUI_PY="${COMFYUI_PY:-$ch/.local/share/comfyui-venv312/bin/python}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
COMFYUI_START_TIMEOUT="${COMFYUI_START_TIMEOUT:-90}"
COMFYUI_POLL_INTERVAL="${COMFYUI_POLL_INTERVAL:-2}"
COMFYUI_LOG="${COMFYUI_LOG:-}"

comfyui_base() { printf 'http://127.0.0.1:%s' "$COMFYUI_PORT"; }

comfyui_healthy() { # [base-url] -> 0 if GET /health or / is HTTP 200
 local base="${1:-$(comfyui_base)}" c
 c="$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "$base/health" 2>/dev/null)" || c=000
 [ "$c" = 200 ] && return 0
 c="$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "$base/" 2>/dev/null)" || c=000
 [ "$c" = 200 ]
}

comfyui_start() { # -> "<pid> <seconds>" on stdout; nonzero + kill on timeout
 local t0="$SECONDS" deadline=$((SECONDS + COMFYUI_START_TIMEOUT)) pid log c
 log="${COMFYUI_LOG:-$ch/.local/share/comfyui/managed-start-$(date -u +%Y%m%dT%H%M%SZ)-$$.log}"
 mkdir -p "$(dirname "$log")" || return 1
 (
  cd "$COMFYUI_DIR" 2>/dev/null || exit 127
  exec "$COMFYUI_PY" main.py --listen 127.0.0.1 --port "$COMFYUI_PORT" \
   --user-directory "$ch/.local/share/comfyui/user" \
   --output-directory "$ch/.local/share/comfyui/output" \
   --temp-directory "$ch/.local/share/comfyui/temp" \
   --extra-model-paths-config "$ch/.config/comfyui/extra_model_paths.yaml"
 ) >"$log" 2>&1 &
 pid=$!
 while [ "$SECONDS" -lt "$deadline" ]; do
  if comfyui_healthy; then
   printf '%s %s\n' "$pid" "$((SECONDS - t0))"
   return 0
  fi
  kill -0 "$pid" 2>/dev/null || {
   echo "comfyui: managed start: server exited early (log: $log)" >&2
   return 1
  }
  sleep "$COMFYUI_POLL_INTERVAL"
 done
 echo "comfyui: managed start: not healthy within ${COMFYUI_START_TIMEOUT}s (log: $log) -- killing" >&2
 comfyui_stop "$pid"
 return 1
}

comfyui_stop() { # pid -> best-effort TERM/kill + reap + confirm port refuses
 local pid="${1:-}" i
 [ -n "$pid" ] || return 0
 kill "$pid" 2>/dev/null || true
 for i in 1 2 3 4 5 6 7 8 9 10; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
 done
 kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
 wait "$pid" 2>/dev/null || true
 if curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:${COMFYUI_PORT}/" 2>/dev/null; then
  echo "comfyui: warning: port ${COMFYUI_PORT} still answers after stop of $pid" >&2
 fi
 return 0
}
