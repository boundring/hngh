# Wave C — Open-Source Adoption Research (2026-08-08)

**Status**: research complete → decision inputs for autonomy-strategy §7 Wave C.
**Attribution (clockwork ledger)**: research + synthesis — LLM
(deepseek-v4-flash-0731 via openrouter, Hermes TUI) against authoritative
sources (kernel docs, project sites/GitHub, engineering write-ups); every
recommendation below is an ADOPT-or-BUILD decision for the owner, nothing
auto-wired.

**Principle (owner directive, 2026-08-08)**: don't reinvent existing tools,
methods, and techniques; take advantage of existing open-source projects.
Only build what is genuinely novel — which the research narrows to exactly
two items out of eight.

---

**Decisions after review (2026-08-08, owner review session):**
- **OPA → SHELVED (ADR-044)** — single host, ~15 immutable CL-owned rules; a
  Rego subprocess + policy language costs more than it buys at this scale.
  Extend `safety-boundary`/sentry native rules instead; revisit only for a
  fleet or owner-editable policy at scale.
- **Backup → Syncthing flagship (ADR-043)** — continuous device/LAN sync is
  Syncthing (P2P, no server, REST API Hngh can steer: observe → reconcile →
  tune). Three-layer split: gbd = dotfiles, backup-manager (git) = Hngh
  state tree, Syncthing = mirror across devices. Encrypted offsite
  (restic/borg) deferred. See `docs/design/backup-sync-integration.md`.

---

## Mapping: Wave C item → existing OSS → decision

| # | Wave C item (autonomy-strategy §7) | Adopt (existing OSS) | Decision |
|---|---|---|---|
| 1 | Immutable safety/policy layer | **Landlock** — kernel LSM: a process caps its own FS access, no root, no helper binary. Works for the in-process boundary we already built (`safety-boundary.lisp`); use `landrun` as the no-SUID CLI wrapper, or `chattr +i` for fs-level config immutability + read-only bind mounts | **ADOPT (reinforce, not replace)** — our layer stays the policy owner; Landlock/`chattr +i` harden it |
| 2 | Append-only action log | We ship part 1 (journal/actions.lisp); **tamper-evidence = hash-chaining** (SHA-256 chain, per entry). Direct precedent: **NousResearch/hermes-agent #487** proposes exactly this pattern (inspired by OpenFang); Trillian is a full transparency-ledger implementation but over-heavy (Google-scale infra) | **BUILD (small, unique)** — ~40-line hash-chain in CL over the journal; reuse sbcl's sha256 if available, else ironclad. Do not adopt Trillian (weight/ops >> value) |
| 3 | Least-agency tool scoping | **OPA (Open Policy Agent)** — CNCF-graduated, de facto standard policy engine; Rego policies can gate tool/model calls by route, cost class, arg shape. Runs as a subprocess (Hngh already shells out to agentic CLIs) | **SHELVED (ADR-044)** — native `safety-boundary`/sentry rules at this scale; revisit for fleet/owner-editable policy |
| 4 | Untrusted-content tagging + provenance | **LLM Guard** (MIT, self-hostable, 15 input + 20 output scanners: prompt injection, secrets, toxicity) or **NVIDIA NeMo Guardrails** (Apache-2.0, input/dialog/execution/output rails, jailbreak + injection detection, OTel tracing). Both Python — run as a sidecar scanner. **Provenance tagging itself = Hngh-native** (no OSS equivalent; it's our attribution ledger) | **REVISED 2026-08-09**: protectai/llm-guard ARCHIVED Jul 9 2026 (read-only). Operator chose "Lisp-preferred, match our stack" — D1 landed as a deterministic LISP rule scanner (`hngh prompt-lint --scan`, commit 7220317) behind a scan() boundary; NeMo Guardrails kept as an optional plugin behind the same boundary. Provenance stays ours |
| 5 | Canary tokens | **Thinkst Canarytokens** (free, self-hostable; core is a Python app, Docker repo is convenience packaging) + **OpenCanary** honeypot. Plant tokens in context/prompts; a fired token = exposure | **ADOPT** — self-hosted canary server (no Docker per repo non-goals; run the Python app directly) |
| 6 | Execution sandboxing | **Bubblewrap (bwrap)** — unprivileged namespace sandboxing, no SUID, no daemon, smallest trust base (it's Flatpak's engine). **Landrun** same idea on Landlock. gVisor (user-space kernel) / Firecracker / Kata (microVM) = stronger, but real infra weight | **ADOPT (bwrap)** — per-task sandbox for agent-generated code: default-deny FS/net; escalate to gVisor only if the threat model does |
| 7 | Pinned/allowlisted deps | **qlot** — project-local Quicklisp pinning (the standard CL tool; `qlfile` pins dist versions); **CLPM** as the newer alternative | **ADOPT (qlot)** — commit qlfile; new deps need owner approval (the `:operation` gate) |
| 8 | `:operation` human gate (core commits + dep installs) | Hngh-native concept (task type already exists in ai-orchestrator) — no OSS equivalent; self-modification gating is novel ground | **BUILD (ours)** — extend the existing `:operation` type to core-file commits + dep installs |

---

## Headline findings

1. **The design is NOT over-restrictive — it's mostly an adoption checklist.**
   Six of eight Wave C items resolve to "install/point at existing OSS and
   wire a fail-closed call." Only *provenance tagging* and the *`:operation`
   gate* are genuinely Hngh-specific.

2. **Sandboxing: Bubblewrap, not Firejail.** The Firejail maintainers
   themselves (rusty-snake, issue #6466) caution that wrapper sandboxes with
   weak profiles and SUID-root binaries buy little against a real RCE;
   Bubblewrap is unprivileged (no SUID), smaller trust base, and the same
   engine Flatpak ships. For agent-generated code specifically, bwrap
   default-deny FS/net per task is the right first rung. Landlock is the
   in-process complement for code we control.

3. **Policy: OPA is the de facto standard** (CNCF graduated, "missing
   guardrail for AI agents" is an active use case). Rego-as-data beats
   hand-written `if` trees for least-agency scoping, and matches the
   repo's immutable-config philosophy: policy lives outside the agent.

4. **The tamper-evident log has a direct precedent in our own harness**
   (hermes-agent #487, SHA-256 hash chain, inspired by OpenFang). It's a
   small build — not a reason to adopt Trillian.

5. **Cost/weight guardrails preserved**: everything recommended is local,
   self-hostable, $0 marginal, and no-Docker-compatible (canarytokens core
   is Python; OPA is a single binary; bwrap/qlot are dist packages on
   CachyOS). gVisor/Firecracker/Kata are assessed and deferred — right
   answer for a hardened *multi-instance fleet*, out of scope now.

---

## Recommended adoption order (smallest-rung-first, matching Wave C gate)

1. **qlot pinning** (item 7) — one config commit, immediate reproducibility;
   prerequisite for "pinned, hash-verified deps" and for vetting any future
   dep the agent proposes.
2. **Bubblewrap per-task sandbox** (item 6) — wrap the task driver's
   agent-generated-code execution; fail-closed profile (default-deny,
   `--ro-bind` only the task dir).
3. **Native least-agency tool scoping** (item 3) — extend
   `safety-boundary`/sentry rules directly (delete-all-by-default tool grant
   list on the tool hub), **no OPA** (ADR-044); revisit external policy
   engine only for a fleet/owner-editable policy at scale.
4. **Hash-chained action log** (item 2) — extend `journal/actions.lisp`
   with per-entry SHA-256 chain + verify command.
5. **Canarytokens self-host + LLM Guard sidecar** (items 4–5) — tokens in
   prompts, output scan on the judge/steer path.
6. **`:operation` gate extension to core commits + dep installs** (item 8) —
   the final check before C6 can touch core files safely.

**Gate stays**: no C6 self-modification of core until items 1–4 land.

---

## Sources

- Bubblewrap vs Firejail vs Landlock (incl. Firejail maintainer nuance on
  wrapper-sandbox limits): firejail issue #6466; kernel.org Landlock docs;
  botmonster.com bwrap guide (2026-05)
- gVisor / Firecracker / Kata isolation-model comparison (untrusted code
  execution, 2026 surveys): dev.to "4 ways to sandbox untrusted code in
  2026"; northflank.com/platforms survey
- OPA: openpolicyagent.org/docs; codilime "Why OPA is the missing guardrail
  for AI agents"
- NeMo Guardrails / LLM Guard / LlamaPromptGuard / LlamaFirewall:
  github.com/NVIDIA-NeMo/Guardrails; turingpost 10 OSS tools for LLM
  security; appsecsanta NeMo 2026 overview
- Canarytokens / OpenCanary: canarytokens.org; thinkst/canarytokens-docker;
  tracebit canary-provider roundup
- Hash-chained audit log: NousResearch/hermes-agent issue #487
  (SHA-256 chain, OpenFang inspiration); transparency.dev (Trillian)
- CL dep pinning: qlot / CLPM project docs; r/Common_Lisp package-
  management thread