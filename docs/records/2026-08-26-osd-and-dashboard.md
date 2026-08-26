# 2026-08-26: OSD overlay and dashboard/evolution surface

## Scope

A record of the operator-facing visual surface that landed in the last
24 hours: the full-screen dashboard TUI, the interface-grading loop, the
operative evolution story, and the desktop OSD overlay. Together they
turn Hngh from a command surface into an observable, graded interface
family — without touching the kernel's refusal vocabulary.

## What shipped

- **`scripts/dashboard-tui`** — a textual (rich) full-screen TUI with an
  animated operative, a lanes panel, and live session tables. It reads
  the same read-only store as `dashboard-readout` and renders the
  operator spine in a bounded foreground loop.
- **Grade loop** — `scripts/grade-interface` renders a deterministic,
  first-finding grade for a UI (target + grade + first finding), with
  `docs/project/ui-grades.md` holding the dated grade table; the
  automated grading loop feeds every interface iteration.
- **Operative evolution** — `scripts/evolve-operative` (the animation /
  generation story: gen 1 through gen 4-5) with
  `docs/design/operative-frames.md` (the frame/animation spec) and the
  operator-facing `docs/design/assistant-interface.md` (the operative
  layer).
- **`scripts/osd-operative`** (+ `osd-operative.qml`) — the Plasma 6
  standalone qml6 overlay window (frameless, always-on-top transparent)
  that floats the operative above the desktop, backed by
  `tests/scripts/test-osd-operative.py`.

## Why it is a record

These are operator-facing surfaces, not governance surfaces: the
kernel's evidence-before-claim, fail-closed, and certificate-bound
invariants are unchanged. The record documents that the surfaces were
shipped candidate-bound through the governance loop (each `hngh: candidate`
commit below), and that the grade loop is the seed of the federated
UI/UX validation the assistant-interface design names.

## Evidence

- Candidate commits: `95c811a` (grade-interface), `3b3c89b`/`3bc4a0b`
  (dashboard-tui), `456046d`/`9e41a6f` (operative evolution +
  operative-frames + assistant-interface), `5224f57` (osd-operative +
  qml + test).
- `docs/project/ui-grades.md` — dated grade table (2026-08-25).
- `docs/design/operative-frames.md` — the frame/animation spec.
- Should not be cited as evidence by an automated gate: surfaces change
  without the kernel.

## Bounded unknown

The grade table reflects 4/10 first findings on `dashboard-tui` as of
2026-08-25; whether a later grade pass moves the TUI past that floor is
the next check-in question, not settled here.