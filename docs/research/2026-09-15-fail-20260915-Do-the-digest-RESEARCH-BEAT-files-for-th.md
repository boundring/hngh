# Do the digest/RESEARCH-BEAT-* files for this line contain any raw log excerpts of the 76 mark-read responses, and if so what status codes do they actually show?

Status: crystallized 2026-09-15 from research line `fail-20260915-Do-the-digest-RESEARCH-BEAT-files-for-th`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Do-the-digest-RESEARCH-BEAT-files-for-th.md.

## Final structured summary — contracting

**Line question:** Do the `digest/RESEARCH-BEAT-*` files for this line contain any raw log excerpts of the 76 mark-read responses, and if so what status codes do they actually show?

**Final verdict:** **Unverified.** The current line material does not establish that `digest/RESEARCH-BEAT-*` contains raw log excerpts of the 76 mark-read responses. It also does not provide any actual status-code values from those responses. Therefore, no status-code distribution can be reported with confidence from this transition.

---

## Findings

1. **No raw mark-read response excerpts are present in the available line material.**
   - The supplied prior material contains a contract/probe plan for testing whether `digest/RESEARCH-BEAT-*` files exist and whether they contain raw HTTP or JSON status evidence.
   - It does not contain any actual excerpt such as:
     - combined-log style lines containing `"HTTP/1.x" NNN`
     - JSON fields such as `"status": NNN`
     - per-response mark-read log lines
   - Therefore, the question of what status codes “actually show” is not answerable from the current line record.

2. **The number “76” appears only as a census target, not as verified per-response evidence.**
   - The prior material treats “76 responses” as a framing or expected census count.
   - It does not show 76 individual raw response lines.
   - It does not show a status-code histogram summing to 76.
   - Consequently, the line must distinguish between:
     - **response-count verification**: whether exactly 76 mark-read responses occurred; and
     - **digest fidelity verification**: whether any digest files faithfully preserve those responses.

3. **The prior material explicitly treats `digest/RESEARCH-BEAT-*` as secondary evidence.**
   - The contract recommends treating the digest files as unreliable for automation unless a byte-level reconciliation with kernel-side log output proves them verbatim.
   - That means the line’s current epistemic position is:
     - possible that digests contain raw excerpts;
     - possible that they are paraphrased or summarized;
     - currently unproven either way.

4. **Kernel-side provenance remains open.**
   - The hngh kernel repository root is referenced as `/home/bricker/Projects/etc/hngh`.
   - However, the available line material does not cite a specific mark-read handler file, test file, or log-emission site inside that repository.
   - Without direct inspection of the kernel source and tests, we cannot verify what status code the mark-read endpoint actually returns under success conditions.

5. **No external sources are required to answer this line at its current state.**
   - The question is internal to the repository and the hngh kernel repository.
   - Any claim about actual digest contents or kernel behavior beyond the stated paths would require direct file inspection, which is not available in this transition.

---

## Recommendations

1. **Do not treat `digest/RESEARCH-BEAT-*` as ground truth for status-code behavior.**
   - Until rawness and census are verified, any automation decision based on digest-reported status codes is at risk of silently encoding the wrong contract.

2. **Run the probe sequence before making any affirmative claim.**
   The minimum verification sequence is:

   1. Confirm whether any matching files exist:
      ```bash
      fd -t f 'RESEARCH-BEAT' digest/
      ```

   2. If files exist, test for raw HTTP status lines:
      ```bash
      rg -n 'HTTP/1\.[01]" [0-9]{3}' digest/RESEARCH-BEAT-*
      ```

   3. Test for JSON-style status fields:
      ```bash
      rg -n '"status"\s*:\s*[0-9]{3}' digest/RESEARCH-BEAT-*
      ```

   4. Only if raw lines are found, compute the census:
      ```bash
      rg -o 'HTTP/1\.[01]" ([0-9]{3})' -r '$1' digest/RESEARCH-BEAT-* \
        | sort | uniq -c
      ```

   5. Check whether the census sums to 76:
      ```bash
      rg -o 'HTTP/1\.[01]" ([0-9]{3})' -r '$1' digest/RESEARCH-BEAT-* \
        | sort | uniq -c \
        | awk '{sum+=$1} END {print sum}'
      ```

3. **If no files exist, close the line as “data unverified.”**
   - The correct outcome would be:
     - no raw log excerpts found;
     - no status codes reported;
     - focus shifts to kernel-side logging and mark-read handler verification.

4. **If files exist but contain no raw status lines, classify the digests as non-raw or paraphrased.**
   - In that case, the answer to the line question is still negative:
     - they do not contain raw log excerpts;
     - therefore they cannot support a claim about actual status codes.

5. **If files exist and contain raw status lines, compare them against the kernel repository before trusting them.**
   - The required reconciliation is:
     - locate the mark-read handler in `/home/bricker/Projects/etc/hngh`;
     - identify the success-code contract from implementation and tests;
     - compare that contract to the digest-derived census.

6. **Preserve the two failure modes separately.**
   - A mismatch in the count of 76 is a **census error**.
   - A mismatch between digest-reported codes and kernel-emitted codes is a **fidelity error**.
   - Conflating them would corrupt downstream automation reasoning.

---

## Open threads

1. **Existence of `digest/RESEARCH-BEAT-*` files**
   - Unresolved from the current line material.
   - Must be confirmed by direct filesystem inspection.

2. **Rawness of any matching digest files**
   - Unknown.
   - The prior material only supplies a discrimination test; it does not supply the result.

3. **Actual status-code distribution for the 76 mark-read responses**
   - Unknown.
   - No per-response raw lines are present in the current line record.

4. **Kernel-side success-code contract**
   - Unverified from this transition.
   - Requires inspection of `/home/bricker/Projects/etc/hngh` to determine what status code mark-read actually returns on success.

5. **Provenance mapping between digest excerpts and kernel log output**
   - Open.
   - Even if digests contain raw-looking lines, they must be reconciled against kernel-side emission before being treated as authoritative.

---

## Direct answer to the line question

**Do the `digest/RESEARCH-BEAT-*` files for this line contain any raw log excerpts of the 76 mark-read responses?**  
Not established. The current line material does not show that they do. It only shows a plan to test whether they do.

**If so, what status codes do they actually show?**  
Cannot be reported from the available evidence. No actual status-code values are present in the current line record, and no verified census of 76 responses is available.

---

## References

- `digest/RESEARCH-BEAT-*` — target glob for the digest files under investigation; existence and contents are **not verified** in this transition.
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root referenced for provenance reconciliation; specific mark-read handler, test, or log-emission files are **not cited here because they were not verified in this transition**.
- Current line prior material for `research beat 2026-09-15` — contains the contract/probe plan and kill conditions, but **no raw log excerpts** and **no status-code census**.
