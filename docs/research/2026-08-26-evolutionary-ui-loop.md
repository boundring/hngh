# Evolutionary UI loop — paper/book-chapter outline

Seed for the planned memoir/blog/business lane. A method, not a result
yet: an evolutionary loop that grows a developer terminal UI by
measurement instead of by taste, and the first overnight run of it.

## Title brainstorm

- *Breeding the Interface: An Evolutionary, Self-Grading Loop for
  Developer Terminal UIs*
- *The 4/10 That Caught a Bug: Grading Interfaces Before Liking Them*
- *Breed, Grade, Mutate, Re-measure: A Self-Correcting UI Loop*
- *The Operative Evolves: A Vision-Graded UI Loop*

## Abstract (2–3 sentences)

We run an evolutionary loop that grows a developer terminal UI by
capturing each variant, grading it with a fixed vision critique, and
mutating a deterministic generator until the grade improves. The first
overnight run bred an operative through five generations and the initial
4/10 grade surfaced a genuine data-dump defect, not a stylistic
complaint. The loop inverts the usual taste-first workflow: a passing
grade is never assumed, it is measured, and every accepted variant is
byte-regressed so the next mutation starts from a reproducible artifact.

## The loop

```
implement → capture → vision critique → ledger → mutate → re-measure
     ↑                                                    │
     └────────────────── accepted variant ───────────────┘
```

- **implement** — one slice from the current ledger finding.
- **capture** — screenshot / accessibility scrape of the live surface.
- **vision critique** — local vision pass with a fixed rubric; emits
  target + grade + first finding (pixels/accessibility, not opinion).
- **ledger** — the finding lands in `docs/project/ui-grades.md`;
  never rewritten, appended.
- **mutate** — `scripts/evolve-operative` mutates a small art-parameter
  pool; deterministic (same seed, same frame) via
  `docs/design/operative-frames.md`.
- **re-measure** — the mutation is graded against the same rubric;
  byte-regression across generations (`operative-frames.md`) keeps the
  accepted aesthetic stable.

## Artifact pipeline

```
generator (evolve-operative)
   → frames catalog (operative-frames.md, byte-regressed per gen)
   → surfaces: dashboard-tui (terminal) · osd-operative (Plasma qml6)
   → grade loop (grade-interface → ui-grades.md)
```

- **generator** — `scripts/evolve-operative`, generations 1–4/5.
- **frames catalog** — `docs/design/operative-frames.md`.
- **TUI** — `scripts/dashboard-tui` (rich full-screen read-only).
- **OSD** — `scripts/osd-operative` + `osd-operative.qml` (frameless
  always-on-top Plasma overlay).
- **grading** — `scripts/grade-interface`; ledger
  `docs/project/ui-grades.md`.

## Results to date

- **Grades** — `dashboard-tui`: 4/10 → 4/10 → 4/10 → `unparsed` →
  *pending re-grade on v5* (`docs/project/ui-grades.md`).
- **Bug caught** — the first 4/10 finding ("title/header text:
  OVERVIEW commands sessions …") was a live-telemetry data-dump in the
  header, caught by the machine before a human reviewed it
  (`docs/records/2026-08-26-osd-and-dashboard.md`).
- **Process note** — the `unparsed` row is itself a finding: the
  capture surface changed faster than the rubric, which is a real
  loop-coupling lesson, not a silent pass.

## Future work

- **Overlay** — a graded `osd-operative` (the operative above the
  desktop) enters the same loop.
- **Voice** — a local TTS/voice surface graded by the same rubric
  (`docs/design/assistant-interface.md` voice section).
- **Fleet nodes each graded** — every HNgh node gets its own operative
  and its own grade ledger, federating the UI/UX validation across the
  mesh (`docs/project/system-harness-roadmap.md`).

## Records to cite

- `docs/records/2026-08-26-osd-and-dashboard.md`
- `docs/records/2026-08-26-scheduled-runs-investigation.md`
- `docs/project/ui-grades.md` (grade ledger)
- `docs/design/operative-frames.md` (frames catalog)
- `docs/design/assistant-interface.md` (operative layer)
- `docs/project/lessons-2026-08-26.md` (transferable lessons)