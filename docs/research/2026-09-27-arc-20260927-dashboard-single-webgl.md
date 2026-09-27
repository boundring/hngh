# How should the paper texture and the megastructure map share one WebGL context (or one canvas) in broadsheet-view.js?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-single-webgl`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-single-webgl.md.

# Research Line Contraction: Final Summary

**Line:** How should the paper texture and the megastructure map share one WebGL context (or one canvas) in `broadsheet-view.js`?  
**State:** `research-lines.tsv` | **Lifecycle:** `contracting → closed` | **Date:** 2026-09-27  
**Model:** kimi:k3-256k | **Wall clock:** 67.0s

---

## Findings

### F1 — The "context swap" design is physically impossible

A `<canvas>` element is bound to exactly one rendering context type for its lifetime. Once `canvas.getContext('webgl')` (or `'webgl2'`) succeeds, subsequent calls return the *same* context object. There is no mechanism to swap contexts between regions of a single canvas. This eliminates the prior beat's Angle 2 ("context swap at the boundary") from the design space.

**Source:** WebGL specification, `HTMLCanvasElement.getContext()` semantics. No external verification needed.

### F2 — Three real options remain

| Option | Description | Drift risk |
|--------|-------------|------------|
| **A** | One canvas, one context, sequential passes (paper then map) | Low — state is explicit and ordered |
| **B** | One canvas, one context, spatially partitioned passes via `gl.scissor`/`gl.viewport` | Medium — scissor state can leak if not guarded |
| **C** | Two stacked canvases, two contexts, composited by browser | Low — full isolation, but adds DOM complexity |

Options A and B are the practical choices for `broadsheet-view.js`. Option C is the fallback if drift is confirmed and cannot be contained.

### F3 — Separate textures prevent cross-surface mutation

The prior beat's Angle 3 (unified atlas) was correctly rejected. A single `WebGLTexture` object means `texSubImage2D` uploads for one surface are writes into the same GPU object the other surface samples. This is exactly the shared-surface mutation pattern warned against in `[[sources/verdict-rule-drift-two-surfaces]]`. Separate `WebGLTexture` objects on separate texture units make cross-surface writes structurally impossible.

**Source:** `[[sources/verdict-rule-drift-two-surfaces]]` (read-only vault pointer; not a citable code path).

### F4 — State guards are mandatory around each pass

The drift failure mode in `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` is state leaking between surfaces. In WebGL terms, this means `gl.enable`/`gl.disable`, `gl.blendFunc`, `gl.viewport`, `gl.scissor`, and texture unit state must be saved and restored around each pass. Without guards, Pass 2's blending state bleeds into Pass 1, or Pass 1's texture unit state bleeds into Pass 2.

**Source:** `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` (read-only vault pointer; not a citable code path).

---

## Recommendations

### R1 — Acquire the context once, at module init, and own it

`broadsheet-view.js` should call `getContext('webgl2', { alpha: true, antialias: true })` (fall back to `'webgl'`) exactly once, store the `WebGLRenderingContext` on the module or view instance, and never re-request it. No other module in hngh-automation should call `getContext` on the same canvas.

**Why:** This removes an entire class of drift — two surfaces cannot mutate "their" context because there is only one, owned in one place.

**Implementation note:** Store the context as a module-level singleton or as a property on the view instance. Log the acquisition once at module load for observability.

### R2 — Two passes, two shader programs, two texture units

- **Pass 1 (paper):** draw the paper texture as a fullscreen quad using its own compiled program, sampling texture unit 0.
- **Pass 2 (megastructure map):** draw the map on top using a *separate* compiled program, sampling texture unit 1, with blending enabled (`gl.enable(gl.BLEND)`, `gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)`).

Keep the paper texture and map texture as **separate `WebGLTexture` objects** on separate texture units. Do **not** unify them into a shared atlas.

**Why:** Separate textures make cross-surface writes structurally impossible. Two shader programs prevent shader state from leaking between passes.

### R3 — A state guard around each pass

Save and restore the following state around each pass:
```
gl.enable(gl.BLEND) / gl.disable(gl.BLEND)
gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
gl.viewport(...)
gl.scissor(...)
gl.activeTexture(gl.TEXTURE0) / gl.TEXTURE1
```

**Why:** The drift failure mode in `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` is state leaking between surfaces. WebGL state is global to the context, not scoped to a pass.

### R4 — Prefer Option A (sequential passes) over Option B (scissor partitioning)

Unless there is a demonstrated need for spatial partitioning (e.g., different blend modes per region), use sequential passes. Scissor state is harder to guard correctly and adds a source of drift itself.

**Why:** Sequential passes are simpler, easier to reason about, and eliminate scissor state as a drift vector.

### R5 — If drift is confirmed and cannot be contained, migrate to Option C (two canvases)

Two stacked canvases with two contexts provide full isolation. The browser composites them. This is the fallback if drift is confirmed and cannot be contained with Options A or B.

**Why:** Full isolation eliminates all cross-surface state leakage. The cost is DOM complexity and potential performance overhead from double rendering.

---

## Open Threads

### OT1 — Performance profiling of two-pass vs. one-pass

The two-pass approach renders the paper texture and map separately. If the paper texture is large or the map is complex, this may cause visible flicker or performance issues. Profile before committing.

**Status:** Not yet investigated. Requires access to `broadsheet-view.js` and a profiling tool.

### OT2 — Shader compilation and caching

Two shader programs means two compilation passes. If the shaders are large or the GPU is slow to compile, this may cause initial load latency. Consider caching compiled programs across frames.

**Status:** Not yet investigated. Requires access to `broadsheet-view.js` and shader source.

### OT3 — Texture upload timing

If the paper texture and map texture are uploaded from CPU to GPU on every frame (e.g., for animated textures), this may cause stalls. Consider uploading once and updating via `texSubImage2D` only when needed.

**Status:** Not yet investigated. Requires access to `broadsheet-view.js` and texture source.

### OT4 — Verification of `[[sources/verdict-rule-drift-two-surfaces]]`

This vault pointer is cited as a source for the shared-surface mutation warning, but I cannot verify its contents or path. If this is a critical source, it should be made citable (e.g., a concrete file path in the repository).

**Status:** Unverified. Requires filesystem access to `[redacted path] or the vault.

---

## References

| Reference | Type | Confidence |
|-----------|------|------------|
| `broadsheet-view.js` | Repository file (named in research line) | High |
| `research-lines.tsv` | Repository file (named in line-state header) | High |
| `[[sources/verdict-rule-drift-two-surfaces]]` | Vault pointer (read-only) | Low — path not verifiable |
| `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` | Vault pointer (read-only) | Low — path not verifiable |
| `[[sources/obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig]]` | Vault pointer (read-only) | Low — path not verifiable |
| `[[concepts/billion-context-tuning]]` | Vault pointer (read-only) | Low — path not verifiable |
| `[[concepts/context-distillation]]` | Vault pointer (read-only) | Low — path not verifiable |
| `[redacted path] | Kernel repository (named in instructions) | Unknown — cannot verify filesystem access |

**Caveat:** I cannot read the filesystem of `[redacted path] or the automation repo. All claims grounded in the repository are based on the research line's prior material and the WebGL specification. Vault pointers are treated as read-only signals, not citable code. Where a claim needs external sources I cannot verify, I have said so explicitly instead of asserting.

---

**Line closed.** This summary is the lasting record of the research line.
