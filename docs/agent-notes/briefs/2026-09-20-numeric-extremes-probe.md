# o9k numeric-extremes reader probe — 2026-09-20

Node: `gap-shared-store-replay::reader-audit-o9k`. Covers beads o9e
(signed-giant-int + 1M-digit gaps) and extends the float fail-closed
characterization. Harness: `probe-o9k/` (probe.lisp, gen-payloads.py,
run.sh); raw rows: `probe-o9k/results.tsv` (53 cases, fresh SBCL per
case, `:hngh` loaded). Payload files regenerate via gen-payloads.py.

## Surfaces probed (the kernel's three numeric readers)

1. Federation carrier-bundle reader (hostile-facing)
   `src/adapter/federation.lisp:213` `json-parse-integer`: unsigned
   only (no sign, no fraction, no exponent, leading zeros refuse);
   unbounded digit-run into `parse-integer` (bignum). Dispatch at
   `:229`. Integer skew flows to the shape gate
   `src/domain/attestation.lisp:253` (`<= skew 86400`) only AFTER the
   full parse. Gather path caps stdout at 65536 BEFORE parse
   (`:523`); the verify path (`src/main.lisp:1745`) reads the envelope
   file with NO length cap before parse.
2. Review reader (peer model output) `src/adapter/review.lisp:300`
   `json-parse-value`: no numeric clause at all, every number refuses
   `malformed-output` at 0 ms regardless of size.
3. Status spine tolerant reader `src/main.lisp:2144`
   `%status-json-number`: scans chars `0123456789+-.eE` then
   `read-from-string` (full Lisp number syntax: signed ints, floats,
   exponents). Document level `:2216` maps any reader error to the nil
   sentinel.

## Result table (latency = in-kernel ms; consed = bytes allocated; wall = fresh-process s; RSS = peak KB)

| case | outcome | latency | consed | wall | RSS |
|---|---|---|---|---|---|
| baseline (load only) | - | 0 | 0 | 0.2 | 103308 |
| fed-int-1k | VALUE bignum | 0 | 0.5MB | 0.2 | 103092 |
| fed-int-10k | VALUE bignum | 6 | 42MB | 0.2 | 103160 |
| fed-int-100k | VALUE bignum | 477 | 4.2GB | 0.7 | 158676 |
| fed-int-1M | VALUE bignum | 43006 | 415GB | 43.2 | 158840 |
| fed-int-4M | VALUE bignum | 732886 | 6.64TB | 733.2 | 198848 |
| fed-int-neg-1M | REFUSED malformed-attestation | 0 | 0 | 0.2 | 107460 |
| fed-int-plus-1M | REFUSED malformed-attestation | 0 | 0 | 0.2 | 103556 |
| fed-int-leadzero-10k | REFUSED malformed-attestation | 0 | 0 | 0.2 | 100960 |
| fed-float-mantissa-1M (777...7.5) | VALUE bignum (integer prefix parsed) | 43075 | 415GB | 43.3 | 159936 |
| fed-float-exp-1e6 | VALUE fixnum:1 (integer prefix, garbage left) | 0 | 0 | 0.2 | 99524 |
| fed-float-exp-neg-1e6 | VALUE fixnum:1 | 0 | 0 | 0.2 | 103004 |
| fed-float-signed (-1.5e300) | REFUSED malformed-attestation | 0 | 0 | 0.2 | 103184 |
| fed-float-exp-token-1M (1e+1M digits) | VALUE fixnum:1 | 0 | 0 | 0.2 | 107592 |
| fed-bnd-mpf | VALUE fixnum 2^62-1 exact=CORRECT | 0 | 0 | 0.2 | 103004 |
| fed-bnd-mpf-plus1 | VALUE bignum 63 bits exact=CORRECT | 0 | 0 | 0.2 | 101004 |
| fed-bnd-2p64 | VALUE exact=CORRECT | 0 | 0 | 0.2 | 103036 |
| fed-bnd-2p128 | VALUE exact=CORRECT | 0 | 0 | 0.2 | 103452 |
| fed-env-skew-86400 | VALUE shape=T skew=86400 | 0 | 0 | 0.2 | 99508 |
| fed-env-skew-86401 | VALUE shape=N malformed-attestation | 0 | 0 | 0.2 | 99452 |
| fed-env-skew-60k (in-cap) | VALUE shape=N | 169 | 1.5GB | 0.4 | 148828 |
| fed-env-skew-1M (verify path, uncapped) | VALUE shape=N | 44542 | 415GB | 44.8 | 162340 |
| fed-env-skew-neg | REFUSED malformed-attestation | 0 | 0 | 0.2 | 101396 |
| fed-env-skew-float | REFUSED malformed-attestation | 0 | 0 | 0.2 | 99268 |
| fed-gather-skew-60k | COMPLETE (skew unused, facts=0) | 169 | 1.5GB | 0.4 | 152584 |
| fed-gather-skew-1M | REFUSED output-too-large BEFORE parse | 0 | 0 | 0.2 | 107292 |
| review-int-1M | REFUSED malformed-output | 0 | 0 | 0.2 | 103464 |
| review-float-exp-1e6 | REFUSED malformed-output | 0 | 0 | 0.2 | 103248 |
| review-float-mantissa-1M | REFUSED malformed-output | 0 | 0 | 0.2 | 101500 |
| review-neg-1M | REFUSED malformed-output | 0 | 0 | 0.2 | 105028 |
| status-int-1k | VALUE bignum, printable | 0 | 33KB | 0.2 | 99568 |
| status-int-10k | VALUE bignum, printable | 1 | 2.7MB | 0.2 | 103152 |
| status-int-100k | VALUE bignum, printable | 52 | 235MB | 0.3 | 140636 |
| status-int-1M | VALUE bignum, printable | 4090 | 23GB | 4.3 | 160552 |
| status-int-neg-1M | VALUE bignum, printable | 4119 | 23GB | 4.4 | 160404 |
| status-int-4M | VALUE bignum, printable | 67853 | 369GB | 68.1 | 227468 |
| status-leadzero-10k | VALUE bignum (Lisp-reader accepts leading zeros) | 1 | 2.7MB | 0.2 | 102924 |
| status-float-mantissa-1M (777...7.5) | REFUSED impossible-number | 43494 | 415GB | 44.2 | 163060 |
| status-float-frac-1M (1.777...7) | VALUE single-float 1.7777778 (silent precision collapse) | 82451 | 623GB | 82.7 | 166648 |
| status-float-exp-1e6 | REFUSED impossible-number | 0 | 0 | 0.2 | 94356 |
| status-float-exp-neg-1e6 | VALUE single-float 0.0 (silent underflow) | 0 | 0 | 0.2 | 101232 |
| status-float-signed (-1.5e300) | REFUSED impossible-number | 1 | 0 | 0.2 | 97104 |
| status-float-exp-token-1M (1e+1M digits) | REFUSED impossible-number | 43402 | 415GB | 43.7 | 168528 |
| status-float-mantissa-exp (777...7e0) | VALUE single-float 0.0 (silent total collapse) | 45757 | 415GB | 46.0 | 166332 |
| status-float-1e3 | VALUE single-float 1000.0 | 0 | 0 | 0.2 | 103020 |
| status-bnd-mpf | VALUE fixnum exact=CORRECT | 0 | 0 | 0.2 | 101404 |
| status-bnd-mpf-plus1 | VALUE bignum exact=CORRECT | 0 | 0 | 0.2 | 103252 |
| status-bnd-mnf | VALUE fixnum exact=CORRECT | 0 | 0 | 0.2 | 103236 |
| status-bnd-mnf-minus1 | VALUE bignum exact=CORRECT | 0 | 0 | 0.2 | 102952 |
| status-doc-int-1M | VALUE (:OBJECT ("n" . 1M-digit bignum)) | 4078 | 23GB | 4.4 | 164716 |
| status-doc-exp-token-1M | REFUSED doc-nil (fail-closed sentinel) | 43413 | 415GB | 43.6 | 171284 |
| status-doc-underflow | VALUE (:OBJECT ("n" . 0.0)) | 0 | 0 | 0.2 | 101368 |
| status-doc-float-exp-1e6 | REFUSED doc-nil | 0 | 0 | 0.2 | 103160 |

## Findings

1. o9e closed: signed giant ints (`-N`/`+N`, 1k..1M digits) refuse
   closed instantly (0 ms, `malformed-attestation`) in the hostile
   federation reader. Unsigned 1M-digit ints DO parse into correct
   bignums (VALUE), with quadratic cost.
2. 1M-digit CPU gap (hostile, real): the verify path reads the
   envelope file with no length cap before parse
   (src/main.lisp:1745), so a 1MB hostile envelope with a 1M-digit
   `skew-seconds` costs 44.5 s CPU + 415 GB allocation churn before
   the shape gate refuses it. The gather path caps at 65536 bytes
   BEFORE parse (src/adapter/federation.lisp:523, proven: 1MB bundle
   refused in 0 ms), so in-cap worst cost is 169 ms + 1.5 GB. A
   pre-parse length cap on the verify path would close the asymmetry.
3. Cost curve (federation `parse-integer` path): 1k/10k/100k/1M/4M
   digits = 0/6/477/43006/732886 ms and 0.5MB/42MB/4.2GB/415GB/6.6TB
   consed, RSS flat (~103-199 MB, GC-bound). Quadratic in digits;
   the practical bound is the 64KB envelope cap (169 ms), not memory.
4. Float fail-closed map: federation reader has no float syntax;
   float-looking tokens parse their integer PREFIX (a 1M-digit
   mantissa before "." still pays the full 43 s bignum parse, then
   trailing garbage refuses at envelope level). Review reader refuses
   every number at 0 ms. Status reader accepts floats: overflow
   (1e1000000, -1.5e300) refuses via SBCL READER-IMPOSSIBLE-NUMBER-ERROR
   but AFTER paying mantissa/exponent bignum cost (43 s + 415 GB for
   1M-digit mantissa or exponent); underflow (1e-1000000) silently
   becomes 0.0 (accepted); giant fraction mantissa (1.<1M digits>)
   silently collapses to single-float 1.7777778 after the suite's
   worst cost (82.5 s + 623 GB, accepted as a WRONG value); giant
   integer mantissa with e0 silently becomes 0.0 (accepted; small
   analogs like 7.7e39 error instead - scale-inconsistent).
5. Bignum correctness controls: 8/8 exact (fixnum boundaries
   +-2^62, 2^64, 2^128; negative boundaries through the status
   reader); skew round-trips exactly; shape gate accepts 86400 and
   refuses 86401/giant as designed.
6. No crash, no hang: 53/53 fresh-SBCL cases exited rc=0, every case
   inside its timeout (longest: fed-int-4M at 12.2 min wall, an
   extrapolation datapoint beyond the real 64KB surface). Peak RSS
   never exceeded 227 MB (baseline 103 MB).

## Follow-up candidates (not done here)

- Pre-parse length cap for the verify-attestation envelope path
  (mirror the gather `+max-bundle-length+` check).
- Optional: bound the digit-run length in `json-parse-integer` (e.g.
  refuse at > 24 digits for skew, or cap at a few thousand) to make
  the hostile parse cost linear-trivial rather than quadratic.
- Silent-wrong-value seams in the status spine reader (underflow ->
  0.0, mantissa collapse) if status numbers ever gate decisions.
