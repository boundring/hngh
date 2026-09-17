# If the probe returns a clean negative for `/home/bricker/Projects/etc/hngh`, has the research root been renamed to a different path (e.g., `/home/bricker/Projects/hngh`) or moved to a remote host accessible via the `remote-access-patterns` 

Status: crystallized 2026-09-17 from research line `fail-20260916-If-the-probe-returns-a-clean-negative-fo`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-If-the-probe-returns-a-clean-negative-fo.md.

**Epistemic Status:** I do not have live access to the filesystem, `research-lines.tsv`, or the `hngh` kernel repository at `[redacted path] Consequently, I cannot verify whether a rename has occurred, confirm the existence of specific file paths, or validate the contents of `remote-access-patterns`. The following summary is derived strictly from the logic of the provided prior material and standard software engineering practices for maintaining research continuity in version-controlled environments. Claims regarding external sources are explicitly marked as unverified where applicable.

---

### Final Structured Summary: Research Line on Path Volatility & Relocation Detection

**Line State:** Contracting (Final Record)
**Core Question:** If the probe returns a clean negative for `[redacted path] has the research root been renamed to a different path (e.g., `[redacted path] or moved to a remote host accessible via `remote-access-patterns`?

#### 1. Findings
The research line identified a critical vulnerability in the current probe logic: **path-dependency**. The system treats a "clean negative" (absence of the expected path) as a valid data point without first verifying the epistemic context (host identity, mount status, or vantage point). This creates ambiguity where a "missing" root could be interpreted as either:
1.  **Local Rename/Move:** The directory was moved within the local filesystem (e.g., to `[redacted path]
2.  **Remote Relocation:** The research root was migrated to a remote host, accessible only via patterns defined in `remote-access-patterns`.
3.  **Vantage Error:** The probe executed in an incorrect context (e.g., container vs. host), leading to a false negative.

The prior material established that **H0 (Vantage Error)** is the primary hypothesis to falsify before concluding relocation. Without decoupling state from absolute paths, the research line cannot distinguish between these three scenarios, leading to broken continuity.

#### 2. Recommendations
To contract this ambiguity into actionable engineering practices for `hngh/hngh-automation`, the following directives are crystallized:

**A. Decouple Research State from Absolute Paths (Content Fingerprinting)**
*   **Rationale:** Absolute paths are volatile identifiers. Content is invariant.
*   **Action:** Replace path-based identification with **content fingerprints**.
    *   Primary Identifier: The `.git` directory’s `HEAD` commit SHA.
    *   Secondary Marker: A unique marker file (e.g., `hngh.research-state`) within the repository root.
    *   **Probe Logic Update:** Instead of checking `test -d [redacted path] execute a content search:
        ```bash
        find [search_root] -maxdepth 4 -name ".git" -type d | xargs git rev-parse HEAD
        ```
    *   Match the resulting SHA against the last known SHA recorded in `research-lines.tsv`. If multiple candidates exist, the one matching the SHA is the valid root.

**B. Codify Vantage-Point Verification as a Precondition**
*   **Rationale:** A "clean negative" is epistemically invalid if the probe ran in the wrong context (e.g., inside a container where the host filesystem is not mounted).
*   **Action:** Wrap all path-dependent probes in a verification function that executes before logging results:
    ```bash
    # 1. Identify Host Context
    hostname
    test -e /.dockerenv && echo "CONTEXT: CONTAINER" || echo "CONTEXT: HOST"
    
    # 2. Check Path Existence
    stat -c '%U %Y' [redacted path] 2>/dev/null || echo "PATH_MISSING"
    ```
*   **Decision Rule:** Only if `PATH_MISSING` is returned *and* the host identity matches the expected research host should the negative be logged. If context is ambiguous (e.g., container), the result is discarded as inconclusive, not negative.

**C. Automate Disappearance Windowing via Shell History**
*   **Rationale:** Determining *when* and *how* a path disappeared requires correlating filesystem events with user actions.
*   **Action:** Implement an automation step in `hngh-automation` that triggers upon detecting a missing root:
    1.  Identify the mtime of the last successful probe.
    2.  Scan shell history (`[redacted path] or `[redacted path] for commands matching `mv|rsync|scp|git (clone|push|remote add)` within the last 7 days.
    3.  Log any matches to the research line as "candidate relocation events."

**D. Standardize Remote Relocation Detection**
*   **Rationale:** If the root moved to a remote host, local probes will fail. The prior material suggests checking `remote-access-patterns` and git remotes.
*   **Action:** Cross-reference Git Remotes. If the local path is missing, check if the last known SHA exists in any configured remote:
    ```bash
    git fetch --all
    git branch -r --contains [last_known_sha]
    ```
    *   If a remote branch contains the SHA, the root has likely been pushed to a remote host.
    *   Consult `remote-access-patterns` (if accessible) to determine if the remote is reachable via known patterns. *Note: I cannot verify the contents of `remote-access-patterns` as I lack filesystem access.*

#### 3. Open Threads
1.  **Verification of `remote-access-patterns`:** The prior material references this file, but its location and contents are unverified. Future beats must confirm whether this file exists in the repository or is an external configuration. If it does not exist, the "Remote Relocation Detection" recommendation (D) requires a fallback strategy (e.g., checking `[redacted path] for known hosts).
2.  **Multi-Root Ambiguity:** The content fingerprinting approach (A) assumes a single valid SHA. If the research line involves multiple active branches or forks, the probe logic must be updated to handle multiple candidate SHAs. This is not addressed in the current recommendations.
3.  **History Scrubbing Reliability:** Recommendation (C) relies on shell history being available and uncorrupted. In environments where history is truncated or encrypted, this method will fail. An alternative event-sourcing mechanism (e.g., `inotify` logs) should be explored in future beats.

#### 4. References
*   **Prior Material:** Research beat 2026-09-17 (provided in prompt).
*   **Repository Context:** `[redacted path] (hngh kernel repository; existence unverified by this agent).
*   **State File:** `research-lines.tsv` (referenced in prior material; contents unverified by this agent).
*   **External Sources:** None cited. All recommendations are derived from internal logic and standard software engineering practices. No external sources were required for verification.
