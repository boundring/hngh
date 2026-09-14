<!-- plan: status=proposed risk=normal accepted=- routed-from=opencode-key-exposed:lobehub-research-doc -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `opencode-key-exposed:lobehub-research-doc`
at 2026-09-14T10:00:39Z. Alert text: residual exposure from push-blocked:openrouter-key-hngh disposition: the OPENCODE_API_KEY value is still plaintext on origin/main in docs/research/2026-09-10-lobehub-api-research.md (Pi/OpenCode-Go feed lines; pushed 2026-09-10 ledger sync, never flagged by secret scanning, never redacted). Operator action: rotate the key, redact the value in the doc (same shape as the 2026-09-11 OpenRouter redaction), then allowlist-or-repush if protection objects. Machine sessions must not touch key material.

## Steps

- [ ] Delve: open research subject fail-20260914-opencode-key-exposed-lobehub-research-doc for opencode-key-exposed:lobehub-research-doc; record disposition; then fix or park
      Verification: research subject fail-20260914-opencode-key-exposed-lobehub-research-doc present in research-subjects.txt with a recorded disposition; alert fixed or parked
