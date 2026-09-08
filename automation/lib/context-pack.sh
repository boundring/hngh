# context-pack.sh — the context pack: one bounded, pre-digested
# orientation file per delegated session (design:
# hngh docs/design/context-manager.md — "the Compass"). Both launch
# paths (overnight-cycle via lib/launch-session.sh, watchdog respawn)
# consume this ONE generator; no second pack builder may be added.
#
# Packs are DERIVED DATA, never sources of truth — the ledgers and the
# kernel docs behind them are. No secret values ever enter a pack (the
# Keyring law, hngh docs/design/keyring.md: credentials live in the
# keyring harness and its store, never in records or packs).
#
# Source AFTER lib/common.sh (needs marked_cut). Env seams for tests:
# ROOT/AUTOMATION_ROOT (pack root), HNGH_HOME (kernel repo),
# CONTEXT_PACK_BYTES (hard cap, default 1500).

declare -F marked_cut >/dev/null ||
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CONTEXT_PACK_BYTES="${CONTEXT_PACK_BYTES:-1500}"

# role -> one line: what good output from this session looks like
context_role_hint() { # role
  case "$1" in
  cistern)
    printf 'work on the Cistern emacs game — respect the clean architecture (domain is pure, game is use cases, view renders, input adapts); run the test suite before committing'
    ;;
  research)
    printf 'crystallize ONE research line — sources plus a named consumer — into docs/research/; no code'
    ;;
  review)
    printf 'attack the record, not the summary; every finding carries file+line evidence or it is not a finding'
    ;;
  *)
    printf 'execute the routed plan as the smallest verified step, land it, append the ledgers, stop'
    ;;
  esac
}

# project block: role == project name -> one bounded repo-orientation block
# (multi-project: hngh docs/design/multi-project.md). Read-only git probes
# only; the target project's sources are never edited or committed from
# here. Env seam: CISTERN_REPO.
context_project_block() { # role
  case "$1" in
  cistern)
    local repo="${CISTERN_REPO:-$HOME/Projects/etc/20260830/cistern}"
    printf 'cistern repo: %s (emacs roguelike, ~17K LOC, clean architecture)\n' "$repo"
    printf 'architecture: domain (pure core, no buffers/faces/timers) -> game (use cases: state+intent -> state+log) -> view (render) -> input (adapter) -> driver (keymap/timer, the single cistern--st global)\n'
    printf 'key files: src/cistern-domain.el (3555 lines, the pure core), src/cistern-game.el, src/cistern-view.el, src/cistern.el, tests/run.el (canonical runner, PROCESS-RETRO P3)\n'
    printf 'test command: cd %s && emacs -Q --batch -l tests/run.el -f cistern-run-all-tests\n' "$repo"
    printf 'dirty files (uncommitted — another session owns them; observe, never edit/commit):\n'
    git -C "$repo" status --porcelain 2>/dev/null | sed 's/^/  /'
    printf 'wiki lessons: ~/Projects/etc/llm-wiki/.llm-wiki/wiki/syntheses/delegated-subagent-steering.md and wiki/cases/cistern-emacs-rewrite.md\n'
    ;;
  esac
}

# context_pack ROLE SLUG -> writes the pack file, echoes its path.
# Sections, in order, total <= CONTEXT_PACK_BYTES (head -c enforced):
# timestamp+role header, repo map, ledger paths, role hint, frontier
# (the torch-sentinel Verified numbers from kernel STATE-OF-PROJECT.md,
# marked_cut-bounded so a cut is visible, never a silent mid-word slice).
context_pack() { # role slug -> pack path on stdout
  local role="$1" slug="$2"
  local root="${ROOT:-${AUTOMATION_ROOT:?AUTOMATION_ROOT unset}}"
  local krepo="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
  local dir out
  dir="$root/prompts/overnight"
  out="$dir/$slug.context.txt"
  mkdir -p "$dir"
  {
    printf '# context pack — role=%s %s — regenerated %s (cite, do not re-derive)\n' \
      "$role" "$slug" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'current UTC (machine clock — verify against it, never assume): %s\n' \
      "$(date -u)"
    printf 'role hint: %s\n' "$(context_role_hint "$role")"
    # project block first: when the cap bites, generic boilerplate
    # truncates, never the project-specific orientation (multi-project:
    # hngh docs/design/multi-project.md)
    context_project_block "$role"
    printf 'automation repo: %s\nkernel repo: %s\n' "$root" "$krepo"
    printf 'automation top level: '
    (cd "$root" && ls | tr '\n' ' ' && printf '\n')
    printf 'ledgers: STATE.md agent-handoffs.md logs/budget.md cadence-params.tsv\n'
    printf 'kernel ledgers: docs/project/STATE-OF-PROJECT.md docs/project/reports.md docs/project/plans/\n'
    printf 'research index: %s/docs/research/\n' "$krepo"
    printf 'frontier (kernel Verified numbers):\n'
    sed -n '/torch:begin/,/torch:end/p' \
      "$krepo/docs/project/STATE-OF-PROJECT.md" 2>/dev/null | marked_cut 700
  } | head -c "$CONTEXT_PACK_BYTES" >"$out" 2>/dev/null || true
  printf '%s\n' "$out"
}
