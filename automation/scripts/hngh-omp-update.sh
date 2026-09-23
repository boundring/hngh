#!/usr/bin/env bash
# hngh-omp-update — update oh-my-pi, its npm extensions, and
# billion-context on this desktop. Run locally or from the deck via ssh
# (Hngh omp Update shortcut). Plugins load on the next omp start; a
# running TUI keeps the old version until restarted.
set -u
. "$(cd "$(dirname "$0")/../lib" && pwd)/prereqs.sh"
require_bins python3 npm || exit 1
OMP="$HOME/.bun/bin/omp"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)" # resolve before any cd

echo "=== omp self-update ==="
before="$($OMP --version 2>/dev/null)"
cd "$HOME" && npm install @oh-my-pi/pi-coding-agent@latest 2>&1 | tail -1
# NOTE: never run bare `omp update` here — it installed a stale 17.3.3 over 18.x
after="$($OMP --version 2>/dev/null)"
echo "omp: ${before:-?} -> ${after:-?}"

echo "=== omp extensions ==="
cd "$HOME/.omp/plugins" || exit 0
python3 - <<'PY' >/tmp/omp-deps.txt
import json
deps = json.load(open("package.json")).get("dependencies", {})
for name, spec in deps.items():
    if name == "hngh-bridge":
        continue               # installed from the in-repo source below
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

echo "=== hngh-bridge (in-repo plugin source) ==="
# Canonical source: automation/omp-plugin (versioned). Install is a COPY
# into node_modules (the plugin load path) — `omp plugin install` cannot
# do local sources: file: specs are rejected outright and bare local
# paths only symlink at the plugin-set root. Must run AFTER the extension
# installs above: they re-materialize the file:./hngh-bridge dep (hardlink
# copy of ~/.omp/plugins/hngh-bridge), which would shadow this copy.
# rm+cp is idempotent and drops stale files (2026-09-23: 3 of 5 modules
# missing from the installed copy made hngh_opencode/hngh_jcode/
# hngh_brief vanish on a fresh omp start).
SRC="$REPO_ROOT/automation/omp-plugin"
DST="$HOME/.omp/plugins/node_modules/hngh-bridge"
mkdir -p "$(dirname "$DST")"
rm -rf "$DST"
cp -R "$SRC" "$DST" || {
  echo "hngh-bridge: install FAILED" >&2
  exit 1
}
echo "hngh-bridge: $DST <- automation/omp-plugin"

echo "=== billion-context (npm global; the proxy) ==="
# billion-context-omp / billion-context-pi are deprecated (removed from
# omp 2026-08-24; hngh docs/records/2026-08-24-context-budget-and-toolchain.md)
# and must NOT be reinstalled — the maintained artifact is the bili proxy.
# npm, not bun: bili lives on PATH at ~/.npm-global/bin/bili.
npm install -g billion-context@latest 2>&1 | tail -1

echo "=== opencode (npm global; agentic executor surface) ==="
# docs/opencode.ai install section names the npm package `opencode-ai`;
# postinstall needs allow-scripts (set 2026-09-11, --location=user).
npm install -g opencode-ai@latest 2>&1 | tail -1

echo "=== versions after ==="
"$OMP" --version
command -v bili >/dev/null 2>&1 && bili --version || echo "billion-context: MISSING from PATH"
command -v opencode >/dev/null 2>&1 && opencode --version || echo "opencode: MISSING from PATH"
echo "note: restart running omp TUIs to load updates"
