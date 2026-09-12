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
#   bash install.sh --no-color                  PLAIN output even on a TTY
# env overrides (win over prompts, automation-safe):
#   HNGH_EDITOR / HNGH_BROWSER / HNGH_DESKTOP / HNGH_JS_PM
#   HNGH_CHOICES_FILE  where the choices record lands
#     (default automation/config/installer-choices.json, gitignored)
set -u
case "$0" in */*) ROOT="$(cd "${0%/*}" && pwd)" ;; *) ROOT="$PWD" ;; esac
AUTO="$ROOT/automation"
NONINTERACTIVE=0
CHECK=0
NOCOLOR=0
for arg in "$@"; do
  case "$arg" in
  --non-interactive | -y | --yes) NONINTERACTIVE=1 ;;
  --check) CHECK=1 ;;
  --no-color) NOCOLOR=1 ;;
  -h | --help)
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "usage: install.sh [--non-interactive|--check]" >&2
    exit 2
    ;;
  esac
done

# ==================== presentation layer (Winamp-class) ====================
# PRESENTATION ONLY: palette, masthead, playlist, seek bar. Same checks,
# same order, same exit codes as the landed installer - a renderer that
# strips cleanly: piped output stays plain so CI/hermetic logs are greppable.
#
# Palette law (docs/design/display-register-spec.md): existing surfaces own
# the colors; no invented hexes. Tokens mapped from
# docs/research/2026-09-11-public-face-redesign.md section (d) - void
# #171B17 (masthead fill), basalt #39413A (box rules), moss #7FA05E
# (structural accent), bone #E7E2D3 (text), ash #9B9889 (dim) - plus the
# dashboard lineage in automation/jobs/digest-html.py: ok #3fb950, warn
# #d29922; danger red #f85149 is that same GitHub-dark primer family's
# error tone (the register names the discipline, it adds no hex).
# 60-30-10 (color theory: the classic interior-design proportion rule,
# 60% dominant / 30% secondary / 10% accent): bone text dominates (~60%),
# moss carries structure (plates, rules, step numbers, seek fill; ~30%),
# and amber/ok/red are the ~10% signal tier, reserved for warnings, pass
# ticks, and failures - hue always means something.
# Degradation (non-negotiable): PLAIN (every escape empty) when stdout is
# not a TTY, NO_COLOR is set, or --no-color is passed; truecolor when
# COLORTERM=truecolor; nearest ANSI-256 otherwise (offline 6x6x6 match);
# every code flows through the single c() helper. Unicode blocks (box
# chars, seek bars, ticks) only under a UTF-8 locale; ASCII fallbacks
# elsewhere (repo language rule: ASCII where the repo is ASCII).
TTY=0; [ -t 1 ] && TTY=1
PLAIN=1
if [ "$TTY" -eq 1 ] && [ -z "${NO_COLOR:-}" ] && [ "$NOCOLOR" -eq 0 ]; then
  PLAIN=0
fi
UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
*[Uu][Tt][Ff]*8*) UTF8=1 ;;
esac
if [ "$PLAIN" -eq 1 ]; then
  P_BONE=''
  P_ASH=''
  P_MOSS=''
  P_BASALT=''
  P_AMBER=''
  P_OK=''
  P_RED=''
  P_VOIDBG=''
  P_BONEV=''
  P_MOSSV=''
  P_ASHV=''
  P_RESET=''
elif [ "${COLORTERM:-}" = truecolor ]; then
  # 24-bit from the register hexes, cited above
  printf -v P_BONE '\033[38;2;231;226;211m'
  printf -v P_ASH '\033[38;2;155;152;137m'
  printf -v P_MOSS '\033[38;2;127;160;94m'
  printf -v P_BASALT '\033[38;2;57;65;58m'
  printf -v P_AMBER '\033[38;2;210;153;34m'
  printf -v P_OK '\033[38;2;63;185;80m'
  printf -v P_RED '\033[38;2;248;81;73m'
  printf -v P_VOIDBG '\033[48;2;23;27;23m'
  printf -v P_BONEV '\033[38;2;231;226;211;48;2;23;27;23m'
  printf -v P_MOSSV '\033[38;2;127;160;94;48;2;23;27;23m'
  printf -v P_ASHV '\033[38;2;155;152;137;48;2;23;27;23m'
  printf -v P_RESET '\033[0m'
else
  # nearest ANSI-256 (6x6x6 cube + gray ramp), computed offline
  printf -v P_BONE '\033[38;5;253m' # E7E2D3 -> 253
  printf -v P_ASH '\033[38;5;246m' # 9B9889 -> 246
  printf -v P_MOSS '\033[38;5;107m' # 7FA05E -> 107
  printf -v P_BASALT '\033[38;5;237m' # 39413A -> 237
  printf -v P_AMBER '\033[38;5;172m' # d29922 -> 172
  printf -v P_OK '\033[38;5;71m' # 3fb950 -> 71
  printf -v P_RED '\033[38;5;203m' # f85149 -> 203
  printf -v P_VOIDBG '\033[48;5;234m' # 171B17 -> 234
  printf -v P_BONEV '\033[38;5;253;48;5;234m'
  printf -v P_MOSSV '\033[38;5;107;48;5;234m'
  printf -v P_ASHV '\033[38;5;246;48;5;234m'
  printf -v P_RESET '\033[0m'
fi

# c STYLE [TEXT...] -> TEXT in STYLE's escape + reset; byte-identical text
# when PLAIN. THE single helper every color code flows through.
c() { # STYLE ARGS...
  local s="$1"
  shift
  local p=''
  case "$s" in
  bone) p=$P_BONE ;;
  ash) p=$P_ASH ;;
  moss) p=$P_MOSS ;;
  basalt) p=$P_BASALT ;;
  amber) p=$P_AMBER ;;
  ok) p=$P_OK ;;
  red) p=$P_RED ;;
  voidbg) p=$P_VOIDBG ;;
  bonev) p=$P_BONEV ;;
  mossv) p=$P_MOSSV ;;
  ashv) p=$P_ASHV ;;
  *) p='' ;;
  esac
  if [ -n "$p" ]; then printf '%s%s%s' "$p" "$*" "$P_RESET"; else printf '%s' "$*"; fi
}
say() { printf '%s\n' "$(c bone "$*")"; }
plate() { printf '%s\n' "$(c moss "$*")"; }
warn() {
  if [ "$PLAIN" -eq 0 ] && [ -t 2 ]; then printf '%s\n' "$(c amber "$*")" >&2; else printf '%s\n' "$*" >&2; fi
}
rep() { # CHAR N -> N copies
  local out='' i=0
  while [ "$i" -lt "$2" ]; do out="$out$1"; i=$((i + 1)); done
  printf '%s' "$out"
}

# Masthead tagline: "it really keeps the llama's ledger" adapts Winamp's
# installer easter egg ("it really whips the llama's ass") into hngh's own
# voice. The joke is natively true here: the unsloth GGUF legs run on
# llama-server, and "keeps" carries the furnace/ledger essay's
# care-not-whip register - the ledger is hngh's own building material. The
# flavor reference stays legible to anyone who knows the original.
# Fallback alternates, recorded: "it really files the llama's paperwork",
# "it really sweeps the llama's halls". ASCII only (repo language rule).
MW=44
MMID='|'
masthead() {
  local top bot h tl tr bl br
  if [ "$UTF8" -eq 1 ]; then
    h='═'; tl='╔'; tr='╗'; bl='╚'; br='╝'; MMID='║'
  else
    h='='; tl='+'; tr='+'; bl='+'; br='+'
  fi
  top="$tl$(rep "$h" "$((MW + 2))")$tr"
  bot="$bl$(rep "$h" "$((MW + 2))")$br"
  printf '%s\n' "$(c basalt "$top")"
  mrow mossv "h n g h  installer (skeleton)"
  mrow ashv "edition: $(uname -s) $(uname -m) / automation tier"
  mrow ashv "it really keeps the llama's ledger"
  printf '%s\n' "$(c basalt "$bot")"
}
mrow() { # STYLE TEXT -> one title-bar row, dark void fill on a color TTY
  local style="$1" text="$2" pad
  printf -v pad '%-*s' "$MW" "$text"
  if [ "$PLAIN" -eq 1 ]; then
    printf '%s %s %s\n' "$MMID" "$pad" "$MMID"
  else
    printf '%s%s%s%s%s\n' "$(c basalt "$MMID")" "$(c voidbg ' ')" \
      "$(c "$style" "$pad")" "$(c voidbg ' ')" "$(c basalt "$MMID")"
  fi
}
# Winamp playlist: the install rendered as a numbered playlist. Steps
# render BEFORE running (the plan is visible up front); each phase prints
# its row with a status glyph as it completes (playlist numbers +
# checkmarks). Order is execution order and never changes.
step_row() { # NUM NAME STATE(pending|ok|fail)
  local num="$1" name="$2" st="$3" glyph gcol
  case "$st" in
  pending) glyph='[ ]'; gcol=ash ;;
  ok) glyph='[x]'; [ "$UTF8" -eq 1 ] && glyph='[✓]'; gcol=ok ;;
  fail) glyph='[X]'; [ "$UTF8" -eq 1 ] && glyph='[✗]'; gcol=red ;;
  esac
  printf '  %s %s %s\n' "$(c "$gcol" "$glyph")" "$(c moss "$num.")" "$(c bone "$name")"
}
step_plan() {
  printf '%s\n' "$(c ash '  playlist - the run, in order')"
  step_row 01 platform pending
  step_row 02 prereqs pending
  step_row 03 stage pending
  step_row 04 preferences pending
  step_row 05 record pending
}

# Winamp seek bar: one line redrawn in place (\r) while a slow step runs.
# Bounded: at most 10s of animation (100 x 0.1s), then it stops redrawing
# and waits honestly - no infinite spinner. Unicode blocks only under a
# UTF-8 locale; ASCII fallback [####----]. Never drawn when PLAIN.
seek_bar() { # LABEL PCT
  local label="$1" pct="$2" w=30 filled solid rest
  [ "$pct" -gt 100 ] && pct=100
  filled=$((pct * w / 100))
  if [ "$UTF8" -eq 1 ]; then
    solid="$(rep '█' "$filled")"
    rest="$(rep '░' "$((w - filled))")"
  else
    solid="$(rep '#' "$filled")"
    rest="$(rep '-' "$((w - filled))")"
  fi
  printf '\r  %s %s%s %3d%% ' \
    "$(c moss "$label")" "$(c moss "$solid")" "$(c ash "$rest")" "$pct"
}
TMPLOG="$(mktemp)"
TMPRC="$TMPLOG.rc"
trap 'rm -f "$TMPLOG" "$TMPRC"' EXIT
# run_winamp [--quiet] LABEL CMD... -> seek-bar wrapper; rc = CMD's rc.
# Output is buffered to a temp log while the bar runs and printed verbatim
# after the bar completes (TTY only; PLAIN runs the command untouched).
run_winamp() {
  local quiet=0
  if [ "${1:-}" = '--quiet' ]; then quiet=1; shift; fi
  local label="$1"
  shift
  if [ "$PLAIN" -eq 1 ]; then
    "$@"
    return $?
  fi
  : >"$TMPLOG"; : >"$TMPRC"
  if [ "$quiet" -eq 1 ]; then
    ( "$@" >/dev/null 2>"$TMPLOG"; echo "$?" >"$TMPRC" ) &
  else
    ( "$@" >"$TMPLOG" 2>&1; echo "$?" >"$TMPRC" ) &
  fi
  local spid=$! i=0
  while [ ! -f "$TMPRC" ] && [ "$i" -lt 100 ]; do
    seek_bar "$label" "$i"
    sleep 0.1
    i=$((i + 1))
  done
  wait "$spid"
  seek_bar "$label" 100
  printf '\n'
  if [ -s "$TMPLOG" ]; then cat "$TMPLOG"; fi
  return "$(cat "$TMPRC")"
}

masthead
step_plan

# --- phase 1: platform checks (pure: detection only, nothing installed) ----
. "$AUTO/lib/platform.sh"
PM="$(detect_pm)"
if [ -n "$PM" ]; then
  say "package manager: $PM"
  say "prereq package map ($PM): $(for t in python3 git curl jq flock sqlite3 sbcl; do printf '%s=%s ' "$t" "$(pkg_for "$PM" "$t")"; done)"
else
  warn "package manager: NONE of pacman/apt-get/dnf/zypper/apk on PATH"
  warn "  hngh prereqs (python3 git curl jq flock sqlite3 sbcl) must be"
  warn "  installed manually; --install support for this manager is future work"
fi
if systemd_user_ok; then
  say "systemd --user: available (unit enable stays operator-run; see below)"
else
  say "systemd --user: not available (automation tier stays dormant - fine)"
fi
if python3_ok; then
  say "python3: >= 3.12"
else
  warn "python3: < 3.12 or absent - kernel floor is 3.12; upgrade recommended"
fi
step_row 01 platform ok

# --- phase 2: the core, exactly what bootstrap.sh does today (fail-closed) --
plate "--- prerequisites (automation/bootstrap.sh) ---"
if run_winamp --quiet prereqs bash "$AUTO/bootstrap.sh" --check; then
  say "prerequisites ok (validated by automation/bootstrap.sh)"
  step_row 02 prereqs ok
else
  step_row 02 prereqs fail
  exit $?
fi
if [ "$CHECK" -eq 1 ]; then
  say "check-only: nothing staged, nothing recorded"
  exit 0
fi
if run_winamp stage bash "$AUTO/bootstrap.sh"; then
  step_row 03 stage ok
else
  step_row 03 stage fail
  exit $?
fi

# --- phase 4: polled operator-environment preferences ------------------------
# SCOPE (honest): these configure the operator environment hngh's automation
# manages on THIS machine - editor/browser/desktop/JS-toolchain assumptions
# used by hngh's automation surface. hngh itself needs only the prereqs
# above; nothing here installs desktop software the operator did not ask
# for, and this skeleton RECORDS choices, it does not act on them.
EDITOR="${HNGH_EDITOR:-}"
BROWSER="${HNGH_BROWSER:-}"
DESKTOP="${HNGH_DESKTOP:-}"
JS_PM="${HNGH_JS_PM:-}"
plate "--- operator-environment preferences (recorded only, nothing installed) ---"
ask() { # VAR PROMPT DEFAULT
  local __var="$1" __p="$2" __d="$3" __ans=""
  eval "__ans=\"\${$__var:-}\""
  if [ -n "$__ans" ]; then
    printf '%s\n' "$(c bone "pref: $__p -> ")$(c moss "$__ans")$(c ash " (env override)")"
  elif [ "$NONINTERACTIVE" -eq 1 ] || [ ! -t 0 ]; then
    printf '%s\n' "$(c bone "pref: $__p -> ")$(c moss "$__d")$(c ash " (default)")"
  else
    # Winamp preference pane: labeled row, default shown dim, input echoed
    # inline by the terminal. Semantics unchanged: env wins, TTY gate,
    # every prompt has a default.
    read -r -p "$(c moss "$__p")$(c ash " [$__d]: ")" __ans </dev/tty || __ans=""
    eval "$__var=\"\${__ans:-\$__d}\""
  fi
}
ask EDITOR "editor (emacs|vim|both|none)" "none"
ask BROWSER "browser (firefox|chrome|both|none)" "none"
ask DESKTOP "desktop (kde|gnome|both|none)" "none"
ask JS_PM "js toolchain (npm|pnpm|bun)" "npm"
step_row 04 preferences ok

# --- phase 5: choices record (reproducibility: what the operator picked) ----
# The machine record stays PLAIN text - the presentation layer never colors
# or reshapes it.
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
step_row 05 record ok

# --- optional companions + systemd: PRINTED, never executed here ------------
plate "--- optional companions (NOT installed by this skeleton) ---"
say "  hngh's sibling tooling installs via the official npm paths"
say "  (automation/scripts/hngh-omp-update.sh is the maintained updater):"
case "$JS_PM" in
*bun*)
  say "    bun install -g @oh-my-pi/pi-coding-agent@latest   # omp"
  ;;
*)
  say "    npm install -g @oh-my-pi/pi-coding-agent@latest   # omp"
  ;;
esac
say "    npm install -g billion-context@latest             # bili (the proxy)"
echo
plate "--- systemd --user units (operator-run; never done from here) ---"
say "  cd $AUTO && make enable   # after reviewing 'make smoke' output"
echo
say "honest boundary (peer-review finding 1): this validates prereqs and"
say "  records preferences. Full hngh operation still needs the operator's"
say "  secrets + desktop today - see automation/README.md 'Run it live'."
say "done."
exit 0
