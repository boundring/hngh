# Milestone M2: Local OpenAI-Compatible Endpoints

## Context
Currently, `src/plugins/ai-tool-hub.lisp` hardcodes `https://api.openai.com/v1/chat/completions` and forces a Secrets Manager lookup for all keys. We need to support the local unsloth server (`http://127.0.0.1:8888/v1`) to stay within the <$1/day remote policy.

## Design Decisions
1. **Provider Mapping**: Move away from hardcoded `ecase` blocks for URLs/Headers. Use a configuration map.
2. **Local Provider**: Introduce `:local-openai-api`. It will bypass the secrets manager and use a static dummy key.
3. **Cost Awareness**: Explicitly set `provider-rate` for local providers to 0.0.

## Patch Proposal

### 1. Registry Update
Update `make-default-tool-registry` in `src/plugins/ai-tool-hub.lisp`:
- Add `:local-openai-api` to the tool registry.
- Update `:openai-api` to include `:local-openai-api` in its capabilities/providers list to allow the orchestrator to select it during privacy-sensitive tasks.

### 2. Endpoint Resolution
Refactor `api-endpoint` and `provider-api-headers`:
```lisp
;; Proposed Refactor
(defun api-endpoint (tool-id)
  (case tool-id
    (:anthropic-api "https://api.anthropic.com/v1/messages")
    (:google-api "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
    (:openai-api "https://api.openai.com/v1/chat/completions")
    (:local-openai-api "http://127.0.0.1:8888/v1/chat/completions")
    (t (error "Unknown tool ID: ~A" tool-id))))
```

### 3. Secrets Manager Bypass
Modify `get-api-key` to return a placeholder for local calls:
```lisp
(defun get-api-key (tool-id)
  (cond ((eq tool-id :local-openai-api) "local-dummy-key")
        (t (handler-case ... ; existing secrets manager logic ...))))
```

### 4. Cost Tracking
Update `provider-rate`:
```lisp
(defun provider-rate (tool-id)
  (case tool-id
    (:anthropic-api 0.003)
    (:openai-api 0.002)
    (:google-api 0.00125)
    (:local-openai-api 0.0)
    (t 0.0)))
```

## Verification Plan
1. **Init Check**: Run `hngh init` and verify `list-tools` includes `local-openai-api`.
2. **Cost Check**: Run a dummy task via `local-openai-api`, then check `cost-log` to ensure `:cost-usd` is `0.0`.
3. **Connectivity**: Verify `execute-direct-api` successfully calls the local unsloth endpoint.
