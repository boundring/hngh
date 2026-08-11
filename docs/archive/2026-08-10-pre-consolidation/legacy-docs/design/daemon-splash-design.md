# Hngh Daemon Splash Screen — Design Spec

**Author**: Sisyphus (Artist / Atlas Plan Executor)
**Target File**: `src/core/main.lisp` (line ~107, after `log-info "Hngh v~A starting..."`)
**Date**: 2026-08-02

---

## Render Target

On daemon startup (and `hngh --version`), print the following splash to stdout
before the log-initialization line. Uses the existing `hngh.core.ascii-art`
package functions.

## Splash Content

```
╔══════════════════════════════════════════════════════════════╗
║  H N G H   v0.1.0   [ M E G A S T R U C T U R E   C O R E ]  ║
║  Common Lisp Agent Orchestrator — SBCL                        ║
╠══════════════════════════════════════════════════════════════╣
║  Event Bus:  [ · ]      Scheduler:  [ · ]                    ║
║  State Store: [ · ]     Supervisor: [ · ]                    ║
║  Plugin Host: [ · ]     Wire Proto: [ · ]                    ║
╚══════════════════════════════════════════════════════════════╝
```

- `[ · ]` placeholders update to `[ ✓ ]` (green) as each component initializes
- If a component fails to initialize, its marker becomes `[ ✗ ]` (red)
- The splash reprints (clear-screen + full redraw) after each component init
- In headless mode, emit only the top two lines (no init grid)

## Implementation Sketch (for Coder)

```lisp
;;; In src/core/main.lisp, replace the simple log-info startup line:

(defun print-splash ()
  "Print the megastructure startup splash."
  (format t "~&")
  (hngh.core.ascii-art:print-megastructure-header
   (format nil "v~A  [ MEGASTRUCTURE CORE ]" *version*))
  (format t "║  Common Lisp Agent Orchestrator — SBCL~24T║~%")
  (format t "╠══════════════════════════════════════════════════════════╣~%")
  (format t "║  Event Bus:  [ · ]      Scheduler:  [ · ]   ~13T║~%")
  (format t "║  State Store: [ · ]     Supervisor: [ · ]   ~13T║~%")
  (format t "║  Plugin Host: [ · ]     Wire Proto: [ · ]   ~13T║~%")
  (format t "╚══════════════════════════════════════════════════════════╝~%"))

(defun update-splash-component (name status)
  "Mark component NAME as STATUS (:ok or :fail) on the active splash."
  ;; Cursor-position to the correct line/column and overwrite [ · ] with
  ;; green [ ✓ ] or red [ ✗ ] depending on status.
  ...)
```

## ANSI Codes

| Element | ANSI |
|---|---|
| Frame borders | Bold Cyan |
| Component names | Dim White |
| `[ ✓ ]` | Bold Green |
| `[ ✗ ]` | Bold Red |
| `[ · ]` (pending) | Dim White |
| Version line | Bold Cyan |
| Architecture tagline | Dim White |

## Acceptance Criteria

1. `hngh --version` prints splash with version number and all `[ · ]` markers
2. Daemon start prints splash, then updates each marker as components init
3. Component failure → `[ ✗ ]` in red, daemon continues initializing remaining components
4. All components init successfully → all six markers show `[ ✓ ]` in green
5. Headless mode → only version line printed, no init grid
