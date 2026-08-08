# Public vetting — self-optimization, feature parity, cost accounting

**Status**: Assessment framing / design seed. NOT a build spec. Written for
the "before we go public" pass; rules what to vet, not what to ship.
**Date**: 2026-08-08
**Owner**: user brief (vision + direction) + Hngh self-development.

## Why this exists

Before the repo is public, Vet whether Hngh's self-improvement loop is honest
and completable toward two public-facing goods: (1) **self-optimizing for
cost and capability** — fewer credits, more capability, provable; (2)
**feature parity** with comparable open autonomous agents so a newcomer can
see Hngh measures up, not just "looks like" them. Under-claiming was already
the README rule; this extends that honesty to the *claims Hngh makes about
itself while running*.

## What is already grounded (do not re-research)

`docs/design/autonomy-strategy.md` §5 covers cheap-inference & cost control
in depth (routing evidence, value metric = SWE-bench ÷ cost/M input,
thinking-token inflation, local-head quantization) and the self-healing loop
(test→run→repair→re-run, cost-gated). `docs/design/situation-scoring.md`
built the recognition/judge/scoring brain (Tier-0 detectors + semantic judge,
now shipped `be14779`). `docs/design/squad-startup-automation.md` already
names Agent Zero as an *inspiration* (hierarchical delegation) — but nothing
vets actual feature parity or the tooling we could integrate.

## What to vet (before going public)

1. **Self-improvement loop honesty.** Can Hngh show a closed loop today
   (situation detected → scored → steered → outcome recorded → recalibrated)?
   If not, that gap is a public-readiness blocker for "self-improving" claims
   (currently steps 5–6 of situation-scoring §8: case-base + review, cross-
   agent normalization).
2. **Feature parity — Odysseus & Agent Zero (docs-first research when built).**
   Read both projects' docs/source before claiming parity or integration:
   - what each does (loop, planning, tool use, autonomy boundaries);
   - what Hngh already matches (recognition/judge/scoring, ACP drive/serve,
     squad dispatch, self-healing);
   - what they have that Hngh has a roadmap path to, vs. genuinely out of
     scope. Result: a parity matrix in `docs/research/`, from which the README
     can honestly name overlap rather than silently borrow the idea.
   - integrate/incorporate where it fits Hngh's toolset (their mechanics as
     plugins, not their whole system).
3. **Multi-agent-tool compatibility.** Hngh already speaks ACP (client +
     server, `acp-transport.lisp` newline framing). Vet any tooling folks work
     with that is ACP-facing, plus MCP/A2A interop per the autonomy doc, so
     "accommodate any variety of agentic tools" is a real surface, not a
     slogan. Compatible with the platforms Hngh runs on.
4. **Public cost accounting.** Target (cheap enough to brag): a public-facing
   dashboard of **cost vs capability** — what a session/run cost and what it
   achieved — and an accounting of how well Hngh self-manages its spend
   (credit use, quota windows, budget gates). Canonical source for the numbers
   already exists (cost policy, quota spreader, probe runner, clockwork
   ledger); a *presentation* layer over it, not new metering.
5. **Network of interconnected instances.** Long-run ambition: Hngh expanding
   into a network of instances, each sized to its hardware, contributing to
   mutual goals/services/activities. Keep as a **design seed** (like the
   encoded-filename-metadata capture) — vetted against security-first
   (per autonomy-strategy hardening) before any cross-instance networking; not
   on the current build path.
6. **Tool integration candidates.** RTK, llmtrim, and similar open projects /
   Hngh-developed plugins that lower cost or raise capability. Vet as they're
   matched to a concrete need; don't hoard.

## Open questions

- What exact feature list defines "parity" for the v1 public claim? (Suggest:
   loop visible, ACP surface, cost accounting live, self-healing demonstrated
   in-repo.)
- Dashboard: public static page generated from the ledger, or live endpoint?
   (Live = more surface to secure; static = cheap + honest.)
- Is the multi-instance network pre-publication (a differentiator) or
   post-v1 (a research line)? The recommended default: post-v1, security-first.

## Register

- Backlog link: public-vetting work item (parity research → dashboard → audit).
- This is a *vetting direction*, filed so the eventual build is grounded and
  wave-ordered; nothing here is scheduled code.