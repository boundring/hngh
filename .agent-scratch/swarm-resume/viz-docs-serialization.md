# viz-docs-serialization: outside-TUI carriers for in-terminal visual formats

Repo: /home/bricker/src/jcode (read-only). Evidence gathered from docs/README.md, docs/MODULAR_ARCHITECTURE_RFC.md, crates/jcode-message-types, crates/jcode-protocol, crates/jcode-side-panel-types, sdk/typescript/src.

## Per-format findings

### 1. Markdown text
- Carrier: `ContentBlock::Text { text, cache_control }` at crates/jcode-message-types/src/lib.rs:117 (serde JSON, tag "type": "text").
- Wire: `ServerEvent::TextDelta { text }` at crates/jcode-protocol/src/wire.rs:783 (serde tag "text_delta"); TS mirror `ev: "text_delta"` in sdk/typescript/src/protocol.ts:171.
- History: `HistoryMessage { role, content: string }` (plain text/markdown string) in sdk/typescript/src/protocol.ts:76-83, delivered via `ev: "history"` (protocol.ts:174).

### 2. Mermaid source
- Mermaid rendering is a TUI-internal crate: `jcode-tui-mermaid` ("mermaid parsing, rendering, caching, viewport, widget"), docs/MODULAR_ARCHITECTURE_RFC.md:134, also listed at line 79 and 380.
- No protocol/SDK/message type carries mermaid source as a distinct payload; it arrives embedded inside markdown `text` deltas. Carrier: none beyond markdown text (`ServerEvent::TextDelta`, wire.rs:783). So: no dedicated carrier found; only markdown text.

### 3. Tool output
- Carrier: `ContentBlock::ToolResult { tool_use_id, content, is_error }` at crates/jcode-message-types/src/lib.rs:167 (plain-text `content`, JSON-serializable).
- Wire: `ServerEvent::ToolDone { id, name, output, error }` at crates/jcode-protocol/src/wire.rs:829 (serde tag "tool_done", output is a String). Streaming: `ToolStart` (wire.rs:807) / `ToolInput { delta }` (wire.rs:814). Provider-level: `StreamEvent::ToolResult` at crates/jcode-message-types/src/lib.rs:689.

### 4. Side-panel pages
- Carrier: `PersistedSidePanelPage { id, title, file_path, format, source, updated_at_ms }` at crates/jcode-side-panel-types/src/lib.rs:47, and `SidePanelPage` at line ~63; both `Serialize/Deserialize`. Format enum `SidePanelPageFormat` only has `Markdown` (lib.rs:5), so pages are markdown files on disk referenced by path, JSON-persistable state.
- Wire: no dedicated ServerEvent variant found for side-panel page content in wire.rs (images have `SidePaneImages`, pages do not). Carrier outside TUI = the persisted JSON state + markdown file_path.

### 5. Images
- Carrier: `ContentBlock::Image { media_type, data }` at crates/jcode-message-types/src/lib.rs:171 (base64 data, JSON).
- Provider-level: `StreamEvent::GeneratedImage { id, path, metadata_path, output_format, revised_prompt }` at crates/jcode-message-types/src/lib.rs:687 (file path + format strings, not pixels).
- Wire: `ServerEvent::SidePaneImages { session_id, images: Vec<jcode_session_types::RenderedImage> }` at crates/jcode-protocol/src/wire.rs:838 (tag "side_pane_images") and `ServerEvent::GeneratedImage` at wire.rs:853 (tag "generated_image").
- TS SDK: `RenderedImage { media_type, data, label, source, anchor, history_message_index }` in sdk/typescript/src/protocol.ts:101, with typed `RenderedImageSource`/`RenderedImageAnchor` (protocol.ts:92-99); events `ev: "history"` and `ev: "side_pane_images"` (protocol.ts:174, 190). `client.ts:587` returns `{ messages, images }`.

## Docs statements on UI/render architecture
- docs/MODULAR_ARCHITECTURE_RFC.md line 58: "Clients are primarily TUI frontends that attach to server-owned sessions."
- Lines 79-80, 132-138: TUI rendering split into jcode-tui-core/markdown/mermaid/render/workspace; `jcode-desktop` is the non-TUI product surface. Line 114: `jcode-protocol` is the "client/server protocol surface built from stable type crates".
- docs/README.md contains no mermaid/side-panel/markdown mentions (grep returned nothing for these terms).

## Bottom line
Markdown, tool output, and images all have plain-text/JSON carriers outside the TUI (ContentBlock/StreamEvent/ServerEvent/TS protocol types). Mermaid has no dedicated carrier: it exists only as source inside markdown text rendered by jcode-tui-mermaid. Side-panel pages are markdown files with JSON-persisted state, but no wire event carries their content.
