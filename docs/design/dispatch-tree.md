# Dispatch Tree + Git-Backed State — Plugin Spec (Wave 3)

**Status**: Draft v0.1 (2026-08-03)
**Milestone**: M9 Wave 3 (extends squad-startup-automation.md §1, §3, §7)
**Session**: D3 (projected-design-sessions.md)
**Author**: Designer — glm-5.2, Hermes harness.
**Plugin file**: `src/plugins/squad-dispatch.lisp` (new)
**Package**: `:hngh.plugins.squad-dispatch`

---

## 0. Summary

This spec defines the on-disk dispatch tree, the `dispatch.md` root index
format, git-backed atomic rollback via `state.git/`, and the API functions
a Coder needs to implement `src/plugins/squad-dispatch.lisp`. Every PM
action — squad creation, task assignment, bean plant, status update,
rollback — is a git commit. Rollback is `git checkout <sha>`. No LLM is
involved in any dispatch-tree operation; this is pure filesystem + git.

The plugin follows the established plugin pattern (see
`config-watcher.lisp`): `in-package`, `defvar` state, helper functions,
lifecycle functions (`init`/`shutdown`/`running-p`/`status`), and
domain functions. Git operations use `sb-ext:run-program` (same as
`backup-manager.lisp`'s `run-git` pattern). Atomic file writes use
write-then-rename (per AGENTS.md convention).

---

## 1. Directory structure

All squad state lives under `~/.hngh/squad/<squad-name>/`. The tree is
created by `create-squad` (§3.1). Every directory below the root is
created at squad init time — roles are not lazily added.

```
~/.hngh/squad/<squad-name>/
  dispatch.md              ← root index: roles, tasks, communications
  state.git/               ← bare git repo backing atomic rollback
  pm/
    inbox.md               ← messages addressed to PM
    outbox.md              ← messages from PM to others
    map.md                 ← PM's rendered view (optional, not git-tracked)
  designer/
    inbox.md
    outbox.md
    tasks/
  coder/
    inbox.md
    outbox.md
    tasks/
  worker/
    inbox.md
    outbox.md
    tasks/
  accountant/
    inbox.md
    outbox.md
    tasks/
  artist/
    inbox.md
    outbox.md
    tasks/
  journal/
    projected.md           ← written at squad startup
    actual.md              ← updated on file-change events
    fragment.md            ← written at shutdown/pause
```

### Path conventions

- `<squad-root>` = `~/.hngh/squad/<squad-name>/`
- `<squad-root>/dispatch.md` is the single root index file.
- Each role directory contains `inbox.md`, `outbox.md`, and `tasks/`.
- `inbox.md` and `outbox.md` are append-only markdown files. Beans are
  appended as delimited sections (§2.2).
- `tasks/` contains one markdown file per task, named `<task-id>.md`.
- `journal/projected.md`, `journal/actual.md`, `journal/fragment.md` are
  append-only markdown files.
- `state.git/` is a bare repository (not a working tree). Files are
  added/committed via `git --work-tree=<squad-root> --git-dir=<state.git>`
  commands. This keeps the squad root clean (no `.git/` in the root).

### Default roles

Six roles, matching the squad-startup-automation.md design:

| Role | Directory | Default status | Default model |
|---|---|---|---|
| pm | `pm/` | active | (from spec) |
| designer | `designer/` | idle | (from spec) |
| coder | `coder/` | idle | (from spec) |
| worker | `worker/` | idle | (from spec) |
| accountant | `accountant/` | idle | (from spec) |
| artist | `artist/` | idle | (from spec) |

The role list is parameterized — `create-squad` accepts a `roles` keyword
that defaults to the six standard roles. Non-standard roles get their
own `<role>/inbox.md`, `<role>/outbox.md`, `<role>/tasks/` directories.

### What is NOT in the tree

- Transient runtime state (rate-limit retries, HTTP connections, agent
  context windows) — these are noise, not signal. Git captures
  decisions and assignments.
- `map.md` (PM's rendered view) — derived from `dispatch.md`, not a
  source of truth. May be gitignored or simply not committed.
- Lock files — concurrent write policy is by convention (§5), not by
  file locks. If a lock is needed later, it goes in state-store.

---

## 2. dispatch.md root index format

`dispatch.md` is the single file the PM reads to see the entire squad
state. It is a markdown file with three tables: Roles, Tasks,
Communications. The PM is the sole writer of `dispatch.md` (§5).

### 2.1 Full format

```markdown
# Squad: <squad-name>

## Roles
| Role | Status | Model | Last seen |
|---|---|---|---|
| pm | active | glm-5.2 | 12:30 |
| designer | idle | glm-5.2 | — |
| coder | idle | free | — |
| worker | idle | free | — |
| accountant | idle | free | — |
| artist | idle | free | — |

## Tasks
| ID | Title | Assigned | Status | Blocked by |
|---|---|---|---|---|
| w2 | file-change notification | designer | dispatched | — |
| w3 | journal lifecycle | designer | staged | w2 |
| t84 | implement watcher | coder | pending | w2-design |

## Communications
| From | To | Bean | Status |
|---|---|---|---|
| pm | designer | wave-2-design-request | planted |
| designer | pm | wave-2-design-complete | pending |
```

### 2.2 Field semantics

**Roles table:**

| Field | Type | Values | Updated by |
|---|---|---|---|
| Role | string | role name (pm, designer, coder, worker, accountant, artist, or custom) | create-squad |
| Status | string | `active`, `idle`, `stale`, `dead` | PM via update-role-status |
| Model | string | model id or `free` | create-squad, update-role-status |
| Last seen | string | `HH:MM` or `—` | PM heartbeat (not in this plugin — updated externally) |

**Tasks table:**

| Field | Type | Values | Updated by |
|---|---|---|---|
| ID | string | short task id (e.g., `w2`, `t84`) | assign-task |
| Title | string | human-readable task title | assign-task |
| Assigned | string | role name | assign-task |
| Status | string | `pending`, `dispatched`, `in-progress`, `done`, `blocked` | update-task-status |
| Blocked by | string | task id or bean id, or `—` | assign-task, update-task-status |

**Communications table:**

| Field | Type | Values | Updated by |
|---|---|---|---|
| From | string | role name | plant-bean |
| To | string | role name | plant-bean |
| Bean | string | bean name (e.g., `wave-2-design-request`) | plant-bean |
| Status | string | `planted`, `harvested`, `digested`, `spoiled` | plant-bean, harvest-bean |

### 2.3 Bean file format (inbox.md entries)

Each bean appended to `inbox.md` is a markdown section delimited by
horizontal rules. The bean's "husk" is the metadata header; the "core"
is the body content. (See beans-aesthetic.md for the full aesthetic.)

```markdown
---
bean: wave-2-design-request
from: pm
to: designer
planted: 2026-08-03T12:30:00
type: message
status: planted
---

# Wave 2 Design Request

Design the file-change notification plugin. See
squad-startup-automation.md §1 and §4 for the dispatch tree and
role senses. Produce docs/design/file-watcher.md.

Acceptance: register-path, deregister-path, file.changed event
payload, systemd path unit spec, mtime-poll fallback.
```

Fields in the husk (YAML-like front matter between `---` lines):

| Field | Required | Description |
|---|---|---|
| `bean` | yes | bean name (matches Communications table) |
| `from` | yes | sender role |
| `to` | yes | recipient role |
| `planted` | yes | ISO-8601 timestamp |
| `type` | yes | `message`, `task`, `status`, `resource`, `context`, `review` |
| `status` | yes | `planted`, `harvested`, `digested`, `spoiled` |
| `expires` | no | ISO-8601 timestamp (optional staleness deadline) |

The core (body after the second `---`) is free-form markdown — the
actual content the role will digest.

### 2.4 Parsing rules

- Tables are standard markdown pipe tables. Parse with `cl-ppcre` (already
  a dependency) or simple line splitting on `|`.
- The `dispatch.md` file is small (6 roles, <100 tasks, <200
  communications for any realistic squad). Full-file parse is acceptable.
- Bean husks in `inbox.md` are parsed by splitting on lines matching
  `^---$`. Odd-indexed sections are husks (front matter), even-indexed
  sections are cores. A simpler approach: split on `^---\n` and pair
  consecutive sections. The Coder should use `cl-ppcre:split` with the
  pattern `"\\n---\\n"` and parse each pair.

---

## 3. Function specifications

All functions are in package `:hngh.plugins.squad-dispatch`. Exported
symbols are marked with `→`.

### 3.1 `create-squad` →

```lisp
(defun create-squad (squad-name &key
                                 (roles '(:pm :designer :coder :worker
                                          :accountant :artist))
                                 (home nil)
                                 (model-config nil))
  ...)
```

**Arguments:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `squad-name` | string | (required) | squad directory name under `~/.hngh/squad/` |
| `roles` | list of keywords | 6 standard roles | roles to create directories for |
| `home` | pathname or nil | `*hngh-home*` or `~/.hngh/` | base directory; if nil, uses `hngh:*hngh-home*` or `(user-homedir-pathname)` + `.hngh/` |
| `model-config` | plist or nil | nil | per-role model assignments (keyword → model-string); roles not in the plist get `"free"` |

**Behavior:**

1. Compute `<squad-root>` = `merge-pathnames (format nil "squad/~A/" squad-name) home`.
2. If `<squad-root>` already exists (probe-file), signal `error` "Squad ~A already exists".
3. Create the directory tree:
   - `<squad-root>/`
   - `<squad-root>/state.git/` (created by `git init --bare`)
   - For each role in `roles`: `<squad-root>/<role>/`, `<squad-root>/<role>/inbox.md`, `<squad-root>/<role>/outbox.md`, `<squad-root>/<role>/tasks/`
   - `<squad-root>/journal/projected.md`, `<squad-root>/journal/actual.md`, `<squad-root>/journal/fragment.md`
4. Initialize `state.git` as a bare repo: `git init --bare <squad-root>/state.git/`.
5. Write initial `dispatch.md` at `<squad-root>/dispatch.md` with:
   - Title: `# Squad: <squad-name>`
   - Roles table: one row per role, status `active` for `:pm`, `idle` for all others; model from `model-config` or `"free"`; last-seen `—` for all except `:pm` which gets current `HH:MM`.
   - Tasks table: empty (header only, no rows).
   - Communications table: empty (header only, no rows).
6. Write initial `journal/projected.md` with squad metadata (goal placeholder, roles, models, timestamp).
7. Initialize empty `inbox.md`, `outbox.md` files (empty string content) for each role.
8. Initialize empty `journal/actual.md`, `journal/fragment.md` files.
9. Stage all files and create the first git commit (see §6 for commit message format):
   - `git --git-dir=<state.git> --work-tree=<squad-root> add -A`
   - `git --git-dir=<state.git> --work-tree=<squad-root> commit -m "[dispatch] create-squad: <squad-name>"`

**Returns:** A plist:

```lisp
(:squad-name <string>
 :squad-root <pathname>
 :state-git <pathname>
 :roles <list-of-keywords>
 :commit-sha <string>)     ; SHA of the first commit
```

**Errors:**

- Squad directory already exists → `error`.
- `git init` fails → `error` with git output in the message.
- `git commit` fails → `error` with git output.

**Git work-tree mode:** Since `state.git/` is a bare repo, all git
commands must use `--git-dir=<state.git> --work-tree=<squad-root>`. This
is the pattern used throughout. The helper `%git (args squad-root)` (§3.8)
encapsulates this.

---

### 3.2 `plant-bean` →

```lisp
(defun plant-bean (squad-root from to bean-name &key
                                               (type :message)
                                               (content "")
                                               (model-config nil))
  ...)
```

**Arguments:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `squad-root` | pathname | (required) | squad root directory |
| `from` | keyword | (required) | sender role (e.g., `:pm`) |
| `to` | keyword | (required) | recipient role (e.g., `:designer`) |
| `bean-name` | string | (required) | bean identifier (e.g., `"wave-2-design-request"`) |
| `type` | keyword | `:message` | bean type: `:message`, `:task`, `:status`, `:resource`, `:context`, `:review` |
| `content` | string | `""` | bean core body (markdown) |
| `model-config` | plist | nil | (reserved for future resource beans; unused in Wave 3) |

**Behavior:**

1. Validate `squad-root` exists (probe-file). If not, signal `error`.
2. Compute recipient inbox path: `<squad-root>/<to>/inbox.md`.
3. Validate recipient directory exists. If not, signal `error` "Unknown role: ~A".
4. Format the bean as a markdown section (§2.3) with husk (front matter) + core (content). Timestamp is `local-time:now` or `(get-universal-time)` formatted as ISO-8601.
5. Append the bean section to `inbox.md` (atomic: write to temp file, then rename).
6. Update `dispatch.md` Communications table: append a new row with `from`, `to`, `bean-name`, status `planted`. This is a PM-owned write (§5).
7. Stage and commit:
   - `git add -A`
   - `git commit -m "[bean] ~A -> ~A: ~A" from to bean-name`

**Commit message format:** `[bean] pm -> designer: wave-2-design-request` (roles in the message are string-downcased keywords).

**Returns:** A plist:

```lisp
(:squad-root <pathname>
 :bean <string>
 :from <keyword>
 :to <keyword>
 :commit-sha <string>)
```

**Errors:**

- `squad-root` doesn't exist → `error`.
- Recipient role directory doesn't exist → `error`.
- `git commit` fails → `error`.

**Note on concurrent writes:** The PM calls `plant-bean` and also writes
`dispatch.md`. Since the PM is the sole writer of `dispatch.md` and the
sole caller of `plant-bean` (in the Wave 3 model), there is no
contention. Cross-role bean planting (Designer → Coder) is supported but
the planter must NOT write `dispatch.md` — only the PM updates the
Communications table. Cross-role planters only append to the recipient's
`inbox.md` and commit with `[bean]` prefix. The PM updates
`dispatch.md` asynchronously. (See §5 for the full policy.)

---

### 3.3 `harvest-bean` →

```lisp
(defun harvest-bean (squad-root role bean-name)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role harvesting the bean (must match the bean's `to` field) |
| `bean-name` | string | bean identifier to harvest |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `<squad-root>/<role>/inbox.md`.
3. Parse bean sections (split on `^---$` lines). Find the section whose husk `bean` field matches `bean-name` and `to` field matches `role`.
4. If not found, signal `error` "Bean ~A not found in ~A inbox" bean-name role.
5. If already harvested (husk `status` field is `harvested`), signal `error` "Bean ~A already harvested".
6. Update the bean's husk `status` field from `planted` to `harvested` in `inbox.md` (rewrite the file with the updated section). Atomic write-then-rename.
7. Update `dispatch.md` Communications table: change the matching row's Status from `planted` to `harvested`. This is a PM-owned write — but in Wave 3, `harvest-bean` is called by the harvesting role, so it updates `dispatch.md` directly. (The concurrent write policy in §5 allows each role to update its own bean statuses in the Communications table. The PM owns role status and task status updates.)
8. Stage and commit:
   - `git add -A`
   - `git commit -m "[bean] ~A harvested: ~A" role bean-name`

**Commit message format:** `[bean] designer harvested: wave-2-design-request`

**Returns:** A plist:

```lisp
(:squad-root <pathname>
 :bean <string>
 :role <keyword>
 :content <string>     ; the bean's core content (for the role to digest)
 :commit-sha <string>)
```

**Errors:**

- Bean not found → `error`.
- Bean already harvested → `error`.
- Role doesn't match bean's `to` field → `error` "Bean ~A is not addressed to ~A".

---

### 3.4 `rollback-squad` →

```lisp
(defun rollback-squad (squad-root sha &key (dry-run nil))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `sha` | string | git commit SHA to rollback to |
| `dry-run` | boolean | if T, don't actually checkout, just validate the SHA exists |

**Behavior:**

1. Validate `squad-root` and `state.git` exist.
2. If `dry-run`: validate SHA exists (`git rev-parse --verify <sha>`) and return T/NIL without checking out.
3. `git --git-dir=<state.git> --work-tree=<squad-root> checkout <sha> -- .`
   - This restores all tracked files to the state at `<sha>`.
   - Files created after `<sha>` that were never committed remain (git checkout doesn't delete untracked files). A `git clean -fd` is NOT called automatically — the caller can clean if needed.
4. Commit the rollback (so the git log records it):
   - `git commit -m "[rollback] checkout ~A" sha`
   - This creates a new commit that reverts the working tree to the SHA's state. `git log` shows the rollback as a new entry, preserving history.

**Commit message format:** `[rollback] pm: undid dispatch to <sha> (reason: <reason>)` — but in Wave 3, the reason is optional. The minimal format is `[rollback] checkout <sha>`.

**Returns:** A plist:

```lisp
(:squad-root <pathname>
 :restored-sha <string>
 :commit-sha <string>     ; SHA of the rollback commit
 :success <boolean>)
```

**Errors:**

- SHA doesn't exist → `error` "Invalid SHA: ~A".
- `git checkout` fails → `error` with git output.
- `git commit` fails (nothing to commit — working tree already at SHA) → log a warning, return `(:success nil :reason "already-at-sha")`.

---

### 3.5 `get-squad-status` →

```lisp
(defun get-squad-status (squad-root)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `<squad-root>/dispatch.md`.
3. Parse the three tables (Roles, Tasks, Communications) into lists of plists.
4. Return a single plist.

**Returns:**

```lisp
(:squad-root <pathname>
 :squad-name <string>          ; parsed from "# Squad: <name>" header
 :roles (list                 ; one plist per role row
          (:role "pm" :status "active" :model "glm-5.2" :last-seen "12:30")
          (:role "designer" :status "idle" :model "glm-5.2" :last-seen "—")
          ...)
 :tasks (list                 ; one plist per task row, empty list if no tasks
          (:id "w2" :title "file-change notification" :assigned "designer"
           :status "dispatched" :blocked-by "—")
          ...)
 :communications (list       ; one plist per comms row, empty list if none
                   (:from "pm" :to "designer" :bean "wave-2-design-request"
                    :status "planted")
                   ...))
```

All field values are strings (as they appear in the markdown). The
caller can coerce to keywords/keywords as needed.

**Errors:**

- `squad-root` doesn't exist → `error`.
- `dispatch.md` missing or unparseable → `error` "Cannot read dispatch.md".

**Parsing implementation notes:**

- Read the file with `uiop:read-file-string`.
- Split into lines with `cl-ppcre:split "\\n"`.
- Identify table sections by `## Roles`, `## Tasks`, `## Communications` headers.
- Within each section, find lines starting with `|` (table rows). Skip the separator line (all dashes).
- Split each row on `|`, trim whitespace, coerce empty strings to `—` or nil.
- The `# Squad: <name>` line is the first non-blank line — extract name with a regex or `cl-ppcre:register-groups-bound`.

---

### 3.6 `check-preconditions` →

```lisp
(defun check-preconditions (spec &key (cwd nil))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `spec` | plist | spec with `:preconditions` key — a list of precondition forms |
| `cwd` | pathname | working directory for file-relative checks; defaults to `(uiop:getcwd)` |

**Behavior:**

Preconditions are boolean expressions evaluated with NO LLM — pure
filesystem and symbol inspection. Each precondition is a plist or
list specifying a check type:

```lisp
(:preconditions
  (:file-exists "src/plugins/hngh-up.lisp")
  (:function-exists :hngh.plugins.hngh-up :generate-pm-prompt)
  (:package-exports :hngh.plugins.config-watcher :init :shutdown :running-p :status)
  (:callable-p :hngh.core.event-bus :publish))
```

Supported check types:

| Check type | Form | Evaluation |
|---|---|---|
| `:file-exists` | `(:file-exists <relative-path>)` | `(probe-file (merge-pathnames <path> cwd))` |
| `:function-exists` | `(:function-exists <package-keyword> <symbol-keyword>)` | `(fboundp (find-symbol (string <symbol>) <package>))` |
| `:package-exports` | `(:package-exports <package-keyword> <symbol-keyword>...)` | Each symbol is `export`-ed from the package: `(nth-value 1 (find-symbol (string <sym>) <pkg>))` is `:external` |
| `:callable-p` | `(:callable-p <package-keyword> <symbol-keyword>)` | `(fboundp (find-symbol (string <sym>) <pkg>))` AND the symbol is external |
| `:file-contains` | `(:file-contains <relative-path> <substring>)` | Read file, search for substring |
| `:custom` | `(:custom <function>)` | Call `(funcall <function> cwd)` — must return generalized boolean |

**Returns:**

```lisp
(:all-passed <boolean>       ; T if every precondition is satisfied
 :results (list              ; one plist per precondition, in order
            (:check :file-exists :path "src/plugins/hngh-up.lisp" :passed t)
            (:check :function-exists :package :hngh.plugins.hngh-up
             :symbol :generate-pm-prompt :passed t)
            (:check :package-exports :package :hngh.plugins.config-watcher
             :symbols (:init :shutdown :running-p :status) :passed nil
             :missing (:running-p))     ; symbols not exported
            ...))
```

**Errors:**

- Unknown check type → `error` "Unknown precondition check: ~A".
- `find-symbol` fails (package doesn't exist) → that precondition gets `:passed nil` with `:reason "package not found"` (NOT an error — a missing package is a failed precondition, not a crash).

---

### 3.7 `assign-task` →

```lisp
(defun assign-task (squad-root task-id title assigned-role &key (blocked-by nil))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `task-id` | string | short task id (e.g., `"t84"`) |
| `title` | string | human-readable task title |
| `assigned-role` | keyword | role to assign (e.g., `:coder`) |
| `blocked-by` | string or nil | task id or bean id this task is blocked by |

**Behavior:**

1. Validate `squad-root` exists.
2. Validate `assigned-role` directory exists.
3. Update `dispatch.md` Tasks table: append a new row with `task-id`, `title`, `assigned-role` (string-downcased), `pending` status, `blocked-by` (or `—`).
4. Create task file `<squad-root>/<assigned-role>/tasks/<task-id>.md` with a task spec template (title, assigned, status pending, blocked-by, acceptance criteria placeholder).
5. Stage and commit:
   - `git add -A`
   - `git commit -m "[assign] pm -> ~A: ~A~@[ (blocked by: ~A)~]" assigned-role task-id blocked-by`

**Commit message format:** `[assign] pm -> coder: t84 (blocked by: w2-design)`

**Returns:**

```lisp
(:squad-root <pathname>
 :task-id <string>
 :title <string>
 :assigned <keyword>
 :blocked-by <string-or-nil>
 :commit-sha <string>)
```

---

### 3.8 `update-task-status` →

```lisp
(defun update-task-status (squad-root task-id status &key (blocked-by nil))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `task-id` | string | task to update |
| `status` | string | new status: `pending`, `dispatched`, `in-progress`, `done`, `blocked` |
| `blocked-by` | string or nil | new blocked-by value (optional, only updates if non-nil) |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `dispatch.md`, find the Tasks table row with matching `task-id`.
3. Update the `status` field. If `blocked-by` is non-nil, update that field too.
4. Write `dispatch.md` (atomic).
5. Stage and commit:
   - `git commit -m "[status] ~A: ~A ~A" assigned-role task-id status`

**Commit message format:** `[status] designer: w2 in-progress` or `[status] designer: w2 done (artifact: docs/design/...)`

**Returns:**

```lisp
(:squad-root <pathname>
 :task-id <string>
 :status <string>
 :commit-sha <string>)
```

---

### 3.9 `update-role-status` →

```lisp
(defun update-role-status (squad-root role status &key (model nil) (last-seen nil))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | role to update |
| `status` | string | new status: `active`, `idle`, `stale`, `dead` |
| `model` | string or nil | new model assignment (optional) |
| `last-seen` | string or nil | new last-seen timestamp (optional) |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `dispatch.md`, find the Roles table row with matching `role`.
3. Update `status`. If `model` is non-nil, update model. If `last-seen` is non-nil, update last-seen.
4. Write `dispatch.md` (atomic).
5. Stage and commit:
   - `git commit -m "[status] ~A: ~A" role status`

**Returns:**

```lisp
(:squad-root <pathname>
 :role <keyword>
 :status <string>
 :commit-sha <string>)
```

---

### 3.10 `squad-log` →

```lisp
(defun squad-log (squad-root &key (limit nil) (oneline t))
  ...
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `limit` | integer or nil | max commits to return (nil = all) |
| `oneline` | boolean | if T, use `--oneline` format |

**Behavior:**

1. Run `git --git-dir=<state.git> log [--oneline] [-n <limit>]`.
2. Return the output as a string (one commit per line if oneline).

**Returns:** A string (the git log output) or nil on error.

---

### 3.11 Helper: `%git`

```lisp
(defun %git (args squad-root)
  ...)
```

Internal helper (not exported). Runs a git command with the squad's
`state.git` as `--git-dir` and `<squad-root>` as `--work-tree`.

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `args` | list of strings | git arguments (without `--git-dir`/`--work-tree`) |
| `squad-root` | pathname | squad root directory |

**Behavior:**

1. Compute `state-git` = `<squad-root>/state.git/`.
2. Prepend `("--git-dir" <state-git> "--work-tree" <squad-root>)` to `args`.
3. Run `sb-ext:run-program "git" full-args :search t :wait t :output :string :error :string`.
4. Return plist: `(:ok <bool> :code <int> :output <string> :error <string>)`.

This follows the exact pattern of `backup-manager.lisp`'s `run-git`
function (lines 162–181), adapted for the `--git-dir`/`--work-tree` split.

---

### 3.12 Helper: `%atomic-write`

```lisp
(defun %atomic-write (path content)
  ...)
```

Internal helper. Writes `content` to `path` atomically:

1. Write to `<path>.tmp.<random>` (temp file in same directory).
2. `rename-file` temp to `path` (atomic on POSIX).
3. Returns `path`.

This follows the AGENTS.md convention: "write-then-rename for atomicity".

---

### 3.13 Helper: `%format-timestamp`

```lisp
(defun %format-timestamp (&optional (universal-time (get-universal-time)))
  ...)
```

Internal helper. Returns ISO-8601 string: `2026-08-03T12:30:00`.

Uses `decode-universal-time` + `multiple-value-bind` + `format`. No
external time library (keeps dependencies minimal).

---

### 3.14 Helper: `%parse-bean-section`

```lisp
(defun %parse-bean-section (section-text)
  ...)
```

Internal helper. Parses a single bean section (text between `---`
delimiters in `inbox.md`) into a plist:

```lisp
(:bean "wave-2-design-request"
 :from "pm"
 :to "designer"
 :planted "2026-08-03T12:30:00"
 :type "message"
 :status "planted"
 :expires nil
 :content "...")
```

Parses the husk (lines between the two `---` delimiters) as
`key: value` pairs. Everything after the second `---` is the `content`.

---

### 3.15 Helper: `%parse-dispatch-md`

```lisp
(defun %parse-dispatch-md (squad-root)
  ...)
```

Internal helper. Reads and parses `dispatch.md`, returns the plist
described in `get-squad-status` (§3.5). Used by `get-squad-status`,
`harvest-bean`, `assign-task`, `update-task-status`, `update-role-status`.

---

### 3.16 Helper: `%rewrite-dispatch-md`

```lisp
(defun %rewrite-dispatch-md (squad-root parsed-plist)
  ...)
```

Internal helper. Serializes a parsed plist back to `dispatch.md` format
and writes it atomically. Used by all functions that update
`dispatch.md` tables.

---

### 3.17 Lifecycle functions

Following the established plugin pattern (`config-watcher.lisp`):

```lisp
(defun init () ...)         ; no-op for now (no background threads in Wave 3)
(defun shutdown () ...)      ; no-op
(defun running-p () ...)     ; returns *running* (always nil in Wave 3 — no daemon)
(defun status () ...)        ; returns plist with plugin info
```

The plugin is stateless in Wave 3 — all state is on disk. The lifecycle
functions exist for ASDF/plugin-host compatibility and future extension
(Wave 4+ may add background watchers).

---

## 4. Package definition

Add to `src/packages.lisp`:

```lisp
(defpackage :hngh.plugins.squad-dispatch
  (:documentation "Squad Dispatch Tree (Wave 3) — directory tree, dispatch.md index, git-backed rollback.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           ;; Squad lifecycle
           #:create-squad
           #:rollback-squad
           #:get-squad-status
           #:squad-log
           ;; Bean operations
           #:plant-bean
           #:harvest-bean
           ;; Task operations
           #:assign-task
           #:update-task-status
           #:update-role-status
           ;; Precondition gates
           #:check-preconditions))
```

---

## 5. Concurrent write policy

### One writer per path

The dispatch tree uses a simple ownership model — one writer per file
path. No file locks; contention is prevented by convention.

| File | Owner | Who writes | Who reads |
|---|---|---|---|
| `dispatch.md` | PM | PM only (create-squad, assign-task, update-task-status, update-role-status) | All roles |
| `<role>/inbox.md` | The role who owns the inbox | Any role (PM plants beans, other roles can plant cross-role beans) | The owning role (harvests) |
| `<role>/outbox.md` | The role | The owning role only | Any role |
| `<role>/tasks/<id>.md` | The role assigned the task | The assigned role + PM (creates initial file) | Any role |
| `journal/projected.md` | PM | PM (at create-squad) | All roles |
| `journal/actual.md` | PM | PM (on file-change events) | All roles |
| `journal/fragment.md` | Each role writes its own section | All roles (at shutdown) | All roles |

### Bean status in dispatch.md

The Communications table in `dispatch.md` is owned by the PM, but
`harvest-bean` is called by the harvesting role. To avoid contention:

- **In Wave 3:** `harvest-bean` updates `dispatch.md` directly. This is
  safe because the squad is single-threaded in practice — the PM dispatches
  beans, then roles harvest them. The PM is not writing `dispatch.md`
  while a role is harvesting. If concurrent dispatch + harvest is needed
  later, a `bordeaux-threads` mutex can be added (the dependency already
  exists).
- **Future (Wave 4+):** The PM reads `dispatch.md` periodically and
  reconciles bean statuses from inbox changes. Roles don't write
  `dispatch.md` directly; they update their inbox and the PM syncs.

For Wave 3, the simple model is sufficient. The Coder should add a
`bt:make-lock` named `"squad-dispatch"` per squad-root, acquired by any
function that reads or writes `dispatch.md`. This is cheap and prevents
race conditions if the plugin is later used from multiple threads.

---

## 6. Git commit message format

All commits use structured prefixes. The format is:

```
[<prefix>] <description>
```

### Prefixes

| Prefix | Used by | Example |
|---|---|---|
| `[dispatch]` | create-squad | `[dispatch] create-squad: squad-automation-bootstrap` |
| `[assign]` | assign-task | `[assign] pm -> coder: t84 (blocked by: w2-design)` |
| `[status]` | update-task-status, update-role-status | `[status] designer: w2 in-progress` |
| `[bean]` | plant-bean, harvest-bean | `[bean] pm -> designer: wave-2-design-request` |
| `[rollback]` | rollback-squad | `[rollback] checkout a1b2c3d (reason: precondition failed)` |

### Rules

1. One commit per action. Never batch multiple actions into one commit.
2. The prefix is always in square brackets at the start of the message.
3. The description after the prefix is free text but follows the patterns
   above for consistency.
4. No multi-line commit messages in Wave 3. The entire message is a
   single line.
5. Role names in messages are string-downcased (`pm`, `designer`, not
   `:pm`, `:designer`).
6. Bean names are used as-is (they're already strings like
   `wave-2-design-request`).

### Git log as action log

`git log --oneline` in `state.git` is the complete squad action history:

```
a1b2c3d [rollback] checkout f9e8d7c (reason: precondition failed)
b4c5d6e [status] designer: w2 done (artifact: docs/design/file-watcher.md)
c7d8e9f [bean] designer harvested: wave-2-design-request
d0e1f2a [bean] pm -> designer: wave-2-design-request
e3f4a5b [assign] pm -> coder: t84 (blocked by: w2-design)
f6c7d8e [dispatch] create-squad: squad-automation-bootstrap
```

The Accountant reads this log (via `squad-log`) to audit squad activity,
identify spoiled beans (planted but never harvested), and measure
throughput.

---

## 7. Test fixture specification

Test file: `tests/unit/test-squad-dispatch.lisp`

### Package and suite

```lisp
(in-package :hngh.tests)

(def-suite :hngh.squad-dispatch
  :description "Tests for squad-dispatch plugin (Wave 3)"
  :in :hngh)

(in-suite :hngh.squad-dispatch)
```

### Fixture helpers

```lisp
(defun %squad-dispatch-tmp-root ()
  "Return a fresh temp directory for a test squad."
  (merge-pathnames (format nil "hngh-squad-dispatch-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-squad (root)
  "Delete the test squad directory tree."
  (when (probe-file root)
    (uiop:delete-directory-tree root :validate t)))
```

### Test cases

#### Test 1: create-squad creates directory tree and initial commit

```lisp
(test create-squad-creates-tree
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((result (hngh.plugins.squad-dispatch:create-squad
                        "test-squad"
                        :home home))
                (root (getf result :squad-root))
                (state-git (getf result :state-git)))
           ;; Directory tree exists
           (is (probe-file root))
           (is (probe-file (merge-pathnames "dispatch.md" root)))
           (is (probe-file (merge-pathnames "state.git/" root)))
           (is (probe-file (merge-pathnames "pm/inbox.md" root)))
           (is (probe-file (merge-pathnames "designer/inbox.md" root)))
           (is (probe-file (merge-pathnames "coder/tasks/" root)))
           (is (probe-file (merge-pathnames "journal/projected.md" root)))
           ;; dispatch.md has correct content
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (string= "test-squad" (getf status :squad-name)))
             (is (= 6 (length (getf status :roles))))
             (is (null (getf status :tasks)))         ; empty
             (is (null (getf status :communications)))) ; empty
           ;; First commit exists
           (is (getf result :commit-sha)))
      (%cleanup-squad home))))
```

#### Test 2: plant-bean writes to inbox and commits

```lisp
(test plant-bean-writes-inbox
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           ;; Plant a bean
           (let* ((plant-result
                   (hngh.plugins.squad-dispatch:plant-bean
                    root :pm :designer "wave-2-design-request"
                    :type :message
                    :content "Design the file-watcher plugin."))
                  (inbox-content
                   (uiop:read-file-string
                    (merge-pathnames "designer/inbox.md" root))))
             ;; Bean is in the inbox
             (is (search "wave-2-design-request" inbox-content))
             (is (search "Design the file-watcher plugin." inbox-content))
             ;; dispatch.md Communications table updated
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (is (= 1 (length (getf status :communications))))
               (let ((comm (first (getf status :communications))))
                 (is (string= "pm" (getf comm :from)))
                 (is (string= "designer" (getf comm :to)))
                 (is (string= "wave-2-design-request" (getf comm :bean)))
                 (is (string= "planted" (getf comm :status)))))
             ;; Commit SHA returned
             (is (getf plant-result :commit-sha))))
      (%cleanup-squad home))))
```

#### Test 3: harvest-bean reads bean, marks harvested, commits

```lisp
(test harvest-bean-marks-harvested
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           ;; Plant then harvest
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design the file-watcher plugin.")
           (let ((harvest-result
                  (hngh.plugins.squad-dispatch:harvest-bean
                   root :designer "wave-2-design-request")))
             ;; Bean content returned
             (is (search "Design the file-watcher plugin."
                         (getf harvest-result :content)))
             ;; dispatch.md Communications status is "harvested"
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (let ((comm (first (getf status :communications))))
                 (is (string= "harvested" (getf comm :status)))))
             ;; Commit SHA returned
             (is (getf harvest-result :commit-sha))))
      (%cleanup-squad home))))
```

#### Test 4: git log shows action history

```lisp
(test squad-log-shows-actions
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design it.")
           (hngh.plugins.squad-dispatch:harvest-bean
            root :designer "wave-2-design-request")
           (let ((log (hngh.plugins.squad-dispatch:squad-log root :oneline t)))
             ;; Log contains all three actions
             (is (search "[dispatch] create-squad: test-squad" log))
             (is (search "[bean] pm -> designer: wave-2-design-request" log))
             (is (search "[bean] designer harvested: wave-2-design-request" log))
             ;; Three commits (create + plant + harvest)
             (is (= 3 (count #\Newline log) :key (lambda (c) (if (char= c #\Newline) 1 0)))))) ; or length of split lines
      (%cleanup-squad home))))
```

#### Test 5: rollback-squad restores previous state

```lisp
(test rollback-restores-state
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root))
                (create-sha (getf create-result :commit-sha)))
           ;; Plant a bean (changes state)
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design it.")
           ;; Verify bean exists
           (let ((status-before (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status-before :communications)))))
           ;; Rollback to create-squad commit (before the bean)
           (hngh.plugins.squad-dispatch:rollback-squad root create-sha)
           ;; Verify bean is gone
           (let ((status-after (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (null (getf status-after :communications)))
             (is (null (getf status-after :tasks))))
           ;; inbox.md is empty again
           (let ((inbox (uiop:read-file-string
                          (merge-pathnames "designer/inbox.md" root))))
             (is (string= "" inbox))))
      (%cleanup-squad home))))
```

#### Test 6: assign-task adds task to dispatch.md

```lisp
(test assign-task-updates-dispatch
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (let ((assign-result
                  (hngh.plugins.squad-dispatch:assign-task
                   root "t84" "implement watcher" :coder
                   :blocked-by "w2-design")))
             ;; Task appears in dispatch.md
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (is (= 1 (length (getf status :tasks))))
               (let ((task (first (getf status :tasks))))
                 (is (string= "t84" (getf task :id)))
                 (is (string= "implement watcher" (getf task :title)))
                 (is (string= "coder" (getf task :assigned)))
                 (is (string= "pending" (getf task :status)))
                 (is (string= "w2-design" (getf task :blocked-by)))))
             ;; Task file exists
             (is (probe-file (merge-pathnames "coder/tasks/t84.md" root)))
             ;; Commit SHA returned
             (is (getf assign-result :commit-sha))))
      (%cleanup-squad home))))
```

#### Test 7: check-preconditions evaluates boolean expressions

```lisp
(test check-preconditions-procedural
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           ;; A spec with mixed pass/fail preconditions
           (let ((spec (list :preconditions
                             (list (list :file-exists "dispatch.md")
                                   (list :function-exists :hngh.plugins.hngh-up
                                         :generate-pm-prompt)
                                   (list :file-exists "nonexistent-file.lisp")
                                   (list :package-exports
                                         :hngh.plugins.config-watcher
                                         :init :shutdown :running-p :status)))))
             (let ((result (hngh.plugins.squad-dispatch:check-preconditions
                            spec :cwd root)))
               ;; Not all passed (nonexistent file fails)
               (is (null (getf result :all-passed)))
               ;; 4 results
               (is (= 4 (length (getf result :results))))
               ;; First two pass, third fails
               (is (getf (first (getf result :results)) :passed))
               (is (getf (second (getf result :results)) :passed))
               (is (null (getf (third (getf result :results)) :passed))))))
      (%cleanup-squad home))))
```

#### Test 8: update-task-status and update-role-status

```lisp
(test status-updates
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:assign-task
            root "t84" "implement watcher" :coder)
           ;; Update task status
           (hngh.plugins.squad-dispatch:update-task-status
            root "t84" "in-progress")
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (let ((task (first (getf status :tasks))))
               (is (string= "in-progress" (getf task :status)))))
           ;; Update role status
           (hngh.plugins.squad-dispatch:update-role-status
            root :designer "active")
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (let ((designer-role
                    (find "designer" (getf status :roles)
                          :key (lambda (r) (getf r :role)) :test #'string=)))
               (is (string= "active" (getf designer-role :status))))))
      (%cleanup-squad home))))
```

#### Test 9: double-harvest signals error

```lisp
(test double-harvest-errors
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "test-bean" :content "Test.")
           (hngh.plugins.squad-dispatch:harvest-bean
            root :designer "test-bean")
           ;; Second harvest should error
           (signals error
             (hngh.plugins.squad-dispatch:harvest-bean
              root :designer "test-bean")))
      (%cleanup-squad home))))
```

#### Test 10: custom roles in create-squad

```lisp
(test create-squad-custom-roles
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((result (hngh.plugins.squad-dispatch:create-squad
                         "test-squad"
                         :home home
                         :roles '(:pm :designer :coder :reviewer)))
                (root (getf result :squad-root)))
           (is (probe-file (merge-pathnames "reviewer/inbox.md" root)))
           (is (probe-file (merge-pathnames "reviewer/tasks/" root)))
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 4 (length (getf status :roles))))))
      (%cleanup-squad home))))
```

### ASDF registration

Add to `hngh.asd` in the `hngh` system `:components` list (after
`squad-resources`):

```lisp
(:file "plugins/squad-dispatch")
```

Add to `hngh/tests` system `:components` (after `test-hngh-up`):

```lisp
(:file "test-squad-dispatch")
```

---

## 8. Implementation notes for the Coder

### Dependencies

- `cl-ppcre` — already in `hngh.asd` `:depends-on`. Use for regex
  parsing of `dispatch.md` tables and bean husks.
- `bordeaux-threads` — already in `hngh.asd`. Use for the
  `bt:make-lock` mutex on `dispatch.md` access.
- `sb-ext:run-program` — SBCL built-in. Use for all git operations.
  Follow the `backup-manager.lisp` `run-git` pattern exactly.
- `uiop` — available via ASDF. Use `uiop:read-file-string`,
  `uiop:delete-directory-tree`, `ensure-directories-exist`.

No new dependencies needed.

### Git bare repo pattern

`state.git/` is a bare repository. This means there is no working tree
inside `state.git/` — the working tree is the squad root itself. All
git commands must specify both `--git-dir` and `--work-tree`:

```
git --git-dir=<squad-root>/state.git --work-tree=<squad-root> add -A
git --git-dir=<squad-root>/state.git --work-tree=<squad-root> commit -m "..."
git --git-dir=<squad-root>/state.git --work-tree=<squad-root> log --oneline
git --git-dir=<squad-root>/state.git --work-tree=<squad-root> checkout <sha> -- .
```

The `checkout <sha> -- .` form restores files to the working tree
without switching branches. After checkout, a new commit captures the
rollback state. This keeps git history linear — no branch switching,
no detached HEAD.

### Atomic file writes

All writes to `dispatch.md`, `inbox.md`, and `outbox.md` use
write-then-rename (per AGENTS.md):

1. Write content to `<path>.tmp.<random>`.
2. `rename-file` temp to final path.

This ensures readers never see a half-written file.

### Error handling

- All functions validate inputs (squad-root exists, role directories
  exist) before doing work.
- Git failures propagate as `error` conditions with the git output in
  the error message.
- `check-preconditions` does NOT propagate errors — failed preconditions
  are return values, not conditions. Only truly unexpected errors
  (malformed spec, unknown check type) are signaled.

### Thread safety

- Add a per-squad-root mutex (stored in a hash table keyed by
  `squad-root` pathstring) acquired by any function that reads or
  writes `dispatch.md`.
- Git operations are inherently serialized (one process at a time).
- The mutex prevents two threads from parsing and rewriting
  `dispatch.md` simultaneously (read-modify-write race).

### What NOT to implement in Wave 3

- No background threads (no watchers, no polling). The plugin is
  stateless.
- No event-bus integration (that's Wave 2/4).
- No LLM calls (preconditions are purely procedural).
- No bean type-awareness beyond the `type` field in the husk (full bean
  lifecycle is Wave 4).
- No spore beans, no spoiled bean detection, no feral culling (Wave 4).
- No benchmarking, no clone-squad-state (Wave 8).

---

## 9. Open questions (deferred to Wave 4+)

1. **Bean staleness**: How to detect spoiled beans (planted but never
   harvested within a time window)? The `expires` field in the husk is
   defined but not checked in Wave 3. Wave 4 adds staleness detection.

2. **Cross-role dispatch.md updates**: When Designer → Coder plants a
   bean, who updates the Communications table? Wave 3 says the PM owns
   `dispatch.md`, so cross-role plants only append to inbox and commit
   with `[bean]` prefix — the PM updates `dispatch.md` when it next
   reads the tree. This may need refinement in Wave 4.

3. **Branching for what-if analysis**: `git checkout -b experiment-2`
   is mentioned in the design doc but not implemented in Wave 3. The
   rollback function uses `checkout <sha> -- .` (same branch, restore
   files). Branching is Wave 8 (benchmark squad).

4. **Git clean after rollback**: `git checkout <sha> -- .` doesn't
   remove untracked files (files created after the SHA). A `git clean
   -fd` call could remove them, but that's destructive. The Coder
   should NOT call `git clean` automatically — leave it to the caller.

---

**Attribution**: Designer — glm-5.2, Hermes harness.
