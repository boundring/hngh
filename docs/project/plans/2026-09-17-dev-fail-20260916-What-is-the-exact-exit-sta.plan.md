<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-What-is-the-exact-exit-sta (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260916-What-is-the-exact-exit-status-and-match-` by establishing a deterministic, self-contained verification harness for the `Storage=persistent` token within the hngh-automation repository, ensuring the grep exit status contract (0/1/2) is explicitly tested and documented without relying on external host state.

## Steps

- [ ] Create `tests/fixtures/storage-persistent-present.txt` containing exactly one line with the literal string `Storage=persistent`.
  Verification: `LC_ALL=C grep -F -- 'Storage=persistent' tests/fixtures/storage-persistent-present.txt && echo "exit 0 confirmed"`

- [ ] Create `tests/fixtures/storage-persistent-absent.txt` containing only lines that do not match the literal string `Storage=persistent`.
  Verification: `! LC_ALL=C grep -F -- 'Storage=persistent' tests/fixtures/storage-persistent-absent.txt && echo "exit 1 confirmed"`

- [ ] Write `scripts/verify-storage-token.sh` to execute `LC_ALL=C grep -F -- 'Storage=persistent'` against a specified file and explicitly capture/echo the exit status ($?).
  Verification: `bash -n scripts/verify-storage-token.sh`

- [ ] Execute the verification script against the present fixture to confirm it correctly identifies exit status 0.
  Verification: `bash scripts/verify-storage-token.sh tests/fixtures/storage-persistent-present.txt | grep "exit_status=0"`

- [ ] Execute the verification script against the absent fixture to confirm it correctly identifies exit status 1.
  Verification: `bash scripts/verify-storage-token.sh tests/fixtures/storage-persistent-absent.txt | grep "exit_status=1"`
