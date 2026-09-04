# Browser relay architecture — how omp drives browsers, and Hngh's parallel routes

Status: research record — operator directive 2026-09-04: CachyOS = Arch
Linux, so playwright may need extra research; take notes from the
approach oh-my-pi (omp) uses for browser interaction; browser extensions
(Chrome AND Firefox) are AUTHORIZED to help Hngh integrate with a
browser-relay approach; multiple parallel routes toward the feature are
welcome. Extends docs/research/2026-09-03-browser-messaging-automation.md
(sister doc: probe batteries, architecture candidates A/B/C, token-cost
analysis, credentials rules).

## Grounding (verified 2026-09-04, read-only)

- omp = `@oh-my-pi/pi-coding-agent` 18.0.9, installed at
  `~/node_modules/@oh-my-pi/pi-coding-agent` (`~/.bun/bin/omp` is a
  symlink to its `dist/cli.js`; the binary header is ELF only because
  the symlink target was catted — the package itself ships readable
  TypeScript source under `src/`, so the mechanism below is quoted from
  source, not guessed from minified dist).
- omp's relay extension is already on disk on this machine:
  `~/.omp/browser-relay/extension/{manifest.json,background.js,options.html,options.js}`.
- Playwright installed user-space this beat (see §2 Route A):
  venv `~/.hngh-automation/venvs/playwright`, playwright 1.62.0,
  chromium build `~/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`
  (Chrome 151.0.7922.34 + headless shell 151.0.7922.34).
- Not established: any actual browser-relay send end to end (no real
  message sending happened in this beat; the prototype is capabilities
  plan step 7). Firefox relay path (Route B) is design-only; no Firefox
  extension was built or tested.

## 1. What omp does (evidence-quoted)

omp has TWO browser routes, both built on CDP semantics:

**1a. Spawned browser — `puppeteer-core` 25.3.0.** From
`package.json` dependencies: `"puppeteer-core": "25.3.0"` (puppeteer-core
only — no bundled browser download; it drives a locally available
Chrome-family binary or a CDP endpoint). Supporting modules:
`src/tools/browser/launch.ts`, `attach.ts`, `registry.ts`,
`tab-supervisor.ts`, `tab-worker.ts` — a registry/supervisor/worker
machinery that speaks CDP to a connected browser.

**1b. Browser relay — a Chrome MV3 extension + local CDP relay.**
Files (all quoted/verified 2026-09-04):

- CLI: `src/commands/browser-relay.ts` — "`omp browser-relay` — drive
  the user's own Chrome tabs"; actions `serve | install`; flags
  `--port` (default 9224), `--token`, `--dir` (extension install dir,
  default `~/.omp/browser-relay/extension`).
- Relay kind: `src/tools/browser/relay/kind.ts` — the key architectural
  sentence: "The relay **impersonates Chrome's CDP discovery endpoint**,
  so beyond kind resolution the entire connected-browser machinery
  (registry, tab supervisor, tab workers) applies unchanged." Default
  endpoint `DEFAULT_RELAY_URL = "http://127.0.0.1:9224"`. Opt-in via
  `browser.relay` setting or `PI_BROWSER_RELAY=0|1` env override.
- Server: `src/tools/browser/relay/server.ts` — binds localhost;
  `GET /json/version` → 200 with `webSocketDebuggerUrl` once the
  extension is connected (the CDP impersonation); `WS /ext` → the
  extension endpoint, **token-gated when configured** (`?token=`
  query-param check; unset disables the check).
- Wire protocol: `src/tools/browser/relay/protocol.ts` — "The extension
  dials out to `ws://127.0.0.1:<port>/ext`" — the extension is a
  WebSocket CLIENT (outbound only), the relay drives it with numbered
  RPCs: `attach | detach | send {tabId, sessionId?, method, params}` |
  `createTab | removeTab | activateTab | group | ungroup`; the extension
  pushes tab lifecycle and `chrome.debugger` events as they happen.
- Extension (on disk, `~/.omp/browser-relay/extension/manifest.json`):
  MV3, `"permissions": ["debugger", "tabs", "tabGroups", "storage",
  "alarms"]`, background service worker. `background.js`:
  connects out to the relay, ping every 20 s, exponential reconnect
  1 s→10 s cap, keepalive `chrome.alarms.create("omp-relay-keepalive",
  { periodInMinutes: 0.5 })`; the RPC handler maps `send` onto
  `chrome.debugger.sendCommand(...)` (CDP 1.3) against the operator's
  real tab — the agent drives the USER'S OWN LOGGED-IN TABS.

Design lesson for Hngh: an MV3 service worker CANNOT listen on a
localhost port — omp's extension therefore dials OUT to a relay the
agent side runs, and the agent side keeps speaking ordinary CDP because
the relay impersonates Chrome's discovery endpoint. Token in the query
string, loopback binding only. The agent-side machinery stays dumb
(puppeteer-core), all browser-native execution happens in the extension
via `chrome.debugger`, which is why the operator's real sessions and
passkeys work natively.

## 2. Route A — Playwright persistent profile (isolated)

Status after this beat's install: the 2026-09-03 research doc's ADMIT
gate is now SATISFIED. Arch/CachyOS notes (operator directive: extra
research on Arch):

- The host python is Homebrew's (Python 3.14.7, pip 26.2.1; Homebrew's
  prefix lives outside the user home, `python3` resolves to its 3.14
  opt build) and is **PEP 668 externally-managed** — `pip install
  --user playwright` refuses with the externally-managed-environment
  error. Arch-native system python would behave the same.
- Taken path (works, documented exactly): venv at
  `~/.hngh-automation/venvs/playwright` created with
  `python3 -m venv`, then `pip install playwright` (1.62.0) inside it.
  Activation seam: the slice code must invoke
  `~/.hngh-automation/venvs/playwright/bin/python` directly (no source-activate
  needed for a script entrypoint) — simplest durable seam.
- Browser: `python -m playwright install chromium` downloaded
  self-contained builds to `~/.cache/ms-playwright/` — chromium-1234
  (Chrome 151.0.7922.34) + chromium_headless_shell-1234 + ffmpeg-1011,
  ~115 MiB, no pacman, no sudo, no system chromium
  (`pacman -Q chromium` → not installed, exit 1). Playwright noted
  "your OS is not officially supported; downloading fallback build for
  ubuntu24.04-x64" — on Arch the bundled-build path is exactly right:
  the build is self-contained and the smoke test passed anyway.
- Smoke proof (this beat, data: URL only, no real service touched):
  headless launch → `page title: hngh-smoke | h1: ok`. The generic
  build runs on CachyOS.
- What the prototype (capabilities plan step 7) needs: Google Messages
  web in a persistent context with an ISOLATED profile dir
  (`user_data_dir`), 700 mode, never backed up/copied; the ONE human
  step is the QR pairing (if messages web demands it — park with the
  pairing step quoted); one message to the operator, no retries against
  a refusing service.

## 3. Route B — browser extension relay ("hngh relay", operator-authorized)

Design sketch for Chrome MV3 + Firefox WebExtension, directly
informed by omp's relay (§1) — corrected where omp's evidence beats the
original brief:

- **Topology (omp-derived):** the extension CANNOT host a localhost
  server (MV3 service workers can't listen) — so it is a WebSocket
  CLIENT that dials out to `ws://127.0.0.1:<port>/ext` on a relay Hngh
  runs (loopback-bound, token-gated via `?token=`, 20 s pings,
  1–10 s reconnect backoff, alarm keepalive — all omp-proven values).
  Hngh POSTs a send request to a tiny local API on its relay; the relay
  issues the RPC to the extension.
- **Execution model:** the send is performed in page context of the
  operator's existing logged-in session. Two sub-options: (a) like omp,
  `chrome.debugger` CDP into the real tab (works today in Chrome, but
  shows the "controlled by debugging" infobar and needs the `debugger`
  permission); (b) content-script DOM automation in the target tab
  (no `debugger` permission, quieter, but DOM-fragile). Start with
  (a) reusing omp's proven RPC surface; add (b) per channel only where
  (a) is refused.
- **Firefox:** no `chrome.debugger` equivalent (BellSchedules aside,
  Firefox has no debugger permission for extensions); the Firefox
  variant must use content-script DOM automation + native messaging or
  an outbound WebSocket from a background page. Firefox background
  pages are event-persistent (no MV3 service-worker churn), so the
  keepalive problem is smaller; the WebSocket-client topology is
  identical. Unproven — design-only.
- **Permissions minimality:** `tabs`, `storage`, `alarms` (+`debugger`
  only for sub-option (a)); host permissions limited to the exact
  channel origins (e.g. `https://messages.google.com/*`), added per
  channel as each channel is gated separately. Never
  `<all_urls>`, never cookies permission, no remote code, no
  webRequest. It never touches or exfiltrates cookies/storage — it
  only drives UI events in tabs the operator already uses.
- **Shipping:** out-of-repo, store-free, developer-mode load (chrome://
  extensions → load unpacked; Firefox: temporary add-on or
  DeveloperEdition persistent load). Source version-controlled in
  hngh-automation (e.g. `extensions/hngh-relay/`), never in the kernel
  repo.
- **Honest risks:** MV3 service-worker lifetime churn (omp mitigates
  with 0.5-min alarm keepalive + reconnect; WS resets on worker wake);
  Firefox background differences above; DOM fragility of web UIs
  (selectors rot; each channel gated separately and never retried
  against a refusing service); ToS surface per service — automation of
  a personal web session may violate a given service's terms, so each
  channel gets its own admit/park verdict, Google Messages web first
  as the known shape.
- **Credentials posture:** inherits credentials-posture.md §4 in full —
  the extension runs inside the operator's real profile, so session
  credentials are never copied, logged, or moved; the relay logs redact
  to op names and tab ids; profile contents are never read by Hngh.

## 4. Parallel-route verdict + recommendation

- **Route A (playwright persistent profile): ADMIT** — the gate
  (playwright importable + chromium build available) now passes; the
  re-probe line is recorded under capabilities plan step 6. First
  proof: one message via Google Messages web, isolated profile.
- **Route B (extension relay): the durable endgame** — the operator's
  active logins and passkey-friendly flows work natively (extension
  runs in the real profile; zero profile duplication, zero session
  re-login), and it is multi-channel (any tab). More moving parts, so
  it is NOT the first proof.
- **Sequence: A proves the pipeline, B industrializes it.** They are
  deliberately parallel code paths sharing one contract (a
  `send(channel, recipient, body)` request shape at the Hngh side);
  Route A's request plumbing should be written so Route B can swap the
  transport underneath it.
- Both routes inherit credentials-posture.md §4; both stay out of the
  kernel repo's code (Route A slice lives in hngh-automation, Route B
  extension source in hngh-automation).

## 5. Sources + not established

Sources (read 2026-09-04):
- omp source: `src/commands/browser-relay.ts`,
  `src/cli/browser-relay-cli.ts`, `src/tools/browser/relay/kind.ts`,
  `server.ts`, `protocol.ts` in
  `~/node_modules/@oh-my-pi/pi-coding-agent` (v18.0.9); extension
  `manifest.json` + `background.js` at `~/.omp/browser-relay/extension/`.
- Playwright install + smoke (this beat); probe battery re-run
  (recorded under capabilities plan step 6).
- docs/research/2026-09-03-browser-messaging-automation.md;
  docs/project/plans/2026-09-03-capabilities.plan.md steps 6/7;
  docs/design/credentials-posture.md §4.

Not established (honest bounds): no real message send was attempted;
Route B has no running code; Firefox behavior claims are design-level
(Firefox lacks a `debugger`-permission equivalent — asserted from
extension-platform knowledge, not tested here); omp's relay was read
from source but not exercised end to end in this beat.