# viz-sidepanel: side-panel page data inventory (jcode)

## Data shapes (crate `crates/jcode-side-panel-types/src/lib.rs`)
- `SidePanelPageFormat` enum (Markdown only), lib.rs:5 — serde snake_case, Serialize+Deserialize.
- `SidePanelPageSource` enum (Managed | LinkedFile | Ephemeral), lib.rs:20.
- `PersistedSidePanelState { focused_page_id: Option<String>, pages: Vec<PersistedSidePanelPage> }`, lib.rs:38.
- `PersistedSidePanelPage { id, title, file_path, format, source, updated_at_ms }`, lib.rs:46 (no content; content lives in per-page markdown files).
- `SidePanelPage { id, title, file_path, format, source, content, updated_at_ms }`, lib.rs:58 — full runtime shape.
- `SidePanelSnapshot { focused_page_id, pages }`, lib.rs:73.

## Creation: side_panel tool payload
- Tool impl: `crates/jcode-app-core/src/tool/side_panel.rs`. Input struct `SidePanelInput` (side_panel.rs:20): `action` (required, enum status|write|append|load|focus|delete), `page_id`, `file_path`, `title`, `content`, `focus` (schema at side_panel.rs:44-77).
- Registered as base tool "side_panel": `crates/jcode-app-core/src/tool/mod.rs:330-331`. Excluded from catchup replay: `crates/jcode-app-core/src/catchup.rs:469`.

## Storage
- Disk-backed, per session: `~/.jcode/side_panel/<session_id>/index.json` (`state_file`, `crates/jcode-base/src/side_panel.rs:313-320`), state via `storage::read_json`/`write_json_fast` (side_panel.rs:306-311). Page bodies are markdown files next to the index (`write_page` std::fs::write, side_panel.rs:205).
- `snapshot_for_session` rebuilds SidePanelSnapshot from disk (side_panel.rs:10).

## Serving / delivery
- IPC wire event `SidePanelState { snapshot: SidePanelSnapshot }` tagged `"side_panel_state"`: `crates/jcode-protocol/src/wire.rs:1230` — JSON serialization over the protocol socket.
- History payload to clients includes the snapshot: `crates/jcode-app-core/src/server/client_state.rs:519,699,777`; roundtrip tests in `crates/jcode-protocol/src/protocol_tests/core_events.rs:202-293,337-365`.
- TUI consumes side_panel_state (jcode-tui remote events tests); refresh policy `linked_side_panel_refresh_interval` in `crates/jcode-app-core/src/perf.rs:83-94`.
- Tool output text-only via `status_output` (jcode-base/src/side_panel.rs:141); swarm transport whitelists "side_panel_state" (`crates/jcode-app-core/src/tool/communicate/transport.rs:139`).

## Verdicts
- Data types (`SidePanelSnapshot`/`SidePanelPage`/Persisted*): **native-passthrough** — plain serde Serialize/Deserialize, no TUI dependency.
- Tool payload (SidePanelInput / parameters_schema): **native-passthrough** — plain JSON schema + serde Deserialize; usable from any harness, no TUI coupling.
- Storage (index.json + markdown files on disk): **native-passthrough** — filesystem JSON, readable outside the TUI (storage::read_json/write_json_fast).
- Delivery (`side_panel_state` wire event, bus `SidePanelUpdated` at jcode-base/src/bus.rs:319): **native-passthrough** — JSON-tagged protocol event; however the *rendered* side panel view (TUI widget, perf.rs refresh intervals) is **terminal-only**.
- Overall: everything the tool writes/reads is JSON-serializable outside the TUI; only the rendered panel is terminal-only.
