# D6 — Squad-Up Integration Design

**Status**: Spec (2026-08-07)
**Wave**: 6 (wire procedural prompts + dispatch tree + beans into squad-up)
**Author**: Designer — z-ai/glm-5.2 via openrouter, Hermes harness
**Depends on**: Wave 3 (squad-dispatch), Wave 4 (beans), Wave 5 (prompt-matrix)
**Preconditions**: `generate-prompt` in hngh-up.lisp; `create-squad`/`plant-bean`/`get-squad-status` in squad-dispatch.lisp; `husk-bean`/`cull-spoiled-beans` in beans.lisp — all verified present.

---

## 1. Problem

`squad-up` (612-line bash script) already has partial integration:
- `generate_pm_prompt()` shell function calls `hngh up --dry-run` and strips orientation header
- `AUTO_PROMPT=1` generates PM prompt, falls back to static `SEAT_PROMPT[pm]`
- Bean-lite envelopes from `$SQUAD_RUN_DIR/beans/<role>.md` appended to prompts
- Run directory structure: `$SQUAD_RUN_DIR/{beans,status,prompts}/`

Missing:
1. No dispatch tree created (squad-dispatch's `create-squad` is never called)
2. Only PM gets procedural prompt; other roles use static `SEAT_PROMPT`
3. Bean-lite is a flat file append, not real bean plant/harvest lifecycle
4. `--stop` kills Konsole windows but does not husk (no fragment journal, no final git commit)
5. `squad-seats.conf` model assignments are static; `select-role-model` is never consulted

---

## 2. Design

### 2.1 Dispatch tree creation on launch

When `squad-up` launches (not `--dry`, not `--list`, not `--status`), it calls `create-squad` via the hngh CLI to create the dispatch tree at `~/.hngh/squad/<squad-name>/`.

**Mechanism**: `squad-up` calls `hngh squad create <name> --roles pm,designer,coder,artist,accountant,worker` (or the activated subset). The hngh CLI delegates to `squad-dispatch:create-squad`.

**Squad name**: derived from `SQUAD_RUN_ID` — `squad-<run-id>` (e.g., `squad-20260808T010207Z-217956`).

**Linking**: `squad-up` writes a `.squad-root` file in `$SQUAD_RUN_DIR/` pointing to the dispatch tree path. All subsequent operations resolve the squad root from this file.

**Fallback**: if `hngh squad create` fails (binary not found, daemon not running), log a warning and continue with bean-lite envelopes (current behavior). The squad works without the dispatch tree — it just loses git-backed state and formal bean lifecycle.

### 2.2 Procedural prompts for all roles

Replace the `AUTO_PROMPT` check that only applies to PM with a per-role generation loop.

**Current** (prepare_seat_prompt):
```bash
if [[ "$AUTO_PROMPT" == "1" && "$seat" == "pm" ]]; then
    prompt=$(generate_pm_prompt 2>/dev/null) || prompt="${SEAT_PROMPT[$seat]:-}"
fi
```

**Spec**: When `AUTO_PROMPT=1`, `prepare_seat_prompt` calls `hngh up --prompt-for <role> --goal "$SQUAD_GOAL" --squad-name "$squad_name"` for every role. This invokes `generate-prompt` with role-appropriate dimensions. Falls back to `SEAT_PROMPT[role]` on failure.

**New CLI flag**: `hngh up --prompt-for <role> --goal <str> --squad-name <str>` — thin wrapper around `generate-prompt` that constructs a `prompt-dimensions` struct for the given role with `:scenario :startup` and prints the assembled prompt to stdout. Does not launch anything.

**Dimension construction**:
- `:role` — from the `--prompt-for` argument
- `:scenario` — `:startup` (startup context)
- `:strategy` — from `squad-seats.conf` or `:feature-sprint` default
- `:resources` — `:local-only` if `FREE_MODE`, else `:budget-50` if `CHEAP_MODE`, else `:budget-200`
- `:lifetime` — `:continual` (default; configurable via `SQUAD_LIFETIME` env var)
- `:directory` — `HNGH_DIR`
- `:purpose` — `SQUAD_GOAL` or `SQUAD_GOAL` env var

**Bean-lite evolution**: When dispatch tree exists, `squad-up` calls `hngh squad plant-bean --squad <name> --from pm --to <role> --type task --content "$prompt"` to plant the startup prompt as a task bean in the role's inbox. The role's prompt is the bean content. When dispatch tree is absent, fall back to the current bean-lite file append.

### 2.3 `squad-up --stop` husking

**Current**: `stop_all()` kills Konsole windows.

**Spec**: `stop_all()` first calls `hngh squad husk --squad <name>` to trigger final husking. This calls `beans:husk-bean` for each role with unfinished beans, writes fragment journals via `fragment-journal:write-fragment`, and makes a final git commit `[shutdown] squad <name> stopped`. Then kills Konsole windows.

**Fragment journal path**: `~/.hngh/squad/<name>/journal/fragment.md`. Each role's husk entry includes: unharvested beans, in-progress work, resume hints, value captured.

**Grace period**: `squad-up --stop` sends SIGTERM to agent processes, waits 5 seconds, then kills Konsole. This gives agents time to write their status files and husk entries. (Agents are expected to trap SIGTERM and write their fragment.)

### 2.4 Model assignment from select-role-model

**Current**: `SEAT_MODEL[role]` is statically defined in `squad-up` or overridden by `squad-seats.conf`.

**Spec**: When `AUTO_PROMPT=1` and dispatch tree exists, `squad-up` calls `hngh up --model-for <role>` to get the model assignment from `select-role-model`. This returns `<provider>/<model>` on stdout. Falls back to `SEAT_MODEL[role]` on failure.

**squad-seats.conf evolution**: The conf file remains the override mechanism. If `SEAT_MODEL[role]` is set in the conf, it takes precedence over `select-role-model`. The conf is the human override; `select-role-model` is the procedural default. This preserves the existing override pattern.

---

## 3. Atomic work items

### W6-1: `hngh up --prompt-for <role>` CLI flag

**Files**: `src/plugins/hngh-up.lisp` (extend `cmd-up`), `src/client/cli.lisp` (or wherever CLI args are parsed)
**Tests**: `tests/unit/test-hngh-up.lisp` (extend)

**Spec**: Add `--prompt-for <role>` keyword to `cmd-up`. When present, `cmd-up` does not launch or run the questionnaire. Instead it constructs a `prompt-dimensions` struct for the given role with `:scenario :startup` and calls `generate-prompt`, printing the result to stdout.

**Acceptance criteria**:
- `hngh up --prompt-for coder --goal "test" --squad-name "test-squad"` prints a prompt containing "CODER" and "Scope" sections
- `hngh up --prompt-for designer --goal "test"` prints a prompt containing "DESIGNER" and "Scope"
- Falls back to `:pm` skeleton if role is unknown (log warning)
- `make test` green (new count: N+3 — one per role tested)
- Exit code 0 on success, 1 on error

**Test fixtures**:
1. `--prompt-for coder` produces output containing "CODER" and "conventions"
2. `--prompt-for designer` produces output containing "DESIGNER" and "aesthetic"
3. `--prompt-for unknown-role` falls back to PM skeleton, logs warning, exit 0

---

### W6-2: `hngh squad create` / `plant-bean` / `husk` CLI commands

**Files**: `src/client/cli.lisp` (extend), `src/plugins/squad-dispatch.lisp` (extend if needed), `src/plugins/beans.lisp` (extend if needed)
**Tests**: `tests/unit/test-squad-dispatch.lisp` (extend), `tests/unit/test-beans.lisp` (extend)

**Spec**: Add CLI subcommands:
- `hngh squad create <name> [--roles r1,r2,...]` — calls `create-squad`, prints squad root path
- `hngh squad plant-bean --squad <name> --from <role> --to <role> --type <type> --content <string|->` — calls `beans:plant-bean` (which delegates to `squad-dispatch:plant-bean`), prints bean name + commit SHA
- `hngh squad husk --squad <name>` — calls `beans:husk-bean` for each role with open beans, writes fragment journal, final git commit, prints summary

**Acceptance criteria**:
- `hngh squad create test-squad --roles pm,coder` creates `~/.hngh/squad/test-squad/` with dispatch.md, pm/inbox.md, coder/inbox.md, state.git/
- `hngh squad plant-bean --squad test-squad --from pm --to coder --type task --content "Do X"` writes to coder/inbox.md, git commit exists, commit SHA printed
- `hngh squad husk --squad test-squad` writes fragment.md, all beans marked husked, final git commit exists
- `make test` green (new count: N+4)

**Test fixtures**:
1. `squad create` with `--roles` creates correct subdirectories
2. `squad plant-bean` via CLI writes to inbox and commits
3. `squad husk` writes fragment journal and marks beans husked
4. `squad husk` on empty squad produces empty fragment (no error)

---

### W6-3: squad-up dispatch tree wiring

**Files**: `~/.local/bin/squad-up` (extend), `~/.hngh-night/squad-seats.conf` (update comment)

**Spec**: In `launch_seats()`, before launching any seat:
1. Call `hngh squad create "$squad_name" --roles "$(IFS=,; echo "${seats[*]}")"` to create the dispatch tree
2. Write `$SQUAD_RUN_DIR/.squad-root` with the squad root path
3. If `hngh squad create` fails, log warning, set `HAS_DISPATCH_TREE=0`, continue with bean-lite

In `prepare_seat_prompt()`, when `HAS_DISPATCH_TREE=1`:
1. Call `hngh up --prompt-for "$seat" --goal "$SQUAD_GOAL" --squad-name "$squad_name"` to get the procedural prompt
2. Call `hngh squad plant-bean --squad "$squad_name" --from pm --to "$seat" --type task --content "$prompt"` to plant the prompt as a bean
3. Use the planted bean content as the seat prompt (it's the same content, but now it's in the dispatch tree)

In `stop_all()`, before killing Konsole:
1. Read `.squad-root` if it exists
2. Call `hngh squad husk --squad "$squad_name"` (5 second timeout, then continue)
3. Then kill Konsole windows

**Acceptance criteria**:
- `squad-up --dry --auto-prompt` shows procedural prompts for all roles (not just PM)
- `squad-up pm coder` creates dispatch tree at `~/.hngh/squad/squad-<run-id>/`
- `squad-up --stop` produces `journal/fragment.md` in the squad root
- When `hngh` binary is unavailable, squad-up falls back to current behavior (no crash)
- `squad-seats.conf` model assignments override `select-role-model` when set

**Test fixtures**: Manual verification (bash script, not FiveAM):
1. `squad-up --dry --auto-prompt "test goal"` output contains "DESIGNER" and "CODER" sections
2. `squad-up --dry --auto-prompt` output contains "Accountant" section
3. After `squad-up --stop`, `.squad-root` file can be read and `journal/fragment.md` exists

---

### W6-4: `hngh up --model-for <role>` CLI flag

**Files**: `src/plugins/hngh-up.lisp` (extend `cmd-up`), `src/client/cli.lisp`
**Tests**: `tests/unit/test-hngh-up.lisp` (extend)

**Spec**: Add `--model-for <role>` to `cmd-up`. When present, constructs default dimensions for the role and calls `select-role-model`, printing `<provider>/<model>` to stdout. Does not launch.

**Acceptance criteria**:
- `hngh up --model-for coder` prints a model string in `provider/model` format
- `hngh up --model-for pm` prints a model string
- Falls back to `*model-mapping*` default if `select-role-model` returns nil
- `make test` green (new count: N+2)

**Test fixtures**:
1. `--model-for coder` returns a non-empty string containing "/"
2. `--model-for unknown-role` returns a default, exit 0

---

## 4. Risks

| Risk | Mitigation |
|---|---|
| `hngh` binary not in PATH during squad-up | Graceful fallback to current behavior (static prompts, bean-lite) |
| Dispatch tree creation slow (git init) | Squad startup doesn't block on it — tree creation runs in background, seats launch immediately |
| `--stop` husk hangs agent processes | 5-second timeout on `hngh squad husk`, then force-kill |
| Procedural prompt generation fails for a role | Per-role fallback to `SEAT_PROMPT[role]` |
| Model assignment disagrees between conf and select-role-model | Conf wins (human override) |

---

## 5. Attribution

Designer — z-ai/glm-5.2 via openrouter, Hermes harness.
Coder (consult) — implementation patterns, CLI arg parsing.
PM (review) — end-to-end flow, preconditions.

---

## 6. Related

- `docs/design/squad-startup-automation.md` — parent design (waves 2-9)
- `docs/design/prompt-matrix.md` — generate-prompt, select-role-model
- `docs/design/dispatch-tree.md` — create-squad, plant-bean, rollback
- `docs/design/beans-lifecycle.md` — husk-bean, cull-spoiled-beans
- `docs/design/projected-design-sessions.md` — D6 session structure
