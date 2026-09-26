# os: what daily check pairs hngh-packages.tsv pins with pacman reality so drift files a subject, never an auto-update?

Status: crystallized 2026-09-26 from research line `arc-20260925-os-package-pairing`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260925-os-package-pairing.md.

# Research Line Crystallization (state: contracting → closed record)

**Line:** os: what daily check pairs hngh-packages.tsv pins with pacman reality so drift files a subject, never an auto-update?

---

## Verification posture

I cannot inspect the live filesystem from this session. Claims below are grounded in (a) prior beats on this line, (b) the llm-wiki vault pointers supplied as prior art, and (c) paths I am confident of by convention in the hngh kernel repository at `[redacted path] Anything I cannot verify is marked **[unverified]** rather than asserted.

---

## Findings

1. **The check is a comparator, not an actuator.** The line's central answer, stable across both prior beats: `hngh-packages.tsv` pins are *intended state*; the local pacman database (`/var/lib/pacman/local/`) is *actual state*. The daily check's only job is to diff the two and emit a drift report. Under no branch of its logic does it invoke `pacman -S`, `-Sy`, `-Syu`, or any install/remove operation. Auto-update is explicitly out of scope — that is the line's defining invariant.

2. **Dual-surface confirmation is required before filing.** Per `[[sources/verdict-rule-drift-two-surfaces]]`, a single observation of divergence is insufficient: drift is only confirmed when *both* surfaces are independently read and both readings agree that they disagree. A pacman query failure, an unreadable TSV, or a partially-written database must not be coerced into a drift verdict.

3. **Freshness is a moment-of-action property.** Per `[[concepts/moment-of-action-freshness]]`, the TSV must be re-read at check execution time. No caching of pin state between runs, no reuse of yesterday's parse. A pin that cannot be resolved against the live pacman database is itself a drift subject, not a silently-skipped row.

4. **Failure of the check is not "no drift."** Per `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`, the drift pipeline has known failure modes. When the checker cannot complete (network unavailable for repo metadata, pacman lock held, TSV corrupt), it files a *failure report* — a distinct artifact from both the clean report and the drift report. Silence is the one forbidden output.

5. **Preflight health gates the run.** Per `[[sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]`, the harness verifies its own preconditions before comparing: TSV exists and parses, pacman DB is readable, no pacman transaction is in flight (`/var/lib/pacman/db.lck` absent — noting this is advisory, not a guarantee of quiescence).

6. **Execution model: background job, sandboxed repro.** Per `[[sources/async-proof-pattern-for-long-drop-ins]]`, the check runs as a non-blocking background job alongside the research pipeline, not inside it. Per `[[sources/debug-repro-sandboxes-only]]`, any investigation of a filed drift subject reproduces in a sandbox/container with a mock pacman DB — never against the live host.

## Recommendations (final form)

1. **Implement the check as a pure function `pins × pacman-db → report`.** No side effects beyond writing the report file. Exit semantics: 0 = clean, 1 = drift filed, 2 = check failure (self-reported).
2. **Commit reports as evidence.** Drift reports land in the repository as dated subjects (filename pattern carrying the date, e.g. `drift-YYYYMMDD-<pkg>.md` **[unverified — naming convention is a proposal, not an observed repo convention]**). The report records: pin value, observed value, both raw readings, and the dual-surface confirmation.
3. **Parse the TSV defensively.** Treat it as the schema it is: tab-separated, comment-tolerant, with a package column and a pin column. Any row failing schema validation becomes a failure-report entry, not a drift entry and not a skip.
4. **Schedule via the existing timer harness rather than a new cron path.** The night-check precedent in the vault implies a systemd timer is the expected mechanism **[unverified — no concrete `.timer` unit path confirmed in the kernel repo]**.
5. **Keep a strict air gap from auto-update.** No code path in the checker imports or shells to pacman's write operations; this should be auditable by grep.

## Open threads (handed to future lines)

- **Concrete checker location.** No confirmed path for the checker's implementation (candidate: a script under the kernel repo's tooling area — **[unverified]**). A future expanding line should locate or place it.
- **TSV schema formalization.** Whether `hngh-packages.tsv` has a versioned schema header or is de-facto **[unverified]**.
- **Failure-report routing.** Where failure reports go when the repository itself is unreachable is undefined.
- **Drift subject lifecycle.** Who/what consumes a filed drift subject, and whether repeated identical drift should deduplicate or re-file daily, was never resolved on this line.
- **LES scroll-behavior fail mode.** The vault note `[[sources/LES-fail-20260915-...]]` is truncated in prior material; its full failure-mode description was never incorporated into a test case.

## Pace note

Per protocol: this line ran continuously on idle capacity across its expanding → distilling → contracting arc. This document is its crystallized record; the open threads above seed subsequent lines rather than a scheduled revisit.

---

## References

**Repository paths (kernel repo: `[redacted path]
- `hngh-packages.tsv` — the pin file; existence asserted by line convention, exact path within the repo tree **[unverified]**
- `/var/lib/pacman/local/` — pacman local database (system path, standard on Arch-family hosts)
- `/var/lib/pacman/db.lck` — pacman lock file (system path, standard)

**llm-wiki vault (read-only prior art):**
- `[[concepts/moment-of-action-freshness]]` — Attestation freshness recheck (moment-of-action)
- `[[sources/verdict-rule-drift-two-surfaces]]` — Shared verdict rule drifted across two surfaces in one observation
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research Lesson: If drift is confirmed... (truncated in source material)
- `[[sources/async-proof-pattern-for-long-drop-ins]]` — Prove long-running drop-ins with background job patterns
- `[[sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]` — Observation: night check / harness healthy / timer doc vs install drift
- `[[sources/debug-repro-sandboxes-only]]` — Debug repros must run in sandboxes, never against live systems

**Explicitly not asserted:** no external documentation on pacman internals, systemd timer semantics, or TSV tooling was consulted; all mechanism-level claims above rest on the vault notes and prior beats of this line only.
