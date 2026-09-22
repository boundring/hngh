# 2026-09-20 o9l GC retention probe (bead o9f gap)

Task-graph node `gap-shared-store-replay::reader-audit-o9l::gc-retention-o9f`.
Probe dir `probe-o9l-gc/` (untracked): `run.sh`, `probe.lisp`, `fresh-base.lisp`,
`diag.lisp`, `gen-payloads.py`, `results.tsv`, `gc-verbose.log`, `fresh.log`,
`long.log`. Delivered as deltas vs the fresh-SBCL base (o9b isolation
convention). Kernel `src/`, `tests/`, `Makefile`, `hngh.asd` untouched; nothing
committed. SBCL 2.6.8, entry point `hngh.main::%status-json-document`
(src/main.lisp:2216), payloads: keys-50k (745 kB text), flat-1m, flat-10m.

## Verdict

**No GC retention leak.** In one long-lived process, after dropping all
references and one `(sb-ext:gc :full t)`, BOTH the internal heap and RSS return
to the pre-parse base; three more full GCs change nothing. SBCL releases the
freed pages back to the OS (RSS delta C2-C0 = -1,732 kB, i.e. slightly BELOW
the C0 base; heap delta -27,584 bytes, noise). `VmHWM` keeps the 409,532 kB
peak by definition. The heap-vs-RSS split the task asked about is therefore
trivial here: there is no split, because SBCL reclaimed internally AND returned
the pages to the OS. Retention of equal structures across parses is fine; the
observed behavior is allocation-churn, not retention.

## Delta table (probe-o9l-gc/results.tsv, longlived process)

| delta | value | meaning |
|---|---|---|
| rss C0-minus-fresh | +3,408 kB | base comparability (run-to-run load variance only) |
| rss C1-C0 | +343,476 kB | RSS while holding 15 retained parses |
| heap C1-C0 | +401,318,528 B | dynamic space at C1 = live + nursery garbage |
| heap C1g-C0 | +258,712,976 B | retained LIVE heap (full GC while structures held) |
| rss C1g-C0 | +251,100 kB | RSS tracks live heap almost 1:1 |
| rss C2-C0 | **-1,732 kB** | after drop + 1 full GC: fully returned to OS |
| rss C3-C0 | **-1,736 kB** | after 4 total full GCs: identical |
| rss C3-C1 | -345,212 kB | reclaimed delta (negative = RSS returned) |
| heap C2-C0 | -27,584 B | internal heap back to base after 1 full GC |
| heap C3-C0 | -28,880 B | no accumulation over 3 more GCs |
| consed C1-C0 | 1,434,799,952 B | total parse consing for 15 payloads (1.34 GiB) |
| VmHWM | 409,532 kB | peak, never returns (expected for HWM) |

Footprint reconciliation (three independent measurements, agree within ~1.5%):
EST structural estimate 254,687,600 B (all 500,020 parsed strings are 4-byte
`character` strings; 500,035 conses at 16 B); measured C1g live delta
258,712,976 B; churn-clean per-payload RET rows 5,390 + 4,033 + 40,814 kB =
50,237 kB/round x 5 = 251,185 kB. C4 `room`: dynamic space 19,669,600 B with
baseline 354,780 conses / 92,080 instances (matches C0 floor).

## Secondary findings (reader-audit relevant)

1. **All parsed strings are wide: 4 bytes/char.** `%status-json-string`
   (src/main.lisp:2110) parses via `make-string-output-stream` +
   `get-output-stream-string`; SBCL string-output-stream element type is
   `character` (wide). `diag.lisp` confirmed: 1M-char wide string = 4,029 kB;
   and `uiop:read-file-string` text is ALSO `(SIMPLE-ARRAY CHARACTER (n))`, so
   the pipeline costs ~4x for ASCII payloads end to end. keys-50k: 100,000 wide
   strings retain 5,390 kB where base-strings would be ~1,000 kB.
2. **Parse consing is heavy.** Per parse: keys-50k 40,751,552 B consed (54.7x
   its 745 kB text, ~815 B/entry, for a 5,390 kB retained structure);
   flat-1m 8,323,920 B (7.9x); flat-10m 109,070,336 B (10.4x). Cost is
   transient churn (per-string stream machinery), not retention.
3. **C1 heap (411,057 kB) is live+garbage** (no GC since the last parse);
   C1g isolates the live part. Nursery garbage explains the C1 inflation.
4. **Measurement-methodology trap (also affects o9b/o9k-style liveness
   probes):** conservative stack scanning retains freshly-dead text/buffer
   strings across a full GC when the measurement happens right after the
   parse call returns; per-payload RET rows read ~2x until a stack-churning
   recursion (`churn-stack`) overwrites the stale slots before the measuring
   GC. `notinline` on the parse helper alone was not sufficient.

## What was not checked

- SBCL 2.6.8 `sb-ext:gc :full t :verbose t` produced no gencgc page-table lines
  in Lisp-level capture (empty in gc-verbose.log); page-level data came from
  `room` (dynamic-space usage + breakdown) instead of used/free page counts.
- Only `%status-json-document`; federation `json-parse-value` retention path
  not probed.
- Fixed 5 rounds x 3 payloads; no repeated parse/drop cycles over time, no
  incremental/generational GC variants, no arena mode, no smaller/sparser
  payload shapes beyond the three specified.
- C0-minus-fresh (+3,408 kB this run, -2,296 kB in an earlier run) is
  run-to-run load variance; single pair of runs, not averaged.
- keys-50k RET (5,390 kB) vs structural formula (~4.0 MB) gap not itemized per
  object type (would need a per-structure room breakdown); aggregate agrees.
- get-bytes-consed attribution: consed numbers are process-wide deltas,
  including SBCL-internal allocation; no per-allocation-site breakdown.