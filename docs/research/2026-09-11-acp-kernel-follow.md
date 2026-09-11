# acp-kernel follow-up: the billion-context author's standalone kernel

Date: 2026-09-11. Status: research only; no code changed. English/ASCII.
Read the repos as a stranger; every claim cites a URL or file-path.

## 1. What acp-kernel actually is

**Name collision, resolved first.** The author's "ACP" is *Active Context
Pruning* -- their own model-driven context-compression architecture -- NOT
Zed's Agent Client Protocol (agentclientprotocol.com). Ranxianglei's repos
never mention Zed's ACP. The operator's reading ("similar approach to Hngh --
de-coupling the kernel") is directionally right but about a different kind of
kernel: acp-kernel decouples a *context-compression engine* from agent hosts,
not a *governance kernel* from executor surfaces.

**Mechanism** (github.com/ranxianglei/acp-kernel README + DESIGN.md, master):
- A pure-TypeScript core with "zero host dependency": `processTurn({
  messages, state }) -> { messages, state, nudge? }` and `applyCompression({
  ranges, ... })`. State is an explicit in/out of every call; the core is
  "stateless with respect to storage" and "never calls a model" (DESIGN.md
  sections 1-2).
- The one external dependency -- the summarizer -- is reduced to a string
  argument the model produces. The core decides when/what to compress, tracks
  blocks/refs/tiers, prunes, decompresses, searches (DESIGN.md s1).
- Port surface is deliberately tiny: one injected port (`countTokens`), with
  a default tokenizer shipped in-core; persistence, prompts rendering, tool
  registration, config merge, auth/logger all stay in per-host adapters
  (DESIGN.md s5-s6 concept-mapping table).
- Node pipeline per turn: assign-refs -> sync-blocks -> merge-blocks ->
  prune -> filter -> hide-compress-calls -> nudge-inject ->
  emergency-truncate -> render-refs (README, "API / processTurn").

**Relationship to hngh's installed stack**: billion-context (bili) is the
proxy that already serves hngh's omp sessions; acp-kernel is its extracted
algorithmic core, "an independent reimplementation, not a port" of
Tarquinen's opencode-dynamic-context-pruning (DCP, AGPL-3.0), released MIT
(README "Why a separate library" + PROVENANCE.md compliance note).

**Maturity signals** (GitHub API + repo tree, checked 2026-09-11):
- Created 2026-07-31; pushed 2026-09-11 (same day as this research); ~359
  commits (rel=last page=359 at per_page=1); 21 stars, 6 forks, 50 open
  issues -- real traffic, not a demo.
- CI: `.github/workflows/ci.yml`, `release.yml`, `pr-artifact.yml`; bench/
  corpus harness (`bench/search/bench.ts`); per-module provenance audit
  (PROVENANCE.md) classifying every donor file A/B/adapter-only against DCP.
- Not thin: 23 core modules (README Status claims "full suite green"), a
  `tests/` directory, DESIGN.md as an explicit contract document, and a
  separate `wire/` codec subpath (anthropic/openai/responses round-trip).
- Adoption: consumed by billion-context (README "rewriting ... with
  acp-kernel compression"), billion-context-pi, and the DeepSeek-harness
  port billion-context-dsh (fork description names "acp-kernel reuse").
  Repo-age caveat: ~6 weeks old; "engine complete" is the author's claim,
  not independently verified.

## 2. Comparison vs hngh

| Dimension | acp-kernel | hngh | Where ahead |
|---|---|---|---|
| Kernel purity | Pure TS core, zero I/O, zero host deps; state in/out; never calls a model (DESIGN.md s2) | `hngh.domain` pure Common Lisp; no clock/env/path/payload/subprocess; `hngh.application` pure use cases with inward ports (docs/architecture.md; docs/core/clean-architecture-charter.md) | Aligned in kind; hngh's purity covers governance policy, acp-kernel's covers compression orchestration |
| Boundary enforcement | Convention + type system + "core holds no state, performs no I/O"; provenance audit documents the discipline (DESIGN.md s2; PROVENANCE.md) | Dependency law + fixture guard that *rejects inward packages importing adapters* (charter "Forbidden dependencies"; architecture.md) + promotion ladder with gates | hngh: enforcement is mechanical (fixtures, certificates), not just declared |
| Governance of mutations | None -- no mutation concept at all; core transforms messages/state | Certificate ceremony: propose -> issue-cert -> mutation-check; closed run lifecycle; receipts hold evidence only (docs/design/autonomous-development-control.md; architecture.md lifecycle) | hngh, outright -- acp-kernel has no analogue |
| Delegation / workers | No worker model; multi-host = multiple thin adapters embedding the same core (README "Multi-host"); wire/ subpath carries subagent-namespace helpers but no supervisor | Governed delegation: omp-bridge gates sessions through create-run + admit-transport; watchdog; spend attribution (architecture.md "omp / opencode executors") | hngh; different problem -- acp-kernel decouples an algorithm, not an authority |
| Context handling | The product itself: 3-tier compression, growth-gated nudges, protected tools, decompress/search, fork-recovery replay (README; DESIGN.md s3-s4) | Research lane only (ctx-compaction-strategies, ctx-structured-briefs; docs/research/2026-09-08-ctx-*), plus bili as an *installed outer proxy* -- never a kernel concern | acp-kernel, decisively |

### 2b. The Zed-ACP DEFER, re-evaluated

The 2026-09-11 DEFER (docs/records/2026-09-11-opencode-configuration.md
s3) deferred *Zed's* Agent Client Protocol: JSON-RPC/stdio agent
subprocess for an interactive editor host. Adopt trigger: "a genuinely
interactive operator surface (editor/TUI host) driving hngh sessions."

acp-kernel does not touch that protocol at all, so the DEFER stands
unchanged on this evidence. What acp-kernel DOES add: proof by production
that a "pure core + thin adapters" split survives contact with five hosts
(proxy, pi, opencode, dsh, omp plugin) and that a stateless-with-explicit-
state contract (no storage port at all) is enough to make a kernel
portable. That is confirmation of hngh's existing doctrine, not new
pressure to adopt Zed-ACP.

## 3. Actionable lessons for hngh (architecture)

Ranked by value/effort. APPLY = act now; WATCH = track, revisit on a
trigger; SKIP = examined and declined.

1. **[WATCH] The extraction play -- ship the proxy first, extract the
   kernel when multi-host pressure appears.** hngh adopted bili as an
   installed outer proxy (docs/research/2026-09-10-bili-lobehub-
   integration.md); the author then extracted acp-kernel *because* "the
   original plugin is tightly coupled to OpenCode's hook system, making
   the algorithm hard to test and reuse" (acp-kernel README "Why a
   separate library"). Lesson for hngh is sequencing, not new code: hngh's
   compression concern correctly stays outside the kernel (kernel-purity
   charter); if hngh ever needs compression in-process (e.g. a
   long-lived dashboard-hosted session), bili already carries the
   extracted core -- no hngh work required. Effort: zero. Revisit
   trigger: any feature wanting compression inside hngh's own process.

2. **[WATCH] Explicit-state contracts beat hidden persistence.** The core
   keeps zero storage: "state is an explicit input and output of every
   call" (DESIGN.md s2), and the port surface shrank to ONE injected port
   (countTokens, s5). hngh's kernel does this for governance values, but
   hngh.application still composes a per-harness clock/identifier store
   (architecture.md "hngh.main"). Not a change request -- a calibration
   point: when hngh adds any port, ask whether it can be an argument
   instead. Effort: zero (a design-review heuristic).

3. **[WATCH] Failure-informed data model: what they REMOVED teaches as
   much as what they ship.** acp-kernel has "no GC -- age-based
   deactivation was removed (it caused memory-loss upstream)" (DESIGN.md
   s4 note) and documents every such fix as a numbered defect (#237
   count-gating, billion-context-pi#32 livelock, opencode-acp Bug 39
   protected-tools). hngh's certificate governance already refuses
   speculative capability; the transferable habit is recording the
   REMOVAL rationale in the design contract itself (DESIGN.md s4
   "Concept Mapping" and the no-gc notes are exactly hngh's
   decisions.md style). Effort: zero; already hngh practice in most
   places.

4. **[WATCH] License-provenance as a first-class artifact.** PROVENANCE.md
   classifies every donor file into buckets (A original / B reimplemented
   fresh / adapter-only) with a stated legal rule ("expression is
   protected, not ideas"). hngh has no equivalent document, but hngh also
   carries no AGPL-adjacent code. Relevant only if hngh ever borrows
   expression from a copyleft source (e.g. the AGPL DCP). Effort: low if
   ever needed. SKIP adopting now -- no current dependency requires it.

5. **[SKIP as code, WATCH as signal] Wire-format honesty work.** The wire/
   codec layer exists because "a <acp> tag inside {\"command\":\"echo\"}
   corrupts the JSON" (README renderTags section) and because strict
   backends reject mid-stream system messages (billion-context README
   #377 SGLang rationale). hngh's surfaces (omp-bridge, MCP) do not
   re-voice provider wire bodies, so there is nothing to port. The
   durable signal: cross-backend format regressions (#170, #187) are
   found by users on OTHER backends, not by the author's tests -- for
   hngh, any future provider-facing surface needs a strict-backend
   fixture, not just an Anthropic-shaped one.

## 3b. Process-level lessons (grounded in the issues/PR track record)

What a solo author running a kernel-decoupling project in the open
actually does (acp-kernel: 359 commits since 2026-07-31, 172 closed PRs,
17 open; billion-context issue #714 filed 2026-09-11 -- both repos active
the day of this research):

- **Self-filed, RFC-style issues as the design surface.** The author
  files `feat(...)` issues that read as mini-specs before code exists
  (acp-kernel #166 "pluggable compression candidate planner --
  advisory", #167 "advisory compression prompt set"; billion-context
  #629 "Design: tree-shaped prefix affinity", #518-521 native-mode
  series A-D). hngh equivalent: hngh plans via the ceremony, but the
  *exploration* stage often lives in session context instead of a
  numbered, linkable artifact. What to imitate: the issue as an
  RFC-before-plan unit -- a plan-file skeleton could cite a
  queue/report item the way their PRs cite issue numbers (PR #253
  closes #251). Cost: low; surfaces in report-queue item formatting,
  not new machinery.
- **Visible self-triage.** acp-kernel #168 "scan all issues and PRs --
  which are worth it, which are not" (6 comments) is a scheduled
  backlog-disposition sweep done in public. hngh does the same thing
  (docs/research/2026-09-09-backlog-disposition-sweep.md) but internally.
  Imitation value: low effort, medium visibility -- if hngh ever gains a
  public face, disposition sweeps are already the artifact to publish.
- **Release PRs as the unit of shipping.** Every version lands through a
  `release v0.0.6x` PR (acp-kernel #240 v0.0.61, #243 v0.0.62, #246
  v0.0.63 on consecutive days) -- 63 patch releases in ~6 weeks, i.e.
  release-as-PR with CI (`ci.yml`, `release.yml`, `pr-artifact.yml` in
  the repo tree). hngh's loop already commits per green (commit-per-green
  rule, hngh skill); the observable difference is the *named version
  boundary*. Verdict: hngh's cadence governs a different artifact class
  (evidence-bearing runs, not npm packages); a versioned-release habit
  would add ceremony without an operator need. SKIP; revisit only if
  hngh publishes a package.
- **External contribution handling is small but real.** acp-kernel #163
  (config defaults drift + non-finite nudge scalars) is by @Tyan66666,
  resolved with 4 comments; billion-context-dsh is a third-party fork
  (Tyan66666) upstreamed as a sibling repo. The pattern: accept
  narrow, well-scoped external bug reports; keep design authority
  with the author. hngh: N/A today (single-operator), but validates
  hngh's "reviewers advise, never decide" posture as scale-compatible.
- **Breaking changes are documented as numbered migrations, not
  changelog blurbs.** billion-context's README carries an entire
  rationale section for one wire-format change (#377: why summaries ride
  on user messages, why not forged tool calls) with the accepted
  trade-off named. Compare docs/project/decisions.md -- same shape, and
  hngh's version is already stricter (decision + revisit trigger).
  Nothing to change; confirmation only.
- **What the absence says (honesty note).** The author does NOT use
  public governance artifacts: no PR reviews requested, no CODEOWNERS,
  merge is self-merge. The public process is issue-RFC + fast self-merge
  + CI -- fine for a compression library; it is exactly the "weakest
  validation baseline" (rubber-stamp approval) the govbench
  weak-validation-baseline line warns about
  (docs/research/2026-09-07-govbench-weak-validation-baseline.md). Their
  speed comes from skipping what hngh exists to formalize. The mirror:
  hngh should imitate their *visibility* (numbered, public design
  discussion) and not their *validation* (self-merge).
