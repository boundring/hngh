# LobeHub integration surface — programmatic study for autonomous Hngh management

Status: RECORD/RESEARCH — ground for the operator's ask (2026-09-07): Hngh
should fully manage the LobeHub setup (premium plan + desktop app + Android
app). Every endpoint claim below cites one real fetched line or HTTP status
from probes run 2026-09-07, read-only (no keys sent except none; no
purchases, no plan changes, no account creation).

## 1. Programmatic surfaces matrix (all verified live)

| Surface | URL | Verified result 2026-09-07 |
|---|---|---|
| Docs llms.txt | `GET https://lobehub.com/docs/llms.txt` | 200; "Full site map for agents: https://lobehub.com/llms.txt" |
| Full agent sitemap | `GET https://lobehub.com/llms.txt` | 200; names `/openapi.json`, `/.well-known/api-catalog`, `/api/agent-readiness` |
| Landing OpenAPI | `GET https://lobehub.com/openapi.json` | 200; paths: `/api/agent-readiness`, `/api/mcp`, `/api/rate-limits` |
| Agent-readiness bootstrap | `GET https://lobehub.com/api/agent-readiness` | 200; returns `cli: {command: "lh", install: "npm i -g @lobehub/cli"}`, `mcpWebTransport: "https://lobehub.com/api/mcp"`, OAuth discovery URLs |
| Rate-limit contract | `GET https://lobehub.com/api/rate-limits` | 200; "Start at 1 second, double each retry up to 32 seconds" |
| OAuth discovery | `/.well-known/oauth-authorization-server`, `/.well-known/oauth-protected-resource` | listed by agent-readiness (issuer app.lobehub.com, S256 PKCE — prior probe) |
| **WebMCP** | `POST https://lobehub.com/api/mcp` | **keyless 200** (see §2) |
| MCP discovery | `GET https://lobehub.com/.well-known/mcp` | 200; "Primary end-user API and OAuth flows are hosted on LobeHub Cloud (app.lobehub.com)" |
| MCP marketplace | `https://market.lobehub.com/s/plugins` | 200; agent-facing marketplace, `npx -y @lobehub/market-cli mcp search --q KEYWORD`; "thousands of MCP plugins" |
| Dead host | `api.lobehub.com` | 404 Vercel (dead) — confirmed dead, no API there |

Keyless answer, definitive: **the WebMCP endpoint requires no auth** for
discovery-class operations. OAuth (app.lobehub.com issuer) gates the
Cloud/actor surfaces only.

## 2. WebMCP probe (definitive keyless result)

Handshake against `https://lobehub.com/api/mcp` with
`Content-Type: application/json`, `Accept: application/json` (no
Authorization header, no cookies):

- `initialize` (protocolVersion 2025-03-26) -> **200**:
  `{"result":{"capabilities":{"prompts":{"listChanged":false},"resources":{"subscribe":false},"tools":{"listChanged":false}},"instructions":"Use resources/list then resources/read for ui:// onboarding and pricing content.","protocolVersion":"2025-03-26","serverInfo":{"name":"LobeHub WebMCP","version":"1.0.0"}}}`
- `notifications/initialized` -> 200 with JSON-RPC error -32601 "Method not
  found" (stateless server; supported: `initialize`, `resources/list`,
  `resources/read`, `tools/list`, `tools/call`) — the notification step is
  skippable.
- `tools/list` -> **200**: one tool, `lobehub_get_onboarding_links`
  ("Get canonical onboarding links for human + agent setup").
- `resources/list` -> **200**: `ui://lobehub/onboarding`, `ui://lobehub/pricing`.

Read the verdict: WebMCP is a keyless agent-onboarding/discovery surface
(plus workflow-submission helpers per the OpenAPI), not an inference or
account-management API. Full account control for Hngh goes through OAuth
Cloud tokens (app.lobehub.com, S256 PKCE) or the `lh` CLI
(`@lobehub/cli`), which handles "auth, token refresh, and retries" per the
marketplace page.

## 3. Desktop app (this machine)

- Running process: `/opt/LobeHub/lobehub-desktop` (Electron, pid group
  live at probe time). `ss -tlnp` shows exactly one listener:
  `127.0.0.1:33250` (loopback only).
- Probe of the local port (read-only GET): `/` -> 400 "Bad Request: Empty
  file path"; `/api/mcp` -> 404 "File Not Found". It is an internal
  static/file server, not a documented control API. **No local management
  RPC found** — desktop config management for Hngh means editing the app's
  on-disk config (operator-visible files) or driving the GUI, not calling
  a local API. This matches the app's design: state syncs via the cloud
  account ("Sign in once and your Agents, Pages, and Memory stay in sync
  across every device" — docs/usage/getting-started/get-lobehub.mdx,
  fetched from github lobehub/lobehub).

## 4. Android

- Distribution (get-lobehub.mdx): Google Play
  (`com.lobehub.app`) plus **APK from the official download page**
  (lobehub.com/download). Not on F-Droid (no F-Droid listing found in any
  fetched doc).
- Push/notification surface: **not documented** in any fetched page. The
  documented phone-side promise is sync + "Voice conversations, quick
  check-ins, and reviewing outputs away from your desk" (get-lobehub.mdx).
- Alternate documented phone-reach surface discovered: **Channels** —
  docs/usage/channels/ has per-service integration guides (telegram,
  slack, discord, imessage, wechat, line, qq, feishu/lark). A Telegram
  channel would give Hngh-to-phone messaging without any custom channel.

### ssh-to-phone (Termux) sketch — candidate secure channel, parked

Path: Termux on the phone runs sshd (Termux:API for notifications via
`termux-notification`); the desktop side holds the public key; Hngh pushes
short status/notification payloads over LAN or tailscale. Strengths:
operator-owned transport, no third-party cloud in the message path,
matches the Mirror's local-first law. Weaknesses: Android kills background
processes; battery/Doze; APK-source trust (Termux from F-Droid, not Play).
Status: parked pending the operator's channel choice (Termux vs LobeHub
Telegram channel vs the app's own push, which is undocumented).

## 5. Autonomous-management plan (cloud + desktop + phone)

1. **Bootstrap (done)**: `/api/agent-readiness` is the machine-readable
   index of everything above; Hngh should read it at integration time,
   not hardcode URLs.
2. **Cloud config**: authenticate once via OAuth device/PKCE flow
   (app.lobehub.com issuer) or `lh login`; store the token in the Keyring
   (handle-only law). From there, cloud-side agent/model/plugin
   configuration is editable as the operator's proxy identity.
3. **Desktop config**: no local API (§3). Hngh manages config files on
   disk with the operator's visibility, or drives settings through the
   cloud account that the desktop syncs from.
4. **Google tie-ins (gmail/calendar/sheets/docs/drive)**: on LobeHub these
   are plugins/MCP servers configured per-agent, not LobeHub APIs. They
   are **operator-facing surfaces**: Hngh orchestrates (chooses, installs,
   configures, sequences), LobeHub executes, and every touch operates on
   the operator's real Google accounts.
5. **Security frame (cited, not invented)**: the Mirror's model-exposure
   policy governs — "local-first by default ... Remote-model exposure
   requires **per-item policy rows** ... Nothing from the Mirror enters a
   remote prompt without a policy row naming it" (hngh
   docs/design/operator-mirror.md §4). The Keyring's handle-only law keeps
   Google OAuth secrets out of model context. Hngh orchestrates, LobeHub
   executes, secrets never reach models.

## 6. Sources

- Fetched 2026-09-07: lobehub.com/docs/llms.txt, lobehub.com/llms.txt,
  lobehub.com/openapi.json, /.well-known/mcp, /.well-known/api-catalog,
  /api/agent-readiness, /api/rate-limits, live JSON-RPC probes on /api/mcp,
  market.lobehub.com/s/plugins.
- MDX sources fetched from github **lobehub/lobehub** (lobe-chat was
  renamed; api.github.com returns "Moved Permanently" for the old name):
  docs/usage/start.mdx, docs/usage/getting-started/get-lobehub.mdx.
- Local: `ss -tlnp` + pgrep scan (read-only), desktop port probes.
