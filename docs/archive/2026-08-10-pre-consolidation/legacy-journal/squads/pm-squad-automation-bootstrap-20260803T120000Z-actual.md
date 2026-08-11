# Actual Squad Journal

- **Squad:** pm-squad-automation-bootstrap
- **Timestamp:** 20260803T120000Z
- **Launcher:** PM (manual, this session)
- **Closed:** 20260803T123000Z

## What was done

### Wave 0: Test-count lint (DONE)

Built `scripts/lint-test-counts.sh` — procedural test-count lint. Runs `make test`,
parses "Did N checks" from lisp-unit2 summary, scans AGENTS.md and roadmap.md
current-state references for N/M patterns. Exits 1 on stale, 0 on fresh.
Shellcheck clean. Wired into Makefile as `make lint-counts`.

Fixed stale test counts across AGENTS.md (1203 -> 1368 -> 1393), roadmap.md
(1120, 1183, 1203, 1235, 1263 -> 1393), work-sessions.md (1203 -> 1393).

### Wave 1: C7 PM-first-prompt generator (DONE)

Delegated to subagent (local gemma-4-12b, 240s, 50 API calls). Subagent:
- Wrote 13 fixture-based tests first (TDD RED)
- Implemented `generate-pm-prompt` with 7 sections: orientation, context
  summary, roadmap, OptMem, intent, lifetime policy, coordination protocol
- Helper functions: `%scan-plans`, `%scan-design-docs`, `%read-roadmap-status`,
  `%gather-system-context`, `%run-optmem-wake`, `%format-lifetime-policy`
- Modified `cmd-up` dry-run path to print the generated prompt
- Fixed 2 bugs during implementation (unexported `split-lines`, list ordering)
- Hit max_iterations before final green run

PM verification: 4 test assertions had case-sensitivity mismatches
(searching lowercase "ephemeral"/"continual"/"purpose-bounded" vs capitalized
output) and one title-extraction mismatch ("test-plan" vs "test plan").
Fixed directly — 3 `string-downcase` wraps + 1 hyphen-to-space fix. No
implementation changes needed.

Final: 1393/1393 pass, 0 fail. Lint clean.

### Planning and design (DONE)

- Plan: `.hermes/plans/2026-08-03_squad-automation-bootstrapping.md`
- Design request: `.hngh-night/artifacts/pm-to-designer-squad-startup-automation.md`
- D-036 decision recorded
- Projected + actual squad journals written
- OptMem note #352 logged
- AGENTS.md current-state updated

### Waves 2-5 (PENDING)

- W2: File-change notification system (gbd systemd .path pattern)
- W3: Squad journal lifecycle (startup/ongoing/shutdown)
- W4: squad-up integration with generated prompts
- W5: Self-improvement loop bootstrap

## Members

| Role | CLI | Model | CWD |
|---|---|---|---|
| PM | hermes | z-ai/glm-5.2 | ~/Projects/etc/hngh/ |
| Worker | subagent | gemma-4-12b (local) | ~/Projects/etc/hngh/ |

## Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Worker — gemma-4-12b-it-qat-GGUF (local, unsloth), $0, via delegation harness.

## Subagent assessment

Local model completed C7 generator in 240s. Implementation sound, no
architectural drift. Stayed in file scope (2 files only). 4 test-assertion
failures from case sensitivity — PM fixed in 4 one-line patches. Model is
reliable for well-specified self-contained tasks; needs PM verification pass
for test-level details.

## Fragment (unfinished work)

- Waves 2-5: not started
- Designer design doc: not yet started (design request written, awaiting
  Designer seat startup)
- Commit and push: owner-gated
