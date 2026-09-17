# 2026-09-16 — fifth token-file reader gated: unsloth_chat mode-600 gate

## The gap

Node `gap-unsloth-tokenfile-600-gate` (follow-up to the
token-file-0600-gates class, f809a05f/f8b0fe7f): `automation/lib/
model.sh unsloth_chat` read `TOKEN_FILE` (`cat` at :263) with an
existence check but NO mode-600 gate. The same secret class was
gated at four other readers (remote_chat :360, credential-health
probe_token, manga-vision, grade-interface), and g2's summary claimed
"all four un-gated token-file reads" — the count was wrong: the
unsloth chat read was a fifth instance that e1's sweep never flagged.

Exposure: `~/.hngh-automation/unsloth.token` is chmod-600 only after
a successful refresh (`refresh_unsloth_token` chmods the rotated
pair, model.sh:205). An operator-created or restored 0644 token was
silently read and sent as the bearer header on every chat call —
including the bench lanes (`model-bench.sh` calls `unsloth_chat`
directly) and every `model_call` fall-through to the local fleet.

## What landed

- `automation/lib/model.sh unsloth_chat` — above the `cat`, in the
  exact kimi/remote byte shape: absent-token-file contract made
  explicit first, then `stat -c %a != 600 -> breadcrumb "key file too
  open (chmod 600 required) -> next backend" -> return 1`, fail-closed
  BEFORE the value is read or sent. The `:286` re-read after
  `refresh_unsloth_token` needs no gate (post-refresh chmod).
- `automation/tests/test-model-remote-token-mode.sh` — new section 4
  (`unsloth 0644 refusal + 0600 control`), extending the remote-leg
  pattern: 0644 -> empty stdout + too-open breadcrumb + ZERO POSTs
  against a live stub; 0600 -> past the gate (dead-URL HTTP
  breadcrumb shape), exactly one POST against the live stub, stub
  answered; absent token file -> dormant breadcrumb (existing
  contract pinned).
- Fixture alignment in the four suites that exercise the unsloth leg
  (their sandbox token files were created by `printf >` under umask
  022 -> 0644, which the new gate now rightly refuses):
  test-model-pin-routing.sh, test-model-kimi-leg.sh,
  test-model-ocgo-leg.sh, test-review-ladder.sh — all now chmod 600
  their sandbox token, matching the real operator posture.

## Red proof

With the new cases in place and the gate temporarily reverted
(git checkout of model.sh), the suite failed exactly the leak shape:

- `FAIL: unsloth 0644: too-open breadcrumb (want [1] got [0])`
- `FAIL: unsloth 0644 vs live stub: empty stdout (got [stub-says-hi])`
- `FAIL: unsloth 0644 vs live stub: zero POSTs (want [0] got [1])`
  — the 0644 token value was POSTed to the stub as a bearer header.

Green after the gate landed and the fixtures were aligned.

## Collateral finding (deflaked, same slice)

`test-model-ocgo-leg.sh` "outside-window events ignored" case is
time-of-week flaky: with `OCGO_CAP_7D_CALLS=100000`, the 7d-window
soft pace (`allowed = cap * (now % 604800) / 604800`) blocks any
`used > ~566` for the first ~9.4 minutes of each epoch-anchored
604800s cycle (Thursday 00:00Z). The fixture's 95 six-hour-old events
are inside the 7d window, so at cycle start the case archived instead
of answering (observed 2026-09-17T00:00Z, reproducing the 13-test
mid-gate failure from the render-layer slice). Fix: the case now uses
huge 7d/month caps (1e8) so the soft pace can never trip there; the
case's purpose — proving 5h-window exclusion of 6h-old events — is
unchanged.

## Validation

- `tests/test-model-remote-token-mode.sh` — all pass (25 assertions,
  incl. the 10 new unsloth ones)
- `tests/test-model-pin-routing.sh` — all pass
- `tests/test-model-kimi-leg.sh` — all pass
- `tests/test-model-ocgo-leg.sh` — all pass (x2 after deflake)
- `tests/test-review-ladder.sh` — all pass
- `tests/test-probe-token-mode.sh` — all pass
- `tests/test-credential-health-argv.sh` — all pass
- full `make test`: ALL PASS

## What this does not cover

- The unsloth `_unsloth_ctx_limit` probe (:249) sends the same token
  as a bearer header and is reached only after the new gate (gate is
  above the first use of `$tok`), so it inherits the guard; a
  standalone audit of probe-side sends was not re-run.
- `/Users/`, `/root/` families and marker unification stay with
  `llc-gate-scrub-site-divergence`.
- The 7d soft-pace boundary arithmetic itself (a pacer that treats
  the window as epoch-anchored rather than product-reset-anchored for
  rolling windows) is a model.sh design question, not re-litigated
  here; the ocgo fixture note documents the observable behavior.
