# What is the current maximum length of session transcripts in the system, and does it exceed the viewport height without virtualization?

Status: crystallized 2026-09-15 from research line `fail-20260914-What-is-the-current-maximum-length-of-se`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-What-is-the-current-maximum-length-of-se.md.

# Contracted Research Line: Session Transcript Length vs. Viewport Height (Unvirtualized)

**Line:** What is the current maximum length of session transcripts in the system, and does it exceed the viewport height without virtualization?
**State:** expanding → **contracted** (final structured summary)
**Target repositories:** `hngh/hngh-automation` (this repo) · `~/Projects/etc/hngh` (kernel)
**Epistemic status of this record:** The prior beat and this contracting pass both operated **without a direct read** of either repository's filesystem. No file path, constant name, or line number below is asserted as verified unless explicitly flagged. Where the answer depends on an unread source, the gap is stated rather than papered over.

---

## Findings

### F1 — "Maximum transcript length" is not a single constant (structural, high confidence)

The question as posed presupposes one number. The prior beat's analysis, and standard TUI/agent-system architecture, indicate the cap is **topologically split** across at least three independent limits:

| Cap | Governs | Typical locus (unverified) |
|---|---|---|
| **Write cap** | Max bytes/entries persisted to disk or ring buffer before rotation/truncation | Storage layer in `hngh` kernel |
| **Read cap** | Max entries deserialized into memory for replay, salvage, or context assembly | Load/salvage path |
| **Render cap** | Max lines drawn to the terminal in one frame (or per scrollback window) | TUI render loop |

These three caps are **not guaranteed to be equal**, and the binding constraint for any given session depends on which is smallest. The prior beat's F1 finding stands: any answer that quotes a single "max length" without specifying *which* cap is being referenced is incomplete.

> **Verification gap:** I cannot name the specific constant(s) (e.g., `MAX_TRANSCRIPT_BYTES`, a ring-buffer size, a render-window row count) because I have not read the kernel source tree at `~/Projects/etc/hngh` or this repository. The prior beat made the same explicit caveat.

### F2 — Structural answer to "does it exceed the viewport without virtualization?": **Yes, for any non-trivial session** (logical, high confidence)

A terminal viewport is bounded by the user's terminal dimensions—commonly 24–60 rows on a laptop, occasionally more on a large monitor. A session transcript that has accumulated even ~100 entries will exceed a 60-row viewport **if the render path draws all entries without windowing or virtualization**. This is a geometric fact, not an implementation detail:

- If `render_cap ≥ total_entries` and there is no scrollback clipping, the terminal emulator's own scrollback limit (commonly 10 000 lines in `tmux`/`screen`, configurable) becomes the effective ceiling.
- If `render_cap < viewport_height`, the UI is structurally broken (content clipped before it fills the screen).
- If there **is** a render window (e.g., "draw last K rows, keep full history in memory"), the transcript can be arbitrarily long without exceeding the viewport, because only K rows are sent per frame.

The prior beat's F2 finding is confirmed as a structural certainty: **the answer to the question is "yes" unless a render window or virtualization layer exists.** Whether that layer exists in `hngh` is an open thread (see OT-1).

### F3 — The three-cap topology creates independent failure modes (structural, high confidence)

Because write/read/render caps are decoupled:

- A transcript can be **stored** (write cap satisfied) but **not displayable** (render cap too small or no windowing).
- A transcript can be **loaded into memory** (read cap satisfied) but **waste memory** if the render path only needs the last K rows.
- The `session-salvage` concept (referenced in prior art as `[[concepts/session-salvage]]`) implies a read-time reconstruction path whose fidelity depends on the read cap, not the render cap.

This means the research question's premise ("the maximum length") is **underdetermined** until the specific cap under discussion is named.

### F4 — Terminal scrollback is an external, environment-dependent ceiling (unverified)

The prior beat noted that terminal emulators impose their own scrollback limits (e.g., `tmux` default 10 000 lines, `screen` similar, configurable via `history` or `scrollback` options). This is **external to the `hngh` codebase** and depends on:
- The user's terminal emulator (`xterm`, `gnome-terminal`, `kitty`, `alacritty`, etc.)
- Multiplexer configuration (`tmux`, `screen`)
- Whether the TUI uses alternate-screen mode (which typically disables scrollback entirely)

> **Verification gap:** I cannot verify which rendering mode `hngh` uses (alternate screen vs. primary screen, full redraw vs. diff-based). This requires reading the TUI render loop in the kernel repository. The prior beat flagged this as unverified; it remains so.

### F5 — No quantitative answer is available from this record (explicit gap)

**I cannot state a number.** The current maximum transcript length—whether measured in bytes, entries, or rendered rows—is not known from any source I can verify in this pass. The prior beat did not read the source; neither has this contracting pass. Any specific constant name, magic number, or file path that appears in downstream notes should be treated as **unverified until a direct read is performed**.

---

## Recommendations

These are distilled from F1–F5 and are actionable for `hngh/hngh-automation` and the kernel repository.

### R1 — Perform a targeted source read to resolve the three caps

The single highest-value next action is a **direct read** of the kernel repository at `~/Projects/etc/hngh`, specifically:

1. **Storage layer:** Locate the write cap (ring buffer size, max file size, rotation policy). Search for constants like `MAX_.*BYTES`, `RING_.*SIZE`, `TRANSCRIPT_.*LIMIT`, or equivalent in the persistence module.
2. **Load/salvage path:** Locate the read cap (max entries deserialized per session load). Check the salvage/replay code path referenced by `[[concepts/session-salvage]]`.
3. **Render loop:** Locate the render cap and determine whether a **windowing or virtualization layer** exists. Specifically check:
   - Is there a "last K rows" slice before drawing?
   - Does the TUI use alternate-screen mode (disabling terminal scrollback)?
   - Is rendering full-redraw, diff-based, or windowed?

This read converts F1, F2, and F4 from structural hypotheses to verified facts. Until it is done, all downstream claims about specific numbers remain ungrounded.

### R2 — If no render windowing exists, implement one

If the source read (R1) confirms that the render path draws all entries without a window:

- Add a **render window** of `viewport_height + buffer` rows (e.g., last 60–80 rows drawn per frame).
- Keep full history in an in-memory structure for search, salvage, and context assembly.
- This decouples the render cap from the transcript length, making F2's "yes" answer a non-issue at the UI layer while preserving data integrity at the storage layer.

### R3 — For `hngh/hngh-automation`: assert on the visible viewport, not the full transcript

If automation tests interact with the TUI:

- Do **not** assert that all N entries are visible in the terminal.
- Assert on the **visible viewport content** (the last K rows actually rendered).
- If the system lacks virtualization and the transcript exceeds scrollback, automation tests will fail or hang at ~100+ entries. The test harness must account for this by either (a) capping test transcripts below the scrollback limit, or (b) asserting only on the visible window.

### R4 — Document the three-cap topology in the system's architecture notes

The finding that "maximum transcript length" is not one number should be recorded in the project's architecture documentation (e.g., alongside `[[concepts/clean-architecture]]` and `[[concepts/system-reproducibility]]`) so that future research beats, onboarding, or incident response do not re-derive this from scratch.

---

## Open Threads

| ID | Thread | Status | Blocking dependency |
|---|---|---|---|
| **OT-1** | Does `hngh` use a render window / virtualization layer? | **Open.** Structural answer is "yes, it exceeds the viewport" *if* no windowing exists. The existence of windowing is unverified. | Direct read of TUI render loop in `~/Projects/etc/hngh`. |
| **OT-2** | What are the concrete values of the write, read, and render caps? | **Open.** No number can be cited from this record. | Same source read as OT-1. |
| **OT-3** | Does `hngh` use alternate-screen mode? | **Open.** Determines whether terminal scrollback is a live constraint or irrelevant. | Source read of TUI initialization code. |
| **OT-4** | How does the session-salvage path interact with the read cap? | **Open.** The salvage concept (`[[concepts/session-salvage]]`) implies a reconstruction path, but its interaction with transcript length limits is unexamined in this line. | Source read of salvage module; cross-reference with `[[concepts/session-salvage]]`. |
| **OT-5** | Is the write cap a hard limit or a soft rotation policy? | **Open.** Affects whether "maximum length" is a ceiling or a rolling window. | Source read of storage/persistence module. |

All open threads are blocked on the same prerequisite: **a direct source read of the kernel repository.** This is not a research-line failure; it is an access constraint that was explicitly flagged in the prior beat and persists here.

---

## What this line can and cannot say (final epistemic boundary)

**Can say (structural, high confidence):**
- "Maximum transcript length" is a multi-cap question, not a single number.
- Without virtualization, any transcript longer than the viewport height will exceed it. This is geometrically certain.
- The three caps (write/read/render) create independent failure modes.
- Terminal scrollback is an external, environment-dependent ceiling.

**Cannot say (requires source read):**
- The specific constant names and numeric values for any of the three caps.
- Whether a render window or virtualization layer exists in `hngh`.
- Whether the TUI uses alternate-screen mode.
- Any specific file path within `~/Projects/etc/hngh` or this repository, with the exception of the repository root itself, which is given in the line definition.

Any downstream note that cites a specific constant (e.g., `MAX_TRANSCRIPT_BYTES = 65536`) or file path (e.g., `hngh/src/tui/render.rs`) **without a verified source read** should be treated as a hypothesis, not a fact.

---

## References

All references below are either given in the line definition or cited from prior art pointers. **No file path within the kernel repository or this repository is cited as a verified existence**, because no direct filesystem read was performed in this pass or the prior beat.

- `~/Projects/etc/hngh` — hngh kernel repository root (given in line definition; contents unverified in this pass)
- `hngh/hngh-automation` — this repository (target of recommendations; specific file paths unverified)
- `[[concepts/session-salvage]]` — Session Salvage concept note (prior art pointer, created 2026-08-24; content not read in this pass)
- `[[concepts/clean-architecture]]` — Clean Architecture for Agent Systems (prior art pointer; content not read in this pass)
- `[[concepts/system-reproducibility]]` — system reproducibility (prior art pointer, created 2026-08-18; content not read in this pass)
- `[[concepts/hngh-lessons-current]]` — Hngh Lessons -- Current (prior art pointer, created 2026-09-07; content not read in this pass)
- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24) (prior art pointer; content not read in this pass)

**External sources not verifiable in this pass:**
- Terminal emulator scrollback defaults (`tmux`, `screen`, `xterm`, etc.) are well-known configuration values but were not verified against a running environment. The commonly cited 10 000-line default for `tmux`/`screen` is stated as a typical value, not a verified fact about this system's deployment.
- Terminal viewport dimensions (24–60 rows) are stated as common laptop defaults; the actual deployment environment's terminal size was not measured.
