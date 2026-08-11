# Wave: M2 — local OpenAI-compatible endpoints for AI Tool Hub

> Convention: self-contained working context for one wave (see gbd JOURNAL.md "Session Files for Local LLM Agents"). One agent, one wave. Supersedes the earlier sketch `sessions/m2-local-baseurl-draft.md` (hermes, local 12b — directionally right, lacked file grounding; its section numbering informed this file).

## Context

hngh's AI Tool Hub can only call *remote* paid APIs: `src/plugins/ai-tool-hub.lisp` hardcodes endpoint URLs and routes all keys through the secrets manager. The machine runs a local OpenAI-compatible unsloth server at `http://127.0.0.1:8888/v1` (models `unsloth/gemma-4-12b-it-qat-GGUF` — daily driver, 219904 ctx, warm-pinned at boot by `unsloth-warm.service`; Qwythos-9B 1M variants on demand). Budget policy: remote API < $1/day, so hngh loops must be able to run fully local at $0.

## Current state (exact, verified 2026-07-31)

`src/plugins/ai-tool-hub.lisp` (817 lines):
- L32 `defstruct tool-info` — slots incl. `:id :name :type :command :available-p :capabilities :providers :cost-model :context-format :dogfooding`
- L107 `make-default-tool-registry` — direct-API entries at L178-219 (`:type :direct-api`, `:command "curl"`, `:available-p (and (which "curl") (api-key-available-p :…))`, `:cost-model :per-token`)
- L222 `api-key-available-p` · L328 `estimate-cost` (`:free` cost-model ⇒ 0.0) · L349 `provider-rate` (case, t⇒0.0 — local already covered)
- L358 `select-tool` — privacy filter keeps tools with `:local` in `:providers`; prefers agentic CLI
- L494 `execute-tool` — dispatch on type (CONFIRM: `:direct-api` ⇒ `execute-direct-api`)
- L547 `execute-direct-api` — curl `-sS --fail-with-body --connect-timeout 10 --max-time 120`; key→endpoint→model→payload→headers
- L604 `api-endpoint` — case, three hardcoded URLs (the target)
- L611 `provider-api-headers` — (CONFIRM shape; near-certain ecase needing a local branch mirroring `:openai-api`)
- L644 `default-model` — **ecase** (errors on unknown id) · L651 `format-json-payload` — **ecase** · L691 `get-api-key` — **ecase** on secret-name, then secrets-manager lookup
- Cost ledger exists: L763 `log-cost-entry`, `*cost-log*` L81; orchestrator calls `SELECT-TOOL`→`INVOKE` via find-symbol (ai-orchestrator.lisp L342-445) — **no orchestrator changes needed**
- Unsloth auth: `/v1/models` returns 401 without a key; `UNSLOTH_API_KEY` is exported in `~/.hermes/.env` (any non-empty bearer may or may not pass — use the real key from env when available)

## Target state (exact changes)

1. **New helper** (after `which`, ~L30; dependency note: `(ignore-errors (require :sb-bsd-sockets))` at file top):
```lisp
(defun local-endpoint-available-p (host port)
  "T when a TCP connection to HOST:PORT succeeds within ~2s. NIL on any error."
  (handler-case
      (let ((addr (sb-bsd-sockets:host-ent-address
                   (sb-bsd-sockets:get-host-by-name host))))
        (sb-bsd-sockets:with-timeout 2
          (sb-bsd-sockets:socket-close
           (sb-bsd-sockets:socket-connect
            (make-instance 'sb-bsd-sockets:inet-socket :type :stream :protocol :tcp)
            addr port)))
        t)
    (error () nil)))
```
2. **Registry entry** (after the `:openai-api` block, L219, before `nreverse`):
```lisp
    ;; Local OpenAI-compatible (unsloth :8888) — direct API, $0
    (push (make-tool-info
           :id :local-openai-api
           :name "Local OpenAI-Compatible (unsloth)"
           :type :direct-api
           :command "curl"
           :available-p (and (which "curl")
                             (local-endpoint-available-p "127.0.0.1" 8888))
           :capabilities '(:simple-output)
           :providers '(:local :openai-compatible)
           :cost-model :free
           :context-format :https-system-message
           :dogfooding t)
          tools)
```
3. **`api-endpoint` (L604-609) → data-driven** (backward compatible, anti-hardcode):
```lisp
(defparameter *provider-endpoints*
  '((:anthropic-api . "https://api.anthropic.com/v1/messages")
    (:google-api . "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
    (:openai-api . "https://api.openai.com/v1/chat/completions")
    (:local-openai-api . "http://127.0.0.1:8888/v1/chat/completions"))
  "Provider endpoint map. Rebind/extend via config instead of editing code.")
(defun api-endpoint (tool-id)
  "Return the API endpoint URL for TOOL-ID."
  (or (cdr (assoc tool-id *provider-endpoints*))
      (error "Unknown tool ID: ~A" tool-id)))
```
4. **ecase branches to add** (all three error without them):
   - `default-model` (L644): `(:local-openai-api "unsloth/gemma-4-12b-it-qat-GGUF")`
   - `format-json-payload` (L651): branch identical to `:openai-api`
   - `provider-api-headers` (L611): branch identical to `:openai-api` (Bearer + JSON content-type) — CONFIRM shape first
5. **`get-api-key` (L691) short-circuit before the ecase**:
```lisp
(when (eq tool-id :local-openai-api)
  (return-from get-api-key (or (uiop:getenv "UNSLOTH_API_KEY") "local-dummy-key")))
```

## Tasks

1. Read L494-511 (`execute-tool`) and L611-628 (`provider-api-headers`); confirm the two assumptions above; adjust if needed.
2. Apply changes 1–6 in order. Keep style consistent with the file.
3. `make build && make test` in `~/Projects/etc/hngh`.
4. Live verification in `make repl`:
   - `(hngh.plugins.ai-tool-hub:init)` then `(hngh.plugins.ai-tool-hub:list-tools)` — includes `:local-openai-api` as available (unsloth running)
   - `(hngh.plugins.ai-tool-hub:execute-direct-api :local-openai-api "Reply with exactly: ok")` ⇒ contains "ok"
   - `(hngh.plugins.ai-tool-hub:select-tool "hi" :prefer-tool :local-openai-api)` ⇒ `:local-openai-api`
   - `(hngh.plugins.ai-tool-hub:estimate-cost :local-openai-api "test")` ⇒ `0.0`
5. Record the session in `docs/project/work-sessions.md` per hngh convention; note completion in OptMem (`memo note "hngh: M2 applied+verified — ai-tool-hub reaches unsloth:8888"`).

## Verification (wave is complete when)

All task-4 checks pass AND `make test` stays green AND remote tools (`:openai-api` etc.) are byte-identical in behavior (endpoint map returns same URLs).

## Anti-patterns

- **No new hardcodes without the alist** — the point of change 3 is configurable endpoints.
- **Don't touch secrets-manager** or any remote provider's URL/model/headers/payload.
- **Don't forget an ecase branch** — missing any of the three = runtime error on first local invoke.
- **Don't change the curl flags** — they're provider-agnostic. Caveat only: `--max-time 120` can be short for a *cold* model load; M0's warm-pin makes this acceptable today. Configurable per-provider timeout is a later milestone.
- **Don't bypass `select-tool`'s ordering** — local tool must win through `:providers`/cost channels, not special-casing.
