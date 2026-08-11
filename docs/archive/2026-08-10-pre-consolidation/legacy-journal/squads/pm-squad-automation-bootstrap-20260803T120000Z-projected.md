# Projected Squad Journal

- **Squad:** pm-squad-automation-bootstrap
- **Timestamp:** 20260803T120000Z
- **Launcher:** PM (manual, this session)

## Mission

Automate squad startup end-to-end. C7 PM-first-prompt generator, file-change
notification system (gbd pattern), squad journal lifecycle integration,
test-count lint. Bootstrap hngh's self-improvement loop. Decompose into
nearly-atomic work items for worker/coder dogfooding.

## Members

| Role | CLI | Model | CWD |
|---|---|---|---|
| PM | hermes | z-ai/glm-5.2 | ~/Projects/etc/hngh/ |
| Designer | hermes | z-ai/glm-5.2 | ~/Projects/etc/hngh/ |
| Worker | opencode | local/free | ~/Projects/etc/hngh/ |
| Coder | opencode | local/free | ~/Projects/etc/hngh/ |

## Preflight results

- PASS: Tests 1368/1368 green @ d569e3b+uncommitted
- PASS: Build clean
- PASS: M9 W1-2 code present (agents-md, squad-resources, fragment-journal, hngh-up)
- PASS: Plan saved to .hermes/plans/2026-08-03_squad-automation-bootstrapping.md
- PASS: Design request written to .hngh-night/artifacts/pm-to-designer-squad-startup-automation.md
- PENDING: Designer design doc (squad-startup-automation.md)
- PENDING: Test-count lint (Wave 0)
- PENDING: C7 PM-first-prompt generator (Wave 1)

## Budget estimate

All local/free models for implementation. PM (glm-5.2) for coordination and
design review. $0 projected.

## Expected deliverables

1. `scripts/lint-test-counts.sh` + `make lint-counts` target (Wave 0)
2. `docs/design/squad-startup-automation.md` (Designer)
3. C7 PM-first-prompt generator in `src/plugins/hngh-up.lisp` (Wave 1)
4. File-change notification system (Wave 2)
5. Squad journal lifecycle wiring (Wave 3)
6. `squad-up` integration with generated prompts (Wave 4)
7. Self-improvement loop bootstrap (Wave 5)
8. Updated roadmap, work-sessions, AGENTS.md

## Timeline estimate

Start: 20260803T120000Z.
- Wave 0: 30 min (lint script)
- Wave 1: 2-4 hours (C7 generator — core of today's work)
- Wave 2: 2-3 hours (file-change system)
- Wave 3: 1 hour (journal wiring, mostly integration)
- Wave 4: 1 hour (squad-up script update)
- Wave 5: deferred to next session (needs W1-4 stable)

## Risk flags

- Designer not yet started; design doc is the gate for worker dispatch
- Uncommitted work must be committed before parallel workers touch the tree
- squad-up script is outside the repo; changes there need separate tracking
- Self-improvement loop (Wave 5) is ambitious for one session; may fragment

## Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
