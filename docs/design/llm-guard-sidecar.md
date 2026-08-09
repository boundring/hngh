# D1 — LLM Guard sidecar: design brief (card 109, Sprint 1)

One page. Per 115 bounded-brief format. se's design slice for the
D1-A decision; feeds cibo's impl gate.

## DECISION (operator 15:39): LLM Guard sidecar only — local
content-safety scanner on the agent message path. Canaries deferred
post-114. MUST-NOT: no internet-exposed scanner/server.

## FACT-CHECK (documentation-first, primary sources)

- protectai/llm-guard was ARCHIVED Jul 9, 2026 — repository is
  read-only, project unmaintained (github.com/protectai/llm-guard:
  "This repository was archived by the owner on Jul 9, 2026. It is
  now read-only."). Last commit = the archiving commit.
- The tool still installs (pip llm-guard) and its scanners work as
  of the last release — an archived package is not a broken package.
- A maintained OSS alternative with the same shape (Python library,
  self-hosted, local): NVIDIA NeMo Guardrails (Apache-2.0, 0.23.0,
  actively released, IORails content-safety engine). Already listed
  as the alternative in docs/research/wave-c-open-source-tooling.md.
- TrustGate (NeuralTrust, Go gateway) is the closest "successor"
  per third parties, but it is a GATEWAY architecture (traffic
  proxy), not an embeddable library — different integration shape.

## CHOICES (for operator — the decision named an archived tool)

- A. SHIP AS DECIDED: pin llm-guard at last release, use its
  prompt-injection + secrets + toxicity scanners. Cost: dead project
  — no security fixes/upstream patches going forward; acceptable
  only because the scanner is a best-effort content gate, not a
  trust boundary. Unblocks: fast, matches the operator's exact pick.
- B. SWAP TO MAINTAINED: NeMo Guardrails (same Python-library shape,
  self-hosted, Apache-2.0, NVIDIA-maintained). Cost: config/model
  differences (Colang flows vs llm-guard scan calls), small design
  delta, but a live project. Unblocks: long-term maintenance, CVE
  flow.
- C. BOUNDARY-ABSTRACT (recommended): design the integration
  boundary to accept EITHER (a thin scanner interface: scan(text) →
  verdict/risk), ship A now, swap to B later without touching the
  boundary. Cost: one small interface layer (~30 lines). Unblocks:
  both — honors the operator's decision AND the archive reality.

Recommendation: C. The boundary is the design deliverable anyway;
the scanner impl behind it is swappable by construction. This is the
honest reading of D1-A: LLM Guard sidecar ONLY (A), with the
maintenance risk surfaced (B/C) — operator picks the impl, the
boundary ships regardless.

## BOUNDARY DESIGN (the integration point)

```
            ┌─────────────┐    scan(text)     ┌──────────────────┐
 seat/steer │ agent path  │ ────────────────► │ llm-guard-scan    │
  (message) │ (pre-spawn, │   verdict{ok|     │ (sidecar process  │
            │  judge,     │    block, risk}   │  or library call) │
            │  outbox)    │ ◄──────────────── │                  │
            └─────────────┘                   └──────────────────┘
```

- The sidecar exposes ONE function-shaped boundary:
  `scan(text) -> {ok | blocked, risk: 0..1, scanner: name, reason}`
  implemented as a local library call (Python) or a local HTTP
  sidecar — process-local either way, no network exposure.
- Where it plugs in (existing surface): the prompt-lint gate
  (pre-spawn, seat-up) already rejects prompts; llm-guard-scan adds
  the content-safety verdict AFTER lint passes, BEFORE spawn. Same
  fail-closed semantics: any scanner error → treat as blocked
  (fail-closed, per the deck's security doctrine).
- MUST-NOT: no tool-output wholesale scanning, no internet-exposed
  server, no secrets sent to the scanner (scanner is local, but the
  boundary still passes only the prompt text, not keys).
- Config: scanner model/settings in ~/.hermes/config or hngh config;
  the interface is config-agnostic (scan(text) doesn't know which
  backend).

## FIXTURE (design-for-test, cibo's impl will fixture this)

- Fixture = a fake scanner implementing the same scan() contract:
  (a) benign text → ok; (b) injection-pattern text → blocked with
  reason; (c) scanner down/error → blocked (fail-closed); (d) risk
  threshold boundary. The fixture runs against the INTERFACE, not
  the real llm-guard package — hermetic, no pip dep in CI.
- The real llm-guard (or NeMo) integration is a thin adapter tested
  separately (smoke: one real scan call, offline-capable scanners
  only — no model download at test time).

## ACCEPTANCE (this design)

- Boundary doc (this page) + fixture contract — done here.
- Operator pick on CHOICES (A/B/C) — recommendation C.
- cibo implements: scan() interface + adapter + fixture, wired into
  the prompt-lint gate fail-closed; make test green.

## Open questions (operator)

- Scanner strictness default: block on risk >= 0.5? (Recommend:
  block >= 0.5, log >= 0.3, pass < 0.3 — three-tier, adjustable.)
- Offline-only constraint: does the scanner need to run with NO
  model download at all (pure heuristic scanners only), or is a
  small local model acceptable (e.g. the Toxicity scanner uses a
  HuggingFace model)?

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes
TUI, 2026-08-09. Informed by docs/research/wave-c-open-source-
tooling.md (items 4-5) + primary sources (protectai/llm-guard
archive banner; NVIDIA NeMo Guardrails releases).
