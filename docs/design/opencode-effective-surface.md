# Effective OpenCode surface (card 146)

Status: DESIGN — card 146, 2026-08-10.
Source: `docs/project/next.md` row 12 (audit resolved config after
global/plugin merge; the nominal Hngh file is not the effective MCP/tool
surface; fix precedence or add a controller before no-input promotion);
`docs/design/autonomous-action-policy.md` §4 OpenCode and §8 promotion gate 3;
`docs/design/model-economy-and-context-lifecycle.md` §"OpenCode's nominal Hngh
config is not its effective surface".
Cross-links: `autonomous-action-policy.md` (card 145: no-input worker policy,
§7 fixtures, §8 gates and rollback), `model-economy-and-context-lifecycle.md`
(profiles, compression discipline, cost telemetry), `operation-gate.md`
(pre-exec gate), `agent-client-protocol.md` (ACP permission routing),
`docs/project/next.md` row 11 (Hermes 120k compression cap; OpenCode needs a
version-verified trigger/controller seam).

## Motivation

The nominal Hngh OpenCode config is a 575-byte file that names one provider,
three agents, and a few deny rules. It is not what a session executes.
`hngh-opencode` exports `OPENCODE_CONFIG`/`OPENCODE_CONFIG_DIR`, but the
resolved config in OpenCode 1.18.15 merges in the global config file, plugin
configuration, and project-level configs. The resolved inventory — MCP
servers, agents, plugins, permissions, compaction keys — is the actual
security and token budget. Card 146 audits that resolved surface, decides the
precedence fix or Hngh controller, and pins acceptance fixtures before any
no-input promotion (autonomous-action-policy §8 gate 3).

## Decision

1. The resolved surface (`opencode debug config` with the wrapper env vars)
   is the only authoritative inventory for Hngh workers. The nominal file is
   an input, never a claim.
2. No undocumented OpenCode config key is used to express the compression
   cap. OpenCode 1.18.15 documents `auto`, `keep.tokens`, and `buffer` for
   compaction; there is no documented absolute `maxContext`/threshold key in
   this version, so no such key is invented. The 120,000-token compression
   cap is a Hngh policy constant enforced by a Hngh-side controller, not by
   an OpenCode config field.
3. Until a controller exists, retain OpenCode's high-level automatic
   compaction (`auto: true`) as the safety net, with its effect made
   explicit: with the effective model's 262,144-token context and default
   `buffer` 20,000, auto compaction triggers near 242k estimated tokens —
   well above the 120k discipline. Auto compaction alone does not honor the
   cap; it only prevents hard overflow.
4. No-input promotion for OpenCode stays blocked (card 145 §8 gate 3) until
   the effective surface audit and the controller/fixture set in this doc
   land, with `bash` deny-with-controller and `--auto` still banned.

## 1. Verified evidence (2026-08-10, OpenCode 1.18.15)

All facts below were captured on this date; reproduction commands are in
§1.6.

### 1.1 Wrapper seam

`~/.local/bin/hngh-opencode` (296 B) exports:

```bash
export OPENCODE_CONFIG="${HNGH_OPENCODE_CONFIG:-$HOME/.config/opencode/hngh/opencode.jsonc}"
export OPENCODE_CONFIG_DIR="${HNGH_OPENCODE_CONFIG_DIR:-$HOME/.config/opencode/hngh}"
exec opencode "$@"
```

`OPENCODE_CONFIG_DIR` additionally carries `agents/{hngh-implement,
hngh-probe,hngh-review}.md` and `HNGH.md` (the instruction file named in the
nominal config's `instructions`).

### 1.2 Nominal source config

`~/.config/opencode/hngh/opencode.jsonc` (575 B) declares exactly:

- `enabled_providers: ["unsloth-local"]`
- `model: unsloth-local/unsloth/Qwen-AgentWorld-35B-A3B-GGUF`
- `small_model: unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF`
- `default_agent: hngh-implement`
- `compaction: { auto: true, prune: true, reserved: 12000 }`
- `permission: { "*": "ask", external_directory: "deny", task: "deny",
  question: "deny", webfetch: "deny", websearch: "deny" }`
- `instructions: ["…/hngh/HNGH.md"]`

It declares **no** `mcp`, **no** `plugin`, **no** `agent`, and **no** `read`
permission block.

### 1.3 Effective resolved surface

`opencode debug config` run with the wrapper's env vars (exit 0, version
1.18.15 via `opencode --version`) resolves to:

- **MCP servers (7 entries, 6 enabled, 0 declared in the nominal file):**
  `websearch` (remote exa.ai, enabled), `context7` (remote, enabled),
  `grep_app` (remote, enabled), `lsp` (local oh-my-openagent daemon,
  enabled), `codegraph` (local, **enabled: false**), `misakanet` (local,
  enabled — the only MCP the global file declares), `oh-my-claudecode:t`
  (local OMC bridge, enabled).
- **Plugins (3):** `opencode-antigravity-auth@latest`,
  `oh-my-openagent@latest`, `file:///home/bricker/.config/opencode/plugins/rtk.ts`
  (all global scope). The global file declares only the first two; the third
  is plugin-supplied. All three are `@latest`/file-pinned — an update can
  change the surface without touching Hngh files.
- **Agents (43):** the three Hngh agents (`hngh-implement`, `hngh-probe`,
  `hngh-review` from `OPENCODE_CONFIG_DIR/agents/`) plus 40 global/plugin
  agents: built-in/global (`plan`, `oracle`, `explore`, `librarian`, `build`,
  `multimodal-looker`, `Atlas - Plan Executor`, `Metis - Plan Consultant`,
  `Momus - Plan Critic`, `Prometheus - Plan Builder`, `Sisyphus - ultraworker`,
  `Sisyphus-Junior`), 21 `oh-my-claudecode:*` specialists, and 15
  `llmtrim-*` specialists. `Sisyphus - ultraworker` carries permissive
  permissions (`question: allow`, `task: allow`, `teammate: allow`) and a
  remote model reference (`openrouter/z-ai/glm-5.2`).
- **Permission (merged, per-key):** `"*": "ask"` (nominal), `webfetch:
  "deny"` (nominal overrides global allow), `external_directory: "deny"`
  (nominal overrides global allow), `task/question/websearch: "deny"`
  (nominal), `read: { "*": "allow", "*.env": "deny", "*.env.*": "deny",
  "*.env.example": "allow", "*.env.sample": "allow",
  "~/.hermes/auth.json": "deny", "~/.local/share/opencode/auth.json":
  "deny", "*.key": "deny", "~/.gnupg/**": "deny", "~/.ssh/id_*": "deny" }`
  (global — the nominal file does not set `read`, so the global block
  survives the merge).
- **Provider gate holds:** `enabled_providers: ["unsloth-local"]`; the four
  local models resolve with context/output limits Qwen-AgentWorld-35B
  262144/16384, Ornith-35B 222464/16384, Ornith-9B 120320/8192,
  gemma-4-12b 219904/8192. Remote-model agent references cannot resolve
  under this gate (fail at resolution, no remote call).

### 1.4 Precedence rule (observed, not assumed)

The named `OPENCODE_CONFIG` file overrides the global file **per key it
sets**; every key it does not set inherits global/plugin values, and MCP
entries and agents merge **by name**. Evidence: global `webfetch: allow` and
`external_directory: allow` resolve to `deny` (nominal wins); the global
`read` block and all MCP/plugin/agent entries resolve unchanged (nominal
silence). Project-level `opencode.json(c)` files additionally merge from the
working directory upward, so the audit must be re-run in the actual worktree
(`/home/bricker/Projects/etc/20260605/.opencode/opencode.json` exists in the
tree and would merge there). A global `AGENTS.md` also exists
(`~/.config/opencode/AGENTS.md`) and can inject instructions into sessions.

### 1.5 Compaction: documented V2 seam vs. source keys

Official V2 docs (`opencode.ai/v2/docs/compaction`, fetched 2026-08-10):

- Automatic compaction (default on) estimates the final system prompt,
  messages, and advertised tools before each model call (JSON-serialize,
  4 chars/token) and starts when
  `estimated tokens > context limit - max(requested output tokens, buffer)`.
- Documented config fields: `auto` (default `true`), `keep.tokens` (default
  `15000`), `buffer` (default `20000`).
- Manual compaction: `/compact` (`/summarize` alias; `session_compact`
  keybind). "The CLI has no separate `compact` subcommand. Use the TUI
  command or the server API": `POST /api/session/{id}/compact` or
  `opencode2 api v2.session.compact --param sessionID=ses_…`.
- "V1 used additional tail-turn and pruning behavior. Those V1 details are
  only migration context; the settings and behavior on this page describe
  V2." GitHub issue #8140 (configurable context limit and auto-compaction
  threshold) is still a feature request — no absolute threshold key in this
  version.

Consequences for the source config:

- `compaction.prune: true` is a V1 key; V2 has no pruning behavior. The
  pruning intent does not execute.
- `compaction.reserved: 12000` is not a documented V2 field; V2's reserve
  field is `buffer` (default 20000). The "12k reserve" intent is
  unverifiable and cannot be relied on.
- Effective trigger with the default agent model:
  262144 − max(16384, 20000) = **~242,144 estimated tokens** — far above the
  120k Hngh compression discipline. Auto compaction prevents hard overflow
  only.

### 1.6 Reproduction

```bash
opencode --version                                  # 1.18.15
OPENCODE_CONFIG="$HOME/.config/opencode/hngh/opencode.jsonc" \
OPENCODE_CONFIG_DIR="$HOME/.config/opencode/hngh" \
  opencode debug config                             # resolved surface JSON
# effective inventory (2026-08-10): 6 enabled MCP, 3 plugins, 43 agents,
# permission merge per §1.3, enabled_providers ["unsloth-local"]
```

## 2. Leakage risk assessment

| Surface entry | Source | Enabled | Risk | Control that holds today | Gap |
|---|---|---|---|---|---|
| `websearch`, `context7`, `grep_app` MCP | plugins (global) | yes | remote MCP servers receive request context (exa.ai, context7, grep.app); undeclared in nominal file | top-level `websearch`/`webfetch` deny covers the built-in tool only; MCP tool names fall under `"*": "ask"` | `*: ask` prompts interactively — the card 145 wait bug in a no-input worker unless ACP-mediated |
| `lsp`, `oh-my-claudecode:t`, `misakanet` MCP | plugins + global | yes | local daemons expand tool surface and schema cost (token budget) | local endpoints; misakanet is the declared Hngh MCP | surface not owned by nominal file; plugin update can add more |
| `codegraph` MCP | plugin | no | dormant but present; one config/plugin change enables it | `enabled: false` today | not pinned; an upgrade may flip defaults |
| 40 non-Hngh agents (OMC, llmtrim, global) | plugins + global | n/a | permissive agents (`Sisyphus`: task/question/teammate allow, remote model ref) selectable via `/agent` or a `default_agent` edit | `default_agent: hngh-implement`; hngh agents deny `task`/`question` | agent surface one config change away; `@latest` plugins drift without Hngh consent |
| `read: {"*": "allow", …secret denies}` | global | n/a | secret-file guardrail is load-bearing for the whole surface | block verified in resolved config | nominal file does not own it; a global edit weakens all workers |
| `"*": "ask"` (incl. `bash` by default) | nominal | n/a | every uncovered tool prompts; no-input workers must never wait on a prompt | card 145 §8 gate 3: `bash` deny-with-controller before promotion; `--auto` banned | controller/ACP route required; absent today |
| `enabled_providers: ["unsloth-local"]` | nominal | n/a | remote calls if provider gate leaks | gate verified in resolved config; remote agent models fail resolution | keep as a hard control; never relax for workers |
| `AGENTS.md` (global), `HNGH.md` | global + nominal | n/a | instruction injection surface | HNGH.md forbids remote work/subagents/web research | global AGENTS.md merges in and is not owned by Hngh |

## 3. No-input worker policy intersection (card 145 §8 gate 3)

Promotion requires: "OpenCode effective surface audited (card 146) with
`bash` deny-with-controller (never `--auto`)". This doc is that audit. The
remaining gate-3 work is the controller that converts every `*: ask` (MCP
tools, `bash`) into a procedural allow/deny/`awaiting-operator` record via
the ACP channel — never a live prompt — and the fixtures in §5. Until then,
attended OpenCode sessions and the current source config are unchanged.

## 4. Recommendation

1. **Primary: a maintained Hngh wrapper/controller (or version-pinned
   plugin) that owns the compression trigger.** It must:
   - observe effective request usage (session event stream / server API) and
     estimate input tokens per model call;
   - issue compaction via the version-verified server seam
     (`POST /api/session/{id}/compact` or `v2.session.compact` — which
     endpoint exists on the installed 1.18.15 binary must be verified by a
     fixture, not assumed) when estimated usage crosses the **Hngh policy
     constant ≤ 120,000 tokens** (matching the Hermes compression cap;
     enforced controller-side, not as an OpenCode config key);
   - fail closed: if the controller cannot measure, cannot reach the API, or
     the version check fails, it does nothing and journals
     `controller-absent`; OpenCode's high-level auto compaction remains
     enabled as the overflow safety net;
   - be covered by source-verified event/controller tests (§5 F4).
2. **Interim (until the controller lands):** keep `compaction.auto: true`
   and document its true effect (trigger ~242k, overflow prevention only).
   Do not claim the source config enforces the 120k discipline — it does
   not.
3. **Config surface fix (follow-up card, not this one):** make the nominal
   file own the surface instead of inheriting it — explicit `"mcp": {}`
   (or the intended allowlist), explicit `"plugin": []`, and an explicit
   `read` block copied from the global guardrail; `enabled_providers` stays
   `["unsloth-local"]`. Replace the dead V1 compaction keys with documented
   V2 fields: drop `prune`, express the reserve as `buffer` (and optionally
   `keep.tokens`) so the intent is verifiable. Do not add an undocumented
   threshold key.
4. **Precedence fix options (evaluate in the follow-up card):** (a) launch
   workers with an isolated XDG config home so `~/.config/opencode/opencode.jsonc`
   is not merged at all; (b) explicit overrides per option 3; (c) keep the
   global file for attended sessions only. Option (a) is the strongest
   guarantee and the least dependent on merge semantics.

## 5. Acceptance fixtures (spec — implemented by the follow-up card)

Fixtures are hermetic (fake `HOME`, empty `GIT_CONFIG_*`, no network, no
live config mutation) and assert exact resolved JSON, per card 145 §7 style.

- **F1 — resolved-surface isolation.** With `OPENCODE_CONFIG`/
  `OPENCODE_CONFIG_DIR` set and a global file absent, `opencode debug config`
  resolves to exactly the nominal file's declarations: `mcp == {}`,
  `plugin == []`, agents == the hngh trio, `enabled_providers ==
  ["unsloth-local"]`. Fails on any leaked entry.
- **F2 — precedence and inheritance.** Global sets `webfetch: allow`; nominal
  sets `deny` → resolved `deny`. Nominal omits `read` → global `read` block
  survives verbatim. Nominal adds `read` → nominal wins. Assert the exact
  merged permission object, not a subset.
- **F3 — compaction-key truth.** Resolve with and without
  `prune`/`reserved` in the nominal file: identical effective config proves
  the keys are dead (V1 residue); assert the documented trigger math
  `context − max(output, buffer)` with the effective model's limits
  (262144/16384, default buffer 20000 → ~242144).
- **F4 — controller trigger.** Event stream with estimated usage crossing
  120,000 → exactly one `session.compact` API call with the session ID;
  below threshold → no call; controller absent, version mismatch, or API
  unreachable → no call, journal `controller-absent`, `compaction.auto`
  still `true` (safety net retained).
- **F5 — no-input interception.** hngh-implement agent, F1 surface, tool
  request for an MCP tool not explicitly allowed → `*: ask` would prompt;
  assert the controller/ACP route converts it to `awaiting-operator`
  (durable record, worker retires) and that **no** session prompt is ever
  issued or waited on.
- **F6 — rollback oracle.** Apply the surface fix (option 3/4), capture
  `opencode debug config`, revert, capture again: byte-identical inventories;
  F1–F3 re-pass.

## 6. Upgrade and rollback

- **This card** is docs-only: rollback is `git rm`/checkout of this file. No
  config or source file is edited by card 146 itself.
- **Future surface-fix card:** every change is a per-key override in the
  nominal file; rollback = restore the prior file bytes, which reverts the
  resolved surface to the global union by the §1.4 precedence rule. Keep the
  pre-change `opencode debug config` JSON as the rollback oracle (F6).
- **Controller:** disabling the controller returns to interim mode (auto
  compaction only) with a journaled `controller-absent` event. Any gate
  regression auto-demotes no-input state per card 145 §8 (fixture failure,
  audit-chain break, or `awaiting-operator` past SLA).
- **Upgrade:** pin the OpenCode version used by workers; after any upgrade
  re-run F1–F4 and re-verify which compaction API seam exists before
  re-enabling the controller. `@latest` plugin specs are an upgrade risk in
  themselves; prefer pinned plugin versions for worker launches.

## Explicit non-goals

- No invented OpenCode config key for an absolute context threshold; the
  120k cap is a Hngh policy constant in the controller.
- No change to the global `~/.config/opencode/opencode.jsonc` or the
  attended interactive surface.
- No change to the nominal `hngh/opencode.jsonc` in this card (the surface
  fix is a separate, fixture-gated card).
- No `--auto` and no `approvals.mode: off`-style bypass; card 145 §8 gates
  still own no-input promotion.
- No claim that auto compaction enforces the 120k discipline — verified
  trigger is ~242k on the default agent model.
