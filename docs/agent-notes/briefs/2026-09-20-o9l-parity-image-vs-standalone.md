# 2026-09-20 o9l probe A: full-image vs standalone parser parity (beads o9a, o9b)

Task-graph node `gap-shared-store-replay::reader-audit-o9l::parity-o9a-o9b`.
Probe dir `probe-o9l-parity/` (untracked): `run.sh`, `probe.lisp`,
`ladder.lisp`, `digest.lisp`, `digest-diag.lisp`, `digest-run.sh`,
`ext-time.py`, `gen-payloads.py`, `results.tsv`, `digest-ladder.log`,
`build.log`, `hngh-full.core`. Kernel `src/`, `tests/`, `Makefile`,
`hngh.asd` untouched; nothing committed. SBCL 2.6.8, cwd=repo root,
boot pattern per probe-o9k. Payloads byte-identical to probe-o9l-gc
(md5-verified: keys-50k `ce493809...`, flat-1m `484e6814...`, flat-10m
`5f44e1b8...`). Readers: `hngh.main::%status-json-document` (primary),
`hngh.adapters.federation::json-parse-value` (text 0 0),
`hngh.adapters.review::json-parse-value` (text 0 0).

## Verdicts

**o9a (image-vs-standalone parity): PASS.** All 9 payload x reader
combinations (3 payloads x 3 readers x 2 environments) produce identical
outcome AND value. Outcome+detail rows are byte-identical across
environments; a full-representation FNV-1a content digest (see
`digest-ladder.log`) is identical across environments AND across readers
within each payload: keys-50k `3649734603226059513` (repr 755,007 chars,
`(OBJECT (k00000 . v0) ...)` alist of 50,001 entries), flat-1m
`10912241726246198778` (repr 1,048,594 chars), flat-10m
`673590267928485370` (repr 10,485,778 chars). No REFUSED rows: none of
the three readers caps these payloads (the fed gather 65536 cap lives on
the gather path, not exercised here). The saved core boots
(`--core probe-o9l-parity/hngh-full.core`, 42,997,056 B) and confirms all
four reader fbinds present (`READERS status=T fed=T review=T num=T`).

**Time-tool gap (o9a rider): standalone startup/ASDF cost measured at
0.27-0.45 s wall per process; image boot 0.08-0.19 s.** There is no
`/usr/bin/time` on this box; external wall/maxRSS come from a wait4
rusage wrapper (`ext-time.py`). External MaxRSS agrees with in-process
VmHWM exactly in 3 of 4 wrapped cases and within 172 kB (0.1%) in the
fourth (see below). The load cost is real but small because fasls were
warm; it is NOT minutes.

**o9b (RSS isolation): delivered as deltas.** Every latency-affected RSS
number below is stated as a delta from the appropriate ladder rung; a
3-shot/2-shot noise repeat bounds run-to-run VmHWM variance at ~+-2-4 MB,
so sub-deltas under ~4 MB are not interpretable.

## RSS ladder (probe-o9l-parity/results.tsv, LADDER rows)

Fresh process per rung, VmHWM from /proc/self/status.

| rung | config | VmHWM kB | delta from (a) |
|---|---|---|---|
| a | bare `sbcl --non-interactive` (+ ~/.sbclrc quicklisp) | 100,956 | 0 |
| b | + require :asdf + asdf:load-asd | 96,872 | -4,084 |
| c | + asdf:load-system :hngh | 96,944 | -4,012 |
| d | boot saved core `hngh-full.core` | 54,168 | -46,788 |

Noise repeats (`digest-ladder.log`): a-bare 99,160/103,124/103,192;
c-hngh 103,268/103,296; d-boot 42,408/46,408. So (a) ~ (b) ~ (c) within
+-4 MB: ASDF + the loaded hngh system add no measurable resident peak
over the bare+quicklisp base; b and c reading BELOW a in the main run is
run-to-run variance, not negative cost. Rung (d) is consistently ~42-54
MB, i.e. the saved image boots with a peak ~46-58 MB BELOW the fresh-SBCL
base (the saved image is post-GC compacted and skips fasl load work).
Note: main-run d (54,168) also loaded+compiled probe.lisp before
sampling; the noise runs loaded only ladder.lisp.

## Parity table (results.tsv, RESULT rows)

Outcome/detail identical per row across environments for all 9 rows; all
VALUE, no REFUSED, no ERROR. Detail shown: structure summary.

| payload/reader | standalone lat_ms | image lat_ms | consed B (both envs) | rss standalone | rss image |
|---|---|---|---|---|---|
| keys-50k/status | 15 | 11 | 40,751,552 | 104,008 | 92,840 |
| keys-50k/fed | 10,102 | 9,842 | 40,751,552 | 104,008 | 92,676 |
| keys-50k/review | 10,249 | 9,856 | 40,751,552 | 104,008 | 92,676 |
| flat-1m/status | 6 | 5 | 8,323,920 | 103,088 | 66,680 |
| flat-1m/fed | 7 | 7 | 8,323,920 | 103,088 | 66,680 |
| flat-1m/review | 8 | 7 | 8,323,920 | 103,088 | 66,680 |
| flat-10m/status | 72 | 60 | 109,071,392 / 109,070,192 | 180,856 | 181,084 |
| flat-10m/fed | 90 | 76 | 109,070,384 / 109,070,192 | 181,348 | 180,912 |
| flat-10m/review | 85 | 75 | 109,070,384 / 109,070,192 | 181,348 | 180,912 |

All three readers return the SAME structure per payload (identical digest
within payload): keys-50k a 50,001-entry alist; flat docs a 2-element list
`(OBJECT ("n" . "aaa..."))`. Image parses are ~2-17% faster on the big
cases (no fasl load in-run); consed bytes agree to within 1,200 B on
10 MB (GC timing noise).

### RSS deltas (o9b isolation statement)

- Standalone rows vs rung (c) 96,944 kB: keys-50k +7,064 kB; flat-1m
  +6,144 kB; flat-10m +84,404 kB (max row 181,348).
- Image rows vs rung (d) 54,168 kB: keys-50k +38,508 kB; flat-1m
  +12,512 kB; flat-10m +126,916 kB (max row 181,084).
- Cross-env note: image base is 42,776 kB lower, but the flat-10m peak
  converges (~181 MB both envs) because peak is payload-churn dominated;
  keys-50k peak is ~11 MB lower in the image, consistent with the lower
  boot floor.

## Time-tool gap (EXT rows, wait4 rusage wrapper)

| env/case | EXT wall_s | EXT maxRSS kB | in-process lat sum ms | wall-minus-parse (startup+ASDF or boot) |
|---|---|---|---|---|
| standalone/keys-50k | 20.64 | 104,008 | 20,366 | 0.27 s (startup+ASDF) |
| standalone/flat-10m | 0.70 | 181,348 | 247 | 0.45 s (startup+ASDF dominates: 64% of wall) |
| image/keys-50k | 19.79 | 92,676 | 19,709 | 0.08 s (core boot) |
| image/flat-10m | 0.40 | 180,912 | 211 | 0.19 s (core boot dominates: 48% of wall) |

External MaxRSS == in-process VmHWM exactly for standalone/keys-50k,
standalone/flat-10m, image/keys-50k; image/flat-10m disagrees by 172 kB
(EXT 180,912 vs status-row VmHWM 181,084, 0.1%) -- VmHWM sampled at row
print vs rusage at process exit; treated as measurement noise. The
"minutes per 10 MB parse" budget in the task was not needed: parses take
60-90 ms (o9l-gc already showed flat-10m conses ~109 MB, churn not
retention).

## Probe-implementation notes (bugs found and fixed during this probe)

- SBCL `--core` is a C runtime option: must precede `--non-interactive`,
  else "C runtime option --core in the middle of Lisp options".
- First digest implementation multiplied the running hash by the BYTE
  instead of the FNV prime; v2(char-code) accumulation drives any long
  repr to 0 mod 2^64 (keys-50k digest = 0). Fixed to true FNV-1a
  (xor byte, multiply by 0x100000001b3) and re-ran all digests.
- `ecase` dispatch on string literals is eql-based and unreliable; reader
  dispatch uses symbols.

## What was not checked

- `hngh.main::%status-json-number` not exercised with these payloads (it
  is a token reader, not a document reader); only its fbound presence was
  confirmed in the image.
- The fed gather path (65536 length cap) and envelope/verify path were
  not run here (they were covered by probe-o9k); no REFUSED rows exist in
  this probe, so REFUSED-parity is vacuously confirmed only.
- Ladder rung (b) measured once (no noise repeat); b-a and c-a deltas
  under ~4 MB are within single-shot variance.
- Digest covers the `~A` printed representation only, not object
  identity/interning differences between environments.
- Single run per parity case (no latency averaging); timing deltas
  image-vs-standalone (2-17%) are single-sample.
- ext-time.py wall includes its own python startup (~50 ms, uncorrected);
  /usr/bin/time itself unavailable, so no cross-tool comparison of the
  time tool against a second external tool.
- Nothing committed; probe dir and briefs dir remain untracked.
