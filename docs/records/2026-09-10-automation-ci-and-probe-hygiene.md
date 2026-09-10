# Automation CI tier and probe-hygiene lint

Date: 2026-09-10. Scope: peer-review findings 2 and 3
(docs/research/2026-09-10-peer-standard-review.md), landed as one
ceremony slice.

## What landed

1. **CI for the automation tier** (.github/workflows/ci.yml): second
   job `test-automation` — checkout, install sqlite3 (the only suite
   dependency not preinstalled on ubuntu-latest runners; bash, python3,
   git, curl, jq, flock all are), then `cd automation && make test`.
2. **Probe-class lint** (automation/tests/test-probe-hygiene.sh, wired
   into automation/Makefile's test target): every curl in
   automation/jobs/credential-health.sh targeting a key-gated endpoint
   var (`$UNSLOTH_URL`, `$lobe_models_url`, `$kimi_models_url`) must be
   exactly one call carrying `Authorization: Bearer`; the deck /health
   probe is the single documented exemption (no key gate exists —
   credential-health.sh section 3); any other headerless curl fails the
   suite. Negative-verified: reintroducing the kimi headerless probe
   shape fails the lint with the offending line echoed.

## Hermeticity verification (finding 2 precondition)

The suite was verified, not assumed: `env -i HOME=$HOME
PATH=/usr/bin:/bin:/usr/local/bin make test` in automation/ — full
suite green, exit 0, ~23s, no env-skipping needed. No test requires
systemd user units, HNGH_HOME secrets, or /tmp/hngh-failfirst state;
the sandbox pattern (mktemp dirs, env-var state overrides, fixture
repos — see tests/stub-lib.sh, test-remote-push.sh, test-model-demote.sh)
holds for all 40 files.

## Rule statement (finding 3)

Every credential probe must exercise the authenticated path its real
caller uses. The 2026-09-10 kimi/lobehub incident: probes measured
their own missing header/wrong path for five days (kimi 401,
lobehub 404; commits 8db143a, b367b0c) while the real legs worked, and
both were caught by hand. The lint now makes that shape a suite
failure instead of a manual catch.
