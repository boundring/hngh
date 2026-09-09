# 2026-09-09 — lessons + next plan

## Status
accepted. Evidence reviewed 2026-09-09T23:00Z.

## Lessons from 2026-09-03 staging plan

### What worked
- Steps 2–7 executed in order with strict grow/research alternation
- Dashboard tabs fetched via browser automation (single-page app, hash routes)
- Stall-recovery evidence verified from logs (3 session-run attempts, first stalled, second landed step 1, third closed plan)
- Publication --site run completed (27,378 bytes, 7-file contract)

### What didn't work
- Bench jsonl files for 09-01/02/03 missing (only 08/09 available)
- Dashboard tabs are client-side routes, not separate URLs (needed browser automation)
- Publication output is a flat HTML page with no navigation (no TOC/anchors/dates)

### Foldback lessons
1. **Bench probe calibration**: p1_reader is a keyword-matching artifact, not a semantic discriminator. Recalibrate with regex matching reader-macro patterns.
2. **Stall recovery**: The 2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7 plan ran 3 times (00:30:34, 00:34:13, 01:09:39) before completing. This matches the plan's note about stall recovery.
3. **Dashboard structure**: Single-page app with hash routes (#schedule, #sessions, etc.), not separate URLs. Browser automation required for tab fetching.
4. **Publication pipeline**: --site run consumes 7-file contract, generates flat HTML. No navigation, no TOC, no verification hook.

## Next plan: 2026-09-09-stall-recovery-and-operator-surfaces

### Steps
1. **GROW — wake-mutation-lane rotation beat** (step 1 of 2026-09-03-staging, executed 2026-09-09T16:24Z)
   - Boundary proposal certified, park alert filed
   - FORBIDDEN clause superseded by operator-flexibility doctrine §2

2. **RESEARCH — bench probe calibration** (step 2 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - p1_reader is a keyword-matching artifact
   - Recalibrate with regex matching reader-macro patterns
   - Multi-day threshold rule for delegated-lane gate (3/5 across 3 consecutive days)

3. **GROW — stage-2/3 exit-criteria verification** (step 3 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - Stage 2: dashboard up, all tabs identifiable (VERIFIED)
   - Stage 3: full delegation cycle witnessed end-to-end (VERIFIED)
   - Not established: browser-graded mobile sweep, operator-item lifecycle

4. **RESEARCH — unsloth recovery/local-lane** (step 4 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - Unit states: llama-server.service disabled, unsloth-warm.service disabled, unsloth-studio.service active
   - Model file: /home/bricker/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/snapshots/78e1321ef86b69126dc991f481bb0cdc37614ed0/Ornith-1.0-35B-UD-Q2_K_XL.gguf (12.25 GB)
   - Operator-supervised start path required (critical-class systemd unit edit)

5. **GROW — publications pipeline --site increment** (step 5 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - --site run completed (27,378 bytes)
   - Gap inventory: 3 of 8 research docs missing, 31 of 38 research-lines.tsv entries absent
   - No TOC/anchors/dates/line ids, no publish path

6. **RESEARCH — stage-4 package upgrade runbook** (step 6 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - Runbook outline: probe inventory → bind certificate → fresh evidence → operator supervision gate → mutation → rollback
   - Operator-supervised boundary: operator issues allow/deny gate (step 4)
   - Execution parked for operator supervision

7. **GROW — wrap, lessons, author next plan** (step 7 of 2026-09-03-staging, executed 2026-09-09T23:00Z)
   - Lessons documented
   - Next plan authored (this file)

## Parked follow-ons (for next plan's author)
- The `:wake-mutation` kernel src mutation itself — operator-landed or explicitly authorized
- Returning the 35B server to service (llama-server.service / unsloth-warm.service start or unit amendment)
- Browser-graded mobile-width sweep of every dashboard tab
- ebook-book-inputs (manuscript/outline/metadata set)
- Fold sibling automation slice's prompter + digest section into next plan once it lands in hngh-automation

## Kernel gate

`make test` passes (2855 checks, 2026-09-09T23:00Z).
