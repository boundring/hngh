# Prior art: candidate (b) — jcode TUI "requires an interactive terminal" error lacking a headless/spawn_hook hint

Date: 2026-09-15
Task: `prior-art-b-tui-headless-hint`
Mode: READ-ONLY exploration (no repo edits; git log searches only)
Artifact: `.agent-scratch/swarm-resume/prior-art-b-tui-headless-hint.md`

## Verdict

**Upstream prior art: NOT FOUND.** No GitHub issue or PR in
github.com/1jehuang/jcode (open or closed) reports the bare
`jcode TUI requires an interactive terminal (stdin/stdout must be a TTY)`
error or asks for a headless-mode / `spawn_hook` hint in that message.
The error message still ships hint-free on upstream master today.
The candidate (adding a headless/spawn_hook hint to the error) therefore
appears novel against upstream, though it touches a real, reproduced
failure mode that is documented only in this repo's local records.

## Candidate recap

The jcode CLI bails out with:

```
Error: jcode TUI requires an interactive terminal
(stdin/stdout must be a TTY)
```

when stdin or stdout is not a TTY, with no suggestion of what to do
instead (headless run, `jcode run`, tmux/PTY wrap, or the
`[terminal] spawn_hook` config alternative).

## Evidence — upstream GitHub (github.com/1jehuang/jcode)

Searches performed against the GitHub search API (issues + PRs, open and
closed states included by default) on 2026-09-15:

| Query | Result |
| --- | --- |
| `"requires an interactive terminal"` (exact phrase) | 0 results (`total_count: 0`) |
| `"interactive terminal"` (broad) | 11 results, all unrelated (SSH input capture #925, macOS stdin-detect false positive #1146, auth-docs audit #386, OSC 11 startup garbage #1004, security review #568, triage PR #656, etc.) |
| `headless TTY` | 2 results, unrelated (#1014 OAuth browser suppression in shared-server sessions; #663 CI restore PR) |
| `"must be a TTY" OR "spawn_hook" OR "non-TTY"` | 7 results: closest are #1026 (`session_start` hook lacking swarm metadata for inline/headless workers — hook-metadata feature request, not the TUI error) and #792 (tmux pane spawning feature request; confirms `spawn_hook` docs exist but not the error hint); rest unrelated (#1014, #401, #405, #666) |
| `"TTY" in:title` | 1 result: #987 (OPOST/ONLCR staircase after exit — raw-mode restore bug, different failure) |
| `PTY` | 26 results, none about this error (render storms #1205/#1184, Warp agent #668, TUI lag #540, bg stdin revoked-fd #903, CI #1191, etc.) |
| `Konsole OR "dies immediately" OR "closes immediately"` | 5 results, none matching (#690 resume-autocomplete note mentions a "closes immediately" glimpse bug but different surface; #903 Python child dies from revoked stdin) |
| `swarm spawn window` | 23 results, none about the TUI TTY error (#1069 Alt+O pop-out closing kills inline worker — closest thematically: a spawned worker dies when its terminal closes, but it is about lifecycle ownership, not the error message) |
| `TUI headless` | 40 results, none matching (scheduled-task live delivery #1194, Windows RAM runaway #1192, api-bridge visibility #1200, etc.) |
| `"stdin/stdout"` | 16 results, none matching (MCP transports #483/#761, #1014, #925, etc.) |
| Commits: `"interactive terminal"` | 1 result: 096d5e8 "Remove stdin input hijacking - show informational notice only" (Feb 2026) — changes the stdin-capture notice behavior, does not touch the TUI TTY guard error |
| Code search for `"requires an interactive terminal"` | 401 Unauthorized (code search requires auth); mitigated by grepping the local mirror `~/src/jcode`, which tracks upstream (verified identical message and line numbers; see below) |

No upstream issue or PR matches the candidate's fix (adding a headless /
spawn_hook hint to the `init_tui_terminal` bail).

## Evidence — upstream master source state (verified 2026-09-15)

`https://raw.githubusercontent.com/1jehuang/jcode/master/src/cli/terminal.rs`
still contains, in `init_tui_terminal`:

```rust
fn init_tui_terminal(inherited_terminal: bool) -> Result<ratatui::DefaultTerminal> {
    if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        anyhow::bail!("jcode TUI requires an interactive terminal (stdin/stdout must be a TTY)");
    }
    ...
```

The message has no hint of any kind. Notably, other sibling errors in the
same codebase DO carry remedial hints, so the convention exists:

- `src/cli/login.rs:219` — "`jcode login --provider auto` requires an
  interactive terminal. Use `jcode login --provider <provider>` in
  non-interactive mode."
- `crates/jcode-tui/src/tui/session_picker.rs:2426` — "Session picker
  requires an interactive terminal. Use --resume <session_id> directly."

This asymmetry (login and session-picker errors tell you the non-interactive
alternative; the TUI startup error does not) strengthens the candidate and
suggests the fix pattern is already established in-repo.

## Evidence — upstream git history (via local mirror ~/src/jcode)

The local mirror is at `74e7a4be54` ("docs: update weekly stars chart",
Sep 15 2026) and contains the same message. `git log -S 'jcode TUI requires
an interactive terminal'` yields exactly three commits, all mechanical:

1. `cfbc498fd` (2026-02-10) "Fail gracefully when terminal init panics" —
   introduces the guard line (added in `src/main.rs` at the time).
2. `568b0d80e` (2026-03-06) "Extract CLI modules from main.rs: args,
   dispatch, startup, terminal, selfdev tests" — moves the line verbatim
   into the new `src/cli/terminal.rs`.
3. `37159430c` (2026-09-13) "docs: update weekly stars chart" — pick-side
   reapplication; no wording change.

So the message was introduced as a plain fail-closed guard and has never
been revisited upstream. Nothing in upstream history hints at awareness of
the headless-spawn use case in this error.

## Evidence — hngh repo git history (as tasked)

`git log -S 'requires an interactive terminal' --oneline` in
~/Projects/etc/hngh returns exactly one commit:

- `1399e179` (2026-09-14) "docs: visible-spawn flash-die root cause (TUI
  needs PTY) + tmux spawn router fix" — adds
  `docs/records/2026-09-14-visible-spawn-flash-die.md`, which documents the
  exact error text reproduced locally ("Error: jcode TUI requires an
  interactive terminal (stdin/stdout must be a TTY)") when a visible swarm
  worker runs `jcode self-dev` non-interactively, causing Konsole windows
  to flash-die. The local fix was a tmux spawn router
  (`~/bin/jcode-spawn-router` + `[terminal] spawn_hook`) outside this repo.

This is the only in-repo trace of the error, and it is the operator-side
workaround (wrap the spawn in tmux so a real PTY is allocated), not an
upstream fix or a filed upstream issue.

## Adjacent prior art (thematically related, not duplicates)

- jcode #1069 (open): closing an Alt+O pop-out terminal removes an inline
  swarm worker and aborts its task — worker death caused by terminal
  lifecycle, adjacent symptom family.
- jcode #1026 (open): `session_start` hook lacks swarm metadata for
  inline/headless workers — same headless/visible spawn asymmetry area.
- jcode #792 (closed as fixed-pending-release): native tmux pane spawning
  feature request; confirms `[terminal] spawn_hook` + `swarm_spawn_mode`
  docs exist and that inline mode never fires the hook (root-cause
  similarity: non-interactive spawn path), but never mentions the TTY
  error message.
- jcode #987 (closed): raw-mode restore corruption after exit — different
  TTY bug, demonstrates the TUI terminal-guard area is actively maintained.

None of these propose or implement a hint in the TTY guard error.

## Conclusion

- **Upstream prior art for the exact fix: none found** (issue tracker and
  commit history both clean as of 2026-09-15).
- The bug is real and reproduced locally (hngh record 2026-09-14) but was
  worked around operator-side, never reported upstream.
- Upstream master still ships the hint-free error; the in-repo convention
  for hint-bearing non-interactive errors (login.rs, session_picker.rs)
  gives an established pattern to follow if a hint is ever proposed.
- Candidate (b) is therefore not blocked by prior art; a filed upstream
  issue or PR adding the hint would be first-of-kind.
