# Is there a migration log or changelog entry in the `hngh` repository that documents when version-pinning fields (e.g., `commit_hash`) were added to or removed from the `research-lines.tsv` schema?

Status: crystallized 2026-09-22 from research line `fail-20260922-Is-there-a-migration-log-or-changelog-en`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Is-there-a-migration-log-or-changelog-en.md.

# Final Structured Summary — `hngh` `research-lines.tsv` Schema Migration-Log Line

**Line:** Is there a migration log or changelog entry in the `hngh` repository that documents when version-pinning fields (e.g., `commit_hash`) were added to or removed from the `research-lines.tsv` schema?
**Disposition:** Contracted. Closed as a *methodology-plus-deferred-verification* record. The decisive yes/no answer is not resolvable from this host; it is handed to an idle host with local access to the kernel repository. No claim below is asserted beyond what prior material established, and every unverified item is labeled as such.

---

## Findings — Grounded

**F1 · Grep tab-escape trap (established).** GNU grep treats `\t` as a stray escape sequence, so `grep '\t'`-style field checks match nothing and fabricate "field absent" results. Any prior claim of absence derived from such a grep is invalid. Field-presence checks must use `awk -F'\t'`. *(Prior art: [[sources/grep-tab-escape-matches-nothing]].)*

**F2 · Timezone rendering trap (established).** Local-time git date display can displace or appear to omit commits, fabricating "missing" history. Date filtering on displayed local time is unsafe. Use `--all` plus ISO-8601 UTC (`%aI`) so timestamps are unambiguous. *(Prior art: [[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]].)*

**F3 · The question is two-part and neither part is answered in this record.** (a) Does a migration log / changelog entry documenting add/remove of version-pinning fields exist? (b) If so, when? No material in this line records an executed result for either. The line therefore terminates as *open-verification*, not as a settled fact.

## Findings — Unverified Hypotheses (explicitly NOT confirmed; do not cite as fact)

**H1 · "No dedicated migration/changelog file exists."** Prior material phrased this as the "core finding," but it was reached *without* access to the repository and rests on a convention assumption ("standard `hngh` kernel layouts"). It is a **prediction**, not a verified property of `[redacted path] It is falsifiable by the `find` step in Recommendations; treat as open until that step runs.

**H2 · "Schema evolution is tracked exclusively via git commit history + inline TSV header comments."** Same status: inferred from convention, unverified against this repository. The commit-message-as-documentation model holds *if* H1 is true, but H1 is not yet established.

> Honesty note: I cannot inspect the repository from here. I assert no internal file path as existing except where the line itself presupposes it (see References). Anything requiring a source outside this local repository is flagged rather than asserted.

## Recommendations — for an idle host with local access to the kernel repository

Run in sequence; each step's expected outcome is a *prediction*, not a confirmed result.

**Step 1 — Confirm exact file location (resolves path redaction in prior record).**
```bash
find [redacted path] -type f -name 'research-lines.tsv' 2>/dev/null
```
Record the resolved path; all subsequent commands use it. Do not assume root placement.

**Step 2 — Field-aware header parse (never `grep '\t'`).**
```bash
awk -F'\t' 'NR==1 {print "NF=" NF; for(i=1;i<=NF;i++) print i": "$i}' <resolved-path>
```
- `commit_hash` present in the header → field is **currently present**; proceed to Step 3 for the addition event.
- Absent → either never added or removed; Step 3 distinguishes.
- Capture *all* pinning columns, not just `commit_hash` (see Open Thread O3).

**Step 3 — Full history scan, date-agnostic, UTC-stamped.**
```bash
cd [redacted path]
git log --all --format='%H %aI %s' -- <resolved-path>
# Per candidate commit, inspect the header at that revision:
git show <COMMIT>:<path> | head -1   # repeat for each hash from above
```
Decision rule:
- **Addition event** = first commit (oldest in the scan) whose header contains `commit_hash`.
- **Removal event** = a commit where the field is present in the parent revision's header but absent in this one.
- The answer to the line's question per field is binary: *documented by commit X* (the commit message/diff is the documentation) vs. *no dedicated entry; change is implicit in the diff*.

**Step 4 — Falsify H1 (changelog existence).**
```bash
find [redacted path] -maxdepth 2 -type f \
  \( -name 'MIGRATION*' -o -name 'CHANGELOG*' -o -name '*schema*.md' -o -name '*migration*.tsv' \) 2>/dev/null
```
- Empty → H1 survives as the best-supported reading; record "git history is the sole authoritative record" *for this repository* (not as a generalizable claim).
- Non-empty → inspect for `commit_hash` references; **re-open the line** and supersede this summary.

## Open Threads

- **O1 · Execute Steps 1–4 on an idle host** and report: resolved path, current header field list, and the `git log --all` sequence for `research-lines.tsv`. This is the single action that converts H1/H2 into findings or falses them.
- **O2 · Confirm exact subpath** of `research-lines.tsv`; prior record redacted it. Step 1 closes this.
- **O3 · Scope of "version-pinning fields."** The line names `commit_hash` as an *example*, implying a possible family (e.g., tag/ref pins, lockfile hashes). Step 2's full header dump must enumerate every pinning column so the add/remove analysis covers the whole family, not one field.
- **O4 · Contingency:** if Step 4 surfaces a changelog/migration file, this line reopens and the "git-history-only" model is discarded in favor of that artifact as the authoritative record.

## Boundary Statement

- Grounded: F1, F2, F3 (methodology and the honest status of the question).
- Unverified / prediction-only: H1, H2, and every "expected outcome" above.
- No external sources are required; resolution is entirely local (`awk` + `git`). Any generalization of "standard `hngh` kernel layouts" beyond this one repository would need external verification and is out of scope here — flagged, not asserted.

## References

- `[redacted path] — kernel repository root as stated for this line; internal layout **unconfirmed from this host**.
- `research-lines.tsv` — subject file within the `hngh` repository (existence presupposed by the line); exact subpath to be confirmed per O2.
- [[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]] — prior lesson on whether the schema includes the pinning field.
- [[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]] — basis for F2.
- [[sources/grep-tab-escape-matches-nothing]] — basis for F1.
