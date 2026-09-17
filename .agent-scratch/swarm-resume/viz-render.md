# viz-render: jcode-tui-render + related render concerns

Repo: /home/bricker/src/jcode (READ-ONLY inspection, 2026-09-15)

## 1. ANSI color/styling model

- Crate `jcode-tui-render` (crates/jcode-tui-render/src/) is built on ratatui:
  `use ratatui::prelude::{Line, Span, Style}` at src/lib.rs:7.
- Core box helper: `render_rounded_box(title, content: Vec<Line<'static>>, max_width, border_style: Style)` at crates/jcode-tui-render/src/lib.rs:9-13.
- Styles are ratatui `Style`/`Span::styled` values, e.g. src/lib.rs:27,44,53; swarm_gallery.rs:177,349-357,721; memory_tiles.rs:201-230 (Color::Rgb values).
- Consumers: `jcode-tui` (crates/jcode-tui/Cargo.toml:79). Tool colors selected via `tool_color()`/`dim_color()` in crates/jcode-tui/src/tui/ui_messages.rs:337 etc.
- All styling is emitted as ratatui Line/Span at render (paint) time into terminal cells; ratatui writes ANSI escapes at draw. No ANSI strings are stored in session data.

Verdict: **terminal-only**. Style objects exist only in the paint path; session storage (jcode-message-types, jcode-session-types) carries no styling.

## 2. Tool-output blocks

- Underlying data: `ContentBlock::ToolResult { tool_use_id, content: String, is_error }` in crates/jcode-message-types/src/lib.rs:161-168 (serde-tagged `type: tool_result`). This is the message-content tool_result block, not a bespoke type.
- Display shape: `DisplayMessage { role, content: String, tool_calls: Vec<String>, tool_data: Option<ToolCall> }` at crates/jcode-tui-messages/src/message.rs:9-18; `ToolCall { id, name, input: serde_json::Value, ... }` at crates/jcode-message-types/src/lib.rs:2-13. Tool result content is flattened to a plain String before rendering (also see state_ui_messages.rs:72-76 where ContentBlock::ToolResult content is pushed as text).
- Boxing/styling happens only at render: `render_tool_message(msg, width, diff_mode)` at crates/jcode-tui/src/tui/ui_messages.rs:3843, which builds special cards (todo card, memory card) and otherwise emits boxed lines via `render_rounded_box` (crates/jcode-tui-render/src/lib.rs:9). Timestamp/timing headers stripped at ui_messages.rs:1074 (`strip_tool_result_timestamp_header`).
- So the stored form is a plain string + ToolCall metadata; the box/card presentation is fully derived at paint time.

Verdict: **terminal-only** presentation over a **native-passthrough** data shape (the JSON `tool_result` content block survives as-is; only display flattening to String happens in the TUI).

## 3. Image protocol

- Protocol layer: crate `jcode-terminal-image`, `pub enum ImageProtocol { Kitty, ITerm2, Sixel, None }` at crates/jcode-terminal-image/src/display.rs:24-34; `detect()` at display.rs:37 (KITTY_WINDOW_ID, TERM_PROGRAM=WezTerm/iTerm.app, sixel detection); `display_image(path, ImageDisplayParams)` at display.rs:196. Config gating is terminal-environment detection, not user config.
- Inline transcript renderer: crates/jcode-tui/src/tui/ui_inline_image.rs — lazy decode/transmit at draw time, ingest-time base64 payload registry (lines 126-151), kitty virtual-placement constraints (line 89), text fallback (`uses_text_fallback`, line 34).
- Data shape: `RenderedImage { media_type, data: String (base64), label, source, anchor: Option<RenderedImageAnchor>, history_message_index }` at crates/jcode-session-types/src/lib.rs:126-148; anchors enum at lib.rs:116-123 (ToolCall{ id } / UserPrompt{ ordinal}). Derives Serialize+Deserialize. Duplicated in harness API events at crates/jcode-harness-api/src/events.rs:411.
- Because RenderedImage is serde-serialized with full base64 `data`, image payloads DO survive in session/JSON form (session restore renders them again, e.g. ui_inline_image.rs:1636 uses RenderedImageSource::ToolResult).

Verdict: protocol emission (kitty/iTerm2/sixel escape sequences) is **terminal-only** at paint time, but the image data itself is **native-passthrough**: base64 media is a first-class serialized session field (RenderedImage) and survives session JSON.

## Summary table

| Concern | Representation | Verdict |
|---|---|---|
| ANSI style model | ratatui Style/Span, paint-time only (jcode-tui-render/src/lib.rs:7,13) | terminal-only |
| Tool output blocks | ContentBlock::ToolResult (jcode-message-types/src/lib.rs:161) flattened to DisplayMessage string; boxed at ui_messages.rs:3843 | data native-passthrough; presentation terminal-only |
| Image protocol | ImageProtocol Kitty/ITerm2/Sixel (jcode-terminal-image/src/display.rs:24); RenderedImage base64 serialized (jcode-session-types/src/lib.rs:126) | escape emission terminal-only; data native-passthrough (survives session JSON) |
