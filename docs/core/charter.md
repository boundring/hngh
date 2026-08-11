# Hngh project charter

**Status:** DESIGN
**Authority:** operator
**Purpose:** the durable charter for Hngh as both a personal operating system harness and a consultation portfolio.

## 1. Business need

Modern Linux, agentic tools, model providers, local inference, and personal automation are individually useful but difficult to operate together safely. Hngh reduces repeated manual prompting, configuration work, maintenance, research, and coordination without handing authority to an opaque agent loop.

Hngh first solves the operator's own CachyOS/Arch Linux environment. The evidence, controls, and reusable patterns then support a consultation practice for people who need agentic solutions suited to their own systems and constraints.

## 2. Product statement

Hngh is a local-first system harness. It coordinates existing agentic tools, local and remote models, Linux services, and durable records. It does not replace those tools. It makes their work bounded, observable, reviewable, and cheaper to repeat.

## 3. Portfolio structure

| Level | Hngh meaning |
|---|---|
| Portfolio | Hngh product, its operator environment, and future client engagements |
| Program | Safe automation and agent orchestration capabilities that reinforce each other |
| Project | A bounded deliverable with a charter, work package, acceptance evidence, and closeout |
| Operation | Repeated observation, maintenance, backup, model serving, or approved automated work |
| Session | A temporary execution lease used to advance one work package |

## 4. Objectives

1. Automate repeatable Linux and development work with explicit safety and recovery boundaries.
2. Coordinate Hermes, OpenCode, ACP-capable tools, MCP services, and local/remote model routes without trusting their prose as system truth.
3. Convert expensive reasoning into bounded decisions, fixtures, prompts, and procedures that cheaper routes can apply.
4. Preserve an evidence-backed work record that lets a fresh session resume without transcript replay.
5. Build a public-quality case base for later consulting, without exposing secrets, private transcripts, or invented performance claims.

## 5. Scope

### In scope

- CachyOS/Arch Linux user-space automation and maintenance.
- Local model serving on available GPU capacity, plus cost-controlled remote routes.
- Agent session admission, context budgets, handoffs, retirement, afterlife reduction, and lessons.
- Agent adapters and control surfaces for Hermes, OpenCode/Oh My OpenAgent, ACP, MCP, Pi where documented, RTK, and llmtrim where a concrete contract exists.
- Dashboard, watcher, queue, claim, journal, case-base, and backup/sync integration that remain under Hngh control.

### Out of scope unless separately chartered

- Root-level changes without an explicit operator maintenance window.
- Autonomous publication, payment, secret handling, irreversible system change, or self-modifying core behavior.
- Reimplementing an existing agent harness merely to own it.
- Provider/model claims without current route, price, quota, and receipt evidence.
- Treating a transcript, model confidence, or dashboard animation as verification.

## 6. Success measures

A measure is useful only when its baseline and evidence path are named.

| Objective | Initial measure |
|---|---|
| Safe work | accepted work packages with a named verifier and no unreviewed privileged action |
| Recoverability | fresh successor completes its next verification from a compact handoff |
| Cost discipline | observed input/output receipts, route class, and `UNKNOWN` coverage recorded per work package |
| Engineering quality | focused fixtures and bounded repository gates tied to the changed surface |
| Learning value | accepted lessons linked to a counterexample, fixture, or measurable policy change |
| Consultation readiness | redacted, reproducible case studies with limits and evidence stated |

## 7. Roles and authority

| Role | Responsibility | May decide |
|---|---|---|
| Operator | intent, budget, risk, privileged action, release, and final acceptance | all operator-gated choices |
| Hngh control plane | task admission, procedural refusal, state recording, routing enforcement | configured safe paths only |
| Designer/PM session | work-package design, dependencies, risks, acceptance design | proposals, never final authority |
| Implementer session | bounded implementation and evidence production | only its named write boundary |
| Verifier | independent acceptance or rejection against a fixed artifact | task completion state |
| Research/teacher route | bounded decision, invariants, counterexamples, unknowns | no implementation or automatic escalation |

## 8. Constraints and risks

- Agent context, provider price, quota, tool surface, and local VRAM are finite resources.
- Agent-generated text, external content, and durable memory are untrusted until classified.
- Runtime state and workbench records may contain private operational evidence.
- Parallel work creates collisions unless claims, write boundaries, and review identity are explicit.
- The system must remain useful when a model, provider, GUI, network, or watcher is unavailable.

## 9. Approval rule

A project starts when the operator accepts a bounded work package: purpose, exclusions, acceptance command, authority, budget/route class, write boundary, verifier, and stop condition. A project closes when its deliverable is accepted or terminally classified, its claims are reconciled, and its receipt/lesson disposition is recorded.
