# Wave C — canary/scan scope research (card 109A, 2026-08-09)

Documentation-first notes read from the vendor docs on 2026-08-09.
Source of truth: github.com/protectai/llm-guard, protectai.github.io/
llm-guard, github.com/thinkst/canarytokens, github.com/thinkst/
canarytokens-docker, docs.canarytokens.org.

## 1. LLM Guard — project is ARCHIVED (changes the wave-c recommendation)

- Repo `protectai/llm-guard`: MIT, ~3.2k stars. **Archived by the owner
  on 2026-07-09; read-only (commit 168c103, "Archiving Project").** No
  further upstream development.
- Docs site still live (protectai.github.io/llm-guard); `pip install
  llm-guard` still works; 15 input / 20 output scanners unchanged.
- Scanners relevant to us: prompt injection, secrets, toxicity,
  sensitive-data, regex, refusal, relevance (input); toxic, secrets,
  regex, URL reachability, sensitive (output).
- Assessment: adoption = a frozen dependency. Value overlap with what
  Hngh already has: prompt-lint (local no-LLM guard on brief/steer/
  outbox paths) + sentry secret-guard. Incremental value is output-side
  scanning of model replies, which prompt-lint does not do.
- Options for the owner: (a1) adopt frozen LLM Guard as the sidecar
  anyway (works today, MIT, no maintenance cost since frozen, but no
  upstream security fixes), (a2) NVIDIA NeMo Guardrails (Apache-2.0,
  active, heavier: rails pipeline + model comms), (a3) extend prompt-lint
  in-house with the specific scanners we need (no new dependency, but
  we own the scanner logic).

## 2. Thinkst Canarytokens — self-host needs infrastructure

- Core `thinkst/canarytokens` (Python, ACTIVE: latest commit 2026-08-07,
  uv-based, ~2.1k stars, 983 commits). canarytokens-docker is just
  packaging (BSD-3-Clause): switchboard + frontend + nginx + redis,
  compose/docker-compose*.yml.
- Running the core without Docker = python app + redis + nginx + an
  SMTP server or webhook for alerts. Auth request/email/webhook alerting
  is a hard requirement of the service (CANARY_SMTP_* or webhook).
- Most token types work by the token's unique URL/DNS string beaconing
  OUT to the canary service when touched (HTTP callback). That means a
  self-hosted canary server must be REACHABLE from wherever the token
  fires — for our threat model (agent context / prompt / output), firing
  happens where the model runs, which is this machine, so a local-only
  loop is possible WITHOUT any exposed endpoint. Internet exposure
  stays MUST-NOT without owner approval.
- Result: a minimal slice does not need the Thinkst server at all. The
  local tripwire pattern: generate a unique marker string, plant it in
  seat context (mission file), scan tool outputs / lane files for it;
  occurrence = the marker was copied into an output — fire a situation
  record. Zero external services, zero exposure, fixture-testable.
- Keep Thinkst as the upgrade path for real-world beaconing (DNS/HTTP
  tokens in actual networks) when the owner wants it.

## 3. Recommendation for the scope decision brief

- Ship (b)-first as the minimal slice: LOCAL CANARY TRIPWIRE (no
  server, no exposure). Directly matches the card's "tokens planted in
  agent context with output scanning", costs nothing, fixture-testable,
  and its firing path doubles as the L2/L3 situation feed (card 111).
- LLM Guard decision is genuinely open because of the archive: present
  a1/a2/a3 to the owner rather than auto-picking a frozen dep. Default
  recommendation: a3 (extend prompt-lint with output scanning) unless
  the owner wants the broad scanner set for the price of a pip install.
- MUST-NOT kept: no internet-exposed canary server without owner
  approval; sentry secret-guard scope untouched (no wholesale tool-
  output scanning).

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes TUI,
2026-08-09. Vendor docs read first; no probes run against any service.