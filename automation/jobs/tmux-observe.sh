#!/usr/bin/env bash
# tmux-observe.sh - stall-recovery step 4: detached tmux session "hngh-obs"
# with one labeled pane per running overnight session log (mtime within
# OBS_MAX_AGE_S, default 300 -- matches sessions-feed.py LIVE_S). Each pane
# renders the log colored via pygmentize -g, then live-tails it plain
# (pygmentize buffers stdin until EOF, so `tail -f | pygmentize` hangs).
# Fail-closed: missing binary or no fresh logs -> exit 0 with a breadcrumb.
# UI-launcher surface: spawned by dashboard-server via ui-config launchers.
set -u
AUTOMATION_ROOT="${AUTOMATION_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
say() { echo "tmux-observe: $*" >&2; }

command -v tmux >/dev/null 2>&1 || { say "no tmux binary; nothing to observe"; exit 0; }
pyg="$(command -v pygmentize 2>/dev/null)" || { say "no pygmentize; nothing to observe"; exit 0; }

max_age_s="${OBS_MAX_AGE_S:-300}"
cutoff=$(( $(date +%s) - max_age_s ))
mapfile -t logs < <(find "$AUTOMATION_ROOT/logs" -maxdepth 1 -name 'overnight-*.log' \
  -newermt "@$cutoff" -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn | cut -d' ' -f2- | head -n "${MAX_PANES:-9}")
[ "${#logs[@]}" -gt 0 ] || { say "no running overnight sessions (mtime within ${max_age_s}s)"; exit 0; }

tmux has-session -t hngh-obs 2>/dev/null && tmux kill-session -t hngh-obs

session_made=0
pane_id=""
labels=""
built=0
for log in "${logs[@]}"; do
  base="${log##*/}"; base="${base%.log}"; label="${base#overnight-}"
  cmd="printf '### ${label}\n\n'; '${pyg}' -g '${log}' 2>/dev/null; exec tail -n0 -f '${log}'"
  if [ "$session_made" = 0 ]; then
    # roomy detached geometry: 80x24 default cannot tile MAX_PANES panes
    pane_id="$(tmux new-session -d -x "${OBS_WIDTH:-220}" -y "${OBS_HEIGHT:-50}" \
      -s hngh-obs -n obs -P -F '#{pane_id}' "$cmd")" && session_made=1
  else
    pane_id="$(tmux split-window -d -P -F '#{pane_id}' -t hngh-obs "$cmd")" || pane_id=""
  fi
  # tmux 3.7c refuses some splits against a stacked layout until it is
  # re-tiled; tiling after every pane keeps the next split eligible
  tmux select-layout -t hngh-obs:obs tiled 2>/dev/null
  [ -n "$pane_id" ] || { say "skipped ${label}: tmux refused the pane"; continue; }
  built=$((built + 1))
  tmux select-pane -T "$label" -t "$pane_id"
  labels="$labels $label"
done

tmux set-option -w -t hngh-obs:obs pane-border-status top
tmux set-option -w -t hngh-obs:obs pane-border-format ' #{pane_title} '
say "hngh-obs: ${built} pane(s):$labels"
exit 0
