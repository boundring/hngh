# wiki-viewer QoL comparison

Status: crystallized 2026-08-28 from research line `wiki-viewer-qol`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-wiki-viewer-qol.md.

# Research Line: wiki-viewer QoL comparison
**Lifecycle State:** Contracted (Final)
**Target Application:** `hngh/hngh-automation`
**Date:** 2026-08-28

## Executive Summary
This research line investigated the Quality of Life (QoL) differentiators for a read-only wiki viewer or generated documentation UI. The core finding is that **functional utility** (search, navigation, readability) outweighs **visual polish** in determining user satisfaction and reliability perception. For `hngh/hngh-automation`, the recommendation is to abandon open-ended feature comparison in favor of implementing a concrete, measurable **Viewer QoL Baseline**.

## Key Findings

### 1. Search is the Primary Usability Surface
Search quality is the single highest-leverage QoL factor. If users cannot find content quickly, the viewer feels broken regardless of rendering fidelity.
*   **Critical Gap:** Many viewers treat search as a secondary utility rather than the primary entry point.
*   **Requirement:** Client-side indexing must be fast (<100ms for local queries) and support fuzzy matching, prefix search, and ranked results (title > heading > body).

### 2. Navigation Context Must Be Persistent
Wiki content is non-linear; disorientation is a major friction point.
*   **Critical Gap:** Mobile drawers often reset context; browser back/forward behavior is inconsistent across search results and linked pages.
*   **Requirement:** The viewer must always clearly indicate the user’s location within the hierarchy (breadcrumbs, persistent sidebar, or TOC) without requiring URL inspection.

### 3. Readability Controls Are Non-Negotiable for Dense Content
Raw wiki rendering is often uncomfortable for sustained reading.
*   **Critical Gap:** Lack of default controls for font size, line height, and typography leads to user fatigue.
*   **Requirement:** The viewer must provide out-of-the-box readability adjustments (e.g., "Reading Mode") that respect system preferences while allowing manual override.

### 4. Performance and Offline Behavior Define Reliability
On constrained devices or networks, perceived reliability is tied to performance.
*   **Critical Gap:** Heavy client-side dependencies or slow initial loads erode trust.
*   **Requirement:** The viewer must feel instant on mobile and degrade gracefully offline (e.g., cached content, clear error states).

### 5. Accessibility and Provenance Build Trust
Usability extends beyond sighted users; trust requires transparency about content origin.
*   **Critical Gap:** Poor keyboard/screen reader support and lack of source attribution undermine credibility.
*   **Requirement:** Full keyboard navigability, screen reader compatibility, and visible provenance (e.g., "Last updated by X on Y").

## Recommendations for `hngh/hngh-automation`

### 1. Implement a First-Class Search Baseline
**Action:** Build or configure a client-side search index over wiki pages.
*   **Index Fields:** Page title, headings, first ~200 chars of body, namespace/chapter, tags, last-updated date.
*   **Features:** Prefix search, typo tolerance/fuzzy matching, ranked results, snippet highlighting.
*   **Follow-on (Post-Baseline):** Filters (namespace, tag, date), recent searches, "where was this used?" links.
*   **Acceptance Criteria:**
    *   Known pages appear in top 3 results for title/common phrases.
    *   Mobile-compatible without desktop-only interactions.
    *   Query response <100ms for typical wiki sizes.
    *   No-result state offers fallbacks (sitemap, recent changes).

### 2. Enforce Persistent Navigation Context
**Action:** Ensure the user always knows their location within the wiki structure.
*   **Features:** Persistent breadcrumbs or sidebar/tree, TOC controls for long pages, next/previous navigation, "back to top," related pages.
*   **Mobile-Specific:** Preserve current location when opening/closing mobile drawer.
*   **Browser Behavior:** Predictable back/forward across search results, linked pages, and revisions.
*   **Acceptance Criteria:**
    *   User can navigate 5 pages deep and still know their location without checking URL.
    *   Mobile drawer does not reset context.
    *   Keyboard users retain focus context through navigation.

### 3. Default to Readability Controls
**Action:** Provide comfortable reading defaults for dense content.
*   **Features:** Adjustable font size, line height, and typography presets (e.g., "Standard," "Comfort," "High Contrast").
*   **Behavior:** Respect system `prefers-color-scheme` and `prefers-reduced-motion` while allowing manual override.
*   **Acceptance Criteria:**
    *   Users can adjust readability without leaving the page.
    *   Defaults are comfortable for sustained reading (e.g., line length <80 chars, adequate line height).

### 4. Optimize Performance and Offline Behavior
**Action:** Ensure reliability on constrained devices/networks.
*   **Features:** Lazy loading of content/images, service worker caching for offline access, clear error states for network failures.
*   **Acceptance Criteria:**
    *   Initial load <2s on 4G mobile networks.
    *   Cached pages accessible offline with clear "offline" indicator.
    *   No layout shift (CLS) during content loading.

### 5. Ensure Accessibility and Provenance
**Action:** Make the viewer usable by all users and transparent about content sources.
*   **Features:** Full keyboard navigation, ARIA labels for screen readers, visible source attribution (author, date, version).
*   **Acceptance Criteria:**
    *   Passes WCAG 2.1 AA compliance checks for core navigation and content.
    *   Every page displays clear provenance information.

## Open Threads
1.  **Authoring/Admin Scope:** This line assumes a read/browse viewer. If editing, permissions, or administration are in scope, a separate research line is required to address those specific QoL concerns (e.g., WYSIWYG vs. Markdown editor UX, permission management UI).
2.  **Content Generation Pipeline:** The quality of the wiki content itself (structure, tagging, metadata) directly impacts search and navigation effectiveness. A follow-up line on "Wiki Content Quality Metrics" may be needed to ensure the viewer baseline is supported by well-structured data.
3.  **A/B Testing Framework:** How will the QoL baseline be measured in production? Defining metrics (e.g., time-to-find-page, bounce rate from search, readability toggle usage) is an open implementation question.

## Conclusion
The `hngh/hngh-automation` team should implement the **Viewer QoL Baseline** as a concrete, testable set of features rather than engaging in open-ended tool comparison. The baseline prioritizes **search**, **navigation context**, and **readability** as the core pillars of user experience. Visual polish and advanced features (e.g., AI summarization, complex filtering) should be considered only after this baseline is met and validated.
