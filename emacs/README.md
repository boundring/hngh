# hngh-mc.el — Emacs mission-control dashboard for hngh

MC-2 wave 1 — produced by opencode (kimi-k3, attended), 2026-07-31.

Read-only Emacs dashboard over the existing hngh tooling (`hngh-status`, the
event journal, `llmtrim`, `svc-dash`). The hngh daemon lifecycle is **not**
managed here: tmux (`mc`) remains the headless fallback and owns the daemon
(`mc status`; `make run` in `~/Projects/etc/hngh`).

## Load

```elisp
(load "~/Projects/etc/hngh/emacs/hngh-mc.el")
```

Emacs 30.2+. Built-ins only. `eat` is used for the svc-dash panel when
installed, with a `compilation-mode` fallback (noted in the mode line).
`zoom` stays user-managed on `C-c z`; the layout uses `display-buffer` side
windows with no fixed sizes and tolerates resizing.

## Commands

| Command | Description |
| --- | --- |
| `M-x hngh-mc-open` | Open the dashboard: `*hngh-status*` left, `*hngh-events*` right-top, `*llmtrim*` right-bottom. Starts the 5s status/journal timer and the 30s llmtrim timer. |
| `M-x hngh-mc-refresh` | Refresh all panels immediately. |
| `M-x hngh-mc-svc-dash` | Open `*svc-dash*` running the Textual TUI via `uv run --project ~/Projects/etc/svc-dash python -m svc_dash.app` in an eat terminal; falls back to `compilation-mode` (mode line says so) when eat cannot be loaded. |
| `M-x hngh-mc-tmux-status` | Echo-area summary of `mc status` (tmux fallback session). |
| `M-x hngh-mc-close` | Kill dashboard timers and buffers; remove the dashboard side windows. |

No default keybindings are installed; bind as desired, e.g.
`(global-set-key (kbd "C-c m") #'hngh-mc-open)`.

## Panels

- `*hngh-status*` — `hngh-mc-status-mode` (derived from `special-mode`); `g`
  (`revert-buffer`) re-runs `hngh-status`; auto-refreshes every 5s.
- `*hngh-events*` — visits the newest `~/.hngh/journal/events/YYYY-MM-DD.lisp`
  with `auto-revert-tail-mode`, point held at end; rolls over to a newer
  day's file automatically on the 5s timer.
- `*llmtrim*` — raw `llmtrim status` output (box chars intact), refreshed
  every 30s.
