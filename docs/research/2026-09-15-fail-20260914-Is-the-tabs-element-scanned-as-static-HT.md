# Is the `#tabs` element scanned as static HTML or live DOM, and does the hydration process inject any non-tab nodes (e.g., tooltips, focus traps) into the `tablist` container?

Status: crystallized 2026-09-15 from research line `fail-20260914-Is-the-tabs-element-scanned-as-static-HT`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Is-the-tabs-element-scanned-as-static-HT.md.

# research beat — line crystallization (final record)

_line: Is the `#tabs` element scanned as static HTML or live DOM, and does the hydration process inject any non-tab nodes (e.g., tooltips, focus traps) into the `tablist` container? | state: contracting → **crystallized (closed, unresolved)**_

---

## Final verdict

**CLOSED AS UNRESOLVED — the line's premise was never verified against the hngh kernel, and this transition has no tool access to verify it.** The prior beat correctly identified that all apparent "findings" on this line were framework-general deduction (React/Vue/Svelte hydration semantics) rather than observations of the hngh codebase. No claim in this record is asserted as true of hngh. The lasting value of the line is the gating analysis and the decision procedure, not an answer.

## Findings (what the line established, with confidence levels)

1. **The question is conditional, not atomic** *(high confidence — logical structure of the line)*. The original question decomposes into three premises, all of which must hold for the question to have content:
   - hngh renders a browser DOM containing `#tabs` / a `role="tablist"` container;
   - that DOM undergoes a client-side hydration step (as opposed to being a static artifact, a server-rendered string, or a TUI);
   - hngh-automation's tab-targeting logic reads the live DOM rather than an internal model.
   None of the three was confirmed by this line.

2. **Prior art cuts against the hydrated-SPA reading** *(moderate confidence — grounded in named vault notes)*. The available hngh-specific prior art — [[sources/hngh-storeless-cli-state-loss]] and [[sources/subprocess-stub-seam-for-hermetic-tests]] — describes a **storeless, multi-process CLI/automation architecture with env-overridable subprocess seams**, not a browser application. If that characterization holds, premise (1) likely fails and the line's question collapses: there is no `tablist` container to hydrate, and "scanning" would mean parsing a generated artifact, if anything. This was the line's key tension and it was never resolved empirically.

3. **The DOM-injection concern is real in the general case but unobserved here** *(framework knowledge, not repo observation)*. Hydrating frameworks can insert sentinel/wrapper nodes and flip attributes (`inert`, `aria-hidden`, focus-trap sentinels) inside containers, which would break naive `childNodes`-based tab targeting. This is asserted as general web-platform behavior only; **no hngh file, bundle, or runtime was observed to confirm or refute it for this codebase.**

4. **No kernel-repo file paths can be cited** *(high confidence about the absence)*. Neither the prior beat nor this crystallization had verified access to `/home/bricker/Projects/etc/hngh`. Naming paths would be fabrication, so none appear below. This is itself a finding: the research environment for this line lacked repo access, and any future work on the line must begin there.

## Recommendations (the line's actionable residue, in dependency order)

- **R1 (gate; do first).** Verify the premise: search the kernel repo for the literal `#tabs` id and `role="tablist"`, locate the single producing entry point, and classify the emitter (SSR string, SPA bundle, CLI-generated static file, TUI, none). This one check decides the line's branch: static artifact → question closes as "static scan of a produced artifact, injection out of scope"; hydrated SPA → proceed to R2.
- **R2 (empirical capture, only if R1 finds a live DOM).** Take two artifacts: (a) the pre-hydration served HTML of `#tabs`; (b) a post-hydration `MutationObserver` log (`childList` + `attributes`) on the resolved node. Decision rule: any non-tab node present post- but absent pre-hydration ⇒ injection occurs; identical trees ⇒ automation selectors can treat the container as static. Log structural insertions and attribute flips separately so an attribute-based focus trap isn't misread as node injection.
- **R3 (reframe).** Determine what "scanned" means *for hngh-automation specifically*: if targeting runs through an internal model or the subprocess seams described in the prior art, the DOM-injection question is moot regardless of R2's outcome.
- **R4 (defensive posture, applicable without R1–R3).** Any tab-targeting selector should filter by `role="tab"` / `[role="tab"]` rather than positional `childNodes` indexing, making it robust to injected wrappers, tooltips, and sentinels whether or not they exist today.

## Open threads (handed off, not answered)

1. Does hngh/hngh-automation ship any browser-rendered UI at all? (R1 — the gate.)
2. If yes: which framework/runtime owns hydration, and where is the entry point?
3. If injection is observed: is it node insertion or attribute mutation, and does it occur inside or adjacent to the `tablist`?
4. Process thread: this line burned two beats without repo access. Future lines touching kernel internals should verify filesystem/tool access at line-open, before expansion.

## References

Prior-art vault notes named in this record (paths as given to the line; contents not re-verified this transition):

- [[sources/hngh-storeless-cli-state-loss]] — Hngh storeless CLI state loss in multi-process flows
- [[sources/subprocess-stub-seam-for-hermetic-tests]] — Env-overridable binary seam for hermetic subprocess tests
- [[sources/SRC-2026-08-18-008]], [[sources/SRC-2026-08-24-002]] — present in prior-art pointers but **not relevant to this line** (noted so future readers don't chase them)

Kernel repository: `/home/bricker/Projects/etc/hngh` — **referenced but not accessed**; no file paths within it are cited because none could be verified. External framework-hydration behavior (finding 3) is asserted from general platform knowledge and is explicitly unverified against any source in this environment.
