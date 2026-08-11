# File-Change Notification — Plugin Spec (Wave 2)

**Status**: Draft v0.1 (2026-08-03)
**Milestone**: M9 Wave 2 (extends squad-startup-automation.md §2, §4)
**Session**: D2 (projected-design-sessions.md)
**Author**: PM — z-ai/glm-5.2, Hermes harness (Designer seat stalled; PM produced spec directly)
**Plugin file**: `src/plugins/file-watcher.lisp` (new)
**Package**: `:hngh.plugins.file-watcher`

---

## 0. Summary

Generalize config-watcher's pattern into a registered-path file-change bus.
Any plugin or role registers interest in filesystem paths. The watcher emits
`file.changed` events on the event bus when registered paths are modified.
Uses inotify on Linux when available; falls back to mtime-poll. Debounces
rapid successive writes. Thread-safe via a background watch thread.

config-watcher stays as-is. file-watcher is a separate plugin that
generalizes the pattern for arbitrary path registration.

---

## 1. Plugin API

All functions in package `:hngh.plugins.file-watcher`. Exported symbols
marked with `→`.

### 1.1 `register-path` →

```lisp
(defun register-path (path &key (scope :global) (label nil))
  ...)
```

Register a filesystem path for change watching.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string or pathname | (required) | Absolute or relative path to watch. Relative paths resolved against `*default-pathname-defaults*`. Directories watched recursively. |
| `scope` | keyword | `:global` | Scope tag for the registration. `:global` = visible to all subscribers. Per-role scopes (`:pm`, `:designer`, `:coder`, `:artist`, `:accountant`, `:worker`) restrict events to subscribers who declared interest in that scope. |
| `label` | string or nil | nil | Optional human-readable label for the registration (e.g. `"designer-inbox"`). Included in event payload. |

**Returns**: `t` on success, `nil` if path does not exist (warns, does not error).

**Behavior**: Adds path to `*registered-paths*` hash table (key = absolute path, value = plist with `:scope`, `:label`, `:snapshot`). Seeds the content snapshot so the first scan cycle detects only future changes. If path is already registered, updates scope/label and returns `t` without re-seeding.

### 1.2 `deregister-path` →

```lisp
(defun deregister-path (path)
  ...)
```

Remove a path from change watching.

**Returns**: `t` if path was registered and removed, `nil` if path was not registered.

**Behavior**: Removes path from `*registered-paths*`. No further events fire for this path. Does not touch the filesystem.

### 1.3 `registered-paths` →

```lisp
(defun registered-paths (&key (scope nil))
  ...)
```

Return a list of registered path plists.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `scope` | keyword or nil | nil | If nil, return all registered paths. If a scope keyword, return only paths registered under that scope. |

**Returns**: list of plists `(:path string :scope keyword :label string-or-nil)`.

### 1.4 `init` →

```lisp
(defun init (&key (watch-interval *watch-interval*))
  ...)
```

Initialize the file watcher. Start the background polling thread.

Seeds snapshots for all currently-registered paths. Creates a background
thread named `"hngh-file-watcher"` that runs `watch-loop`.

**Returns**: `t`.

### 1.5 `shutdown` →

```lisp
(defun shutdown ()
  ...)
```

Stop the file watcher. Sets `*running*` to nil, joins the watch thread
(3-second timeout), clears `*registered-paths*` and `*file-snapshots*`.

**Returns**: `t`.

### 1.6 `running-p` →

```lisp
(defun running-p ()
  ...)
```

Return `t` if the file watcher is active.

### 1.7 `status` →

```lisp
(defun status ()
  ...)
```

Return a plist describing the watcher status:

```lisp
(:running t
 :registered-count 5
 :watch-interval 5
 :last-event 3920345678
 :paths ("path1" "path2" ...))
```

---

## 2. Event payload format

The watcher publishes events on topic `"file.changed"` via
`hngh.core.event-bus:publish`.

### 2.1 Payload structure

```lisp
(hngh.core.event-bus:publish
 "file.changed"
 (list :path path-string
       :scope scope-keyword
       :label label-string-or-nil
       :diff-summary diff-plist
       :timestamp universal-time
       :source 'file-watcher)
 :source 'file-watcher)
```

### 2.2 Payload fields

| Field | Type | Description |
|---|---|---|
| `:path` | string | Absolute path of the changed file or directory. |
| `:scope` | keyword | Scope under which the path was registered. |
| `:label` | string or nil | Optional label from registration. |
| `:diff-summary` | plist | Summary of what changed. See §2.3. |
| `:timestamp` | integer | Universal time of the detected change. |
| `:source` | symbol | Always `'file-watcher`. |

### 2.3 Diff summary structure

```lisp
(:type :modified      ; :modified, :created, :deleted
 :size-before 1024   ; bytes, or nil if created
 :size-after 2048     ; bytes, or nil if deleted
 :mtime-before ...    ; universal-time, or nil
 :mtime-after ...)    ; universal-time, or nil
```

For directory watches: one event per changed file within the directory,
not one event for the directory itself. `:path` is the individual file path.

### 2.4 Event topic

Topic string: `"file.changed"`

Subscribers use the event bus subscribe API:

```lisp
(hngh.core.event-bus:subscribe "file.changed"
  (lambda (event)
    (let ((payload (hngh.core.event-bus:event-payload event)))
      ...)))
```

Subscribers can filter by scope or path in their callback. The event bus
handles wildcard topic matching (`"file.*"` matches `"file.changed"`).

---

## 3. Per-role path registration scoping

Roles register interest in paths within their scope. The watcher emits
events tagged with the scope so subscribers can filter.

### 3.1 Default scope assignments

| Role | Scope keyword | Paths |
|---|---|---|
| PM | `:pm` | All paths under squad root (registers with `:global` scope) |
| Designer | `:designer` | `docs/design/`, `designer/inbox.md`, `designer/tasks/` |
| Coder | `:coder` | `src/`, `coder/inbox.md`, `coder/tasks/` |
| Artist | `:artist` | `docs/design/`, `artist/inbox.md`, `assets/` |
| Accountant | `:accountant` | `accountant/inbox.md`, `journal/`, `state.git/log` |
| Worker | `:worker` | `worker/inbox.md`, `worker/tasks/`, `~/.hngh-night/tasks/` |

### 3.2 Scope semantics

- `:global` scope: events delivered to all subscribers of `"file.changed"`.
- Named scope (`:designer`, `:coder`, etc): events delivered to all
  subscribers, but subscribers can filter by checking `:scope` in the payload.
- The watcher does not enforce access control. Scoping is a tagging
  convention for subscriber-side filtering, not a security boundary.

### 3.3 Registration helper

```lisp
(defun register-role-paths (role squad-root)
  "Register default paths for ROLE under SQUAD-ROOT."
  ...)
```

Convenience function that registers the default paths for a role using
the table above. Called by squad startup (Wave 3 dispatch tree creation).

---

## 4. Systemd .path unit generation (daemon mode)

For daemon-mode operation, generate systemd `.path` units that trigger
on file changes. This follows the gbd (git-back-dots) pattern.

### 4.1 Unit template

```ini
[Unit]
Description=Hngh file watcher trigger for %i

[Path]
PathChanged=%I

[Install]
WantedBy=paths.target
```

### 4.2 Generation function

```lisp
(defun generate-path-unit (path &key (unit-name nil) (output-dir nil))
  "Generate a systemd .path unit file for PATH.
UNIT-NAME: base name for the unit (default: derived from path).
OUTPUT-DIR: directory to write the unit file (default: ~/.config/systemd/user/).
Returns the path to the generated unit file."
  ...)
```

### 4.3 Path unit naming

Unit files named `hngh-file-<hash>.path` where `<hash>` is a short hash
of the absolute path. This avoids name collisions and keeps unit names
deterministic.

### 4.4 Service unit

Each `.path` unit needs a matching `.service` unit that runs a trigger
command:

```ini
[Unit]
Description=Hngh file watcher handler for %i

[Service]
Type=oneshot
ExecStart=/usr/bin/hngh file-changed --path=%i
```

The `hngh file-changed` CLI command emits a `file.changed` event on the
event bus (when the daemon is running) or writes to a trigger file that
the polling loop picks up.

### 4.5 When to use systemd units vs inotify

- **Daemon mode**: systemd `.path` units. The daemon is always running,
  systemd handles the watching. The `.service` unit fires the event.
- **Interactive mode**: inotify or mtime-poll in the background thread.
  No systemd units needed.

The plugin auto-detects: if `hngh.core:daemon-running-p` returns `t`,
use systemd units. Otherwise, use the background thread.

---

## 5. mtime-poll fallback

When inotify is unavailable, the watcher falls back to mtime-polling.
This reuses config-watcher's pattern exactly.

### 5.1 Poll loop

```lisp
(defun watch-loop ()
  "Poll registered paths at *watch-interval* seconds."
  (loop while *running* do
        (handler-case
            (scan-registered-paths)
          (error (c)
            (hngh.core:log-warn "File-watcher scan error: ~A" c)))
        (loop repeat *watch-interval*
              while *running*
              do (sleep 1))))
```

### 5.2 Scan function

```lisp
(defun scan-registered-paths ()
  "Poll every registered path. Publish file.changed when content differs."
  (loop for path being the hash-keys of *registered-paths*
          using (hash-value info)
        do (let* ((previous (getf info :snapshot))
                  (current (snapshot-content path)))
             (unless (equal previous current)
               (when (within-debounce-window-p)
                 (sleep (/ *debounce-ms* 1000.0)))
               (let ((diff (compute-diff path previous current)))
                 (setf *last-event-time* (get-universal-time))
                 (setf (getf info :snapshot) current)
                 (publish-file-changed path info diff previous current))))))
```

### 5.3 Inotify detection

```lisp
(defun inotify-available-p ()
  "Return t if inotify is available on this system."
  #+linux
  (handler-case
      (let ((fd (iolib.syscalls:inotify-init)))
        (iolib.syscalls:close fd)
        t)
    (error () nil))
  #-linux
  nil)
```

If inotify is available, the watcher can use it for instant notification
instead of polling. If not, the mtime-poll loop runs. The poll interval
defaults to 5 seconds (`*watch-interval*`).

**Implementation note**: inotify support is optional. The first
implementation can use mtime-poll only. Add inotify as an enhancement
later. The API is the same either way — the poll loop is the baseline
that always works.

---

## 6. Debounce behavior

Reuse config-watcher's debounce pattern exactly.

### 6.1 Parameters

```lisp
(defparameter *debounce-ms* 300
  "Milliseconds to coalesce rapid successive changes into a single event.")
```

### 6.2 Debounce logic

```lisp
(defun within-debounce-window-p ()
  "Return t when we are inside the debounce window."
  (let ((now (get-universal-time)))
    (and (plusp *last-event-time*)
         (< (* (- now *last-event-time*) 1000) *debounce-ms*))))
```

When a change is detected and the debounce window is active, the scan
function sleeps for the remaining debounce time before publishing. This
coalesces rapid successive writes (e.g. editor save + format) into one
event.

### 6.3 Per-path debounce

The debounce is global (one `*last-event-time*`), matching
config-watcher's behavior. Per-path debounce is a future enhancement —
the frequency table from §8 (sense optimization) can drive this.

---

## 7. Thread safety

### 7.1 Background thread

```lisp
(defvar *running* nil
  "Whether the file watcher is active.")

(defvar *watch-thread* nil
  "Background thread polling for file changes.")
```

`init` creates the thread via `sb-thread:make-thread`. `shutdown` sets
`*running*` to nil and joins the thread with a 3-second timeout.

### 7.2 Hash table access

`*registered-paths*` and `*file-snapshots*` are accessed from:
- The watch thread (read + write during scan)
- The main thread (register-path, deregister-path, registered-paths)

Use a mutex to protect hash table access:

```lisp
(defvar *paths-lock* (bt:make-lock "hngh-file-watcher-paths"))
```

All functions that read or write `*registered-paths*` must acquire
`*paths-lock*`. The scan loop acquires the lock per-path (not for the
entire scan) to avoid blocking registration during long scans.

### 7.3 Event publishing

Events are published via `hngh.core.event-bus:publish`, which is
thread-safe (uses `*bus-lock*` internally). The watcher does not need
additional locking for publishing.

---

## 8. State variables

```lisp
(defvar *registered-paths* (make-hash-table :test 'equal)
  "Hash of absolute-path-string → plist(:scope :label :snapshot).")

(defparameter *watch-interval* 5
  "Seconds between mtime-poll cycles (fallback when inotify unavailable).")

(defparameter *debounce-ms* 300
  "Milliseconds to coalesce rapid successive changes.")

(defvar *last-event-time* 0
  "Internal universal-time of the last published file.changed event.")

(defvar *running* nil
  "Whether the file watcher is active.")

(defvar *watch-thread* nil
  "Background thread polling for file changes.")

(defvar *paths-lock* (bt:make-lock "hngh-file-watcher-paths")
  "Mutex protecting *registered-paths* access.")
```

---

## 9. Helper functions

### 9.1 `snapshot-content`

```lisp
(defun snapshot-content (path)
  "Return file content string for PATH, or nil if unreadable.
For directories, return a sorted list of (name . mtime) entries."
  ...)
```

For files: read file content as a string (reuse config-watcher's pattern).
For directories: return a sorted list of `(entry-name . mtime)` pairs.
This detects new/deleted files within watched directories.

### 9.2 `compute-diff`

```lisp
(defun compute-diff (path before after)
  "Compute a diff summary plist for PATH between BEFORE and AFTER states."
  ...)
```

Returns the `:diff-summary` plist from §2.3. For files, compares size
and mtime. For directories, compares entry lists to detect additions
or deletions.

### 9.3 `publish-file-changed`

```lisp
(defun publish-file-changed (path info diff before after)
  "Emit a file.changed event through the event bus."
  (when hngh.core.event-bus:*event-bus*
    (handler-case
        (hngh.core.event-bus:publish
         "file.changed"
         (list :path path
               :scope (getf info :scope)
               :label (getf info :label)
               :diff-summary diff
               :timestamp (get-universal-time)
               :source 'file-watcher)
         :source 'file-watcher)
      (error (c)
        (hngh.core:log-warn "File-watcher event publish failed: ~A" c)))))
```

### 9.4 `resolve-absolute-path`

```lisp
(defun resolve-absolute-path (path)
  "Return absolute pathname string for PATH."
  (namestring (truename path)))
```

---

## 10. Package definition

```lisp
(defpackage :hngh.plugins.file-watcher
  (:use :cl :hngh.core :hngh.core.event-bus)
  (:export #:register-path
           #:deregister-path
           #:registered-paths
           #:register-role-paths
           #:init
           #:shutdown
           #:running-p
           #:status
           #:generate-path-unit))
```

### ASDF registration

In `hngh.asd`, add to the `:serial` components under `src/plugins/`:

```lisp
(:file "file-watcher")
```

After `config-watcher` in the load order (file-watcher depends on
event-bus, which is loaded before plugins).

---

## 11. Test fixture specification

Test file: `tests/unit/test-file-watcher.lisp`

### 11.1 Package and suite

```lisp
(in-package :hngh.tests)

(def-suite :hngh.file-watcher
  :description "Tests for file-watcher plugin (Wave 2)"
  :in :hngh)

(in-suite :hngh.file-watcher)
```

### 11.2 Fixture helpers

```lisp
(defun %file-watcher-tmp-dir ()
  "Return a fresh temp directory for file-watcher tests."
  (merge-pathnames (format nil "hngh-file-watcher-test-~D/"
                           (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-tmp-dir (dir)
  "Delete a test directory tree."
  (when (probe-file dir)
    (uiop:delete-directory-tree dir :validate t)))

(defun %touch-file (path &optional (content "test"))
  "Write CONTENT to PATH, creating parent dirs."
  (ensure-directories-exist (directory-namestring path))
  (with-open-file (s path :direction :output :if-exists :supersede)
    (write-string content s)))
```

### 11.3 Test cases

#### Test 1: register-path registers and seeds snapshot

```lisp
(test register-path-seeds-snapshot
  (let ((dir (%file-watcher-tmp-dir)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (is-true (hngh.plugins.file-watcher:register-path
                     (namestring file) :label "test-file"))
           (is (= 1 (length (hngh.plugins.file-watcher:registered-paths)))))
      (hngh.plugins.file-watcher:deregister-path (namestring file))
      (%cleanup-tmp-dir dir))))
```

#### Test 2: file.changed event fires on modification

```lisp
(test file-changed-event-fires
  (let ((dir (%file-watcher-tmp-dir))
        (events nil))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "test-file")
           ;; Subscribe to file.changed
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event)
              (push event events)))
           ;; Init watcher with short interval
           (let ((hngh.plugins.file-watcher:*watch-interval* 1))
             (hngh.plugins.file-watcher:init)
             ;; Modify file
             (sleep 1)
             (%touch-file file "modified")
             ;; Wait for scan
             (sleep 3)
             (hngh.plugins.file-watcher:shutdown))
           (is-true (find-if
                     (lambda (e)
                       (string= "file.changed"
                                (hngh.core.event-bus:event-topic e)))
                     events))
           (let ((payload (hngh.core.event-bus:event-payload
                           (first events))))
             (is (string= "modified"
                          (getf payload :label)))))
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir))))
```

#### Test 3: deregister-path stops events

```lisp
(test deregister-stops-events
  (let ((dir (%file-watcher-tmp-dir))
        (events nil))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "test-file")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (hngh.plugins.file-watcher:init)
           ;; Deregister before modification
           (hngh.plugins.file-watcher:deregister-path
            (namestring file))
           (sleep 1)
           (%touch-file file "should-not-fire")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (is (null events)))
      (%cleanup-tmp-dir dir))))
```

#### Test 4: register-path on nonexistent path returns nil

```lisp
(test register-nonexistent-path
  (is (null (hngh.plugins.file-watcher:register-path
             "/nonexistent/path/does/not/exist.txt"))))
```

#### Test 5: status returns correct plist

```lisp
(test status-returns-plist
  (let ((dir (%file-watcher-tmp-dir)))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "content")
           (hngh.plugins.file-watcher:register-path
            (namestring file) :label "status-test")
           (hngh.plugins.file-watcher:init)
           (let ((status (hngh.plugins.file-watcher:status)))
             (is (getf status :running))
             (is (= 1 (getf status :registered-count))))
           (hngh.plugins.file-watcher:shutdown)
           (let ((status (hngh.plugins.file-watcher:status)))
             (is-false (getf status :running))))
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir))))
```

#### Test 6: scoped registration tags events

```lisp
(test scoped-registration-tags-events
  (let ((dir (%file-watcher-tmp-dir))
        (events nil))
    (unwind-protect
         (let ((file (merge-pathnames "test.txt" dir)))
           (%touch-file file "initial")
           (hngh.plugins.file-watcher:register-path
            (namestring file) :scope :designer :label "designer-inbox")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (hngh.plugins.file-watcher:init)
           (sleep 1)
           (%touch-file file "modified")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (when events
             (let ((payload (hngh.core.event-bus:event-payload
                             (first events))))
               (is (eq :designer (getf payload :scope))))))
      (hngh.plugins.file-watcher:deregister-path
       (namestring (merge-pathnames "test.txt" dir)))
      (%cleanup-tmp-dir dir))))
```

#### Test 7: directory watch detects new file

```lisp
(test directory-watch-detects-new-file
  (let ((dir (%file-watcher-tmp-dir))
        (events nil))
    (unwind-protect
         (progn
           (ensure-directories-exist dir)
           (hngh.plugins.file-watcher:register-path
            (namestring dir) :label "watched-dir")
           (hngh.core.event-bus:subscribe
            "file.changed"
            (lambda (event) (push event events)))
           (hngh.plugins.file-watcher:init)
           (sleep 1)
           ;; Create a new file in the watched directory
           (%touch-file (merge-pathnames "new-file.txt" dir) "new content")
           (sleep 3)
           (hngh.plugins.file-watcher:shutdown)
           (is-true (find-if
                     (lambda (e)
                       (let ((p (hngh.core.event-bus:event-payload e)))
                         (search "new-file.txt" (getf p :path))))
                     events)))
      (hngh.plugins.file-watcher:deregister-path (namestring dir))
      (%cleanup-tmp-dir dir))))
```

---

## 12. Implementation notes for the Coder

1. **Start with mtime-poll only.** Inotify support is a future enhancement.
   The poll loop is the baseline that always works. Do not add inotify
   dependencies (iolib) in the first implementation.

2. **Reuse config-watcher's patterns.** The scan loop, debounce,
   thread management, and event publishing all follow the same structure
   as config-watcher.lisp. Copy the pattern, generalize the path list to
   a hash table.

3. **Hash table for registered paths.** config-watcher uses a fixed
   `*watch-paths*` list. file-watcher uses `*registered-paths*` hash
   table for dynamic registration/deregistration.

4. **Mutex on hash table.** config-watcher doesn't need a mutex (fixed
   list, no runtime registration). file-watcher does — register/deregister
   can be called from any thread while the watch loop is running.

5. **Directory watching.** For directory paths, `snapshot-content` returns
   a sorted list of `(entry-name . mtime)` pairs. When the list changes
   (new or removed entries), emit a `file.changed` event for each changed
   entry.

6. **Event bus dependency.** The watcher requires the event bus to be
   initialized before publishing. If the bus is not running, log a
   warning and skip publishing (do not error).

7. **ASDF load order.** file-watcher must load after event-bus (core)
   and before any plugin that uses it (squad-dispatch, beans).

8. **No new dependencies.** Use only what config-watcher uses: SBCL
   built-ins, `hngh.core`, `hngh.core.event-bus`, `bordeaux-threads`
   (already available).

---

## 13. Sense optimization (future, Wave 5+)

Track which events a role actually acts on vs ignores. Over time, prune
the registration list to the events that matter. A simple frequency
table (event type × role → action taken) is enough to start. No model
needed — just count and threshold.

This is out of scope for Wave 2. The first implementation registers all
default paths per role and emits all events. Optimization comes later
when we have real usage data.

---

## Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness (Designer subagent
stalled; PM produced spec directly from config-watcher.lisp source
analysis and squad-startup-automation.md §2, §4).
