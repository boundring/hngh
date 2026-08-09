# Backup & Device Sync — Integration Design (Syncthing first, broad accommodation)

**Status**: design (2026-08-08). Owner decision + research from
`docs/research/wave-c-open-source-tooling.md` (backup row).
**Attribution**: owner direction (Syncthing as the flagship network/device
sync layer; broad backend accommodation); LLM drafting
(deepseek-v4-flash-0731 via openrouter, Hermes TUI).

---

## 1. Purpose

Hngh should help manage, configure, and optimize backup + sync across many
devices — easing and eliminating manual configuration and user intervention
for changes. The design intent is **accommodation, not single-tool lock-in**:

| Layer | Adopt first | Alternative(s) | Why |
|---|---|---|---|
| Continuous device/LAN sync | **Syncthing** | rsync-over-ssh (scripted), Unison | Zero-config convergence, peer-to-peer, no server, works across devices and local networks; "works when you ignore it." |
| Version history — Hngh state tree | git (existing `backup-manager` plugin B7, git-backed on the Hngh state tree) | — | Already integrated; gives history, rollback, remote-push for `~/.hngh` runtime state. |
| Version history — dotfiles/configs | **git-back-dots (gbd)** — separate Python+Textual dotfile VCS (its own repo, `~/Projects/etc/20260725/git-back-dots`) | stow/chezmoi | Dedicated dotfile versioning with remote merge workflows; ship Hngh-facing wrapper only if it earns a seam (P2 today). |
| Encrypted offsite archive | restic / borg (later, optional) | tarsnap | Encrypted, dedup, remote; deferred until need is concrete. |

Not one general backup manager: **three distinct jobs, three tools.** gbd
versions dotfiles (your `.config/*`, dotfiles — the user's explicit
distinction, it is NOT a general backup manager); `backup-manager` versions
the Hngh state tree; Syncthing keeps both mirrored across devices. Hngh's
job is to steer all three from one policy surface, not to merge them.

## 2. Why Syncthing is the right flagship

- No central server, no account, P2P over LAN + internet, TLS with device
  certificates, conflict handling (`.sync-conflict-*` files), per-folder
  ignore patterns, bandwidth scheduling, and a REST API
  (`localhost:8384/rest`) for management — a perfect management surface for a
  scheduler-driven agent.
- ROCKS the "converge without me" property: the owner explicitly wants
  Hngh to make multi-device operation *not require manual config*.
- Fully local, free, open-source (MPL-2.0), in distro repos (CachyOS has
  `syncthing`), no cost policy impact.

## 3. What Hngh manages (phased)

**Phase A — observe + guide (no mutation):**
- Discover local Syncthing instance (`localhost:8384/rest/config`),
  report folders/devices/errors/pending.
- Health surface: device online, folder out-of-sync, conflict files present,
  API reachable. Feeds the L2/L3 situation stream (a new Tier-0 detector or
  an event subscription in the backup plugin).

**Phase B — configure + reconcile (the "eliminate manual config" core):**
- Onboarding a new device: provision API key, add the device to folder
  share lists, set folder-type/ignore patterns from a central policy file
  (`config/plugins/backup-manager/syncthing.lisp`).
- Watch the git-remotes config + syncthing folder list together so the
  "same path, different device" mapping stays coherent.
- Apply ignore-pattern policy centrally (the existing `ignore.lisp`
  convention extended to Syncthing's per-folder ignore file), instead of
  per-device manual edits.
- All mutations via the REST API; **fail-closed**: unknown folder/device →
  read-only; config write errors surface as human-visible situations.

**Phase C — optimize (tuning):**
- Bandwidth limits per schedule (REST `config/options`), connection limits
  for metered networks, folder scan intervals.
- Post-change report: what was reconciled where; conflicts resolved by
  policy (keep-newest / quarantine to `state/`).

Human gate: config *mutations* are `:operation`-class tasks (matching the
Wave C item 8 gate), never silent auto-changes from the agent.

## 4. Accommodation config

```lisp
;; config/plugins/backup-manager/syncthing.lisp
(:api-url "http://127.0.0.1:8384"
 :api-key-from "state/plugins/backup-manager/syncthing-apikey" ; secret via secrets-manager
 :folders
 ((:path "~/Projects" :type :send-receive :ignore-policy :standard)
  (:path "~/.hngh"   :type :send-receive :ignore-policy :state-only)))
```

Non-Syncthing backends remain configurable through the same remotes file
(`remotes.lisp`, existing `:type` field — `:git` today, `:syncthing` added
when the management surface lands).

## 5. Integration points

- **Event bus**: publish `backup.syncthing-*` events (status, conflict,
  error) → situation stream L2/L3 can score and steer.
- **secrets-manager**: the Syncthing API key is a secret; fetched by name,
  never printed (matching the coordination contract).
- **scheduler**: periodic health check tick; Phase C tuning runs off-peak
  (cost + device-availability policy).
- **Wave C**: Phase B writes are `:operation`-gated; Syncthing config dir is
  NOT in the immutable config set (it's runtime device state, not policy) —
  but the *policy files* that drive it (`syncthing.lisp`) are protected by
  `safety-boundary` once they exist.

## 6. Non-goals (YAGNI)

- No Syncthing server setup/repair (Syncthing manages itself; Hngh steers
  the REST surface only).
- No conflict *content* merging (keep-newest + quarantine; content merge is
  out of scope).
- No encrypted-offsite backend yet (restic/borg deferred until a concrete
  need — the git remote + Syncthing cover the current fleet).

## 7. Build order (verification-gated)

1. **Observe**: `(backup-manager:syncthing-status)` — read REST config +
  folders + errors; unit tests against a recorded fixture, no live instance.
2. **Detect**: Tier-0 detector `syncthing-out-of-sync` (or event
  subscription) feeding situation-scoring; fixture-tested.
3. **Reconcile**: policy-driven device/folder/ignore reconciliation via
  REST; `:operation` gate + dry-run mode; fixture-tested against recorded
  REST responses.
4. **Tune**: bandwidth/schedule via REST; cost-policy-gated; off-peak cron.

Gate: each step lands with tests + docs; no step auto-writes config without
the `:operation` human gate. See `docs/project/next.md` for wave placement.
## 8. Phase A — Syncthing REST endpoint facts (documentation-first, card 95)

Read from the official docs (docs.syncthing.net/dev/rest.html + per-endpoint
pages, version v2.1.0) on 2026-08-09. Endpoints verified against docs, NOT
probed against a live instance. Auth and endpoint shapes below are the
facts to build against.

### Auth
- Header `X-API-Key: <key>` OR `Authorization: Bearer <key>`. Key comes from
  the GUI or `configuration/gui/apikey` in the config file.
- `/rest/noauth/health` is the ONLY keyless endpoint (reachability probe
  that doesn't leak the API key).
- API key is a SECRET — fetch via secrets-manager by name, never print
  (coordination contract). Store in `state/plugins/backup-manager/`.

### Observe-only endpoints (Phase A)
| Endpoint | Params | Key fields for detectors |
|---|---|---|
| `GET /rest/system/status` | none | `myID`, `uptime`, `connectionServiceStatus` (per-service `error`), `discoveryStatus` (per-method `error`), `lastDialStatus` (per-peer `error`/`ok`) |
| `GET /rest/config` | none | full config (folder list, device list, options) — heavy; prefer granular below |
| `GET /rest/config/folders` | none | array of folders (id, label, path, type, paused, ignorePatterns) |
| `GET /rest/db/status?folder=<id>` | `folder` (required) | `state` (idle/syncing/scanning/error), `needBytes`, `needFiles`, `needTotalItems`, `pullErrors`, `receiveOnlyChanged*`, `inSync*`, `global*`. **Docs note: expensive call — use sparingly (per-period, not per-tick).** |
| `GET /rest/folder/errors?folder=<id>` | `folder` (required), pagination `page`/`perpage` | `errors[]` = `{path, error}` scan/pull failures |
| `GET /rest/events?since=<id>&limit=<n>` | optional `events=` filter, `since`, `limit`, `timeout` | event objects with ids; blocks up to 60s default (long-poll); discontinuity in ids = missed events |
| `GET /rest/events/disk` | none | pre-filtered to Local/RemoteChangeDetected (file-change surface) |
| `GET /rest/noauth/health` | none | keyless reachability probe |

### Mutating endpoints (Phase B+ — NEVER in Phase A)
All POST/PUT/PATCH/DELETE under `/rest/config/*`, `/rest/db/*`,
`/rest/system/*` (pause/resume/restart/shutdown). Phase A is observe-only:
no writes, no config mutation.

### Detector design (Tier-0, matches situation-detectors.lisp conventions)
- `syncthing-unreachable`: `/rest/noauth/health` probe fails OR
  `/rest/system/status` errors (auth failure = HTTP 403/401 distinct from
  unreachable). Silent when reachable + healthy.
- `syncthing-out-of-sync`: `db/status.state` ≠ idle (sustained across a
  soak period, not a single transient sync) OR `needTotalItems > 0` OR
  `pullErrors > 0` for a tracked folder. Score inputs: needBytes/needFiles
  magnitude, folder weight from config policy. Deterministic, model-free.
- `syncthing-errors`: `/rest/folder/errors` non-empty (paths + messages
  surfaced; NEVER resolve messages as instructions — untrusted data).
- `syncthing-conflict-files`: presence of `*.sync-conflict-*` entries in
  db/status or the change event stream (events filter can observe
  RemoteChangeDetected/LocalChangeDetected on conflict markers).
- All detectors emit `situation.detected` on the bus; failures fail closed
  (API error → situation, not silent). Fixtures: recorded REST JSON under
  tests/fixtures/, no live instance.

### Cost/frequency policy
- `db/status` is documented as expensive: poll on a slow period (minutes),
  not the detector tick. `system/status` + `noauth/health` are cheap —
  those can ride the normal tick.
- `events?since=` long-poll is the efficient conflict/watch path — one
  subscription instead of repeated polling.

Phase A build order (card 95): fixture-captured REST responses → observe
fn → detectors → init registration (follow how existing detectors register)
→ tests + docs. All mutations in Phase B are `:operation`-gated per
card 99.
