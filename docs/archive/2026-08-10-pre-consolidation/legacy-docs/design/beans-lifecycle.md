# Bean Lifecycle — Plugin Spec (Wave 4)

**Status**: Draft v0.1 (2026-08-03)
**Milestone**: M9 Wave 4 (extends squad-startup-automation.md §6, §7; dispatch-tree.md §2.3, §3.2–3.3)
**Session**: D4 (projected-design-sessions.md)
**Author**: Designer — glm-5.2, Hermes harness.
**Plugin file**: `src/plugins/beans.lisp` (new)
**Package**: `:hngh.plugins.beans`
**Depends on**: `:hngh.plugins.squad-dispatch` (Wave 3)

---

## 0. Summary

This spec extends the Wave 3 dispatch-tree infrastructure with full bean
lifecycle management: typed beans (7 types), the husk/core/membrane file
format, the planted→growing→ripe→harvested→digested→husked state machine,
spoiled and feral detection, spore propagation, cross-role exchange, and
staleness checking. The plugin follows the established pattern
(`config-watcher.lisp`, `fragment-journal.lisp`): `in-package`, `defvar`
state, helper functions, lifecycle functions, and domain functions. No LLM
is involved in any bean-lifecycle operation — all are pure
filesystem + git.

The Wave 3 `plant-bean` and `harvest-bean` (defined in
`dispatch-tree.md` §3.2–3.3) are extended here with type-awareness,
membrane directives, lifecycle state transitions, and journal integration.
This spec defines the *extensions* — the Coder should read
`dispatch-tree.md` for the base behavior and implement the combined
function in `beans.lisp` as the canonical version. The `squad-dispatch`
plugin's `plant-bean`/`harvest-bean` remain as thin wrappers that delegate
to `beans.lisp` (or the Coder may consolidate them — see §11).

---

## 1. Bean type definitions

Seven bean types. Each type has a fixed set of required husk fields beyond
the common husk (defined in §2) and a specific membrane directive set.
The `type` field in the husk determines which validation rules apply at
plant time and which lifecycle transitions are legal.

### 1.1 Type summary

| Type | Keyword | Husk weight | Core density | Typical direction | Spoil rate |
|---|---|---|---|---|---|
| message | `:message` | thin | shallow | any → any | fast |
| task | `:task` | thick | dense | pm → role | slow |
| status | `:status` | thin | shallow | role → pm | fast |
| resource | `:resource` | thick | dense | pm → role | slow |
| context | `:context` | medium | medium | any → any | medium |
| review | `:review` | medium | dense | reviewer → role | medium |
| spore | `:spore` | thick | dense | pm → role | slow (but dangerous) |

### 1.2 Common husk fields (all types)

These fields appear in every bean's husk (front matter), regardless of
type. Defined in dispatch-tree.md §2.3 and extended here:

| Field | Required | Type | Description |
|---|---|---|---|
| `bean` | yes | string | bean identifier (matches dispatch.md Communications table) |
| `from` | yes | string | sender role (string-downcased keyword) |
| `to` | yes | string | recipient role |
| `planted` | yes | string | ISO-8601 timestamp at plant time |
| `type` | yes | string | one of: `message`, `task`, `status`, `resource`, `context`, `review`, `spore` |
| `status` | yes | string | lifecycle state: `planted`, `growing`, `ripe`, `harvested`, `digested`, `husked`, `spoiled`, `feral` |
| `expires` | no | string | ISO-8601 timestamp — staleness deadline |
| `lifecycle` | yes | string | `planted` at creation; transitions through lifecycle states |

Note: `status` and `lifecycle` are the same field. In Wave 3 only `status`
existed (planted/harvested). In Wave 4, `status` carries the full
lifecycle state. `lifecycle` is an alias kept for readability in the husk
— both are written and must agree. The Coder may use `status` as the
canonical field and write `lifecycle` with the same value for
documentation purposes.

### 1.3 Type-specific husk fields

#### message

| Field | Required | Description |
|---|---|---|
| `priority` | no | `low`, `normal`, `urgent` (default: `normal`) |
| `reply-to` | no | bean name this message replies to |

Core: free-form markdown text — the message content.

Membrane directives (§3): `ingest` (default — read and act immediately).

#### task

| Field | Required | Description |
|---|---|---|
| `task-id` | yes | task identifier (matches dispatch.md Tasks table, e.g. `w4`) |
| `title` | yes | human-readable task title |
| `blocked-by` | no | task-id or bean-id this task is blocked by |
| `acceptance` | yes | newline-delimited acceptance criteria (at least one) |
| `files` | no | comma-delimited list of files the task touches |

Core: free-form markdown — the task specification body (context,
constraints, dependencies, resource allocation).

Membrane directives: `chew` (slow digestion — read carefully, verify
preconditions before acting). If `blocked-by` is non-nil, membrane is
`ferment` (wait for dependency before processing).

#### status

| Field | Required | Description |
|---|---|---|
| `role` | yes | the role reporting this status |
| `state` | yes | `growing`, `ripe`, `fallow`, `spoiling` (metabolic state of the reporting role) |
| `task-ref` | no | task-id this status update pertains to |

Core: free-form markdown — status details, progress description, blockers.

Membrane directives: `ingest` (fast read, update dispatch.md, no heavy
processing).

#### resource

| Field | Required | Description |
|---|---|---|
| `kind` | yes | `vram`, `model`, `budget`, `file`, `data` |
| `allocation` | no | amount/units (e.g. `8192 MB`, `glm-5.2`, `$0.50`) |
| `grant-id` | no | resource-manager grant ID (if applicable) |
| `split` | no | list of role names that share this resource bean |

Core: free-form markdown — resource payload description, file paths,
data references, model assignment details.

Membrane directives: `extract` (selectively digest — take what's relevant
to your role). If `split` is non-nil, each consuming role extracts only
its portion.

#### context

| Field | Required | Description |
|---|---|---|
| `scope` | yes | `squad`, `role`, `task`, `global` — what the context applies to |
| `source` | no | origin of the context (e.g. `AGENTS.md`, `roadmap`, `OptMem`) |

Core: free-form markdown — the context content (file sections, plan
summaries, system state snapshots).

Membrane directives: `ingest` (read and integrate into working context)
or `ferment` (sit with it before processing) depending on density.

#### review

| Field | Required | Description |
|---|---|---|
| `artifact` | yes | path to the artifact being reviewed |
| `verdict` | yes | `accept`, `reject`, `request-changes` |
| `severity` | no | `info`, `minor`, `major`, `blocking` (default: `info`) |
| `annotations` | no | list of inline review comments (line-numbered) |

Core: free-form markdown — review body, detailed findings, suggestions.

Membrane directives: `chew` (slow digestion — the reviewed role must
address each finding). If `verdict` is `reject`, membrane is `ferment`
(the role must re-work before re-submitting).

#### spore

| Field | Required | Description |
|---|---|---|
| `spore-id` | yes | unique spore identifier (for propagation tracking) |
| `propagation-limit` | yes | max number of sub-beans this spore may generate (default: 10) |
| `sub-bean-types` | yes | list of bean types the spore may generate (e.g. `task,message`) |
| `parent-spore` | no | spore-id of the parent spore (nil for root spores) |

Core: free-form markdown — self-contained instructions that, when
digested, cause the consuming role to autonomously generate and plant
sub-beans.

Membrane directives: `ferment` (sit with the spore before processing to
understand the full propagation chain). Spore beans always go through
`ferment` membrane — there is no `ingest` path for spores.

---

## 2. Bean file format

### 2.1 Anatomy

Every bean is a markdown file section appended to a role's `inbox.md`
(delimited by `---` lines, per dispatch-tree.md §2.3). The bean has
three parts:

1. **Husk** — the outer casing. YAML front matter between two `---`
   delimiter lines. Carries all metadata: origin, timestamp, type,
   lifecycle state, staleness. This is what other agents see before
   opening the bean.

2. **Core** — the nutrient payload. The markdown body after the second
   `---` delimiter. The actual content the role digests: task spec,
   message text, status report, resource payload, review findings, spore
   instructions.

3. **Membrane** — a thin layer of processing intent. Encoded as a
   `membrane:` field in the husk front matter. Tells the consuming agent
   *how* to eat this bean. Values: `ingest`, `chew`, `extract`,
   `ferment`.

### 2.2 Full format

```markdown
---
bean: wave-4-beans-spec
from: pm
to: designer
planted: 2026-08-03T14:00:00
type: task
status: planted
expires: 2026-08-04T14:00:00
membrane: chew
task-id: w4
title: Bean Lifecycle Design
blocked-by: w3
acceptance: |
  - All 7 bean types defined
  - Lifecycle state machine implemented
  - Spore propagation works
  - make test green
files: src/plugins/beans.lisp, tests/unit/test-beans.lisp
---

# Wave 4: Bean Lifecycle Design

Produce docs/design/beans-lifecycle.md covering bean types, lifecycle
states, husk/core/membrane format, and all function signatures.

The spec must be detailed enough for a Coder to implement without
further design input.
```

### 2.3 Membrane directives

| Directive | Meaning | When to use |
|---|---|---|
| `ingest` | Read and act immediately. Fast digestion. | message, status, context (light) |
| `chew` | Read carefully, verify preconditions before acting. Slow digestion. | task, review |
| `extract` | Selectively digest — take only what's relevant. | resource (especially split beans) |
| `ferment` | Sit with it before processing. Wait for dependencies or understanding to mature. | spore, blocked tasks, rejected reviews |

The membrane directive is advisory — it guides the consuming role's
processing strategy but does not change the lifecycle state machine. The
plugin records the membrane in the husk and the consuming role (or the
agent driving the role) reads it to decide processing approach. The
plugin does NOT enforce membrane semantics procedurally — that's the
role's responsibility. The plugin's job is to carry the directive.

### 2.4 Parsing

Bean sections in `inbox.md` are parsed by splitting on lines matching
`^---$`. Consecutive delimiter pairs form husk/core pairs. The husk is
parsed as `key: value` lines (YAML-like, not full YAML — no nesting,
no lists except pipe-delimited multi-line values via `|`). The core is
everything after the second delimiter.

Use `cl-ppcre:split` with pattern `"\\n---\\n"` to split `inbox.md`
into sections. Each section is then split on the first `\\n` after the
opening `---` to separate husk from core. More precisely:

1. Split `inbox.md` content on `\n---\n` → list of sections.
2. Each bean occupies two consecutive sections: the first is the husk
   (between `---` delimiters), the second is the core (until the next
   `---` delimiter).
3. Parse the husk as `key: value` pairs. Multi-line values use YAML `|`
   block scalar syntax — read until dedent or next `key:`.

The Coder should reuse `%parse-bean-section` from
`dispatch-tree.md` §3.14, extended to handle the new fields (`membrane`,
type-specific fields, `lifecycle` alias). The extended parser lives in
`beans.lisp` and shadows (or replaces) the one in `squad-dispatch.lisp`.
See §11 for the consolidation strategy.

---

## 3. Lifecycle state machine

### 3.1 States

```
                  plant-bean           (auto, file-change event)         harvest-bean
                  ──────────>          ──────────────────────>           ────────────>
PLANTED                              GROWING                              RIPE
                     │                     │                                 │
                     │                     │                                 │
                     │            (expires passed,                          │
                     │             never harvested)                          │
                     │                     │                                 v
                     v                     v                           HARVESTED
                  SPOILED              SPOILED                               │
                                                                               │
                                                                               │ digest-bean
                                                                               v
                                                                          DIGESTED
                                                                               │
                                                                               │ husk-bean
                                                                               v
                                                                          HUSKED
```

Two additional terminal/exception states:

- **SPOILED** — A bean that was never harvested (or was harvested but
  never digested) and has passed its staleness deadline. The core has
  decayed — context gone stale, dependencies broken. Spoiled beans are
  detected by `check-bean-staleness` and culled by `cull-spoiled-beans`.

- **FERAL** — A spore bean that has propagated beyond the squad's
  control. Feral beans are spore beans that have exceeded their
  `propagation-limit` or have generated sub-beans in unintended roles'
  inboxes. Detected during spore propagation tracking and culled by
  `cull-spoiled-beans` (with `:feral t`).

### 3.2 State transitions

| From | To | Trigger | Function |
|---|---|---|---|
| (none) | `planted` | bean written to inbox | `plant-bean` |
| `planted` | `growing` | file-change event detected (or immediate if content is complete) | `plant-bean` (sets `growing` if content provided is incomplete) or auto-transition |
| `planted` | `ripe` | content is complete at plant time | `plant-bean` (sets `ripe` directly) |
| `growing` | `ripe` | content assembly complete | `ripen-bean` (internal, not exported) |
| `ripe` | `harvested` | role reads the bean | `harvest-bean` |
| `harvested` | `digested` | role processes the bean, produces output | `digest-bean` |
| `digested` | `husked` | husk written to journal | `husk-bean` |
| `planted`/`growing`/`ripe` | `spoiled` | `expires` deadline passed and bean not harvested | `check-bean-staleness` |
| `harvested` | `spoiled` | `expires` deadline passed and bean not digested | `check-bean-staleness` |
| `spore` (any state after digestion) | `feral` | propagation-limit exceeded | spore propagation tracking in `digest-bean` |

### 3.3 Transition rules

1. `plant-bean` sets initial state to `planted`. If `content` is a
   non-empty string (the normal case), it immediately transitions to
   `ripe` (content is complete at plant time). If `content` is nil
   (streaming/pending content — rare, used when a bean is pre-allocated
   and content arrives later), state is `growing` and `ripen-bean`
   transitions to `ripe` when content is filled.

2. `harvest-bean` is only legal from `ripe` (or `planted` — a bean
   planted as `ripe` may have been immediately ready). If the bean is
   `growing`, harvest signals an error ("bean not yet ripe"). If the
   bean is `spoiled`, harvest signals an error ("bean is spoiled,
   cannot harvest"). If the bean is already `harvested`, harvest
   signals an error (per Wave 3 behavior).

3. `digest-bean` is only legal from `harvested`. If the bean is not
   `harvested`, digest signals an error. Digestion is the step where the
   role processes the core content and produces output (the actual work
   — writing code, producing a design doc, etc.). The plugin records the
   digestion but does NOT perform the work — that's the role's job.
   `digest-bean` marks the bean as `digested` and triggers `husk-bean`
   automatically.

4. `husk-bean` is only legal from `digested`. Writes the husk entry to
   the role's journal. If already `husked`, signals an error.

5. `spoiled` is a terminal state. Once a bean is spoiled, it cannot be
   harvested or digested. It can only be culled (removed from inbox).

6. `feral` is a terminal state for spore beans. Once a spore is marked
   feral, its propagation chain is halted — no further sub-beans are
   generated from it. It can only be culled.

### 3.4 Auto-transitions

The `growing → ripe` transition is handled by `ripen-bean` (internal):

```lisp
(defun %ripen-bean (squad-root role bean-name)
  ...)
```

This is called when content is filled into a `growing` bean. In
practice, most beans are planted with content already present, so they
skip `growing` and go directly to `ripe`. The `growing` state exists for
the rare case where a bean is pre-allocated (e.g., a resource bean
awaiting a file download to complete). The Coder should implement
`%ripen-bean` but it's not exported — it's called internally by any
function that fills content into a growing bean (e.g., a future
`fill-bean-content` function, not in this spec).

---

## 4. Function specifications

All functions are in package `:hngh.plugins.beans`. Exported symbols
are marked with `→`. Functions that extend Wave 3 functions reference
the base behavior in `dispatch-tree.md` and describe only the deltas.

### 4.1 `plant-bean` → (extended from D3)

```lisp
(defun plant-bean (squad-root from to bean-name &key
                                        (type :message)
                                        (content "")
                                        (membrane :ingest)
                                        (expires nil)
                                        (type-fields nil)
                                        (model-config nil))
  ...)
```

**Extensions from D3** (`dispatch-tree.md` §3.2):

| Parameter | Type | Default | Description (new in Wave 4) |
|---|---|---|---|
| `membrane` | keyword | `:ingest` | membrane directive: `:ingest`, `:chew`, `:extract`, `:ferment` |
| `expires` | string or nil | nil | ISO-8601 staleness deadline |
| `type-fields` | plist or nil | nil | type-specific husk fields (e.g. `(:task-id "w4" :title "..." :acceptance "...")`) |

**Behavior (additions to D3):**

1. Validate `type` is one of the 7 known types. If not, signal `error`
   "Unknown bean type: ~A".
2. Validate `membrane` is one of `:ingest`, `:chew`, `:extract`,
   `:ferment`. If not, signal `error` "Unknown membrane: ~A".
3. Validate `type-fields` against the type's required fields (§1.3).
   Missing required fields → `error` "Bean type ~A requires field ~A".
4. If `type` is `:spore`, validate `propagation-limit` is a positive
   integer and `sub-bean-types` is a non-empty list. If
   `propagation-limit` exceeds 10, log a warning ("spore
   propagation-limit > 10 is dangerous") but do not error.
5. Format the husk (front matter) with all common fields plus
   `membrane`, `expires`, and all `type-fields` key-value pairs.
6. If `content` is non-empty, set initial `status` to `ripe` (content
   is complete at plant time). If `content` is empty/nil, set `status`
   to `growing`.
7. Write the bean section to `<squad-root>/<to>/inbox.md` (append,
   atomic write-then-rename).
8. Update `dispatch.md` Communications table: append row with `from`,
   `to`, `bean-name`, status matching the bean's lifecycle state
   (`planted` or `ripe`).
9. Stage and commit: `git commit -m "[bean] ~A -> ~A: ~A (~A)" from to
   bean-name type`.

**Commit message format:** `[bean] pm -> designer: wave-4-beans-spec (task)`

**Returns:** A plist (extends D3):

```lisp
(:squad-root <pathname>
 :bean <string>
 :from <keyword>
 :to <keyword>
 :type <keyword>
 :membrane <keyword>
 :status <string>          ; "planted" or "ripe"
 :commit-sha <string>)
```

**Errors** (in addition to D3):

- Unknown bean type → `error`.
- Unknown membrane → `error`.
- Missing required type-field → `error`.
- Spore with propagation-limit > 10 → warning (not error).

---

### 4.2 `harvest-bean` → (extended from D3)

```lisp
(defun harvest-bean (squad-root role bean-name)
  ...)
```

**Extensions from D3** (`dispatch-tree.md` §3.3):

**Behavior (additions to D3):**

1. Before harvesting, call `check-bean-staleness` (§4.5) on the bean. If
   the bean is spoiled (or has become spoiled since the last check),
   signal `error` "Bean ~A is spoiled — cannot harvest. Run
   cull-spoiled-beans to clean up.".
2. Validate the bean's lifecycle state is `ripe` (or `planted` with
   content — which means it was planted as ripe). If `growing`, signal
   `error` "Bean ~A is still growing — not yet ripe for harvest.". If
   `spoiled`, signal `error` (covered by staleness check). If
   `feral` (spore), signal `error` "Bean ~A is feral — propagation
   halted.".
3. Update the bean's husk `status` field to `harvested` in `inbox.md`.
4. Update `dispatch.md` Communications table: status → `harvested`.
5. Stage and commit: `git commit -m "[bean] ~A harvested: ~A" role
   bean-name`.

**Returns:** A plist (extends D3):

```lisp
(:squad-root <pathname>
 :bean <string>
 :role <keyword>
 :content <string>          ; the bean's core content
 :type <string>             ; bean type (parsed from husk)
 :membrane <string>         ; membrane directive (parsed from husk)
 :type-fields <plist>       ; type-specific fields parsed from husk
 :commit-sha <string>)
```

The return value now includes `type`, `membrane`, and `type-fields` so
the consuming role knows how to process the bean without re-parsing the
husk.

**Errors** (in addition to D3):

- Bean is spoiled → `error` (from staleness check).
- Bean is growing (not yet ripe) → `error`.
- Bean is feral → `error`.

---

### 4.3 `digest-bean` →

```lisp
(defun digest-bean (squad-root role bean-name &key
                                       (output "")
                                       (output-path nil)
                                       (attribution ""))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role digesting the bean |
| `bean-name` | string | bean identifier to digest |
| `output` | string | the role's output (the work produced by digesting this bean's core) |
| `output-path` | pathname or nil | path to write the output to (if non-nil, writes `output` to this path) |
| `attribution` | string | attribution string (e.g. "Coder — deepseek-v4-flash, Hermes harness, $0") |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `<squad-root>/<role>/inbox.md`, find the bean section matching
   `bean-name` and `to` = `role`.
3. If not found → `error` "Bean ~A not found in ~A inbox".
4. If the bean's `status` is not `harvested` → `error` "Bean ~A must be
   harvested before digestion (current status: ~A)".
5. Update the bean's husk `status` field to `digested` in `inbox.md`
   (rewrite file atomically).
6. If `output-path` is non-nil, write `output` to `output-path`
   atomically (write-then-rename).
7. Update `dispatch.md` Communications table: status → `digested`.
8. **Spore propagation**: If the bean's `type` is `spore`, call
   `%propagate-spore` (§4.8) to auto-generate sub-beans. The
   propagation result is included in the return value.
9. Call `husk-bean` (§4.4) to write the husk entry to the journal.
   This transitions the bean to `husked`.
10. Stage and commit: `git commit -m "[bean] ~A digested: ~A" role
    bean-name`. If spore propagation generated sub-beans, the commit
    message includes the count: `"[bean] ~A digested: ~A (spore: ~D
    sub-beans)"`.

**Commit message format:**
- Normal: `[bean] coder digested: wave-4-beans-spec`
- Spore: `[bean] worker digested: auto-task-chain (spore: 3 sub-beans)`

**Returns:**

```lisp
(:squad-root <pathname>
 :bean <string>
 :role <keyword>
 :output <string>            ; the output text
 :output-path <pathname-or-nil>
 :spore-result <plist-or-nil> ; nil if not a spore; see §4.8 for spore result format
 :commit-sha <string>)        ; SHA of the digest commit (husking is same commit)
```

**Errors:**

- Bean not found → `error`.
- Bean not harvested → `error`.
- Bean already digested → `error` "Bean ~A already digested".
- `husk-bean` fails → `error` (propagated from husk-bean).
- Spore propagation exceeds limit → `error` "Spore ~A exceeded
  propagation-limit of ~D" (and the spore is marked `feral`).

---

### 4.4 `husk-bean` →

```lisp
(defun husk-bean (squad-root role bean-name &key
                                       (output "")
                                       (attribution ""))
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role that digested the bean |
| `bean-name` | string | bean identifier |
| `output` | string | the output produced by digestion |
| `attribution` | string | role — model, harness, cost |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `<squad-root>/<role>/inbox.md`, find the bean section matching
   `bean-name` and `to` = `role`.
3. If not found → `error`.
4. If the bean's `status` is not `digested` → `error` "Bean ~A must be
   digested before husking (current status: ~A)". Note:
   `digest-bean` calls `husk-bean` internally, so by the time
   `husk-bean` runs, the status is already `digested`.
5. Format the husk entry for the journal. The husk entry includes:
   - bean name
   - type
   - from/to
   - planted timestamp
   - digested timestamp (now)
   - membrane directive
   - output summary (first 500 chars of `output`, or full if shorter)
   - attribution
   - output-path (if the output was written to a file)
6. Append the husk entry to `<squad-root>/journal/actual.md`.
7. Update the bean's husk `status` field to `husked` in `inbox.md`.
8. Update `dispatch.md` Communications table: status → `husked`.

Note: `husk-bean` does NOT make a separate git commit — it is called
within `digest-bean`'s commit scope. If called independently (which is
unusual), it makes its own commit: `git commit -m "[bean] ~A husked:
~A" role bean-name`.

**Husk entry format** (appended to `journal/actual.md`):

```markdown
---
bean: wave-4-beans-spec
type: task
from: pm
to: designer
planted: 2026-08-03T14:00:00
digested: 2026-08-03T16:30:00
membrane: chew
attribution: Designer — glm-5.2, Hermes harness, $0
output-path: docs/design/beans-lifecycle.md
---

Digested wave-4-beans-spec (task bean from pm). Produced
docs/design/beans-lifecycle.md. All 7 bean types defined, lifecycle
state machine specified, spore propagation designed.
```

**Returns:**

```lisp
(:squad-root <pathname>
 :bean <string>
 :role <keyword>
 :journal-path <pathname>   ; path to journal/actual.md
 :husk-entry <string>       ; the formatted husk entry text
 :commit-sha <string-or-nil>) ; nil if called within digest-bean's commit
```

**Errors:**

- Bean not found → `error`.
- Bean not digested → `error`.
- Bean already husked → `error` "Bean ~A already husked".

---

### 4.5 `check-bean-staleness` →

```lisp
(defun check-bean-staleness (squad-root role bean-name)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role whose inbox contains the bean |
| `bean-name` | string | bean identifier to check |

**Behavior:**

1. Validate `squad-root` exists.
2. Read `<squad-root>/<role>/inbox.md`, find the bean section matching
   `bean-name` and `to` = `role`.
3. If not found → return `(:stale nil :reason "bean not found")` (not
   an error — the bean may have already been culled).
4. Read the bean's `status` and `expires` fields.
5. If `expires` is nil (no deadline set) → return `(:stale nil)`.
6. If `status` is already `spoiled` or `feral` → return
   `(:stale t :reason "already ~A" status)`.
7. If `status` is `digested` or `husked` → return `(:stale nil)` (the
   bean has been consumed; staleness doesn't apply).
8. Compare `expires` timestamp to current time. If current time >
   `expires`:
   a. Update the bean's husk `status` to `spoiled` in `inbox.md`.
   b. Update `dispatch.md` Communications table: status → `spoiled`.
   c. Stage and commit: `git commit -m "[bean] ~A spoiled: ~A
      (expired ~A)" role bean-name expires`.
   d. Return `(:stale t :reason "expired" :expires <string>)`.
9. If current time ≤ `expires` → return `(:stale nil)`.

**Staleness precondition re-check at harvest time:**

`harvest-bean` (§4.2) calls `check-bean-staleness` before proceeding.
This ensures that a bean which became stale between the last check and
the harvest attempt is caught. The role never harvests a spoiled bean.

**Returns:**

```lisp
(:stale <boolean>
 :reason <string>           ; "expired", "already spoiled", "already feral", "no deadline", "bean not found", or ""
 :expires <string-or-nil>  ; the expires timestamp, if present
 :commit-sha <string-or-nil>) ; SHA of the spoiled-commit, if the bean was just marked spoiled
```

**Errors:**

- `squad-root` doesn't exist → `error`.
- `inbox.md` unparseable → `error` (not a missing bean — that's a
  return value, not an error).

---

### 4.6 `cull-spoiled-beans` →

```lisp
(defun cull-spoiled-beans (squad-root &key
                                        (role nil)
                                        (feral-only nil)
                                        (dry-run nil))
  ...)
```

**Arguments:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `squad-root` | pathname | (required) | squad root directory |
| `role` | keyword or nil | nil | if non-nil, only cull beans in this role's inbox; if nil, cull across all roles |
| `feral-only` | boolean | nil | if T, only cull feral beans (not spoiled) |
| `dry-run` | boolean | nil | if T, identify and report spoiled/feral beans but do not remove them |

**Behavior:**

1. Validate `squad-root` exists.
2. Determine the set of role directories to scan: if `role` is non-nil,
   scan only `<squad-root>/<role>/inbox.md`. If nil, scan all role
   directories under `<squad-root>/`.
3. For each role's `inbox.md`:
   a. Parse all bean sections.
   b. For each bean, check if `status` is `spoiled` (or `feral` if
      `feral-only` is T).
   c. If `dry-run` is nil, remove the bean section from `inbox.md`
      (rewrite the file without the spoiled/feral section, atomic).
   d. Update `dispatch.md` Communications table: remove (or mark)
      the culled bean rows.
4. If `dry-run` is nil, stage and commit: `git commit -m "[bean] culled
   ~D spoiled bean~:P from ~A" count (or role)`.
5. Return the list of culled (or identified) beans.

**Spoiled bean detection within `cull-spoiled-beans`:**

Before culling, `cull-spoiled-beans` runs `check-bean-staleness` on every
non-digested bean in the scanned inboxes. This catches beans that have
expired since the last check but haven't been marked `spoiled` yet.
Newly-detected spoiled beans are marked `spoiled` before being culled.

**Feral bean detection:**

Feral beans are spore beans that have:
- Exceeded their `propagation-limit` (more sub-beans generated than
  the limit allows), OR
- Planted sub-beans in roles not listed in `sub-bean-types` (if
  specified — see §4.8), OR
- Have a `parent-spore` chain deeper than 5 levels (safety limit).

Feral detection requires tracking spore propagation across the squad. The
`%track-spore-propagation` helper (§4.9) walks the git log and inbox
sections to count sub-beans per spore. Feral spores are marked `feral`
and their sub-beans are also marked `feral` (the entire chain is
halted).

**Returns:**

```lisp
(:squad-root <pathname>
 :culled (list               ; one plist per culled/identified bean
           (:role <keyword> :bean <string> :type <string> :state <string> :reason <string>)
           ...)
 :count <integer>            ; number of beans culled (or identified if dry-run)
 :dry-run <boolean>
 :commit-sha <string-or-nil>) ; nil if dry-run
```

**Errors:**

- `squad-root` doesn't exist → `error`.
- `inbox.md` unparseable for a scanned role → `error` (fail fast —
  don't silently skip corrupted inboxes).

---

### 4.7 `read-bean` →

```lisp
(defun read-bean (squad-root role bean-name)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role whose inbox contains the bean |
| `bean-name` | string | bean identifier |

**Behavior:**

1. Read `<squad-root>/<role>/inbox.md`.
2. Parse bean sections, find the one matching `bean-name` and `to` =
   `role`.
3. Return the full parsed bean as a plist.

This is a pure read — it does not change the bean's lifecycle state or
make any git commits. Useful for inspecting a bean before harvesting.

**Returns:**

```lisp
(:bean <string>
 :from <string>
 :to <string>
 :planted <string>
 :type <string>
 :status <string>
 :expires <string-or-nil>
 :membrane <string>
 :content <string>           ; the core body
 :type-fields <plist>)       ; type-specific fields parsed from husk
```

**Errors:**

- Bean not found → `error` "Bean ~A not found in ~A inbox".
- `squad-root` doesn't exist → `error`.

---

### 4.8 Spore propagation: `%propagate-spore` (internal)

```lisp
(defun %propagate-spore (squad-root role bean-name spore-fields output)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `role` | keyword | the role digesting the spore |
| `bean-name` | string | the spore bean's name |
| `spore-fields` | plist | parsed spore-specific fields (`spore-id`, `propagation-limit`, `sub-bean-types`, `parent-spore`) |
| `output` | string | the role's digestion output — expected to contain sub-bean specifications |

**Behavior:**

1. Parse `output` for sub-bean specifications. The output is expected to
   contain a structured section (markdown fenced code block with
   language `spore`) listing sub-beans to plant:

   ````markdown
   ```spore
   - bean: auto-task-1
     to: coder
     type: task
     content: "Implement the foo function"
   - bean: auto-msg-1
     to: designer
     type: message
     content: "Design the bar interface"
   ```
   ````

   If no `spore` code block is found, no sub-beans are generated (the
   role chose not to propagate). This is valid — digestion of a spore
   does not *require* propagation, it *enables* it.

2. Count the sub-beans in the output. If the count exceeds
   `propagation-limit`:
   a. Mark the spore bean as `feral` in `inbox.md`.
   b. Update `dispatch.md`: status → `feral`.
   c. Signal `error` "Spore ~A exceeded propagation-limit of ~D
      (attempted ~D sub-beans)".

3. For each sub-bean specification:
   a. Validate `to` is a valid role directory.
   b. Validate `type` is in `sub-bean-types` (if specified — if
      `sub-bean-types` is `["*"]` or unspecified, all types are
      allowed).
   c. Set `parent-spore` to the current spore's `spore-id`.
   d. Call `plant-bean` to plant the sub-bean in the target role's
      inbox.
   e. Track the sub-bean in the propagation record.

4. If any sub-bean is planted in a role not listed in the spore's
   intended targets (the `to` field of the original spore + any
   additional roles specified in the spore's `sub-bean-types`
   metadata), mark the spore as `feral`. (The intended targets are
   determined by the roles the PM originally authorized — in practice,
   this check compares the sub-bean's `to` role against the set of
   roles that have active tasks from the same PM. For Wave 4, the
   simple check is: sub-bean `to` must be one of the roles in the
   squad's dispatch tree. Unauthorized = planting in a role not in
   the squad.)

5. Check propagation depth: if `parent-spore` is non-nil and the
   chain depth (count of ancestors) exceeds 5, mark the spore as
   `feral`.

**Returns:**

```lisp
(:spore-id <string>
 :sub-beans (list             ; one plist per planted sub-bean
              (:bean <string> :to <keyword> :type <keyword> :planted t)
              ...)
 :sub-bean-count <integer>
 :feral <boolean>             ; T if the spore was marked feral during propagation
 :feral-reason <string-or-nil>)
```

This is an internal function — not exported. Called by `digest-bean`
when the bean type is `spore`.

---

### 4.9 Spore tracking: `%track-spore-propagation` (internal)

```lisp
(defun %track-spore-propagation (squad-root spore-id)
  ...)
```

**Arguments:**

| Parameter | Type | Description |
|---|---|---|
| `squad-root` | pathname | squad root directory |
| `spore-id` | string | spore identifier to track |

**Behavior:**

1. Scan all role inboxes under `<squad-root>/` for beans with
   `parent-spore` = `spore-id`.
2. Count the sub-beans. Check if the count exceeds the spore's
   `propagation-limit`.
3. Check the depth of the propagation chain (follow `parent-spore`
   links upward from each sub-bean to count ancestors).
4. Return the propagation record.

**Returns:**

```lisp
(:spore-id <string>
 :sub-beans (list ...)
 :count <integer>
 :limit <integer>
 :depth <integer>
 :exceeded-limit <boolean>
 :exceeded-depth <boolean>)
```

Used by `cull-spoiled-beans` to detect feral spores. Internal, not
exported.

---

### 4.10 Helper: `%parse-bean-husk` (extended)

```lisp
(defun %parse-bean-husk (husk-text)
  ...)
```

Extends `dispatch-tree.md` §3.14 (`%parse-bean-section`) with:

- `membrane` field parsing
- `expires` field parsing
- `lifecycle` field (alias for `status`)
- Type-specific fields (all unknown keys are captured in
  `type-fields` plist)
- Multi-line values via YAML `|` block scalar (read until dedent or
  next `key:` at column 0)

Returns:

```lisp
(:bean "wave-4-beans-spec"
 :from "pm"
 :to "designer"
 :planted "2026-08-03T14:00:00"
 :type "task"
 :status "planted"
 :expires nil
 :membrane "chew"
 :content "..."              ; core body
 :type-fields (:task-id "w4" :title "..." :blocked-by "w3" :acceptance "..." :files "..."))
```

---

### 4.11 Helper: `%format-bean-husk`

```lisp
(defun %format-bean-husk (bean-plist)
  ...)
```

Serializes a bean plist into the husk+core markdown format (§2.2).
Used by `plant-bean` to format the bean section before appending to
`inbox.md`.

---

### 4.12 Helper: `%rewrite-inbox-section`

```lisp
(defun %rewrite-inbox-section (inbox-path bean-name new-status
                              &optional extra-fields)
  ...)
```

Reads `inbox.md`, finds the section matching `bean-name`, updates the
`status` field (and any `extra-fields`), rewrites the file atomically.
Used by `harvest-bean`, `digest-bean`, `husk-bean`,
`check-bean-staleness`.

---

### 4.13 Lifecycle functions

Following the established plugin pattern (`config-watcher.lisp`,
`fragment-journal.lisp`):

```lisp
(defun init () ...)         ; no-op (stateless — all state on disk)
(defun shutdown () ...)      ; no-op
(defun running-p () ...)     ; returns *running* (always nil in Wave 4 — no daemon)
(defun status () ...)        ; returns plist with plugin info
```

The plugin is stateless in Wave 4 — all state is on disk. Lifecycle
functions exist for ASDF/plugin-host compatibility.

---

## 5. Spoiled and feral states

### 5.1 Spoiled bean detection

A bean is spoiled when:

1. Its `expires` timestamp has passed, AND
2. It has not reached `digested` or `husked` state.

Spoiled beans are detected by `check-bean-staleness` (called at harvest
time and during `cull-spoiled-beans` scans). Once detected, the bean's
status is updated to `spoiled` and the change is committed to git.

A pod (inbox) with multiple spoiled beans is a "rotting inbox" — the
assigned role has been neglecting its feed. The Accountant can detect
this by scanning for spoiled beans across all inboxes.

### 5.2 Feral bean detection

A spore bean is feral when:

1. It has generated more sub-beans than its `propagation-limit` allows,
   OR
2. Its sub-beans have been planted in roles not in the squad's dispatch
   tree, OR
3. Its propagation chain depth exceeds 5 levels.

Feral beans are detected during:
- `digest-bean` of a spore (immediate check during propagation — §4.8)
- `cull-spoiled-beans` with `:feral-only t` (scan-based detection —
  §4.6, uses `%track-spore-propagation` — §4.9)

Once a spore is marked feral:
- The spore bean's status → `feral`.
- All sub-beans in the chain that haven't been digested are marked
  `feral` as well.
- No further sub-beans are generated from any bean in the chain.
- The feral chain is committed to git for audit.

### 5.3 Notification

When `cull-spoiled-beans` removes spoiled or feral beans, it:

1. Returns the list of culled beans in its result plist.
2. Logs a warning via `hngh.core:log-warn` for each culled bean:
   `"Spoiled bean culled: ~A from ~A inbox (~A)" bean-name role reason`.
3. The git commit message records the culling: `[bean] culled 3
   spoiled beans from designer`.

The caller (typically the Accountant or PM) is responsible for
notifying the affected roles. The plugin does not send messages — it
records the culling in git and returns the result.

---

## 6. Cross-role exchange

Any role can plant beans in any other role's inbox. This is a core
design principle from `beans-aesthetic.md`:

> "The PM is the primary planter, but any agent can plant beans in
> another's pod."

**Implementation:**

`plant-bean` accepts `from` and `to` as any role keywords. The only
validation is that the `to` role's directory exists under
`<squad-root>/`. There is no access control — the squad operates on
trust within its own dispatch tree.

**Examples:**

- Designer → Coder: `(plant-bean root :designer :coder "design-handoff"
  :type :message :content "Design complete, see docs/design/...")`
- Coder → Accountant: `(plant-bean root :coder :accountant
  "cost-projection-request" :type :message :content "Need cost
  projection for model tier X")`
- Accountant → PM: `(plant-bean root :accountant :pm "budget-report"
  :type :status :content "Budget projection: $0.45 spent, $0.55
  remaining")`
- Artist → Designer: `(plant-bean root :artist :designer
  "visual-review" :type :review :artifact "assets/moodboard.png"
  :verdict "request-changes" :content "The palette needs more
  contrast")`

**dispatch.md update policy for cross-role plants:**

Per `dispatch-tree.md` §5, the PM owns `dispatch.md`. When a non-PM role
plants a bean:
- The bean is appended to the recipient's `inbox.md` and committed with
  `[bean]` prefix.
- The Communications table in `dispatch.md` is updated by `plant-bean`
  directly (not deferred to the PM). This is consistent with Wave 3's
  policy where `harvest-bean` (called by the harvesting role) updates
  `dispatch.md` directly.
- The per-squad mutex (§8) prevents concurrent write races.

---

## 7. Spore bean propagation

### 7.1 Overview

Spore beans are self-propagating beans that, when digested, cause the
consuming role to autonomously generate and plant sub-beans. This
enables autonomous sub-task chains without further PM intervention.

### 7.2 Propagation flow

1. PM (or any role) plants a spore bean in a role's inbox:
   ```lisp
   (plant-bean root :pm :worker "auto-task-chain"
     :type :spore
     :membrane :ferment
     :content "When you digest this spore, generate task beans for:
               1. Scan the codebase for TODO comments
               2. Create a summary report
               Plant each as a task bean in your own inbox and digest
               them."
     :type-fields '(:spore-id "spore-001"
                    :propagation-limit 5
                    :sub-bean-types "task,message"))
   ```

2. The role harvests and digests the spore bean via `digest-bean`.
   The role's output includes a ```spore``` code block listing the
   sub-beans to plant.

3. `digest-bean` detects `type = spore` and calls
   `%propagate-spore`.

4. `%propagate-spore` parses the sub-bean specifications from the
   output, validates them against the spore's limits, and calls
   `plant-bean` for each sub-bean.

5. Each sub-bean is planted with `parent-spore` set to the original
   spore's `spore-id`, creating a traceable propagation chain.

6. If any validation fails (limit exceeded, unauthorized target,
   depth exceeded), the spore is marked `feral` and propagation
   stops.

### 7.3 Sub-bean specification format

The consuming role's `output` (passed to `digest-bean`) must contain a
fenced code block with language `spore`:

````markdown
```spore
- bean: auto-task-1
  to: worker
  type: task
  content: "Scan codebase for TODO comments"
  membrane: chew
  type-fields:
    task-id: auto-1
    title: TODO scan
    acceptance: "List of TODO comments with file locations"
- bean: auto-task-2
  to: worker
  type: task
  content: "Create summary report"
  membrane: chew
  type-fields:
    task-id: auto-2
    title: Summary report
    acceptance: "Markdown report with TODO count by file"
```
````

The parser reads this as a list of YAML-like entries. Each entry has
`bean`, `to`, `type`, `content`, `membrane` (optional, default
`:ingest`), and `type-fields` (optional plist). The Coder should
implement a simple YAML-subset parser for this block (key-value pairs,
list items starting with `- `, no nesting beyond one level for
`type-fields`). This is the same parsing approach as the husk parser —
not full YAML, just `key: value` and `- key: value` patterns.

### 7.4 Safety limits

| Limit | Default | Configurable | Action on exceed |
|---|---|---|---|
| `propagation-limit` | 10 | per-spore (husk field) | Spore marked `feral`, error signaled |
| Chain depth | 5 | hard-coded | Spore marked `feral` |
| Sub-bean types | `["*"]` | per-spore (husk field) | Unauthorized type → sub-bean rejected, spore marked `feral` |

These limits are procedural — no LLM judgment involved. They prevent
runaway spore propagation (the "feral outbreak" scenario from
`beans-aesthetic.md`).

---

## 8. Bean staleness detection

### 8.1 Staleness mechanism

Every bean may optionally carry an `expires` timestamp in its husk.
When `expires` is set, the bean has a staleness deadline. If the bean
is not digested (or at least harvested) by the deadline, it spoils.

### 8.2 When staleness is checked

| When | Who | How |
|---|---|---|
| At harvest time | `harvest-bean` | Calls `check-bean-staleness` before proceeding |
| During cull scan | `cull-spoiled-beans` | Runs `check-bean-staleness` on every non-digested bean |
| Periodically (future) | Accountant heartbeat | Not in Wave 4 — manual or cron-triggered `cull-spoiled-beans` |

### 8.3 Staleness precondition re-check

The key scenario: a bean was planted with `expires` set to 2 hours
from planting. The role was busy and didn't harvest it. 3 hours later,
the role attempts to harvest. `harvest-bean` calls
`check-bean-staleness`, which detects the bean has expired, marks it
`spoiled`, and returns `(:stale t)`. `harvest-bean` then signals an
error instead of harvesting.

This ensures the role never works on stale context. The spoiled bean
is culled by the Accountant or PM via `cull-spoiled-beans`.

### 8.4 Beans without `expires`

Beans without an `expires` field do not spoil by time. They can remain
in an inbox indefinitely. This is intentional — not all beans have
time-sensitive context. However, beans without `expires` that are never
harvested are still detected by `cull-spoiled-beans` as "abandoned"
(the Accountant can flag beans planted > 24 hours ago that haven't been
harvested, even without an `expires` field — but this is an
Accountant-level heuristic, not a plugin function in Wave 4).

---

## 9. Package definition

Add to `src/packages.lisp`:

```lisp
(defpackage :hngh.plugins.beans
  (:documentation "Bean Lifecycle (Wave 4) — typed beans, husk/core/membrane format, lifecycle state machine, spoiled/feral detection, spore propagation.")
  (:use :cl :hngh.core)
  (:export #:init
           #:shutdown
           #:running-p
           #:status
           ;; Bean lifecycle
           #:plant-bean
           #:harvest-bean
           #:digest-bean
           #:husk-bean
           #:read-bean
           ;; Staleness and culling
           #:check-bean-staleness
           #:cull-spoiled-beans
           ;; Bean type constants
           #:*bean-types*
           #:*membrane-directives*))
```

---

## 10. ASDF registration

Add to `hngh.asd` in the `hngh` system `:components` list (after
`squad-dispatch`):

```lisp
(:file "plugins/beans")
```

Add to `hngh/tests` system `:components` (after `test-squad-dispatch`):

```lisp
(:file "test-beans")
```

---

## 11. Relationship to `squad-dispatch.lisp`

The Wave 3 `squad-dispatch.lisp` defines `plant-bean` and
`harvest-bean` (dispatch-tree.md §3.2–3.3). Wave 4 extends these
functions with type-awareness, membrane directives, lifecycle states,
and journal integration.

**Consolidation strategy (for the Coder):**

The Coder has two options:

1. **Shadow approach** (recommended): Move `plant-bean` and
   `harvest-bean` into `beans.lisp` as the canonical implementations.
   In `squad-dispatch.lisp`, replace the function bodies with thin
   wrappers that delegate to `hngh.plugins.beans:plant-bean` (and
   `harvest-bean`). This keeps `squad-dispatch` as the "tree
   management" plugin and `beans` as the "bean lifecycle" plugin.
   The wrappers handle the package boundary:
   ```lisp
   (in-package :hngh.plugins.squad-dispatch)
   (defun plant-bean (squad-root from to bean-name &rest keys)
     (apply #'hngh.plugins.beans:plant-bean squad-root from to bean-name keys))
   ```

2. **Merge approach**: Move all bean-related code into `beans.lisp` and
   remove `plant-bean`/`harvest-bean` from `squad-dispatch.lisp`
   entirely. Update any callers to use `hngh.plugins.beans:plant-bean`
   directly. This is cleaner but requires updating `squad-dispatch`'s
   package exports and any code that calls the functions via the
   `squad-dispatch` package.

Either approach is acceptable. The spec recommends option 1 (shadow)
for backward compatibility — existing Wave 3 code that calls
`hngh.plugins.squad-dispatch:plant-bean` continues to work.

---

## 12. Concurrent write policy (extends dispatch-tree.md §5)

The per-squad mutex from Wave 3 (dispatch-tree.md §5) is extended to
cover all bean lifecycle functions. Any function that reads or writes
`inbox.md`, `dispatch.md`, or `journal/actual.md` acquires the mutex.

| File | Writers (Wave 4) | Readers |
|---|---|---|
| `dispatch.md` | PM (assign, status), plant-bean (comms table), harvest-bean (comms status), digest-bean (comms status), husk-bean (comms status), check-bean-staleness (comms status), cull-spoiled-beans (comms rows) | All roles |
| `<role>/inbox.md` | plant-bean (append), harvest-bean (status update), digest-bean (status update), husk-bean (status update), check-bean-staleness (status update), cull-spoiled-beans (section removal) | All roles |
| `journal/actual.md` | husk-bean (append husk entry) | All roles |

The mutex is per-squad-root, stored in a hash table keyed by
`(namestring squad-root)`. Acquire with `bt:with-lock-held` around all
read-modify-write operations.

---

## 13. Git commit message format (extends dispatch-tree.md §6)

New prefixes for Wave 4:

| Prefix | Used by | Example |
|---|---|---|
| `[bean]` | plant-bean, harvest-bean, digest-bean, husk-bean | `[bean] pm -> designer: wave-4-beans-spec (task)` |
| `[bean]` | digest-bean (spore) | `[bean] worker digested: auto-task-chain (spore: 3 sub-beans)` |
| `[bean]` | check-bean-staleness | `[bean] designer spoiled: stale-task (expired 2026-08-04T14:00:00)` |
| `[bean]` | cull-spoiled-beans | `[bean] culled 3 spoiled beans from designer` |

All commit messages are single-line (per Wave 3 rule). Role names are
string-downcased.

---

## 14. Test fixture specification

Test file: `tests/unit/test-beans.lisp`

### 14.1 Package and suite

```lisp
(in-package :hngh.tests)

(def-suite :hngh.beans
  :description "Tests for beans plugin (Wave 4)"
  :in :hngh)

(in-suite :hngh.beans)
```

### 14.2 Fixture helpers

```lisp
(defun %beans-tmp-root ()
  "Return a fresh temp directory for a test squad."
  (merge-pathnames (format nil "hngh-beans-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-beans (root)
  "Delete the test squad directory tree."
  (when (probe-file root)
    (uiop:delete-directory-tree root :validate t)))

(defun %setup-squad (&optional (home (%beans-tmp-root)))
  "Create a test squad and return (values root home)."
  (let* ((result (hngh.plugins.squad-dispatch:create-squad
                   "test-beans" :home home))
         (root (getf result :squad-root)))
    (values root home)))
```

### 14.3 Test cases

#### Test 1: plant message bean with membrane

```lisp
(test plant-message-bean-with-membrane
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (let ((result (hngh.plugins.beans:plant-bean
                        root :pm :designer "test-msg-1"
                        :type :message
                        :content "Design the beans plugin."
                        :membrane :ingest)))
           (is (eq :message (getf result :type)))
           (is (eq :ingest (getf result :membrane)))
           (is (string= "ripe" (getf result :status))) ; content provided → ripe
           (is (getf result :commit-sha))
           ;; Verify bean is in inbox with correct fields
           (let ((bean (hngh.plugins.beans:read-bean root :designer "test-msg-1")))
             (is (string= "message" (getf bean :type)))
             (is (string= "ingest" (getf bean :membrane)))
             (is (search "Design the beans plugin." (getf bean :content)))))
      (%cleanup-beans home))))
```

#### Test 2: plant task bean with type-specific fields

```lisp
(test plant-task-bean-with-fields
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (let ((result (hngh.plugins.beans:plant-bean
                        root :pm :coder "test-task-1"
                        :type :task
                        :content "Implement the beans plugin."
                        :membrane :chew
                        :expires "2099-12-31T23:59:59"
                        :type-fields '(:task-id "w4"
                                       :title "Bean Lifecycle"
                                       :blocked-by "w3"
                                       :acceptance "- All types defined
- Lifecycle implemented
- Tests green"
                                       :files "src/plugins/beans.lisp"))))
           (is (eq :task (getf result :type)))
           (is (getf result :commit-sha))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "test-task-1")))
             (is (string= "task" (getf bean :type)))
             (is (string= "chew" (getf bean :membrane)))
             (let ((tf (getf bean :type-fields)))
               (is (string= "w4" (getf tf :task-id)))
               (is (string= "Bean Lifecycle" (getf tf :title)))
               (is (string= "w3" (getf tf :blocked-by)))))
           ;; dispatch.md has the bean in Communications
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status :communications))))))
      (%cleanup-beans home))))
```

#### Test 3: full harvest → digest → husk cycle for a message bean

```lisp
(test full-cycle-message-bean
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :designer "cycle-msg"
            :type :message
            :content "Do the thing.")
           ;; Harvest
           (let ((harvest (hngh.plugins.beans:harvest-bean
                           root :designer "cycle-msg")))
             (is (search "Do the thing." (getf harvest :content)))
             (is (string= "message" (getf harvest :type)))
             (is (string= "ingest" (getf harvest :membrane))))
           ;; Digest
           (let ((digest (hngh.plugins.beans:digest-bean
                          root :designer "cycle-msg"
                          :output "Done."
                          :attribution "Designer — glm-5.2, Hermes harness")))
             (is (getf digest :commit-sha))
             (is (null (getf digest :spore-result)))) ; not a spore
           ;; Verify bean status is husked in inbox
           (let ((bean (hngh.plugins.beans:read-bean root :designer "cycle-msg")))
             (is (string= "husked" (getf bean :status))))
           ;; Verify husk entry in journal
           (let ((journal (uiop:read-file-string
                            (merge-pathnames "journal/actual.md" root))))
             (is (search "cycle-msg" journal))
             (is (search "Designer — glm-5.2" journal))))
      (%cleanup-beans home))))
```

#### Test 4: full cycle for each bean type

```lisp
(test full-cycle-all-types
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (dolist (type '(:message :task :status :resource :context :review))
           (let ((bean-name (format nil "cycle-~A" (string-downcase type))))
             (hngh.plugins.beans:plant-bean
              root :pm :worker bean-name
              :type type
              :content (format nil "~A bean content" (string-downcase type))
              :membrane :ingest
              :type-fields (case type
                             (:task '(:task-id "t1" :title "Test" :acceptance "ok"))
                             (:status '(:role "worker" :state "growing"))
                             (:resource '(:kind "file"))
                             (:context '(:scope "squad"))
                             (:review '(:artifact "test.md" :verdict "accept"))
                             (t nil)))
             (hngh.plugins.beans:harvest-bean root :worker bean-name)
             (hngh.plugins.beans:digest-bean
              root :worker bean-name
              :output "output"
              :attribution "Worker — test")
             ;; Verify husked
             (let ((bean (hngh.plugins.beans:read-bean root :worker bean-name)))
               (is (string= "husked" (getf bean :status))
                   "Bean ~A should be husked" bean-name))))
      (%cleanup-beans home))))
```

#### Test 5: stale bean detection — bean expires and is marked spoiled

```lisp
(test stale-bean-detection
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           ;; Plant a bean that expired in the past
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message
            :content "This is stale."
            :expires "2000-01-01T00:00:00") ; expired long ago
           ;; But plant-bean uses current time for planted, not expires.
           ;; We need to manually set expires to the past. Instead, plant
           ;; with expires in the past and check staleness.
           ;; Actually, expires is set by the caller. Let's plant and
           ;; then check.
           ;;
           ;; Wait — we need the bean to have expires in the past. Let's
           ;; plant with a past expires directly (the function accepts
           ;; expires as a string):
           ;; The bean above was planted with expires 2000-01-01.
           ;; Now check staleness:
           (let ((result (hngh.plugins.beans:check-bean-staleness
                          root :coder "stale-1")))
             (is (getf result :stale))
             (is (string= "expired" (getf result :reason))))
           ;; Bean is now marked spoiled
           (let ((bean (hngh.plugins.beans:read-bean root :coder "stale-1")))
             (is (string= "spoiled" (getf bean :status))))
           ;; Harvesting a spoiled bean errors
           (signals error
             (hngh.plugins.beans:harvest-bean root :coder "stale-1")))
      (%cleanup-beans home))))
```

#### Test 6: stale bean not stale when within deadline

```lisp
(test fresh-bean-not-stale
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "fresh-1"
            :type :message
            :content "This is fresh."
            :expires "2099-12-31T23:59:59") ; far future
           (let ((result (hngh.plugins.beans:check-bean-staleness
                          root :coder "fresh-1")))
             (is (null (getf result :stale)))))
      (%cleanup-beans home))))
```

#### Test 7: cull spoiled beans

```lisp
(test cull-spoiled-beans-removes-from-inbox
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           ;; Plant two beans: one stale, one fresh
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message :content "Stale."
            :expires "2000-01-01T00:00:00")
           (hngh.plugins.beans:plant-bean
            root :pm :coder "fresh-1"
            :type :message :content "Fresh."
            :expires "2099-12-31T23:59:59")
           ;; Mark the stale one as spoiled
           (hngh.plugins.beans:check-bean-staleness root :coder "stale-1")
           ;; Cull
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :role :coder)))
             (is (= 1 (getf result :count)))
             (is (string= "stale-1"
                          (getf (first (getf result :culled)) :bean)))))
           ;; Stale bean is gone from inbox
           (signals error
             (hngh.plugins.beans:read-bean root :coder "stale-1"))
           ;; Fresh bean is still there
           (let ((bean (hngh.plugins.beans:read-bean root :coder "fresh-1")))
             (is (string= "fresh-1" (getf bean :bean)))))
      (%cleanup-beans home))))
```

#### Test 8: cull dry-run identifies but does not remove

```lisp
(test cull-dry-run-keeps-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message :content "Stale."
            :expires "2000-01-01T00:00:00")
           (hngh.plugins.beans:check-bean-staleness root :coder "stale-1")
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :role :coder :dry-run t)))
             (is (= 1 (getf result :count)))
             (is (null (getf result :commit-sha))))
           ;; Bean is still in inbox
           (let ((bean (hngh.plugins.beans:read-bean root :coder "stale-1")))
             (is (string= "spoiled" (getf bean :status)))))
      (%cleanup-beans home))))
```

#### Test 9: spore bean propagation generates sub-beans

```lisp
(test spore-propagation-generates-sub-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :worker "spore-1"
            :type :spore
            :membrane :ferment
            :content "Generate sub-tasks."
            :type-fields '(:spore-id "sp-001"
                           :propagation-limit 5
                           :sub-bean-types "task,message"))
           (hngh.plugins.beans:harvest-bean root :worker "spore-1")
           (let ((digest (hngh.plugins.beans:digest-bean
                          root :worker "spore-1"
                          :output "```spore
- bean: sub-1
  to: worker
  type: task
  content: \"Sub-task 1\"
  type-fields:
    task-id: sub-1
    title: Sub 1
    acceptance: ok
- bean: sub-2
  to: worker
  type: message
  content: \"Sub-message 2\"
```"
                          :attribution "Worker — test")))
             (is (getf digest :spore-result))
             (is (= 2 (getf (getf digest :spore-result) :sub-bean-count)))
             (is (null (getf (getf digest :spore-result) :feral))))
           ;; Sub-beans were planted in worker's inbox
           (let ((sub1 (hngh.plugins.beans:read-bean root :worker "sub-1")))
             (is (string= "task" (getf sub1 :type))))
           (let ((sub2 (hngh.plugins.beans:read-bean root :worker "sub-2")))
             (is (string= "message" (getf sub2 :type)))))
      (%cleanup-beans home))))
```

#### Test 10: spore propagation limit exceeded marks feral

```lisp
(test spore-exceeds-limit-marks-feral
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :worker "spore-2"
            :type :spore
            :membrane :ferment
            :content "Generate too many sub-tasks."
            :type-fields '(:spore-id "sp-002"
                           :propagation-limit 1
                           :sub-bean-types "task"))
           (hngh.plugins.beans:harvest-bean root :worker "spore-2")
           (signals error
             (hngh.plugins.beans:digest-bean
              root :worker "spore-2"
              :output "```spore
- bean: sub-a
  to: worker
  type: task
  content: \"A\"
- bean: sub-b
  to: worker
  type: task
  content: \"B\"
```"
              :attribution "Worker — test"))
           ;; Spore is marked feral
           (let ((bean (hngh.plugins.beans:read-bean root :worker "spore-2")))
             (is (string= "feral" (getf bean :status)))))
      (%cleanup-beans home))))
```

#### Test 11: cross-role bean planting

```lisp
(test cross-role-planting
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           ;; Designer plants a message in Coder's inbox
           (hngh.plugins.beans:plant-bean
            root :designer :coder "design-handoff"
            :type :message
            :content "Design done, implement it.")
           (let ((bean (hngh.plugins.beans:read-bean root :coder "design-handoff")))
             (is (string= "designer" (getf bean :from)))
             (is (string= "coder" (getf bean :to)))
             (is (search "Design done" (getf bean :content))))
           ;; dispatch.md has the cross-role communication
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status :communications))))
             (let ((comm (first (getf status :communications))))
               (is (string= "designer" (getf comm :from)))
               (is (string= "coder" (getf comm :to))))))
      (%cleanup-beans home))))
```

#### Test 12: harvest before ripe errors

```lisp
(test harvest-growing-bean-errors
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           ;; Plant a bean with no content (growing state)
           (hngh.plugins.beans:plant-bean
            root :pm :coder "growing-1"
            :type :task
            :content nil  ; content is nil → growing
            :type-fields '(:task-id "g1" :title "Growing" :acceptance "ok"))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "growing-1")))
             (is (string= "growing" (getf bean :status))))
           ;; Harvest should error
           (signals error
             (hngh.plugins.beans:harvest-bean root :coder "growing-1")))
      (%cleanup-beans home))))
```

#### Test 13: digest before harvest errors

```lisp
(test digest-before-harvest-errors
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "undigested-1"
            :type :message
            :content "Not harvested yet.")
           ;; Bean is ripe but not harvested — digest should error
           (signals error
             (hngh.plugins.beans:digest-bean
              root :coder "undigested-1"
              :output "output"
              :attribution "test")))
      (%cleanup-beans home))))
```

#### Test 14: cull feral beans

```lisp
(test cull-feral-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           ;; Create a feral spore by exceeding limit
           (hngh.plugins.beans:plant-bean
            root :pm :worker "feral-spore"
            :type :spore
            :membrane :ferment
            :content "Go feral."
            :type-fields '(:spore-id "fp-001"
                           :propagation-limit 1
                           :sub-bean-types "task"))
           (hngh.plugins.beans:harvest-bean root :worker "feral-spore")
           (handler-case
               (hngh.plugins.beans:digest-bean
                root :worker "feral-spore"
                :output "```spore
- bean: fsub-1
  to: worker
  type: task
  content: \"A\"
- bean: fsub-2
  to: worker
  type: task
  content: \"B\"
```"
                :attribution "test")
             (error () nil)) ; expect error, swallow it
           ;; Cull feral beans
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :feral-only t)))
             (is (>= (getf result :count) 1))))
      (%cleanup-beans home))))
```

#### Test 15: husk entry appears in journal with attribution

```lisp
(test husk-entry-has-attribution
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :designer "husk-test"
            :type :task
            :content "Do work."
            :type-fields '(:task-id "h1" :title "Husk test" :acceptance "ok"))
           (hngh.plugins.beans:harvest-bean root :designer "husk-test")
           (hngh.plugins.beans:digest-bean
            root :designer "husk-test"
            :output "Work done."
            :attribution "Designer — glm-5.2, Hermes harness, $0")
           (let ((journal (uiop:read-file-string
                            (merge-pathnames "journal/actual.md" root))))
             (is (search "husk-test" journal))
             (is (search "Designer — glm-5.2" journal))
             (is (search "task" journal))
             (is (search "chew" journal))))  ; default membrane for task
      (%cleanup-beans home))))
```

---

## 15. Implementation notes for the Coder

### Dependencies

- `cl-ppcre` — already in `hngh.asd`. Use for parsing bean husks,
  dispatch.md tables, and spore sub-bean specification blocks.
- `bordeaux-threads` — already in `hngh.asd`. Use for the per-squad
  mutex.
- `sb-ext:run-program` — SBCL built-in. Use for git operations
  (follow `backup-manager.lisp` pattern, or reuse `%git` from
  `squad-dispatch.lisp`).
- `uiop` — available via ASDF. Use `uiop:read-file-string`,
  `uiop:delete-directory-tree`, `ensure-directories-exist`.

No new dependencies needed.

### Reusing Wave 3 helpers

The Coder should reuse the following helpers from
`squad-dispatch.lisp` (either by importing them or by copying the
patterns):

- `%git` (dispatch-tree.md §3.11) — git command runner with
  `--git-dir`/`--work-tree`.
- `%atomic-write` (§3.12) — write-then-rename.
- `%format-timestamp` (§3.13) — ISO-8601 formatting.
- `%parse-bean-section` (§3.14) — base bean parser (extend with
  membrane, expires, type-fields).
- `%parse-dispatch-md` (§3.15) — dispatch.md parser.
- `%rewrite-dispatch-md` (§3.16) — dispatch.md serializer.

If these are not exported from `:hngh.plugins.squad-dispatch`, the
Coder should either export them or re-implement them in `beans.lisp`.
Recommendation: export the helpers from `squad-dispatch` and import
them in `beans`, to avoid duplication.

### YAML-like parsing

The husk and spore specification blocks use a simplified YAML subset
(key-value pairs, pipe block scalars, list items with `- `). Do NOT
add a full YAML library dependency. Parse with `cl-ppcre`:

- Split lines on `\n`.
- Match `^(\w[\w-]*):\s*(.*)$` for key-value pairs.
- For `|` block scalars, read subsequent lines until a line matching
  `^\w` (next key at column 0) or end of section.
- For spore sub-bean specs, match `^-\s+(\w[\w-]*):\s*(.*)$` for list
  items.

### What NOT to implement in Wave 4

- No background threads (no watchers, no polling). The plugin is
  stateless — all staleness checks are triggered by explicit function
  calls.
- No event-bus integration (that's Wave 2 — `file-watcher` handles
  inotify; `beans.lisp` just reads/writes files).
- No LLM calls (all bean lifecycle operations are pure filesystem +
  git).
- No TUI rendering (Artist session D4a produces aesthetic assets).
- No benchmarking (Wave 8).
- No automatic staleness cron (the Accountant or PM calls
  `cull-spoiled-beans` manually or via a future cron job).

---

## 16. Open questions (deferred to Wave 5+)

1. **Bean splitting**: `resource` beans can be split among multiple
   roles (the `split` field). Wave 4 records the split directive but
   does not implement the actual splitting logic — each consuming role
   extracts what it needs from the core content. Automatic splitting
   (creating per-role sub-beans) is Wave 5+.

2. **Ferment timeout**: A bean with `membrane: ferment` instructs the
   role to wait before processing. How long should the role wait? Wave
   4 does not enforce a timeout — the role decides. A future
   `ferment-deadline` husk field could add this.

3. **Husk compaction**: As beans are husked, `journal/actual.md` grows
   unbounded. Periodic compaction (extracting husk summaries into a
   condensed log) is Wave 5+.

4. **Cross-squad bean exchange**: Can a bean from one squad be planted
   in another squad's inbox? Wave 4 does not support this — beans are
   squad-scoped. Cross-squad exchange is Wave 7+ (self-improvement
   loop).

---

**Attribution**: Designer — glm-5.2, Hermes harness.
