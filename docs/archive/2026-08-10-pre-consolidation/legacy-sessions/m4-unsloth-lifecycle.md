# Wave: M4 — unsloth lifecycle in model-runtime (shared-server management)

> Convention: self-contained working context for one wave. Grounded in full read of `src/plugins/model-runtime.lisp` (619 lines) on 2026-07-31.

## Context

M0 gave unsloth a systemd lifecycle (`unsloth-studio.service` + `unsloth-warm.service`, :8888). hngh's model-runtime currently stubs unsloth as "manual setup" (`spawn-python-runtime`, L243-256). M4 makes hngh manage unsloth **the ollama way**: shared external server — health-check, model-level state via API, never spawn/kill the process (systemd owns it; spawn/kill would collide on :8888). Eviction discipline honors the one-big-model-resident constraint: no surprise warm/switch calls.

## Current state (exact)

- `runtime-info` struct L13-22 (id/kind/model/pid/port/status/grant-id/started-at).
- `health-check` L100 hits `/api/version` — **ollama-only**; unsloth needs OpenAI-style probes (`/v1/models`).
- `spawn-python-runtime` L243-256: warns "manual setup", marks `:ready` — the stub being replaced.
- `spawn-runtime` L258-315: `ecase kind` — `((:unsloth :comfyui) (spawn-python-runtime ...))` L291-292.
- `stop-runtime` L319-413: ollama branch = API unload (shared server kept); `((:unsloth :comfyui)` L380-389 = kill pid.
- `discover-runtimes` L424-460: `:unsloth python-available` — wrong signal; should reflect the server.
- Existing tests only assert `:unsloth`/`:comfyui` keys in discovery (test-model-runtime.lisp L78-79) — no stub behavior to preserve.
- Unsloth server: OpenAI-compatible `:8888`, `/v1/models` lists ids + `loaded` flags + `context_length`; auth required (401 without key); load-on-call semantics (chat completion with an unloaded model triggers load — user-verified); key: `UNSLOTH_API_KEY` env, fallback by-name read of `~/.hermes/.env` (pattern proven in svc-dash `unsloth_panel`).

## Target state (changes in model-runtime.lisp only)

1. **API helpers** (after `health-check-model`, ~L133):
   - `unsloth-api-key ()` → `(or (uiop:getenv "UNSLOTH_API_KEY") (%read-hermes-env-key "UNSLOTH_API_KEY"))`; `%read-hermes-env-key` greps `~/.hermes/.env` by var NAME (never echoes).
   - `unsloth-request (path &key (method :get) data (max-time 30))` → curl `127.0.0.1:8888` with `Authorization: Bearer`, returns `(values body exit-code)`.
   - `unsloth-health-p ()` → GET `/v1/models`, exit 0 and body contains `"object"`.
   - `unsloth-models ()` → list of `(id . loaded-p)` parsed WITHOUT a json lib: split body on `{`, per chunk extract `"id":"` … `"` and whether `"loaded":true` follows.
   - `unsloth-model-loaded-p (model)` → member check.
   - `unsloth-warm-model (model &key (max-time 900))` → POST `/v1/chat/completions` `{model, messages:[warm], max_tokens:1}`; T on exit 0. (Triggers load; may take minutes for cold models.)
   - `unsloth-ensure-server ()` → if health fails and `systemctl --user is-active unsloth-studio.service` is not active: `systemctl --user start unsloth-studio.service`, poll health 60×1s. T/NIL.
2. **`spawn-unsloth-runtime (info model-spec port)`** (new, replaces stub for `:unsloth` only): port default 8888; `(unless (unsloth-ensure-server) (error "unsloth server unreachable and unstartable"))`; set `pid nil`, `port 8888`, `status :ready`; if model-spec has `:warm t` and `:name`, call `unsloth-warm-model` (log result; status stays `:ready` either way). `:comfyui` keeps the old stub — split it out of `spawn-python-runtime` (rename to `spawn-comfyui-runtime` or keep name for comfyui only).
3. **`spawn-runtime` ecase (L286-292)**: `(:unsloth (spawn-unsloth-runtime ...))`, `(:comfyui (spawn-python-runtime ...))`.
4. **`stop-runtime` (L380-389)**: split — `:unsloth` = no kill, log "shared systemd server left running", status `:stopped`; `:comfyui` = existing kill-pid branch.
5. **`discover-runtimes` (L454-459)**: `:unsloth (unsloth-health-p)` (fast 3s probe); `:comfyui` unchanged.

## Tasks

1. Implement 1–5 in model-runtime.lisp.
2. Append tests to `tests/unit/test-model-runtime.lisp` (no .asd change): key-from-env; spawn with stubbed `unsloth-ensure-server`/`unsloth-request` ⇒ `:ready`, port 8888, pid nil; stop `:unsloth` does NOT invoke kill (stub `run-command`, assert no `kill` program call); discover `:unsloth` reflects stubbed health. Use the file's symbol-function stub pattern (L222-251) and `with-mr` fixture (L46).
3. `make test` green.
4. Live verify (sbcl non-interactive): init event-bus/state-store/resource-manager/model-runtime; `discover-runtimes` ⇒ `:unsloth t`; `(spawn-runtime :unsloth '(:name "unsloth/gemma-4-12b-it-qat-GGUF"))` ⇒ `:ready`, port 8888; `(stop-runtime id)` ⇒ stopped; server still healthy after (curl :8888).
5. Record in `docs/project/work-sessions.md` + OptMem.

## Verification (wave is complete when)

`make test` green incl. new tests; live spawn/stop cycle against the real systemd-managed server succeeds without touching the process; discovery reports `:unsloth t`.

## Anti-patterns

- **Never spawn/kill the unsloth process** — systemd owns it (M0). hngh manages at the API level only.
- **No warm-by-default** — warming evicts the resident 12b on a 20GB card; warm only on explicit `:warm t`.
- **No JSON dependency** — parse `/v1/models` by string surgery like the codebase already does elsewhere.
- **Don't call unknown unsloth endpoints** (evict/unload APIs are unverified) — model switching is load-on-call only.
- **Don't break `:comfyui`** — it keeps the manual-setup stub untouched.
