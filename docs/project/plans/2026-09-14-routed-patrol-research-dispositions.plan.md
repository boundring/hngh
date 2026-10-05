<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=patrol:research-dispositions -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:research-dispositions`
at 2026-09-14T10:00:39Z. Alert text: patrol research-dispositions: adopted-no-followon on fail-20260910-slow-unit-dropin-16-remote-push.sh -- adopted but no research-lines row or queued subject carries it

## Steps

- [x] Delve: open research subject fail-20260914-patrol-research-dispositions for patrol:research-dispositions; record disposition; then fix or park
      Verification: research subject fail-20260914-patrol-research-dispositions present in research-subjects.txt with a recorded disposition; alert fixed or parked
      CLOSED 2026-10-05T00:27Z -- substance landed by the 2026-10-04T21:08Z
      overnight-lead leg (model unsloth/Ornith-1.0-35B-GGUF local-bench,
      automation commit 4ec38d7a, pushed origin/main): research-subjects.txt
      subject, research-lines.tsv line (status=reviewed), and
      research-dispositions.tsv disposition (status=parked) all present.
      Disposition: parked -- the adopted-no-followon alert on
      fail-20260910-slow-unit-dropin-16-remote-push.sh went quiet because
      its lid already exists in research-lines.tsv:99, satisfying the
      lid-in-line_ids check in check_disposition_followons; re-routes only
      if the patrol re-fires with a new alert identity. Verifications
      re-run at close by this wake leg (2026-10-05T00:17Z, glm-5.3-flash):
      python3 -B jobs/patrol.py --patrol research-dispositions -> PASS
      disposition-followons 116 adopted row(s) have follow-ons (rc=0);
      python3 -B tests/test-research-schema.py -> Ran 9 tests, OK (rc=0).
      No kernel src/tests/Makefile/hngh.asd touch; no further fix required.

## Occurrences

- 2026-09-14T11:00:39Z re-occurred (dedup window expired)
- 2026-09-14T12:00:39Z re-occurred (dedup window expired)
