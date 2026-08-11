# Continued Local Work Queue — 2026-08-01

This queue records approved work packages for continual local execution. It is a planning and promotion ledger until Hngh A1/A2/A3 ship. It is not the live `~/.hngh/tasks/queue.lisp`.

## Routing and authority

- `LOCAL-TEXT`: local Gemma 4 12B, $0, 80–350 word source-grounded prompts, text-out only.
- `LOCAL-IMPLEMENT`: one isolated git worktree, one wave file, local OpenCode, test-first, no commit until human review.
- `CHEAP-REVIEW`: one bounded cheap remote review only after local implementation and `llm-budget` admission.
- `HUMAN`: required before any repository promotion, service control, system mutation, package update, snapshot, pacnew merge, root daemon work, or reboot.

No task can change its own authority. Queue expansion may add `:proposed` records only after A1 is live; promotion to execution remains a human decision.

## Maintenance gate

- When `/var/lib/pacman/db.lck` exists, stop local runners before their next task. Do not begin new implementation or review waves.
- During a human-declared Cachy-Update window, do not start new work. Existing bounded local inference may finish; inspect its artifact afterward.
- After update/reboot: re-check Mission Control, local model health, Hngh queue state, pacnew/pacsave count, and project test baselines before resuming.

## Backlog

| ID | Authority | Route | Depends on | Deliverable | Status |
|---|---|---|---|---|---|
| H-A1 | LOCAL-IMPLEMENT | local OpenCode | none | Versioned queue record normalizer/validator | completed: `bb20683`, 1010/0/0 |
| H-A2 | LOCAL-IMPLEMENT | local OpenCode | H-A1 | Pure eligibility selection, dependencies, delay gate | ready |
| H-A3 | LOCAL-IMPLEMENT | local OpenCode | H-A2 | Pause/resume and stale lease recovery | proposed |
| H-B1 | LOCAL-IMPLEMENT | local OpenCode | H-A3 | Read-only maintenance coordinator plugin | proposed |
| H-B2 | LOCAL-IMPLEMENT | local OpenCode | H-B1 | Gate stable-system work on maintenance state | proposed |
| H-U1 | LOCAL-IMPLEMENT | local OpenCode | H-A3 | Deployable user-daemon lifecycle and fixture verification | proposed |
| H-D1 | LOCAL-TEXT | local Gemma | none | ADR outline synthesis from completed Day-Ralph artifacts | ready |
| H-D2 | LOCAL-TEXT | local Gemma | none | Sentry Tier-1 fixture matrix and false-positive criteria | ready |
| H-D3 | LOCAL-TEXT | local Gemma | none | M8 route-table data review against live local routes | ready |
| G-D1 | LOCAL-TEXT | local Gemma | none | gbd-as-Hngh extension boundary and explicit adapter contract | ready |
| S-D1 | LOCAL-TEXT | local Gemma | none | svc-dash release checklist from current sessions/docs | ready |
| H-R1 | CHEAP-REVIEW | Luna/DeepSeek only | H-A1 | Review local A1 diff and tests | blocked pending local result |

## Successful-run intake

- `~/.hngh-night/artifacts/01-m7-wire-protocol-adr.md` is a draft input to M7, not a final ADR.
- `~/.hngh-night/artifacts/08-m8-routing-refine.md` is thin and needs H-D3 before use.
- `~/.hngh-day/artifacts/01-06` are reviewed inputs to H-U1, H-B1/B2, H-D1, and G-D1.
- Historical live-queue tasks 2, 4, and 6 demonstrate local text/spec generation and agentic proof; failures 3 and 5 remain regression fixtures, not retry candidates.

## Cadence

1. One LOCAL-IMPLEMENT wave at a time on the Hngh worktree chain.
2. Between implementation waves, run at most two independent LOCAL-TEXT tasks serially with `day-ralph`.
3. Do not use a remote reviewer until a local diff exists and a human decides that the review is worth the marginal cost.
4. Persist results as artifacts and journal entries. Do not auto-promote artifacts into code or the live queue.
