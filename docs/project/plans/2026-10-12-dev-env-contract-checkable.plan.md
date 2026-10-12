<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `jobs/parse-adoptions.sh` script that reads the current `ADOPTED` findings list and prints each line prefixed with `ADOPTED:`
  Verification: bash jobs/parse-adoptions.sh

- [ ] Create `cadence/track-adoptions.md` with a table mapping each ADOPTED finding to a proposed automation step and its expected verification command
  Verification: grep -c "ADOPTED" cadence/track-adoptions.md

- [ ] Add a `tests/test-adoptions.sh` script that asserts `jobs/parse-adoptions.sh` outputs at least one line containing "ADOPTED:"
  Verification: bash tests/test-adoptions.sh

- [ ] Update `Makefile` to include `test-adoptions` as a new test target that runs `tests/test-adoptions.sh`
  Verification: make test-adoptions

- [ ] Add a `dashboard/adoptions-status.json` file with a JSON object listing each ADOPTED finding and a placeholder `status: "pending"` field
  Verification: python3 -c "import json; d=json.load(open('dashboard/adoptions-status.json')); assert 'findings' in d and len(d['findings'])>0"

- [ ] Create `scripts/update-adoptions-status.sh` that updates `dashboard/adoptions-status.json` with a `status: "in-progress"` marker for each ADOPTED finding
  Verification: bash scripts/update-adoptions-status.sh && python3 -c "import json; d=json.load(open('dashboard/adoptions-status.json')); assert all(f['status']=='in-progress' for f in d['findings'])"
