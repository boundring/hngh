# Why does the ui-audit axe scan report aria-required-children on #tabs (role=tablist) when the static HTML carries nine role=tab children, which element is the disallowed child, and what disposition (fix or park) closes the alert that re-occurred across 2026-09-11..09-14?

Status: crystallized 2026-09-14 from research line `fail-20260911-ui-audit-axe-aria-required-children`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260911-ui-audit-axe-aria-required-children.md.

# Final Structured Summary — `aria-required-children` on `#tabs` (role=tablist)

## Status: Contracted / Closed for Disposition

This line is crystallized. The core finding is that **the alert cannot be dispositioned (fix vs. park) without first extracting the specific offending node from the axe-core JSON output.** The prior beat correctly identified the failure mode as deterministic but failed to produce the diagnostic artifact required to distinguish between a static markup error and a runtime hydration artifact.

## Findings

1.  **Deterministic Failure Mode**: The `aria-required-children` violation on `#tabs` re-occurred consistently across 2026-09-11 through 2026-09-14. This eliminates transient network, flake, or timing-based causes. The issue is structural within the scanned DOM state.
2.  **Rule Mechanics**: axe-core's `aria-required-children` rule for `role="tablist"` fires if *any* child element lacks `role="tab"`. The presence of nine valid `role="tab"` children in the static HTML does not guarantee compliance if a tenth node (or a wrapper) exists in the live DOM without the role.
3.  **Diagnostic Gap**: The prior research beat hypothesized runtime-injected nodes (tooltips, focus traps, scroll containers) but produced no axe JSON output, no DOM snapshot, and no diff between static source and live DOM. Consequently, the "disallowed child" remains unidentified.
4.  **Scan Target Unconfirmed**: It is not verified whether the ui-audit pipeline scans raw `.html` files, built bundles, or hydrated pages in a headless browser. The prior material asserted live DOM scanning without citing pipeline configuration. This distinction is critical: if static HTML is scanned, the issue is a source markup error; if live DOM is scanned, it may be a hydration artifact.
5.  **Repository Verification Limitation**: I have not inspected the hngh kernel repository (`~/Projects/etc/hngh`) or ui-audit pipeline configuration in this session. All file-path references are conditional on the reader verifying them against their working tree.

## Recommendations

### R1 — Capture the Disallowed Child (Blocking)
**Action**: Obtain the axe JSON result for this specific violation and read the `nodes[].target` selector.
- Re-run the ui-audit axe scan against the same build that produced the 09-14 alert.
- Extract the `aria-required-children` entry from the axe JSON (typically at `.violations[]` where `id === "aria-required-children"`). The `nodes[0].target` CSS selector names the exact offending element.
- If the scan runs in a headless browser, dump `document.querySelector('#tabs').innerHTML` immediately before the axe call and diff it against the static source file.

**Rationale**: Every downstream decision (fix vs. park, which component to change, whether audit config needs a rule override) depends on *what* the child is. Parallel investigation without this artifact is wasted effort.

### R2 — Disposition Decision Tree
Once the disallowed child is identified:

| Disallowed Child Is… | Disposition | Action |
|---|---|---|
| Static element in source HTML (e.g., `<div>` wrapper, stray `<span>`, comment node) never marked `role="tab"` | **Fix** | Add missing role or remove/restructure the element in static markup. |
| Runtime-injected node (tooltip wrapper, focus-trap span, scroll container) added during hydration | **Fix** | Modify component to exclude non-tab nodes from `#tabs` container, or add `role="presentation"`/`aria-hidden="true"` if appropriate per ARIA spec. |
| axe-core rule misconfiguration or false positive due to scan target mismatch (e.g., scanning pre-hydration HTML that lacks runtime structure) | **Park** | Adjust ui-audit pipeline to scan post-hydration DOM, or suppress rule for this specific node with documented justification. |

### R3 — Verify Scan Target
**Action**: Confirm whether ui-audit scans static files or live DOM.
- Locate the ui-audit pipeline entry point (likely under `~/Projects/etc/hngh` or adjacent `hngh-automation` directory).
- Check for files matching patterns like `ui-audit*`, `axe*`, `a11y*`, or `audit*.ts/.js/.py`.
- If axe JSON output is not persisted, add a step to write it to an `artifacts/` or `reports/` subdirectory.

## Open Threads

1.  **Identification of Disallowed Child**: Blocked on R1 execution. No progress can be made on disposition until the specific node is named via axe JSON.
2.  **Scan Target Verification**: Unconfirmed. Requires inspection of ui-audit pipeline configuration in hngh kernel repository.
3.  **Static vs. Live DOM Diff**: Not performed. Required to determine if the issue is a source markup error or hydration artifact.

## References

- `~/Projects/etc/hngh` (hngh kernel repository; path unverified in this session)
- ui-audit pipeline configuration (location unverified; likely under hngh or adjacent `hngh-automation` directory)
- axe-core documentation for `aria-required-children` rule (external source; not verified in this session)
- Prior research beat 2026-09-14 (provided in prior material)

**Explicit Limitation**: I have not inspected the hngh kernel repository or any ui-audit pipeline configuration in this session. All file-path references are conditional on the reader verifying them against their working tree. Where I cannot verify a path or an axe output, I say so rather than assert it.
