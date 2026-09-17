# 2026-09-17 — supportive-record fact corrections

Corrections of record for adversarial findings against the supportive
review wave (supportive-2, supportive-4, supportive-5) and one broken
citation. Each correction is pinned to primary evidence read this
session; downstream synthesis must ingest the corrected facts, not the
artifacts' wrong ones. Canonical context:
docs/records/2026-09-16-identity-seam-reconciliation.md.

## Correction 1 — alert latency: ~6 minutes, not ~4h06m

- Wrong claim (supportive-2): alert `fb894f8d` fired "~4h06m after the
  pair landed 00:04:04Z / 00:04:51Z".
- Ground truth: the pair's commits are stamped -0400 —
  `ba6b3905` 2026-09-13T00:04:04-04:00 = **04:04:04Z**,
  `d2d8f515` 2026-09-13T00:04:51-04:00 = **04:04:51Z**
  (`git show --no-patch --format='%h %aI %cI'` read directly). The
  alert row is 2026-09-13T04:10:41Z
  (docs/project/report-bodies/prune-archive-2026-09-15.md:82).
  Latency: **6m37s / 5m50s**. Supportive-1's "~6 minutes" is correct.
- Error mechanism: subtracting a -0400 wall-clock stamp from a Z
  alert timestamp as if both were UTC.
- Spread check: `4h.?06` matches **0** files in this repository — no
  committed record repeated the 4h06m figure; it lived in swarm
  transcripts only. The canonical record DID say the alert named the
  identity "hours after it appeared" (same timezone misread); that
  sentence is corrected in place (Alert trail section), which sharpens
  the record's point: detection was near-immediate, the ~3-day failure
  was execution, not detection.

## Correction 2 — e916af9e / 8e376ff2 are mid-window day 0, not 2026-09-16

- Wrong claim (supportive-4): the two `automation@hngh.local` commits
  are "both 2026-09-16, post-window-end identity fix".
- Ground truth (`git show --no-patch --format=fuller e916af9e 8e376ff2`):
  both author and committer dates are **2026-09-13 20:20:31 and
  20:21:07 -0400** — window day 0, hours after the window opened
  (00:04:04 -0400) — author+committer `hngh-machine
  <automation@hngh.local>` via per-command `-c` identity.
- Implication recorded in the canonical census (edited in place): the
  per-command identity cure was demonstrated in-session the same day
  the window opened, then not propagated to the ambient `.git/config`
  for ~3 days — this **strengthens** the cleanup-lag reading
  (detection and cure both existed on day 0; propagation is what
  lagged).

## Correction 3 — bypass-j child provenance, closed by verbatim reads

supportive-5 named the bypass-j children "gh-push-seam,
pat-governance, token-file-paths, credential-health" and flagged
Caveat A (uncertain whether `bypass-j-adjacent-credentials` was
coordinator-seeded or machinery-grown). Source conflicts
("split into 4" vs "decomposed into 6" vs an 8-name family census)
reconcile cleanly once the `bypass-j-adj-` prefix and the two
creation waves are separated. All lists below are verbatim tool-call
arguments recovered from `~/.jcode/sessions/` transcripts (read
edge, not inference):

1. **Parent creation — machinery-grown (gate-injected).** Session
   `rose` (session_rose_1789576986530_0919f34a0e7331d3, msg 18) ran
   `swarm inject_gap` creating **4** nodes verbatim:
   `bypass-j-adjacent-credentials`, `bypass-j-inbound-ssh-receive`,
   `bypass-j-push-surface-completeness`,
   `bypass-j-identity-verdict-reconciliation`. No coordinator session
   seeded any of these: dolphin's own seed calls were the d-graph
   (7 nodes, msg 1416) and the acp/governance graph (8 nodes,
   msg 1846); the bypass-a..e children came from `nautilus`
   (expand_node on `govmap-bypass-surfaces`: bypass-a-docs-commits,
   bypass-b-push-protections, bypass-c-research-lanes,
   bypass-d-automation-lane, bypass-e-readme-edits) and bypass-f..j
   from `bonehound` (inject_gap: bypass-f-root-gov-files,
   bypass-g-server-protection-resolved, bypass-h-gate-skip-free-lanes,
   bypass-i-ridealong-and-conventions,
   bypass-j-identity-credential-seam). Caveat A answer:
   **machinery-grown**, a gate child two hops below the coordinator's
   graph.
2. **Ant's 4 children — supportive-5's list is right, modulo prefix.**
   Session `ant` (session_ant_1789577848428_6ab267f595de5722, msg 2)
   ran `expand_node` on `bypass-j-adjacent-credentials` with exactly
   4 children verbatim: `bypass-j-adj-gh-push-seam`,
   `bypass-j-adj-pat-governance`, `bypass-j-adj-token-file-paths`,
   `bypass-j-adj-credential-health`. The ant interim report's
   "split into 4" refers to this wave. supportive-5's names match
   these ids with the `bypass-j-adj-` prefix dropped.
3. **Ox's 6 — a different wave, same parent.** Session `ox`
   (session_ox_1789579145848_01b25fcf3687a2e9, msg 2), as the
   `bypass-j-adjacent-credentials::gate`, injected 6 gap nodes
   verbatim: `bypass-j-adj-push-transport-state`,
   `bypass-j-adj-pat-live-surface`,
   `bypass-j-adj-kernel-home-secrets-inventory`,
   `bypass-j-adj-runtime-git-gh-consumers`,
   `bypass-j-adj-activation-surface`,
   `bypass-j-adj-credential-evidence-exposure`. The dolphin
   coordinator's reasoning "bypass-j-adjacent-credentials decomposed
   into 6 children" (msg 1997) refers to THIS wave, not ant's — the
   "4 vs 6" conflict is two waves seen at different times.
4. **Census reconciliation.** Total distinct `bypass-j-adj-*` node
   names: **10** (ant's 4 + ox's 6). The "8-name family census"
   counted the 8 that had reached Completed state at graph v309; the
   two ox nodes `bypass-j-adj-credential-evidence-exposure` and
   `bypass-j-adj-kernel-home-secrets-inventory` were still Blocked
   then.
5. **"credential-health appears nowhere in the dolphin transcript" is
   false as stated.** The string `bypass-j-adjacent-credentials`
   appears 29 times and `credential-health` 74 times in
   session_dolphin_1789472126868_b6fe1d64bcfa1dc6.json, including the
   bare node id `bypass-j-adj-credential-health` in the v166 Completed
   list (msg 1948). What is true: no coordinator tool call created
   any adj-* node — every adj-* node came from ant's expansion or
   ox's gate injection.
6. **The verbatim 21-seed node list, reconstructed exactly.** No single
   coordinator call seeded 21 nodes; the meter counts only
   `task_graph` calls as seeded (inject_gap / expand_node children are
   machinery-grown). Enumerating every `task_graph` call with node
   lists across all `~/.jcode/sessions/` transcripts yields exactly
   21, matching the meter progression (7 -> 15 -> 21):
   - dolphin msg 1416 (7): `d4-principles`, `d4-spec`, `d1-harvest`,
     `d2-replyparse`, `d6-routes-view`, `d1-surface`,
     `d3-memorybridge`;
   - dolphin msg 1846 (8): `acp-architecture`,
     `acp-evidence-audit`, `hngh-governance-map`,
     `injection-comparison`, `gap-analysis`, `threat-model-hngh`,
     `integration-candidates`, `comparison-doc`;
   - bonehound msg 73 (5): `bypass-f-root-gov-files`,
     `bypass-g-server-protection-resolved`,
     `bypass-h-gate-skip-free-lanes`,
     `bypass-i-ridealong-and-conventions`,
     `bypass-j-identity-credential-seam`;
   - eagle msg 20 (1): `bypass-f-root-gov-files::seed-929f2dbe`.
   Meter lines (verbatim): "7 seeded -> 8 nodes (1 machinery-grown)",
   "15 seeded -> 41/46/51 nodes", "21 seeded -> 94 nodes (73
   machinery-grown)" (v213), "21 seeded -> 122 nodes (101
   machinery-grown)" (v309). 7 + 8 + 5 + 1 = 21 exactly; no
   coordinator seeded any `bypass-j-adj-*` node.

## Correction 4 — the 07:15Z handoff row lives in automation/agent-handoffs.md

- Wrong claim (supportive-4 follow-up): plan line
  docs/project/plans/2026-09-09-presentation-pass-1.plan.md:108 cites
  "the handoff row at 07:15Z" but no such row exists in
  automation/STATE.md.
- Ground truth: the row exists verbatim at
  **automation/agent-handoffs.md:113** —
  `overnight-lead | 2026-09-13T07:15:00Z | 2026-09-09-presentation-pass-1|run-1 | rc=0 blocked step=5 unchanged: gate re-verified red on exactly ba6b390 (patch-id a46ed8ae...) + d2d8f51 (patch-id cef31fa5...) ...` —
  mirrored verbatim in the harvest at
  docs/project/lessons-2026-09-13.md:75. It never lived in
  automation/STATE.md (that file carries cadence ticks only; its only
  07:15 hits are 2026-09-08 rows). The plan's citation was real but
  under-specified; fixed in place to name the file. The alert chain
  also survives verbatim in
  automation/logs/overnight-2026-09-09-presentation-pass-1-20260913T000118.log
  (fb894f8d named at line 25) and .json (11 handoff mentions).
- Related archival note: the reports-ledger row for fb894f8d was
  pruned 2026-09-15 to
  docs/project/report-bodies/prune-archive-2026-09-15.md:82 — the
  ledger no longer carries it at top level, which is the prune
  convention, not data loss.

## Net effect on the supportive wave

- supportive-1: unchanged (its ~6 minutes was correct).
- supportive-2: latency figure corrected (timezone misread).
- supportive-4: the two commits move from "post-window-end fix" to
  "day-0 demonstration"; cleanup-lag reading strengthened.
- supportive-5: child list correct modulo the `bypass-j-adj-` prefix;
  Caveat A closed as machinery-grown with verbatim creation-chain
  evidence; the 4-vs-6 and 8-name conflicts reconciled as separate
  creation waves and a state-filtered census.

## Open questions

- Whether any downstream consumer already ingested the wrong
  figures from swarm artifacts (artifacts are append-only
  transcripts and are not edited; this record supersedes).
