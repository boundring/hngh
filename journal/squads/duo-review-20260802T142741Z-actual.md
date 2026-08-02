# Actual Squad Journal

- **Squad:** duo-review
- **Projected journal:** `duo-review-20260802T142741Z-projected.md`
- **Started:** 2026-08-02T14:27:41Z
- **Observed completion:** 2026-08-02T14:31Z
- **Launcher:** `~/.local/bin/squad`
- **Cost:** $0 remote spend; both members used local Gemma 4 12B

## Members

| Role | CLI | Model | Result |
|---|---|---|---|
| coordinator | opencode | `unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF` | Ready after manual wake retry |
| reviewer | hermes | `unsloth/gemma-4-12b-it-qat-GGUF` | Prompt injected and review completed |

## Preflight

- `unsloth-studio`: active.
- MCP health: warning; `mcp-list` is not installed, so declared MCPs were not probed.
- Model endpoint: warning; `:8888/v1/models` returned HTTP 401 without credentials, so endpoint reachability was verified but model identity was not.
- Remote quota: skipped correctly because every member model was local.
- Disk: passed with more than 500 GB available under `~/.hngh`.

## Deviations

The first launch injected the coordinator prompt before OpenCode's TUI input loop was ready. The pane stayed on its welcome screen. A concise manual wake was sent after the TUI settled; OpenCode then processed it and reached ready state. The launcher readiness check was hardened to wait for TUI markers and an additional settling delay before future injections.

Hermes accepted the full reviewer prompt on the first launch and completed a structured AGENTS.md review. Its final state was ready; no files were modified.

## Findings

- The declarative spec, local-model routing, preflight, tmux panes, prompt injection, and projected journal now work together for a two-member attended squad.
- The launcher still needs an explicit actual-journal/status path so completion and pane findings can be captured without manual transcription.
- MCP health remains an integration gap until a documented `mcp-list`-style probe exists.

## Next

1. Add `squad status` and append-only actual-journal events.
2. Add a `squad validate` command that parses specs without launching panes.
3. Keep remote members fail-closed when quota is unknown; do not substitute K3 or Copilot models automatically.
