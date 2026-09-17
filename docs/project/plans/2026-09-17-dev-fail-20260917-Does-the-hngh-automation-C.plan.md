<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260917-Does-the-hngh-automation-C (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the adopted normal-risk research line on cadence job manifest validation by adding stdlib-only manifest checks, a test wrapper, and documentation for hngh-automation without changing provider, credential, systemd, kernel, or security surfaces.

## Steps

- [ ] Add `lib/job_manifest_check.py` as a stdlib-only helper that validates minimal job manifest text and runs a self-test under `__main__`.
  Verification: python3 lib/job_manifest_check.py
- [ ] Add `scripts/check_job_manifests.py` to scan optional `jobs/*.yaml` files for required `job:` and `cadence:` markers, passing when no manifests are present.
  Verification: python3 scripts/check_job_manifests.py
- [ ] Add `tests/test_job_manifest_check.sh` that invokes the manifest checker and propagates its exit status.
  Verification: bash -n tests/test_job_manifest_check.sh
- [ ] Add `cadence/job-manifest-notes.md` documenting the normal-risk job manifest contract for automation jobs.
  Verification: grep -q "job:" cadence/job-manifest-notes.md
