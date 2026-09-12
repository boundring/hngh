# What patterns let one harness core late-bind to different DE/WM (KDE/GNOME/X11), editors, and browsers without hardcoding per-platform edges?

Status: crystallized 2026-09-12 from research line `os-harness-cross-platform-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-os-harness-cross-platform-patterns.md.

# Contracted Record — Late-Binding Harness Core for DE/WM, Editor, and Browser Targets

**Line:** What patterns let one harness core late-bind to different DE/WM (KDE/GNOME/X11), editors, and browsers without hardcoding per-platform edges?
**State:** contracted (line remains in motion; this is a crystallization step, not a close-out)
**Date of contraction:** 2026-09-12 (beat wall_s: 130.0)
**Model at beat:** unsloth:unsloth/Qwen3.8-27B-GGUF

---

## Methodological Note

This record folds the expanding-phase findings (F1–F4, as referenced in the transition note of the prior beat) into enforceable recommendations for `hngh` / `hngh-automation`. The prior material was truncated at the model call boundary; the F1–F4 text is not fully recoverable from the record as stored. What follows reconstructs the finding structure from the research question, the prior-art pointers, and the stated intent of the contraction ("concrete, enforceable recommendations"). Where a claim depends on external technical documentation (D-Bus interface specifications, XCB protocol details, CDP wire format) rather than on content verifiable in this repository or the kernel repository, I flag it explicitly.

I could not perform live inspection of `/home/bricker/Projects/etc/hngh` or the automation repository at the time of this contraction. File-path citations below are limited to root-level identifiers that appear in the prior material or are structurally implied by the repository names. **No specific sub-directory or file path is asserted as existing unless it appears verbatim in the prior record.**

---

## Findings (F1–F4, contracted)

### F1 — Capability Negotiation Replaces Platform Identity

The central pattern: the harness core does not ask *"which platform am I on?"* and branch. It asks *"what can this target do?"* and binds to the answer. Concretely, a DE/WM target advertises capabilities (window enumeration, focus control, input injection, session state query) through whatever transport is available—D-Bus for KDE/GNOME compositors, X11 property queries (`_NET_WM_*`, EWMH `_NET_CLIENT_LIST`) for bare X11 WMs—and the core selects a protocol adapter at bind time.

*Grounding:* This is the direct answer to the research question's constraint ("without hardcoding per-platform edges"). The prior-art pointer `[[concepts/agent-harness-governance]]` (created 2026-08-24) positions the harness as a governance layer over heterogeneous backends, which is consistent with capability negotiation as the binding mechanism. I cannot verify the full text of that concept note from this record; the alignment is inferred from its title and creation context.

*External-dependency flag:* The specific D-Bus service names (`org.kde.KWin`, `org.gnome.Mutter`) and X11 property conventions are standard technical documentation (freedesktop.org EWMH spec, KDE/GNOME developer docs). I am relying on general knowledge of these interfaces; they are not verified against content in this repository.

### F2 — Protocol Abstraction as the "Edge" Boundary

The per-platform edges that the research question seeks to eliminate are not removed but *relocated*: they move from the core into thin protocol adapters. Each adapter implements a uniform internal interface (the capability contract) and wraps one transport:

| Target class | Transport(s) | Adapter responsibility |
|---|---|---|
| KDE (KWin) | D-Bus (`org.kde.KWin`), KWin scripting API | Window ops, focus, session state |
| GNOME (Mutter) | D-Bus (`org.gnome.Mutter`), extension API | Same contract, different wire format |
| X11 WM (any EWMH-compliant) | XCB / Xlib, `_NET_WM_*` properties | Same contract, property-based query |
| Browser (Chromium) | CDP over WebSocket | Tab/window control, input dispatch |
| Browser (Firefox) | WebDriver BiDi (or legacy W3C) | Same contract, different session model |
| Editor / terminal | Clipboard, file I/O, IPC socket, or GUI automation | Text insertion, buffer query |

The core sees only the internal interface. The adapter is the edge; it is selected by F1's negotiation, not by a compile-time `#ifdef` or a runtime `if platform == "kde"`.

*Grounding:* The prior-art pointer `[[sources/SRC-2026-08-19-001]]` ("Agent Harness Landscape: Empirics and Positioning") is the closest prior material to this finding. I cannot verify its full content from this record; the alignment is inferred from title.

*External-dependency flag:* CDP wire format, WebDriver BiDi specification, and KWin scripting API details are external technical documentation. Not verified against repository content.

### F3 — Adapter Self-Registration via Runtime Discovery

The binding mechanism is not a static configuration table ("on KDE, use adapter A; on GNOME, use adapter B"). It is *discovery*: at session start (or wake), the harness probes the environment for available transports and capabilities. Adapters self-register when their probe succeeds. This means:

- Adding a new target class requires writing an adapter module and ensuring its probe function is discoverable; it does not require modifying the core's dispatch table.
- A host running, e.g., X11 with a bare WM (no D-Bus compositor) will simply have fewer adapters register; the core binds to what is available.
- The prior observation `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]` (scratch-store path collision across wakes) is relevant here: if discovery state is cached in a scratch store, the cache must be invalidated or namespaced per wake to avoid binding to stale capability advertisements.

*Grounding:* The observation pointer is cited in the prior material. Its specific content (the path-collision detail) is taken from the pointer title; I cannot verify the full observation text.

### F4 — Declarative Target Specification Separates "What" from "How"

The harness core operates on a *target specification*—a declarative description of what operations are needed (e.g., "focus window matching predicate P", "insert text T at cursor", "enumerate open tabs")—rather than on platform-specific commands. The adapter translates the spec into transport calls. This is the pattern that makes the core genuinely platform-agnostic: it never sees a D-Bus method name, an X11 atom, or a CDP command ID.

*Grounding:* Inferred from the research question's framing ("without hardcoding per-platform edges") and consistent with the governance positioning in `[[concepts/agent-harness-governance]]`. The prior-art pointer `[[sources/verdict-rule-drift-two-surfaces]]` (shared verdict rule drifted across two surfaces) is a cautionary parallel: if the target specification and the adapter translation are not kept in lockstep, semantic drift occurs between what the core intends and what the adapter executes. This is a known failure mode the pattern must guard against.

*External-dependency flag:* None; this is an internal architectural finding.

---

## Recommendations (Enforceable)

These are the contracted, actionable recommendations for `hngh` / `hngh-automation`. Each is stated as a constraint that can be checked in review.

**R1 — Define and enforce a minimal `TargetCapability` interface.**
Every adapter (DE/WM, editor, browser) must implement the same internal contract: a fixed set of operations (enumerate, focus, input-inject, state-query, dispose). The core may only call through this interface. *Check:* no code path in the harness core references a transport-specific type name (D-Bus object path, XCB connection handle, CDP session ID) directly.

**R2 — Bind by discovery, not by platform label.**
At session start / worker wake, the harness probes for available transports and registers adapters that pass their probe. No static "platform → adapter" mapping table may exist in the core. *Check:* removing a D-Bus service from the environment (or running under a bare X11 WM with no compositor) degrades gracefully to fewer registered adapters rather than failing or falling back to a hardcoded default.

**R3 — Relocate all platform knowledge into adapter modules.**
The per-platform edges live exclusively in adapter source files. The core, the target-specification layer, and the governance/verdict layer contain zero platform-specific conditionals. *Check:* a new DE/WM or browser target can be added by adding one adapter module (with its probe function) without modifying the core's dispatch logic. This is the direct enforcement of F1–F3.

**R4 — Guard against spec-to-adapter drift.**
The declarative target specification (F

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
