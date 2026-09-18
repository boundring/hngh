<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the adopted cadence-digest research line by adding a stdlib-only digest formatter, a build script, a shell test, and a static dashboard view, all landing as plain commits gated by hngh-automation's make test. It stays strictly on automation paths (lib/, scripts/, tests/, dashboard/, digest/) and avoids kernel, credential, and systemd surfaces.

## Steps

- [ ] Add lib/digest_format.py defining format_digest(entries) that returns a sorted, de-duplicated list of job result strings using only the Python standard library, with an `if __name__ == "__main__":` self-check asserting a known input maps to the expected output
  Verification: python3 lib/digest_format
