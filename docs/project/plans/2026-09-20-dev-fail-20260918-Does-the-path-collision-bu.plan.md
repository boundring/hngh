<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for automating the HN post ingestion pipeline by introducing a robust Python-based parser and a bash validation script to ensure data integrity before processing.

## Steps

- [ ] Create `lib/parse_hn.py` to implement a standard library-only parser for Hacker News JSON feeds, extracting title, URL, and score fields.
  Verification: python3 lib/parse_hn.py --help

- [ ] Add `scripts/validate_feed.sh` to execute the Python parser against a sample fixture and assert that no exceptions are raised during execution.
  Verification: bash scripts/validate_feed.sh

- [ ] Introduce `tests/test_parse_hn.py` containing three unit tests using `unittest` to verify correct extraction of title, URL, and score from mock JSON structures.
  Verification: python3 -m unittest tests.test_parse_hn

- [ ] Update `jobs/ingest.sh` to invoke the new validation script before proceeding with database insertion logic.
  Verification: bash -n jobs/ingest.sh

- [ ] Add a `tests/fixtures/sample_feed.json` file containing three valid and two malformed Hacker News entries for regression testing.
  Verification: python3 -c "import json; json.load(open('tests/fixtures/sample_feed.json'))"
