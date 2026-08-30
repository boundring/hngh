# ceremony-cost reduction: batching kernel doc landings safely

Status: crystallized 2026-08-30 from research line `ceremony-cost-reduction-batching-kernel-doc-landings-safely`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ceremony-cost-reduction-batching-kernel-doc-landings-safely.md.
Grounded rewrite 2026-08-30: the original crystallization asserted
PR/CI/Sphinx/type-stub/release-tagging mechanics that do not exist in
this repo (no CI workflows, no Sphinx, no `.pyi` stubs, no release
tags — Hngh lands everything through the self-governed certificate
ceremony). That machinery is the named foldback anti-pattern
(docs/records/2026-08-30-lessons-and-foldback.md §2 lesson 3: research
volume is cadence-bound, quality is grounding-bound). This rewrite
keeps the line's directional conclusion and re-grounds it in what the
repository actually has.

## Conclusion (kept, now grounded)

Each hngh docs landing pays a fixed ceremony cost: a fresh store run,
transport admission, a ten-principle propose pass, issue-cert evidence
gathering over the candidate paths, and the two-action
prepare-candidate/commit mutation — plus a green `make test`
before and after. For one small doc that overhead dominates the change
itself. Therefore **batch doc landings**: accumulate independent
docs-only artifacts (research crystallizations, plan files, records,
journal) and land them in ONE certificate ceremony with candidate
paths = exactly those files, rather than one ceremony per file.

Safety boundary, grounded in the actual gate: the batch is safe when
every candidate path is a docs path (`docs/**`) — the gate that
protects the kernel (`make test`: 8 reader guards + suite + ASDF,
currently 2,855 checks) runs unchanged before issue-cert and is the
only verification a docs-only batch needs. Any candidate set that
would touch `src/`, `tests/`, `Makefile`, or `hngh.asd` is not a
docs batch: kernel changes are forbidden to machine sessions by the
standing autonomy rule and park instead.

## Findings (grounded rewrite)

- **F1 — the ceremony has a fixed per-landing floor.** The dogfood
  loop (create-run → admit-transport → propose with one evidence
  requirement per principle → issue-cert → mutation-check
  prepare-candidate/commit) is per-commit work regardless of how many
  files ride it; the 2026-08-28 overnight plan already noted
  whitespace normalization was the only refusal across a multi-file
  landing. Batching N docs into one candidate amortizes the fixed
  part across N files.
- **F2 — the historical stall was landing cadence, not ceremony
  safety.** The six crystallized research docs of 2026-08-28→29 sat
  uncommitted ~36h because each needed a ceremony and no plan drove
  one (foldback §1); today's three 2026-08-30 research lines sat
  untracked the same way until this batch. The fix is scheduling
  (a plan step that owns a batched ceremony), not a lighter gate.
- **F3 — precedent applied live.** The 2026-08-30 evening wave lands
  its plan files, the grounded research rewrites, and the record in
  one ceremony commit with `make test` green immediately before —
  this document's conclusion applied by its own repo.

## Recommendation

Keep per-slice ceremonies for anything coupled (a doc that changes a
contract doc alongside kernel behavior); batch the rest. A plan step
of the shape used today — "land all accumulated research docs in ONE
ceremony, `make test` green immediately before, candidate paths =
docs files only" — is the whole mechanism; no new tooling is proposed
(this repo has no PR/CI lane to route; the certificate loop IS the
landing protocol).

## Open threads

- Whether the day-tier research beat should append its crystallized
  docs to a standing "pending docs batch" list so the next ceremony
  driver finds them without a sweep (follow-on candidate).
- Cross-repo doc references (hngh docs citing hngh-automation paths)
  have no link guard today; the doc-numbers guard covers README
  counts only.

## Grounding

Verified paths read in this repo while rewriting (2026-08-30):

- `scripts/hngh` — the governance CLI (propose/issue-cert/mutation-check verbs)
- `scripts/ceremony-drive` — ceremony driver invoked by the bridge
- `scripts/omp-bridge` — documents the ceremony-invoke wrapper and store behavior
- `Makefile` — `make test` gate composition
- `docs/project/plans/2026-08-28-overnight-continuity.plan.md` — prior
  batched ceremony landing (candidate `5fe88ae0`, commit `16f6344`)
- `docs/records/2026-08-30-lessons-and-foldback.md` — the
  crystallized→committed stall and the anti-pattern naming
- skill://hngh-dogfood-commit-ceremony — the ceremony loop this line's
  cost model is built from

Not established here: exact per-ceremony wall-time cost (no telemetry
row was captured for a docs-only ceremony at authoring time); the
batching saving is argued from the fixed step count, not measured.
