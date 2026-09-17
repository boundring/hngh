<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260917-Does-the-hngh-build-policy (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the cadence-digest research line: folding raw cadence run statuses into a single digest record and surfacing it on the dashboard, without touching providers, credentials, systemd units, or the hngh kernel.

## Steps

- [ ] Add lib/digest.py with a pure stdlib summarize(statuses) returning counts plus worst status, and tests/test_digest.py asserting it
  Verification: python3 tests/test_digest.py
- [ ] Add scripts/render_digest.sh that reads a statuses file, calls the digest lib via python3, and prints one digest line (no network or credentials)
  Verification: bash -n scripts/render_digest.sh
- [ ] Add jobs/cadence_digest.sh cadence entrypoint that runs render_digest.sh on a run's status file and writes output under digest/, plus tests/test_cadence_digest.sh exercising it in a temp dir
  Verification: bash tests/test_cadence_digest.sh
- [ ] Add dashboard/digest.html static template with a {{DIGEST_LINE}} placeholder for the rendered digest (no scripts, no secrets)
  Verification: grep -q "{{DIGEST_LINE}}" dashboard/digest.html
- [ ] Register the cadence-digest job in the repo test harness so make test covers it end to end
  Verification: make test
