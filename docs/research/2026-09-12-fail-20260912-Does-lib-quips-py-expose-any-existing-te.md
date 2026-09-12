# Does lib/quips.py expose any existing template-validation or rendering hook where a wink-marker lexical guard could land as configuration rather than new infrastructure?

Status: crystallized 2026-09-12 from research line `fail-20260912-Does-lib-quips-py-expose-any-existing-te`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-Does-lib-quips-py-expose-any-existing-te.md.

# Contracted Research Line Record

**Line:** Does `lib/quips.py` expose any existing template-validation or rendering hook where a wink-marker lexical guard could land as configuration rather than new infrastructure?  
**Lifecycle state:** contracting → contracted record  
**Date of this transition:** 2026-09-12  
**Repository context:** hngh kernel repository at `/home/bricker/Projects/etc/hngh`

---

## Verdict

There is no verified basis in the available material to conclude that `lib/quips.py` exposes an existing template-validation or rendering hook suitable for a wink-marker lexical guard as pure configuration.

The line can be contracted into a decision gate:

- If `/home/bricker/Projects/etc/hngh/lib/quips.py` contains an existing template-expansion call site, validation hook, or configuration surface, then a wink-marker lexical guard may land there as configuration or minimal config-gated code.
- If it does not contain such a surface, the premise “configuration rather than new infrastructure” is not supported for this file.
- Until that inspection is performed, no implementation recommendation should be treated as settled.

This is not a claim that the guard is impossible. It is a claim that the configuration-only landing zone has not been established.

---

## Findings

### F1 — The only concrete repository artifact named by the line is `lib/quips.py`

The research line names:

- `/home/bricker/Projects/etc/hngh/lib/quips.py`

That path is treated as the object of investigation because it is named in the line itself. Its internal structure, public API, docstring, imports, validation functions, configuration surface, and rendering behavior are not verified in this contraction.

No other concrete file path is asserted here except where directly inherited from the prior material or provided task context.

---

### F2 — The prior material supports a render-time guard window, but not quips-specific hook placement

The prior material cites prior-art entries suggesting that lexical guards can interact badly with template expansion, especially when markers are checked before or after variable expansion in ways that corrupt or miss them.

That reasoning is useful, but it is not proof that `lib/quips.py` has a render-time boundary suitable for the guard. It only supports the general principle:

- A wink-marker lexical guard should be evaluated at the point where template text becomes final rendered output.
- The guard should be a narrow lexical predicate, not a parser or broad content validator.
- The guard must not assume that pre-parse text and post-expansion text are equivalent.

This finding is inherited from the prior material, not independently verified against `lib/quips.py`.

---

### F3 — “Configuration rather than new infrastructure” requires an existing configuration surface

For the guard to land as configuration rather than new infrastructure, at least one of the following must be true in or around `lib/quips.py`:

1. There is an existing template-expansion call site where a post-expansion lexical check can be inserted.
2. There is an existing validation, linting, checking, verification, safety, or guard function.
3. There is an existing configuration object, dictionary, environment-variable prefix, dataclass, keyword argument, or module-level setting that controls quip behavior.

If none of those exist, then adding a wink-marker guard as “configuration” would require creating the configuration surface itself. That would be new infrastructure relative to the line’s constraint.

No such surface is verified in the available material.

---

### F4 — The consumer path determines whether the guard can be global or must be opt-in

The prior material inferred that `lib/` modules may be consumed by rendering or display subsystems, but that inference is not verified.

If `lib/quips.py` is consumed only by one automation rendering path, a guard placed at that path’s post-expansion boundary may be acceptable as a local behavior change.

If `lib/quips.py` is consumed by many subsystems, CLI tools, tests, documentation generators, or non-rendering paths, then a global wink-marker guard could have unintended blast radius. In that case, the guard should probably be opt-in per caller or gated by an explicit configuration entry.

This distinction cannot be resolved without tracing importers.

---

### F5 — The guard should remain lexical

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
