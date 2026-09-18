# 2026-09-17 Typesafe.ai subprocessors: rendered-browser enumeration (ts-angle3-vanta-browser-subprocessors)

Resolves the "actual subprocessor names unchecked" gap left by ts-angle3-legal-posture:
trust.typesafe.ai is a Vanta-hosted JS-SPA; this session rendered it in headless Chromium
(Playwright, chromium-1234) and captured the signed GraphQL payloads the page itself
emits (`https://trust.typesafe.ai/graphql?operation=fetchDataForTrustReport`).

## Enumerated subprocessor list (verbatim, totalCount: 4)

1. **Amazon Web Services** — purpose: Cloud provider — location: USA — url: aws.amazon.com
   Commitment text: "Customer information for live requests is stored and processed on
   databases, caches and compute nodes within AWS"
   (note: this entry implies live-request data DOES persist in AWS storage; no duration pinned)
2. **Modal** — purpose: AI Infrastructure — location: USA — url: modal.com
   Commitment text: "Customer AI prompts are processed, but not stored, on compute nodes
   managed by Modal" (pre-pinned NOT-STORED commitment for prompts on this leg)
3. **Slack** — purpose: Collaboration, Customer Comms — location: USA — url: slack.com
   Commitment text: "Information about customers may be surfaced ... through our
   collaboration tool, Slack ... Customers' own data may be submitted to us by them in
   Slack channels we create for support, in accordance with their own data agreements."
4. **Google Workspace** — purpose: Collaboration, Customer Comms — location: USA —
   url: admin.google.com
   Commitment text: "Customer information and their data may be exchanged through our
   email and document provider, Google, at their request, e.g., in emails to our service
   inbox."

No per-subprocessor retention durations, no deletion SLAs, and no explicit no-training
commitments exist anywhere in the trust-center payload (keyword scan of the full
GraphQL response: "retention"/"retain"/"delete"/"zero"/"training" = 0 hits). The FAQ tab
is empty ("No matching questions found"). The "Data collected" overview section is empty
(`dataCollected: []`). The only pinned retention signals are Modal's not-stored prompt
commitment and AWS's stored live-request data, both unstated in duration.

## Trust-center documents

- Sole resource: Vanta-branded **Engagement Letter** (bulk download
  `https://trust.typesafe.ai/doc/trust-zip?r=fa36t9a4dulcnactq79ryr` contains only
  engagement-letter.pdf). It certifies Typesafe.ai is a Vanta trust-management client
  with continuous control monitoring and an Advantage Partners SOC 2 Type 2 audit that
  started 2026-03-15. No DPA, subprocessor agreement, or DP-related document is published.
- Controls: passing-only Vanta control list (data-retention procedures established,
  customer-data-deleted-upon-leaving listed among "Data and privacy" control names) —
  control existence, not contractual terms.
- Privacy policy: typesafe.ai/privacy — generic "retain personal data as long as
  reasonably necessary"; hosting disclosed as United States. No named model providers.

## Cross-reference vs hngh armed legs — typesafe.ai vendors are NOT overlapping

Armed outbound legs (docs/research/2026-09-17-provider-legal-posture-armed-legs.md):
- kimi (api.kimi.com) — Moonshot AI: not listed as a Typesafe.ai subprocessor.
- openrouter routing google/gemini-3.8-flash — OpenRouter + Google: not listed (Google
  Workspace entry is email/docs collaboration, not an LLM inference leg).
- z.ai (api.z.ai GLM gateway) — not listed.
- opencode zen (glm-5.3-flash) — not listed.
- 127.0.0.1:8888 reviewer leg — local, no third-party vendor.

Overlap check verdict: exactly one semantic overlap of infrastructure class — Amazon
Web Services is a subprocessor for Typesafe.ai's own live-request storage; but the hngh
harness's outbound model legs do not traverse Typesafe.ai, Model, Slack, or Google
Workspace at all. "Modal" (AI Infrastructure, prompts processed but not stored) is the
closest analog to Model providers. The trust center lists NO model-provider
subprocessors (no OpenAI/Anthropic/OpenRouter/Google AI/Moonshot/Kimi entries). Either
Typesafe.ai runs inference exclusively in-house on Modal/AWS, or it discloses no
third-party model providers — both readings leave its legal posture for LLM-training
claims unproven in this artifact. The claim "loaders (e.g. openrouter/anthropic) are
confirmed by the trust center" is NOT supported: no openrouter, no anthropic, no model
vendor appears in the subprocessor list.

## Data-boundary verdict

- If Typesafe.ai is ever considered as a provider leg: its disclosed storage surface is
  AWS-hosted live-request data where data DOES persist (AWS entry) plus Slack/Google
  Workspace collaboration surfaces; prompts on Modal infrastructure carry an explicit
  processed-not-stored commitment. Retention durations absent ⇒ fail closed under the
  hngh unknown-input rule: cannot be classified as zero-retention without a document.
- The gallery's SOC 2 posture rests on the Vanta engagement letter only; no audit
  report is published in the trust center.

## What was not checked

- Blocked/unarmed possibility that Typesafe.ai has more than 4 subprocessors behind an
  NDA gate (reportContext ndaSlugId was null; accessLevel was PUBLIC and the pure list
  returned totalCount:4 — pagination shows hasNextPage:false, so 4 is the full public list).
- Whether Typesafe.ai contracts model inference to any fourth party not tagged as
  subprocessor (chatbot on the trust center was UNAVAILABLE, so no live model output to
  fingerprint).
- Disposition: keep typesafe.ai out of the armed-leg legal map; its subprocessor list
  contains no overlap with the harness's four outbound legs.
