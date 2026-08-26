# Integrations — where the governance pattern binds to the marketplace

Hngh's reusable property is not a feature set; it is a governance
shape: claims are admitted only after evidence, actions never run
without a certificate re-checked at the moment of mutation, and every
refusal is a closed, recordable, human-closable step. That shape plugs
into the wider marketplace as four recurring integration forms:

- **Adapter** — a transport Hngh calls to gather/verify evidence or
  issue a certificate-bound action against one external tool.
- **Hook** — an external system invokes Hngh (or Hngh registers to be
  invoked) at a defined event boundary.
- **Downstream** — Hngh consumes an external artifact (a CI failure,
  an attestation bundle, a secret scan report) as evidence.
- **Upstream** — Hngh produces artifacts (certificates, ledgers,
  declared config) another system consumes.

Each area below names real tools, the integration shape, and a ranked
first slice (`now` / `next` / `later`).

## CI systems — Hngh as a governance gate

- **GitHub Actions** — a workflow runs on `check-suite`/`workflow_run`;
  `scripts/hngh` parses the failure log as downstream evidence, runs the
  dogfood governance loop to complete or reject pending commits, and refuses to
  re-run until the event is governance-resolved. The gate is a Hook; the
  failure log is Downstream evidence. **Now:** a `ci-governance-gate`
  adapter that consumes an exported Actions failure log and emits a
  `:federation`-style evidence fact.
- **GitLab CI** — same shape over `.gitlab-ci.yml` pipelines and their
  `JOB_FAILED` style events. Lower operator priority (not the current
  host). **Later:** a second adapter behind the same evidence port.
- **Gitea/Forgejo Actions** — matches GitHub Actions' YAML model, so a
  single Actions-shaped adapter likely carries; verified only after a
  pinned peer actually runs Forgejo. **Next:** reuse after GitHub, with
  fixture gates against a real Forgejo runner.

Ranked: GitHub Actions adapter **now**; Gitea reuse **next**; GitLab
**later**.

## Agent harnesses — where reviewer/worker/certificate surface plugs in

- **oh-my-pi / omp** — Adapter + Hook. The worker-rung and the
  tts/voice research already note `omp say` for surfacing results;
  the bounded `:worker` task, `:terminal` evidence fact, and
  `:model` review transport map directly onto omp tool calls behind a
  port. **now:** one bridge shim that drives a bounded worker/review
  through the omp tool surface.
- **llm-trim** — compact panels; Hngh's rendered operation results
  already feed the interface family. **Next:** certificate-bound
  command results displayed through an llm-trim-style panel (no new
  kernel surface).
- **opencode** — external agent harness; Hngh can act as a governance
  gate *around* it (Downstream result consumed as evidence) rather than
  inside it. **Later.**
- **hermes / pi** — worker substrate (the Pi survey); reusable for
  evidence-gathering workers. **Next:** run a read-only scout/reviewer
  worker through hermes/pi in a disposable directory.

Ranked: omp + pi bridge **next**; opencode gate **later**.

## Cloud / ops — system configuration manager

- **Terraform / OpenTofu** — Downstream result / Upstream declared
  state. Hngh can certify `plan` vs `apply` pairs: evidence-before-claim
  on the plan diff, then one certificate-bound apply; reversibility is
  the rollback plan admission. **later.**
- **Ansible / NixOS / home-manager** — Hngh as config manager: declared
  per-node config, evidence-backed rollout (read the intended state
  after apply), reversible by reverting the declaration. NixOS home
  assumptions underlap the "config-manager" backlog item. **next.**
- **Arch / CachyOS (yay, paru, pacman)** — adjacent package surface:
  a certificate-bound upgrade *slice* (list current, pin, apply) is a
  natural config-manager first case on the operator host. **now.**

Ranked: arch package slice **now**; model-config patterns **next**;
Infra-as-code manifolds **later**.

## Messaging / automation — reaction chains

- **KDE / org.freedesktop.Notifications (qdbus)** — Hook: desktop
  notifications carry mail/job-search events into an agentic reaction
  chain; the notify-agent listens and prepares (draft reply, first
  evidence, governance proposal). **now.**
- **Notifier for push (ntfy / Apprise)** — an Outbound notifier for
  pushed results; broadcast channel, not an authority. **next.**

Ranked: `notify-agent` (KDE) **now**; ntfy/Apprise **next**.

## Security — the attestation/pinning stack and its neighbors

- **openssl / Ed25519 / carrier bundles** — the rung-12 pinned-key
  registry and signature transport are already in-tree and
  openssl-backed; they are the trust anchor for any external
  attestation we ingest. **now** — reuse, don't vendor.
- **Secret scanning** — `verify-candidate` already guards credentials;
  leak it as an upstream gate (a scan result as an evidence fact) that
  repo hooks and CI gates can consume. **now.**
- **SBOM / audit (syft, grype)** — Downstream: ingest a generated SBOM as
  an evidence artifact into the ledger, diff against an allowed
  baseline, gate on delta. **later.**
- **AGPL posture** — the license restrains *embedding*; integration
  shape therefore favors hooks/adapters at a documented boundary over
  linking Hngh's kernel into proprietary products. Stated in
  SECURITY.md's governance posture; informs *which* integrations are
  pursued. **Always** — a constraint, not a feature rung.

Ranked: secret-scan leak + key reuse **now**; SBOM ingestion **next**;
package/rollout band **later**.

Each first slice (above) is picked to be the smallest concrete,
positionable change that proves the shape in one map surface before any
broader wiring.
