# 2026-09-17 provider legal posture: armed outbound model legs

Task origin: ts-angle3-provider-legal-map (explore follow-up to ts-angle3-legal-posture,
which scored typesafe.ai documents; typesafe.ai is not referenced anywhere in the repo and
no typesafe leg is armed). This artifact scores each provider the automation actually
calls out, with the claim/quote/verdict shape. Sources fetched live 2026-09-17.

## Armed outbound legs (verified in-repo)

- `automation/cadence-params.tsv:22` kimi-endpoint `https://api.kimi.com/coding/v1/chat/completions` (armed, KIMI_AI_KEY verified live 2026-09-07)
- `automation/cadence-params.tsv:26` remote-model-coding `google/gemini-3.8-flash` via OpenRouter (armed, paid cash)
- `automation/cadence-params.tsv:30` zai-endpoint `https://api.z.ai/api/coding/paas/v4/chat/completions` (armed, Z_AI_API_KEY, 2026-09-13)
- `automation/cadence-params.tsv:34` opencode-url `https://opencode.ai/zen/go/v1/chat/completions` (armed, 2026-09-10)
- Reviewer-local endpoint `http://127.0.0.1:8888` never leaves the machine (not scored).
- Sole outbound chokepoint: `automation/lib/model.sh` `model_call`. Reply-side path scrub
  only (model.sh:82-99, "input hygiene stays with caller"); `archive_only` (model.sh:441-449)
  persists raw prompts unredacted to `automation/archive/` (local disk only, never committed).

## Per-provider verdicts

### 1. Kimi (Moonshot AI) — verdict: NO-TRAINING CONFIRMED, retention NOT zero by default

- Claim: platform does not train on customer data by default; retention of prompts is
  not eliminated unless the enterprise ZDR mode is enabled (it is not armed here).
- Quote (platform.kimi.com/docs/guide/zero-data-retention.md, fetched 2026-09-17):
  "Kimi 开放平台默认不使用企业客户数据训练模型，ZDR 在此基础上进一步取消内容留存。"
  (= "The Kimi open platform by default does not use enterprise customer data to train
  models; ZDR further cancels content retention on that basis.")
- ZDR scoping caveat, same doc: ZDR is enterprise-opt-in ("按需开放给企业客户"), and even
  ZDR excludes direct file uploads, Hosted Agents data, security/billing logs, and
  third-party models/connectors/plugins.
- Gap: a consumer/general ToS privacy policy covering non-enterprise coding-plan API
  traffic (api.kimi.com/coding) was not retrievable this session (kimi.com pages render
  JS-shells; no public privacy URL found). The no-training claim is platform-doc-backed;
  the retention default (how long prompts persist for non-ZDR accounts) is UNVERIFIED.
- Risk to hngh: prompts citing concrete kernel file paths leave the machine and are
  retained server-side for an unknown period on a non-ZDR account.

### 2. OpenRouter — verdict: NO-TRAINING BY OPENROUTER CONFIRMED; UPSTREAM PROVIDER TRAINING PERMITTED

- Claim: OpenRouter itself never trains on inputs/outputs, but forwards Inputs to model
  providers whose own training use is permitted and governed by their terms.
- Quotes (openrouter.ai/privacy, Last Updated August 31, 2026, fetched 2026-09-17):
  - "**OpenRouter does not use your Inputs or Outputs for model training.**"
  - "Some Model Providers may use your Inputs and Outputs for model training or
    improvement. ... Where disclosed to us, we label Models that do not use your data
    for training. If you do not want your Inputs used for model training, select a
    Model or Model Provider that commits to not using your data for that purpose."
  - OpenRouter also de-identifies Inputs/Outputs from user ID for aggregated analytics
    and may share those aggregates with corporate partners (Privacy Policy §2).
- hngh leg detail: `google/gemini-3.8-flash` is routed to Google as the upstream model
  provider; Google's own Gemini API data-use terms (paid tier no-training vs free tier)
  were NOT fetched this session and therefore the upstream leg's training posture is
  UNVERIFIED. OpenRouter's per-provider data-practice listing
  (docs/features/provider-routing#terms-of-service) is the next check.
- Risk to hngh: mixed. Gateway is clean; upstream Google posture unproven.

### 3. Z.ai (Zhipu GLM, coding plan gateway) — verdict: NO-TRAINING + NO-CONTENT-RETENTION CONFIRMED for API services

- Claim: API-services content is not stored and not used for training (consumer website
  terms differ and do allow model improvement, but the armed leg is the API/coding-plan
  gateway).
- Quotes (docs.z.ai/legal-agreement/privacy-policy, Last Update September 29, 2025,
  incorporating the Data Processing Addendum for API Services, fetched 2026-09-17):
  - DPA §4(b): "The Company do not store any of the content the Customer or its End
    Users provide or generate while using our Services. This includes any texts, or
    other data you input. This information is processed in real-time ... and is not
    saved on our servers."
  - DPA §1(a): process Customer Data only on Customer's behalf to provide the API
    Services, per written instructions (no training purpose granted).
- Counter-signal (consumer tier, same page §3): "developing, improving, or promoting
  our Services, such as when we train and improve our models" applies to the consumer
  Services, not the API DPA; the DPA text is the governing instrument for the armed leg.
- Risk to hngh: lowest of the four legs. Content processed in real time, not stored.

### 4. OpenCode Zen (opencode.ai/zen gateway) — verdict: ZERO-RETENTION NO-TRAINING CONFIRMED for paid models; EXPLICIT TRAINING EXCEPTIONS on free/stealth models

- Claim: Zen's providers follow zero-retention, no-training for paid models, with named
  exceptions; the armed leg's model is paid-tier GLM.
- Quotes (opencode.ai/docs/zen/, last updated Sep 17 2026, fetched 2026-09-17):
  - "All our models are hosted in the US. Our providers follow a zero-retention policy
    and do not use your data for model training, with the following exceptions: ..."
  - Named exceptions: Big Pickle, MiMo-V2.5 Free, Ling 3.0 Flash Fin Free, Nemotron
    3 Ultra/3.5 Lightning Free (NVIDIA trial logging), OpenAI APIs (30-day retention),
    Anthropic APIs (30-day retention), "Muse Spark 1.3 Contributor Free: Heavily
    discounted token pricing in exchange for permission to use your prompts and
    completions to train future Meta models."
  - "Union Alpha Free ... Its provider follows a zero-retention policy and does not use
    your data for model training."
- hngh leg detail: opencode-model is `glm-5.3-flash` (cadence-params.tsv:36), a paid
  model, not on the exception list. Verdict: clean for the armed configuration; would
  flip if the model row were ever repointed at a free/stealth model (Big Pickle,
  MiMo, Muse Spark contributor variants are the dangerous slugs).

## Cache-to-memory / pathy-prompt classification (payload-inventory boundary)

`automation/cadence/hour/33-research-beat.sh` deliberately ships repo-structural content
to remote providers: research prompts instruct "Ground every claim in this repository and
the hngh kernel repository ($KERNEL): cite concrete file paths ..." (33-research-beat.sh
prompt construction, review leg ~:708-730 and crystallization leg ~:860-875), and embed
crystallized documents (up to 8000 chars via marked_cut) that are full of concrete kernel
paths. model.sh scrubs only the REPLY side; the outbound prompt goes raw.

Classification: this is a BY-DESIGN, operator-visible disclosure of the repository's
PATH STRUCTURE (names of files/directories and their relationships), not of file
CONTENTS or secrets. Under the payload-inventory boundary:

- Disclosed: repo topology (path names, research-line titles, crystallized doc text).
- Not disclosed by the model leg: file contents, credentials (kernel secrets live in
  ~/.hngh-automation, never in prompts), newspaper/manga outputs, archive raw prompts
  stay local (archive_only writes only under automation/, gitignored runtime surface).
- Residual risk: repo topology itself is mildly sensitive (the repo is a private
  research kernel; origin is github.com/boundring/hngh but the working tree carries
  unpushed/operator-local structure). All four providers' retention postures above mean
  the topology text persists (Kimi: unknown duration; OpenRouter: until upstream Google
  policy; Z.ai: not stored; OpenCode Zen paid: zero-retention). Z.ai and OpenCode Zen
  paid are compatible with the by-design pathy-prompt behavior; Kimi and OpenRouter
  leave the structure resident somewhere.

## What was NOT checked

- Google's Gemini API data-use terms (upstream of the OpenRouter gemini-3.8-flash leg).
- Kimi's consumer/coding-plan privacy policy and default retention duration (Chinese
  ToS surfaces were JS-shells this session; only the enterprise ZDR doc was readable).
- OpenRouter's per-provider training labels page for the gemini-3.8-flash routing entry.
- Whether Kimi ZDR or a DPA could be enabled for this account (sales-gated).
- Whether any prompt ever embeds actual file CONTENT beyond crystallized docs
  (marked_cut content is doc text; a content-embedding audit of prompts was not run).
