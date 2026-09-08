#!/usr/bin/env bash
# hngh-omp-update — update oh-my-pi, its npm extensions, and
# billion-context on this desktop. Run locally or from the deck via ssh
# (Hngh omp Update shortcut). Plugins load on the next omp start; a
# running TUI keeps the old version until restarted.
set -u
OMP=/home/bricker/.bun/bin/omp

echo "=== omp self-update ==="
before="$($OMP --version 2>/dev/null)"
cd /home/bricker && npm install @oh-my-pi/pi-coding-agent@latest 2>&1 | tail -1
# NOTE: never run bare `omp update` here — it installed a stale 17.3.3 over 18.x
after="$($OMP --version 2>/dev/null)"
echo "omp: ${before:-?} -> ${after:-?}"

echo "=== omp extensions ==="
cd "$HOME/.omp/plugins" || exit 0
python3 - <<'PY' >/tmp/omp-deps.txt
import json
deps = json.load(open("package.json")).get("dependencies", {})
for name, spec in deps.items():
    if spec.startswith(("http", "file")):
        print(spec)          # re-pull source deps verbatim
    else:
        print(name + "@latest")
PY
while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  echo "-- $spec"
  "$OMP" plugin install "$spec" 2>&1 | tail -1
done </tmp/omp-deps.txt

echo "=== billion-context (npm global; the proxy) ==="
# billion-context-omp / billion-context-pi are deprecated (removed from
# omp 2026-08-24; hngh docs/records/2026-08-24-context-budget-and-toolchain.md)
# and must NOT be reinstalled — the maintained artifact is the bili proxy.
# npm, not bun: bili lives on PATH at ~/.npm-global/bin/bili.
npm install -g billion-context@latest 2>&1 | tail -1

echo "=== versions after ==="
"$OMP" --version
command -v bili >/dev/null 2>&1 && bili --version || echo "billion-context: MISSING from PATH"
echo "note: restart running omp TUIs to load updates"
