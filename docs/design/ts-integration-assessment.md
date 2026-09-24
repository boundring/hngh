# Typesafe integration assessment (hngh-ypb synthesis)

Status: ASSESSMENT - synthesis of banked artifacts only, no new analysis.
Absorb entry: `docs/project/decisions.md` 2026-09-18 (hngh-4m1 absorb-and-record;
tracked remainder exactly this bead). Propagation record:
`docs/records/2026-09-18-beads-jev-propagation.md` (`801a2e3c`).

## 1. typesafe.py wrapper (`10cccb2d`)

Thin Jev/Typesafe inference wrapper (`automation/lib/typesafe.py:1-107`):
`ask_noul` (`typesafe.py:40-56`) and `ask_choice` (`typesafe.py:59-81`)
go through `TypeSafeClient.system_one` with Noul/Choice/Score calls at
~0.6s each (`typesafe.py:4`), never agent-grade inference. Fail-closed:
without `TYPESAFE_API_KEY` every helper returns None and the caller falls
back (`typesafe.py:41-45`, `typesafe.py:60-64`); values are never logged,
one breadcrumb per UTC day max on fallback (`typesafe.py:7`, `typesafe.py:27-37`).

SDK spike numbers (banked, propagation record): tested live at noul 0.92
in ~1s; fail-closed path returns None without key. Without the SDK
installed and no live key, the deterministic rule applies (absorb-and-record
rather than keep-open) per the decisions.md 2026-09-18 entry.

## 2. Beat-skip gate (`d740d967`)

Jev beat-skip gate in `model_call` (`automation/lib/model.sh:937-966`):
before touching local Unsloth, `beat_skip_gate` (`typesafe.py:84-97`,
threshold `v >= 0.5` at `typesafe.py:97`) asks whether the operator is
actively using the machine. `SKIP_LOCAL=1` bypasses both Unsloth sites
(primary at `model.sh:967` and the ranked-fallback loop at `model.sh:974-984`).
Verdict cached 30s in `$AUTOMATION_ROOT/tmp-beatskip.txt`
(`model.sh:945-966`; safe 2/min lane: at most ~2 inference calls per minute
even under beat bursts, `model.sh:941-942`). Fail-open: without key or on
any error the existing quiet guards decide, never this gate (`model.sh:942`).

## 3. vip-gate (`f1a43f9f`)

Midnight gate + defer guard for heavy Unsloth runs
(`automation/lib/vip-gate.sh:1-67`): midnight window 00:00-05:00 local
(`vip-gate.sh:24-25`) first, then the beat-skip verdict file consumer
(`vip-gate.sh:53-67`; missing/unreadable file is fail-open). Wired into
`automation/jobs/model-bench.sh:13-17` and
`automation/jobs/night-research.sh:11-15` as fail-closed exit 0 with a
`vip-defer` breadcrumb. Verified: bash -n clean on all three scripts;
dry-run matrix (daytime defer, in-window keep proceed, in-window skip defer,
job-level exit 0 with breadcrumb).

## 4. Decision map (banked per-bead questions)

From the propagation record: `hngh-4m1` absorb = Choice (asked, fail-closed,
deterministic rule applied); `hngh-vip` Unsloth = Noul beat-skip (wired);
`hngh-4j4` reviewer gates = Score per gap (pending, not this bead).

## 5. Safe / burst lanes

The beat-skip gate runs on the safe 2/min lane (`model.sh:941`): the 30s
verdict cache bounds Typesafe inference to ~2 calls/minute even under beat
bursts. Heavy Unsloth work (fleet bench, night research) is the burst lane:
full-model inference gated to the overnight window by vip-gate, and further
deferred while the safe-lane verdict says the operator is active. Direction
is inward: bursts never preempt sessions; guards fail toward existing paths.

## Remainder

None banked beyond this doc. `hngh-4j4` Score gates and any new Typesafe
questions are separate beads, not remainder of this synthesis.

## Cookbook catalogue (2026-09-24)

catalogued for our use; the seam mapping drove the typed decision seams in
automation/lib/typesafe.py, automation/ng/jev.py, 33-research-beat.sh,
06-review-disposition.sh, oversight-tick.sh

1. consistency_noul_cookbook (https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md) -
   repeat-stability of routing judgments | 14x Noul per run, 15 repeats |
   uncertainty band (no <0.30, uncertain 0.30-0.70, yes >0.70) absorbs wobble
   around 0.5; escalation is code over the returned probability, no 2nd call.
2. consistency_choice_cookbook (https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md) -
   label decisions that must route stably (moderation action/queue/severity) |
   8x Choice, 15 repeats | top-prob >= 0.60 else emit 'uncertain' -> human;
   abstention replaces competing labels with one review outcome; agreement
   90.8% -> 99.2%.
3. parallel_questions (https://docs.typesafe.ai/cookbooks/parallel_questions.md) - one document, N
   independent questions; batch or not | 8 Noul + 2 Choice + 3 Score in ONE
   request | batching is answer-neutral (std dev unchanged) and 12.2x cheaper
   / 10.0x faster because the shared doc is paid once -> add speculative
   questions freely.
4. rerank_typesafe (https://docs.typesafe.ai/cookbooks/rerank_typesafe.md) - reorder a BM25 shortlist
   | 1 Noul per pair, fixed true/false criteria, sort by noul | noul IS a
   comparable 0-1 score on a fixed standard; no invented scale (top-1
   5%->18%, top-10 38%->62%).
5. semantic_find (https://docs.typesafe.ai/cookbooks/semantic_find.md) - which lines answer a query
   AND whether an answer exists | Choice over line IDs (<=255) + companion
   Noul 'exists', one request | Choice probs sum to 1 so some line always
   ranks first; the independent Noul separates WHERE from WHETHER (rank 0.86
   but exists 0.14 = absent).
6. autoformat (https://docs.typesafe.ai/cookbooks/autoformat.md) - rebuild Markdown from stripped
   text without rewriting words | Pass 1: Noul per adjacent line-pair (join?);
   Pass 2: Choice per block (type) + speculative companion questions | model
   answers narrow questions, code renders - every output char comes from
   input; 2 requests, 0.8s, $0.0015.
7. function_calling (https://docs.typesafe.ai/cookbooks/function_calling.md) - NL command -> typed
   function call with closed-set args | Choice per Literal arg, 'stated' Noul
   per optional arg, Noul per set member, Choice over tools; 54 questions per
   command, one request | map the function's own signature into questions so
   answers are always values the function accepts; confidence = min over
   judgments; defaults stand when 'stated' says no.
8. skill_suggestion (https://docs.typesafe.ai/cookbooks/skill_suggestion.md) - pick at most one skill
   (or none) from a 182-item roster | Call 1: Choice over 182 one-liners + 3
   Nouls; Call 2: Choice over top-3 + fit Nouls with full descriptions |
   progressive disclosure: skim all cheaply, re-read top 3, free to reject
   all (wrong loads 16.8%->7.3%, needless loads 9.8%->4.0%).
9. entity_alignment (https://docs.typesafe.ai/cookbooks/entity_alignment.md) - per candidate pair:
   duplicate / related / different | 1 Score with 3 ordered levels + 3
   companion Nouls (which fields match), one request per pair | Score keeps
   ordered outcomes AND a written middle level (curator queue) with no fitted
   threshold; companion nouls say WHICH fields disagree; numeric fields left
   to code.
10. classifying_rag_passages (https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md) - gate
    retrieved passages before generation | 4 Nouls per passage (relevant /
    usable evidence / contradicts premise / injection), thresholds in code |
    separates assessment from policy: all policy numbers in a THRESHOLDS
    dict; catches injection (0.584) vs premise-refuting doc (0.509) where
    embedding spread cannot.
11. citation_check (https://docs.typesafe.ai/cookbooks/citation_check.md) - verify LLM citations
    against the source | string match for quote presence, then 1 Choice
    (supports/contradicts/says_nothing) per surviving citation; conf >= 0.8
    auto-accepts | fabrication needs no model (substring match); Choice over
    section context catches quote-true-claim-false (4/4 planted failures).
12. llm_guardrails (https://docs.typesafe.ai/cookbooks/llm_guardrails.md) - screen every message
    in/out: pass/review/block/support | 4 Noul hazard battery + 1 Score
    severity in one request; per-hazard actions, two thresholds, named
    POLICIES, precedence list | splits 'out of bounds' into atomic hazards so
    each triggers its own action; policy = numbers under a name,
    product-owned, not prompt-buried.
13. sde_cascade (https://docs.typesafe.ai/cookbooks/sde_cascade.md) - cheap extractor makes mistakes;
    verify cheaply, escalate rarely | per-field Noul verifiers P(value wrong)
    / P(absent), code gate: any P > 0.7 escalates to reasoning model | the
    verifier is 1/7th the strong model's price ($0.042 vs $5/Mtok input) and
    fires per-field, so escalation is targeted not blanket.
14. date_extraction_cookbook (https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md) -
    absolute/relative dates without calendar math | 7 Choices in one call
    (mode, month, day, year 1900-2050 + none/out_of_range, day_anchor,
    weekday, week_offset) | model reads parts, code does calendar math and
    validation (Feb 30 -> review); confidence = min of used parts.
15. pre_parsed_value_extraction_cookbook
    (https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md) - select a verbatim
    value (email/phone/amount) from messy text | regex over-finds candidates;
    Choice picks among spans (+ 'none' hatch) | the answer is always a
    verbatim copy of a regex span - the model cannot invent or transpose
    digits; normalization is code.
16. hierarchical_classification (https://docs.typesafe.ai/cookbooks/hierarchical_classification.md) -
    classify down a deep taxonomy | Choice per node, children as options;
    greedy or beam (K parallel paths), path score =
    product(edge_probs)**(1/decisions) | beam over parallel questions lets
    deeper evidence repair an ambiguous early decision.
17. autoresearch_feature_discovery
    (https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md) - free text -> numeric
    features for a supervised regressor | Score (intensity) + Noul (presence)
    per feature; LLM proposes add/revise/drop of questions; CatBoost trains |
    the loop feeds model errors back into QUESTION WORDING (RMSE 3.09 ->
    1.77 over five rounds, most gain in round 1).
18. classification_using_confidence
    (https://docs.typesafe.ai/cookbooks/classification_using_confidence.md) - N-way classification
    with graceful degradation | 1 Choice over 75 groups; read the answer's
    own confidence | confidence < 0.9 -> report the parent division; a broad
    label follows from the narrow one at zero extra calls (unsure half
    40%->70% one level up).

SEAM MAPPING (the load-bearing design output; the fuller guardrails-style
precedence lists are "adopt later" - this slice keeps the one arbiter rule).

(a) Research review verdict (adopted|parked|killed): one request per line,
state = {line digest, supportive-pass findings, adversarial-pass findings,
quoted claims}. Verdict = Choice {adopted, parked, killed} with written
criteria; the middle option wording is load-bearing (entity_alignment
curator-level trick) and must cover "supportive pass liked it, adversarial
pass raised something unrefuted". Companion Nouls in the SAME request
(supportive_evidence_holds, adversarial_objection_valid, passes_agree)
annotate the verdict for review; they do not gate it in this slice. Quote
verification (citation_check trick: string-match quotes first, zero model
cost) and the guardrails precedence list (fabricated quote -> killed;
objection >= 0.7 AND holds < 0.5 -> parked) are adopt-later. Threshold:
consistency_choice's top-prob >= 0.60 bar is the verdict confidence floor.

(b) Review finding severity (P1|P2|nit): one request per digest, state =
digest text with each finding line tagged F001, F002...; one Choice per
finding ("How severe is finding F001?" over P1 = "blocks landing or loses
data/correctness", P2 = "should fix before merge; degrades behavior", nit =
"style/preference, no behavior change") batched fan-out style. Every finding
carries its typed severity and probability (nits stop being silently
dropped by accident; whether nits are skipped becomes a policy constant in
code, per llm_guardrails). The two-Score matrix (likelihood_real x
impact_if_real) is adopt-later - only if the P1/P2 boundary proves contested.

(c) Oversight steer (advisory): one request over the recent tail verbatim.
Core = one Noul "Does this execution tail show repeated identical execution
with no distinct progress?" with explicit criteria (true = "consecutive
steps repeat the same action against the same state with no new artifacts,
conclusions, files, or state changes"; false = "each step produces an
observable change or advances the goal"). Fire the steer-model call at
P(stalled) >= 0.7 (sde_cascade FIRE_T pattern); below, annotate only.
Advisory only - no block/review routing, breadcrumb is the surface.

(d) Bead triage (file|retry|escalate|close): one request per bead. Choice
over the four labels with written level descriptions defined before seeing
data (entity_alignment trick); companion Nouls
(blocked_on_dependency, prior_failure_transient, already_satisfied) annotate
for the human; numeric fields (age_days, attempts) stay in code with code
overrides after the answer (e.g. age_days > 14 AND retry -> escalate).
NOTE: this seam already runs a typed lane locally (automation/ng/jev.py +
ng/cadence.py LABELS = file/retry/escalate/close with fail-closed ESCALATE);
the mapping's companion-Noul + code-override refinements are catalogue-only
in this slice (ng/cadence's attempts-exhausted and ceiling gates already
supply the code policy). tier_hint stays a hint the Choice verifies.

SHORTLIST. Adopt now: parallel_questions/fan-out (every seam below is many
judgments over shared state - batching is the default request shape);
classification_using_confidence (a trust axis for verdict and severity; the
uncertain/fallback branch is nearly free and fixes silent nit-dropping);
llm_guardrails (the reusable decomposition: model assesses, code owns policy
- thresholds, precedence, named policies); entity_alignment (multi-outcome
with a written middle outcome + companion Nouls for explainability - maps
directly onto verdict and disposition); consistency_choice (the concrete
threshold-else-'uncertain' mechanism). Adopt later: citation_check (when
research evidence carries verbatim quotes worth verifying); skill_suggestion
(when the skill/bead index outgrows trivial size); sde_cascade (when a cheap
generator feeds these judgments); function_calling (if dispositions gain
closed-set arguments); hierarchical_classification (only if taxonomies
deepen past ~4 flat labels). No seam today: autoresearch_feature_discovery,
rerank, semantic_find, autoformat, date_extraction, pre_parsed,
consistency_noul.
