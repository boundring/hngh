# viz-inventory-tui-formats: in-terminal visual output formats of jcode

Repo: ~/src/jcode (READ-ONLY, 2026-09-15). Extends viz-render.md,
viz-docs-serialization.md, viz-sidepanel.md in this directory; overlaps are
summarized, new evidence is marked per format.

## 1. Markdown subset (terminal rendering)

- Primary TUI path: `jcode-tui-markdown` (crates/jcode-tui-markdown/src/).
  Full renderer `render_markdown_with_width(text, max_width) -> Vec<Line<'static>>`
  at markdown_render_full.rs:20. Parser state machine covers: headings
  (levels 1-3 get distinct colors, 1-2 underlined, lines 110-129), GFM tables
  (in_table/table_rows/alignments, lines 63-68), fenced code blocks with
  language and syntax highlighting via `highlight_code`
  (markdown_render_full.rs:1), blockquotes with depth, ordered/unordered
  nested lists (`list_stack: Vec<ListRenderState>`, line 52), definition
  lists (line 57), thematic breaks, inline/JSON debug counters
  (dbg_headings/code_blocks/tables/list_items/blockquotes, lines 85-90).
  Incremental path: markdown_incremental.rs; lazy path: markdown_render_lazy.rs.
- Neutral semantic model (NEW, JSON-serializable): `jcode-render-core`
  (crates/jcode-render-core/src/model.rs) — all types derive
  Serialize+Deserialize: `BlockKind` (Paragraph | Heading{level} |
  CodeBlock{language} | BlockQuote | ListItem{ordered,depth} | Table |
  MathDisplay | ThematicBreak | Html) at model.rs:164; `Block` at model.rs:192
  (kind, lines, optional raw `latex`, raw `table: Vec<Vec<String>>` header
  first, `alignments: Vec<Alignment>`, `list_depth`); `Document{blocks}` at
  model.rs:265; `StyledSpan` (model.rs:68), `StyledLine` (model.rs:128),
  `StyleRole` (model.rs:16: Text/Dim/Strong/Code/Link/Html/Reasoning/Math),
  `FillRole` (model.rs:39), `TextAttrs` (model.rs:48).
- Verdict: paint-time ratatui lines are terminal-only, BUT the parsed
  document model (`Document`/`Block`/`BlockKind`) is a plain serde JSON form
  outside the TUI (this is the "render-core adapter" boundary,
  render_core_adapter.rs). Markdown SOURCE also always survives as
  `ContentBlock::Text` (see viz-docs-serialization §1).

## 2. Mermaid diagrams

- Crate `jcode-tui-mermaid` (crates/jcode-tui-mermaid/src/). Rendering is
  NATIVE in Rust, not external CLI: pipeline uses `mermaid_rs_renderer`
  (parse/layout: TextBlock/NodeLayout/EdgeLayout/SubgraphLayout at
  mermaid_cache_render.rs:522-541) then usvg/resvg/tiny-skia for SVG->PNG
  (usvg fontdb at lib.rs:576, resvg color at mermaid_svg.rs:262). PNG
  artifacts cached on disk under the mermaid cache dir
  (mermaid_cache_render.rs:59, cache filenames carry hash+width+profile,
  parse_cache_filename at :313).
- Diagram kinds (NEW evidence): flowchart and sequence are the supported
  themes — sequence styling tokens in `terminal_theme()` at
  mermaid_content.rs:589-595 (sequence_actor_fill #313244, actor_border
  #89b4fa, note, activation colors — Catppuccin-dark palette). Node/edge
  estimator at mermaid_svg.rs:10 caps MAX_NODES=100, MAX_EDGES=200
  (mermaid_cache_render.rs:768-770). No evidence of other diagram families.
- Data shapes (mermaid_model.rs): `DiagramId{source_hash,origin,ordinal}`
  :10; `DiagramOrigin` (Chat | SidePanel{page_id} | StreamingPreview |
  DebugProbe) :17; `DiagramBlock{id,source}` :25; `DiagramRenderProfile`
  (width_cells, aspect_per_mille, MermaidTheme::TerminalDark) :36;
  `DiagramCacheKey` :68; `RenderTarget` (InlineMarkdown | SidePanel |
  PinnedPane | DebugProbe) :89; `DiagramRenderRequest` :111;
  `RenderArtifact{cache_key,path,width,height}` :127;
  `RenderStatus` (Ready | Pending | Failed | ProtocolUnavailable) :135.
  Entry result: `RenderResult::Image{hash,path,width,height} | Error(String)`
  at mermaid_cache_render.rs:745. Detection: `is_mermaid_lang` at
  mermaid_cache_render.rs:753 (fenced ```mermaid blocks).
- Redesign ADR (docs/MERMAID_RENDERING_REDESIGN.md): plans pure
  `renderer::render_to_png(request) -> RenderArtifact`, a session-owned
  `DiagramRegistry` replacing globals, placeholder insertion by
  `RenderStatus` (lines 36-60, 96, 129, 156). Current lib.rs is still a
  global state hub (ADR line 12).
- Verdict: rendered output (PNG at paint time via kitty/iTerm2/sixel
  placeholders) is terminal-only. Diagram SOURCE survives only embedded in
  markdown text (no dedicated carrier; confirms viz-docs-serialization §2).
  Mermaid model types are plain Rust and could be serde'd but are not
  currently Serialize; RenderArtifact carries a file PathBuf, not pixels.

## 3. ANSI color / styling

- Confirmed from viz-render §1: ratatui `Style`/`Span` at paint time only
  (jcode-tui-render/src/lib.rs:7,9-13; tool colors in
  jcode-tui/src/tui/ui_messages.rs:337). NEW: jcode-render-core provides the
  serializable semantic alternative — `StyleRole`/`FillRole`/`TextAttrs`
  (model.rs:16-60, all serde) — i.e. ANSI styling has a JSON-able
  role-based form for non-TUI frontends, while concrete colors remain
  paint-time only.
- Verdict: terminal-only at the ANSI level; role-level styling is
  JSON-serializable (new finding).

## 4. Side-panel pages

- Confirmed from viz-sidepanel.md: `SidePanelPageFormat` (Markdown only,
  jcode-side-panel-types/src/lib.rs:5), `SidePanelPage` (lib.rs:58),
  `PersistedSidePanelState` (lib.rs:38), storage at
  ~/.jcode/side_panel/<session_id>/index.json + markdown files, wire event
  `side_panel_state` (jcode-protocol/src/wire.rs:1230). NEW: mermaid
  diagrams inside side-panel pages get their own
  `DiagramOrigin::SidePanel{page_id}` origin (mermaid_model.rs:17) and
  `RenderTarget::SidePanel` (:89) — side-panel markdown participates in the
  same diagram pipeline.
- Verdict: fully JSON-serializable outside the TUI.

## 5. Tool-output blocks

- Confirmed from viz-render §2: stored as `ContentBlock::ToolResult`
  (jcode-message-types/src/lib.rs:161-168, JSON, plain string content),
  flattened to `DisplayMessage` (jcode-tui-messages/src/message.rs:9-18),
  boxed at paint time (ui_messages.rs:3843 via render_rounded_box). Special
  cards (todo, memory) are presentation-only.
- Verdict: data JSON-passthrough; presentation terminal-only.

## 6. Image protocol

- Confirmed from viz-render §3: `ImageProtocol{Kitty,ITerm2,Sixel,None}`
  (jcode-terminal-image/src/display.rs:24-34), env-based detection :37.
  Escape emission at draw time (ui_inline_image.rs). Data survives as
  serialized `RenderedImage` base64 (jcode-session-types/src/lib.rs:126-148)
  and wire `side_pane_images` (wire.rs:838). NEW tie-in: mermaid PNGs ride
  the same image-protocol path (ImageState/KittyViewportState at
  jcode-tui-mermaid/src/lib.rs:712-896); LaTeX formulas and read images
  register as "external images" in the same cache
  (mermaid_runtime.rs:513-546).
- Verdict: protocol emission terminal-only; image data JSON-passthrough.

## Summary table

| Format | Data shape (file:line) | Plain-text/JSON form outside TUI? |
|---|---|---|
| Markdown paint | render_markdown_with_width (markdown_render_full.rs:20) -> ratatui Lines | No (terminal-only paint) |
| Markdown semantic model | Document/Block/BlockKind (jcode-render-core/src/model.rs:164-265) | Yes (serde Serialize/Deserialize) |
| Markdown source | ContentBlock::Text (jcode-message-types/src/lib.rs:117) | Yes |
| Mermaid pipeline | DiagramRenderRequest/RenderArtifact (mermaid_model.rs:111,127); RenderResult (mermaid_cache_render.rs:745) | No (model not serde; source only inside markdown text) |
| Mermaid kinds | flowchart + sequence (terminal_theme, mermaid_content.rs:589) | source-in-markdown only |
| ANSI styling | ratatui Style/Span (jcode-tui-render/src/lib.rs:7) | No; role-level StyleRole/FillRole/TextAttrs (model.rs:16-60) yes |
| Side-panel pages | PersistedSidePanelPage (jcode-side-panel-types/src/lib.rs:47); wire.rs:1230 | Yes (index.json + md files + wire event) |
| Tool output | ContentBlock::ToolResult (jcode-message-types/src/lib.rs:161) | Yes |
| Image protocol | ImageProtocol (jcode-terminal-image/src/display.rs:24); RenderedImage (jcode-session-types/src/lib.rs:126) | Escapes no; base64 data yes |

## Key new findings vs prior artifacts

1. jcode-render-core's `Document`/`Block` model is the JSON-serializable
   semantic form of the markdown subset (prior artifacts missed it).
2. Mermaid renders NATIVELY (mermaid_rs_renderer + usvg/resvg), not via
   external mmdc/node; only flowchart and sequence diagram families styled.
3. Side-panel pages and chat share the mermaid pipeline via
   DiagramOrigin/RenderTarget variants.
4. ANSI styling gains a serializable role-based counterpart in render-core.
