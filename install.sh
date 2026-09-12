#!/usr/bin/env bash
# install.sh — hngh's one-command public face (repo root, the peer
# convention). Delegates the non-interactive core to automation/bootstrap.sh
# (prereqs, env contract, machine profile) and adds the platform-check +
# interactive-preferences layer. House rules inherited from bootstrap:
#
#   - installs only via the system package manager, never a curl-piped-into-
#     a-shell of a third-party script; this skeleton itself installs NOTHING new (the
#     companion installs it knows about are printed, not run),
#   - no secrets are read, created, or inlined,
#   - systemd is NEVER touched from here: the enable step is printed for the
#     operator to run (the unit set is operator-authorized surface).
#
# usage:
#   bash install.sh --non-interactive --check   CI-safe: validate only
#   bash install.sh --non-interactive           validate + stage defaults
#   bash install.sh                             validate + polled prefs (TTY)
# env overrides (win over prompts, automation-safe):
#   HNGH_EDITOR / HNGH_BROWSER / HNGH_DESKTOP / HNGH_JS_PM
#   HNGH_CHOICES_FILE  where the choices record lands
#     (default automation/config/installer-choices.json, gitignored)
set -u
case "$0" in */*) ROOT="$(cd "${0%/*}" && pwd)" ;; *) ROOT="$PWD" ;; esac
AUTO="$ROOT/automation"
NONINTERACTIVE=0
CHECK=0
for arg in "$@"; do
  case "$arg" in
  --non-interactive | -y | --yes) NONINTERACTIVE=1 ;;
  --check) CHECK=1 ;;
  -h | --help)
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "usage: install.sh [--non-interactive|--check]" >&2
    exit 2
    ;;
  esac
done

echo "=== hngh installer (skeleton) ==="
echo "platform: $(uname -s) $(uname -m)"

# --- platform checks (pure: detection only, nothing installed here) --------
. "$AUTO/lib/platform.sh"
PM="$(detect_pm)"
if [ -n "$PM" ]; then
  echo "package manager: $PM"
  echo "prereq package map ($PM): $(for t in python3 git curl jq flock sqlite3 sbcl; do printf '%s=%s ' "$t" "$(pkg_for "$PM" "$t")"; done)"
else
  echo "package manager: NONE of pacman/apt-get/dnf/zypper/apk on PATH" >&2
  echo "  hngh prereqs (python3 git curl jq flock sqlite3 sbcl) must be" >&2
  echo "  installed manually; --install support for this manager is future work" >&2
fi
if systemd_user_ok; then
  echo "systemd --user: available (unit enable stays operator-run; see below)"
else
  echo "systemd --user: not available (automation tier stays dormant - fine)"
fi
if python3_ok; then
  echo "python3: >= 3.12"
else
  echo "python3: < 3.12 or absent - kernel floor is 3.12; upgrade recommended" >&2
fi

# --- preference engine -------------------------------------------------------
# ask VAR PROMPT DEFAULT: env override wins; else default unless stdin is a
# TTY, in which case the operator is polled (every prompt has a default).
ask() { # VAR PROMPT DEFAULT
  local __var="$1" __p="$2" __d="$3" __ans=""
  eval "__ans=\"\${$__var:-}\""
  if [ -n "$__ans" ]; then
    echo "pref: $__p -> $__ans (env override)"
  elif [ "$NONINTERACTIVE" -eq 1 ] || [ ! -t 0 ]; then
    echo "pref: $__p -> $__d (default)"
  else
    read -r -p "$__p [$__d]: " __ans </dev/tty || __ans=""
    eval "$__var=\"\${__ans:-\$__d}\""
  fi
}

# --- the core: exactly what bootstrap.sh does today (fail-closed) -----------
echo "--- prerequisites (automation/bootstrap.sh) ---"
bash "$AUTO/bootstrap.sh" --check >/dev/null || exit $?
echo "prerequisites ok (validated by automation/bootstrap.sh)"
if [ "$CHECK" -eq 1 ]; then
  echo "check-only: nothing staged, nothing recorded"
  exit 0
fi
bash "$AUTO/bootstrap.sh" || exit $?

# --- polled operator-environment preferences --------------------------------
# SCOPE (honest): these configure the operator environment hngh's automation
# manages on THIS machine - editor/browser/desktop/JS-toolchain assumptions
# used by hngh's automation surface. hngh itself needs only the prereqs
# above; nothing here installs desktop software the operator did not ask
# for, and this skeleton RECORDS choices, it does not act on them.
EDITOR="${HNGH_EDITOR:-}"
BROWSER="${HNGH_BROWSER:-}"
DESKTOP="${HNGH_DESKTOP:-}"
JS_PM="${HNGH_JS_PM:-}"
echo "--- operator-environment preferences (recorded only, nothing installed) ---"
ask EDITOR "editor (emacs|vim|both|none)" "none"
ask BROWSER "browser (firefox|chrome|both|none)" "none"
ask DESKTOP "desktop (kde|gnome|both|none)" "none"
ask JS_PM "js toolchain (npm|pnpm|bun)" "npm"

# --- choices record (reproducibility: what the operator picked) -------------
CHOICES_FILE="${HNGH_CHOICES_FILE:-$AUTO/config/installer-choices.json}"
MODE="interactive"
[ "$NONINTERACTIVE" -eq 1 ] && MODE="non-interactive"
python3 - "$CHOICES_FILE" "$MODE" "$PM" "$EDITOR" "$BROWSER" "$DESKTOP" "$JS_PM" <<'PY'
import json, os, sys, datetime
path, mode, pm, editor, browser, desktop, js_pm = sys.argv[1:]
rec = {
    "installer_mode": mode,
    "package_manager": pm,
    "editor": editor,
    "browser": browser,
    "desktop": desktop,
    "js_pm": js_pm,
    "recorded_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(rec, f, indent=2, sort_keys=True)
    f.write("\n")
print("choices record:", path)
PY

# --- optional companions + systemd: PRINTED, never executed here ------------
echo "--- optional companions (NOT installed by this skeleton) ---"
echo "  hngh's sibling tooling installs via the official npm paths"
echo "  (automation/scripts/hngh-omp-update.sh is the maintained updater):"
case "$JS_PM" in
*bun*)
  echo "    bun install -g @oh-my-pi/pi-coding-agent@latest   # omp"
  ;;
*)
  echo "    npm install -g @oh-my-pi/pi-coding-agent@latest   # omp"
  ;;
esac
echo "    npm install -g billion-context@latest             # bili (the proxy)"
echo
echo "--- systemd --user units (operator-run; never done from here) ---"
echo "  cd $AUTO && make enable   # after reviewing 'make smoke' output"
echo
echo "honest boundary (peer-review finding 1): this validates prereqs and"
echo "  records preferences. Full hngh operation still needs the operator's"
echo "  secrets + desktop today - see automation/README.md 'Run it live'."
echo "done."
exit 0
