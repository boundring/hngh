# TUI QoL Design Brief — Blame!/Tower Dungeon Edition

**Author**: Sisyphus (Artist / Atlas Plan Executor)
**Verifier**: GLM-5.2 (Designer)
**Source**: Task 74
**Brand References**: `docs/design/hngh-brand-and-art.md`, `docs/design/aesthetic-identity.md`

---

## Change 1: Keyboard Help Panel (`?` key)

### Behavior
Roguelike-style modal overlay on any view. Compact ASCII grid of all
keybindings. Uses heavy double-line frame. Auto-dismisses on any key press.

### File: `src/plugins/dashboard-tui.lisp`

### Approx lines: `~210` (after render-plugins, before render-footer)

### Implementation sketch
```lisp
(defvar *help-open* nil)

(defun render-help-panel ()
  (format t "~A╔═══════════════════════════╗~A~%" +ansi-bold+ +ansi-reset+)
  (format t "~A║ KEY        COMMAND       ║~A~%" +ansi-bold+ +ansi-reset+)
  (format t "~A╠═══════════════════════════╣~A~%" +ansi-bold+ +ansi-reset+)
  (format t "~A║ 1          Overview      ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 2          Events        ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 3          Plugins       ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ 4          Megastructure ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A║ q/Q        Quit          ║~A~%" +ansi-dim+ +ansi-reset+)
  (format t "~A╚═══════════════════════════╝~A~%" +ansi-bold+ +ansi-reset+))

;; In handle-key: add (#\? (setf *help-open* t) (render))
;; In render: when *help-open*, render-help-panel instead of main view
;; On any subsequent key: (setf *help-open* nil)
```

### ANSI palette
- Bold cyan: frame borders
- Dim white: body text
- Bold white: header row

### Acceptance criterion
Pressing `?` on any view shows keybinding grid; pressing any other key
dismisses it and returns to the prior view.

---

## Change 2: Floor / Level Indicator

### Behavior
Vertical stack in header area showing megastructure depth. Current "level"
highlighted in bold cyan; inactive levels in dim.

### File: `src/plugins/dashboard-tui.lisp`

### Approx lines: `~121` (render-header, add after title line)

### Implementation sketch
```lisp
(defparameter *level-map*
  '((:overview . "B1-Core")
    (:events . "B3-Event Bus")
    (:plugins . "B2-Scheduler")
    (:megastructure . "B1-Core")))

(defun render-level-indicator ()
  (let ((current (cdr (assoc *current-view* *level-map*))))
    (format t "~A[Level ~A]~A~%" +ansi-dim+ current +ansi-reset+)))
;; Call in render-header after the box
```

### ANSI palette
- Current level: bold cyan
- Inactive: dim
- Frame: bold

### Acceptance criterion
Switching between views (1/2/3/4) updates the level indicator line to
show the correct megastructure floor name.

---

## Change 3: Event Severity Color-Coding

### Behavior
Events view color-codes rows by event topic pattern:
- `error*` / `fault*` / `breach*` → red (Exterminator Alert)
- `warn*` / `pause*` / `throttle*` → yellow (Safeguard Caution)
- `complete*` / `done*` / `green*` → green (Silicon Life)
- default → cyan (Netsphere Beam)

Timestamp column stays dim; only topic + payload get severity color.

### File: `src/plugins/dashboard-tui.lisp`

### Approx lines: `~182` (render-events, modify the dolist format)

### Implementation sketch
```lisp
(defun severity-color (topic)
  (let ((name (string-downcase (string topic))))
    (cond
      ((some (lambda (p) (search p name))
             '("error" "fault" "breach")) +ansi-red+)
      ((some (lambda (p) (search p name))
             '("warn" "pause" "throttle")) +ansi-yellow+)
      ((some (lambda (p) (search p name))
             '("complete" "done" "green")) +ansi-green+)
      (t +ansi-cyan+))))

;; In render-events, replace format:
;; (format t "  ~A~A~A ~A~A~A ~S~%" +ansi-dim+ ... +ansi-reset+
;;         (severity-color event-topic) event-topic +ansi-reset+ payload)
```

### ANSI palette
- Red: `+ansi-red+` (Exterminator Alert / error)
- Yellow: `+ansi-yellow+` (Safeguard Caution / warn)
- Green: `+ansi-green+` (Silicon Life / success)
- Cyan: `+ansi-cyan+` (Netsphere Beam / default)
- Dim: `+ansi-dim+` (timestamps)

### Acceptance criterion
Subscribing an `error.test` event makes the topic row render in red;
subscribing a `warn.test` event makes it render in yellow; a `done.test`
event in green; an unclassified event in cyan.

---

## Change 4: Scroll / Buffer Status Bar

### Behavior
Footer extended to show buffer fill ratio:
`[1]Overview [2]Events [3]Plugins [?]Help [q]uit | Events: 47/100`
Plus a tiny ASCII bar: `████░░░░░░` (10 segments). Updates live.

### File: `src/plugins/dashboard-tui.lisp`

### Approx lines: `~211` (render-footer)

### Implementation sketch
```lisp
(defun buffer-fill-bar (n max)
  (let* ((ratio (/ (min n max) (max max 1)))
         (filled (round (* ratio 10))))
    (concatenate 'string
     (make-string filled :initial-element #\█)
     (make-string (- 10 filled) :initial-element #\░))))

(defun render-footer ()
  (format t "~%")
  (format t "~A[1]Overview [2]Events [3]Plugins [4]Megastructure [?]Help [q]uit~A"
          +ansi-dim+ +ansi-reset+)
  (format t "  |  Events: ~D/~D  ~A~A~A~%"
          (length *event-buffer*) 100
          +ansi-yellow+ (buffer-fill-bar (length *event-buffer*) 100)
          +ansi-reset+))
```

### ANSI palette
- Yellow: buffer-fill bar
- Dim: navigation hints

### Acceptance criterion
Footer shows `Events: N/100 ████░░░░░░` where the bar segment count
matches the buffer fill ratio.

---

## Change 5: Compact Plugin Health Grid

### Behavior
Overview view plugin section becomes a 2-column grid:
- Left: plugin name (bold)
- Right: status dot (`🟢`/`🔴`) + one-word state (active/inactive)

Uses green/red from ANSI palette; dim for unloaded plugins. Replaces the
single-line `Plugins loaded: ~D` summary.

### File: `src/plugins/dashboard-tui.lisp`

### Approx lines: `~140` (render-overview, replace plugins section)

### Implementation sketch
```lisp
(defun render-plugin-grid ()
  (let ((plugins (hngh.core.plugin-host:list-plugins)))
    (if plugins
        (dolist (info plugins)
          (let ((running (hngh.core.plugin-host:plugin-info-running-p info)))
            (format t "  ~A~A~A   ~A~A ~A~%"
                    +ansi-bold+
                    (hngh.core.plugin-host:plugin-info-name info)
                    +ansi-reset+
                    (if running +ansi-green+ +ansi-red+)
                    (if running "active" "inactive")
                    +ansi-reset+)))
        (format t "  ~A(no plugins loaded)~A~%" +ansi-dim+ +ansi-reset+))))
```

### ANSI palette
- Bold: plugin name
- Green: active plugin status
- Red: inactive plugin status
- Dim unloaded/empty states

### Acceptance criterion
Plugin section in Overview shows each plugin name followed by
color-coded status on the same line, replacing the old count-only format.

---

## Implementation Order

| Order | Change | Risk | Approx Lines |
|---|---|---|---|
| 1 | Keyboard Help Panel | Low — isolated feature | +30 |
| 2 | Floor / Level Indicator | Low — header decoration | +15 |
| 3 | Event Severity Color | Medium — modifies render loop | +15 |
| 4 | Scroll / Buffer Bar | Low — footer extension | +15 |
| 5 | Plugin Health Grid | Low — replaces existing section | +20 |

All five changes can be implemented in a single Designer session (≤2 hours).
No existing key bindings or views are broken. All additions are additive
rendering within the existing dashboard-tui.lisp.

## Route

Artist (Sisyphus, deepseek-v4-pro, /usr/bin/bash, free). Read-only research
on hngh source completed. Output: single design brief artifact.
Verifier: GLM-5.2 (Designer) — checks aesthetic consistency and
implementability before routing to the coder lane.
