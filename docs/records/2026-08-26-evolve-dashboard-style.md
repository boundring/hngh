# 2026-08-26: Evolve-dashboard-style — surface-evolution-loop rung 1

## Scope

First slice of the surface-evolution-loop roadmap item: one evolution
loop for one surface (dashboard-tui style), graded by grade-interface,
bounded to a cadence drop-in. A deterministic-per-seed generator breeds
color-theme overlay variants, grades each candidate, and keeps the
fittest overlay mounted for dashboard-tui to consume at startup.

## What landed

- **`scripts/evolve-dashboard-style`** — evolution loop modeled on
  `evolve-operative`'s loop shape:
  - deterministic-per-seed mutation over the dashboard-tui `THEMES`
    color presets (field channel shifts + pair swaps); same seed, preset,
    gens -> identical candidates byte for byte (verified).
  - bounded generations per invocation (`--gens`, hard cap `MAX_GENS=12`);
    a bounded batch is what the cadence runs each tick.
  - each generation emits a candidate overlay and grades it:
    - **`--self-grade`** (default): deterministic WCAG-contrast /
      distinctness rubric, no model, no capture, dimensionless.
    - **`--grade`**: live vision path via `scripts/grade-interface`
      (capture + local VL model).
  - appends `{ts|target|gen|grade}` to `docs/project/ui-grades.md`
    (same ledger format grade-interface writes; target carries the
    generation so the 4-column header stays parseable).
  - leaves the fittest overlay mounted at
    `docs/design/ui-evolve/current-overlay.json`.
- **`scripts/dashboard-tui`** — `_apply_overlay()` reads the mounted
  overlay and applies its fields to the matching preset at import, so the
  accepted variant is live. Verified via the real module load:
  `hngh.secondary == #3d9478` from the mounted overlay.
- **`tests/scripts/test-evolve-dashboard-style.py`** — hermetic suite
  (5 tests): determinism, generation cap, command line, self-grade ledger
  + mount, offline-by-construction. Wired into the Makefile `test:`
  target; `make test` green (2774 lisp checks + all python suites).
- **`cadence/10m/01-evolve-ui.sh`** (hngh-automation) — cadence drop-in
  that runs ONE bounded generation batch per tick (hard cap 3
  generations, rotating deterministic seed derived from the wall-clock
  10-minute bucket), breadcrumbs each run, fail-closed exit 0. Auto-plugs
  via the existing `hngh-cadence-10m.timer` (already enabled) — no
  Makefile/enable-list change is needed for a cadence drop-in.

## Vision-capture gap (explicit)

A live `--grade` probe was attempted first (per the assignment's "try the
live path before falling back"): `scripts/grade-interface` now reaches
the local Unsloth server (the token was expired, rotated by
`jobs/credential-health.sh`), but **no model on that server accepts image
input** — `unsloth/gemma-4-12b-it-qat-GGUF` and every Qwen/Gemma id
return HTTP 400 "The requested model does not support the image input".
So live vision capture is genuinely unavailable in this environment, and
the loop runs `--self-grade` (deterministic, model-free). The capture gap
is noted; the generator's `--grade` path is ready for a VL-capable
environment.

## Real end-to-end run (acceptance)

- `python3 scripts/evolve-dashboard-style --preset hngh --gens 3 --seed 1`
  -> generations 6/10, 10/10, 10/10; ledger rows landed; fittest (10/10,
  gen 2) mounted. (A graded generation landed in ui-grades.md.)
- Determinism: same seed twice -> byte-identical stdout/stderr.
- `python3 scripts/dashboard-tui --theme=hngh` renders with the mounted
  overlay; `scripts/dashboard-tui` module load applies `secondary
  #3d9478`.
- `python3 tests/scripts/test-evolve-dashboard-style.py` 5/5 ok.
- `python3 tests/scripts/test-dashboard-tui.py` 5/5 ok.
- `make test` exit 0 (full gate: 2774 lisp checks + all python suites).
- `TIER=10m jobs/cadence-tick.sh` in hngh-automation: drop-in ran,
  breadcrumb `evolve-ui batch done (hngh gens=3 seed=...)`.

## Steering log (self-introspection ticks)

- After reading evolve-operative + grade-interface + dashboard-tui THEMES:
  next smallest step = probe the live vision path once before choosing
  the grading mode (the assignment requires live if available).
- Token was expired -> Main reported credential-health.sh rotated it; the
  re-probe then failed at the model layer (no VL model). Decision: fall
  back to `--self-grade` and note the capture gap explicitly, per
  assignment #3; keep `--grade` implemented for a VL-capable
  environment. [recorded for the file]
- Chose to mount `current-overlay.json` (not a patch) so dashboard-tui
  consumes a single versioned artifact; `_apply_overlay()` is a small,
  fail-closed read.
- The 10m drop-in auto-plugs into the existing `hngh-cadence-10m.timer`;
  no extra Makefile/enable-list entry is owned by this slice (the
  systemd timer additions are the sibling automation/autonomy slice).

## Commits

- hngh (ceremony, fresh store): <hash>
- hngh-automation (plain): <hash>

## Next

- Vision-grading of the dashboard against the accepted overlay once a
  VL-capable model is reachable (`--grade` path).
- A second surface (OSD overlay / voice) entering the same loop is the
  next roadmap candidate after this rung lands.