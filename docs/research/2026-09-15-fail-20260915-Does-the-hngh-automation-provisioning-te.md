# Does the hngh-automation provisioning template set `Storage=persistent` for journald and enable sysstat collection, or are test hosts ephemeral containers that destroy all three telemetry classes at teardown?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-hngh-automation-provisioning-te`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-hngh-automation-provisioning-te.md.

# Final Structured Summary: hngh-automation Telemetry Provisioning vs. Ephemeral Teardown

**Line:** Does the hngh-automation provisioning template set `Storage=persistent` for journald and enable sysstat collection, or are test hosts ephemeral containers that destroy all three telemetry classes at teardown?
**State:** contracting → **closed (contracted record)**
**Date crystallized:** 2026-09-15

---

## Findings

### F1 — The line as posed is a false dichotomy on two orthogonal axes

The question conflates two independent questions that can each be answered true or false without constraining the other:

| Axis | Question | Status |
|------|----------|--------|
| **A — Template intent** | Does the provisioning template render `Storage=persistent` for journald *and* enable sysstat? | Unresolved (requires static inspection of template source) |
| **B — Host lifecycle** | Are test hosts ephemeral containers, and does teardown destroy all three telemetry classes? | Unresolved (requires dynamic inspection of teardown code path) |

A host can be an ephemeral container *and* have a template that declares `Storage=persistent` (the declaration is structurally inert after teardown). Conversely, a long-lived VM can have a template that never sets persistent storage. The four sub-claims (C1: journald persistent; C2: sysstat enabled; C3: third class provisioned; C4: teardown destroys all three) are **independent outcomes**, not two sides of one switch.

### F2 — The "three telemetry classes" are under-specified

The line names two classes (journald, sysstat) but references a third without naming it. Candidate third classes in an hngh-kernel test context include kernel ring buffer / `dmesg` capture, audit subsystem (`auditd`), ftrace/perf data, or `sadc`/`sa2` weekly rollups. **This is unverified** — the third class is whatever the template provisions beyond journald + sysstat, and identifying it requires grepping the provisioning template for package installs and unit enables. Until that grep is run, C4 is under-specified and cannot be falsified.

### F3 — If hosts are ephemeral containers, `Storage=persistent` is structurally inert

If test hosts are ephemeral containers with a disposable rootfs, then journald will write to `/var/log/journal/` but that path vanishes with the container at teardown. The template declaration becomes a no-op: C1 is *technically true* (the template sets it) but *operationally meaningless* (no data survives). This reframes the question from "does the template set persistent storage?" to "is telemetry exported before teardown, or is persistence structurally impossible?"

### F4 — The two probes are independent and both required

Resolving the line requires two separate measurements:

- **Probe A (static):** Inspect the provisioning template source in hngh-automation for journald configuration (`[Journal] Storage=persistent` or `Storage=volatile`/`auto`), sysstat enablement (package install, `sa1.timer`/`sa1.service`, or cron entry), and the third class. The template source lives in hngh-automation, not on a live host.
- **Probe B (dynamic):** Identify host type (LXC, Docker, KVM/qemu VM, or physical) and trace the teardown code path in hngh-automation. Determine whether teardown calls explicit telemetry wipe (`journalctl --flush --rotate`, `sa1 --check`) or simply discards the filesystem (making persistence moot).

### F5 — Prior observation material exists but was not fully ingested into this line

Two prior art observation files are referenced:
- `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`
- `obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au`

These observations may contain the actual template inspection results and host lifecycle details, but their full content was not available in the prior beat material. The line's resolution depends on whether these observations already answer Probe A and/or Probe B.

---

## Recommendations

### R1 — Ingest the two prior observation files before any new measurement

The observation files referenced in prior art are the most likely source for answers to both probes. Before designing new experiments, read:
- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]`
- `[[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]]`

If these observations already document the template's journald/sysstat configuration and the host lifecycle, the line can be closed without new measurement. If they do not, proceed to R2.

### R2 — Execute Probe A: static template inspection

Locate the provisioning template in hngh-automation and inspect:
1. **Journald section:** Check for `[Journal] Storage=persistent` (or `Storage=volatile`, `Storage=auto`). In a systemd drop-in layout this renders into `/etc/systemd/journald.conf.d/*.conf` on the target host, but the template source is what matters.
2. **Sysstat section:** Check for package install (`sysstat`), `sa1.timer`/`sa1.service` enablement, or equivalent cron entry. In stock sysstat, data lands in `/var/log/sa/` (daily) and `/var/log/sar/` (raw); the template may override paths.
3. **Third class:** Record what the template provisions beyond journald + sysstat. This resolves F2.

### R3 — Execute Probe B: dynamic lifecycle inspection

1. Identify host type from hngh-automation configuration or teardown code.
2. Trace the teardown code path. Specifically: does it call `journalctl --flush --rotate`, `sa1 --check`, or any explicit telemetry wipe? Or does it simply discard the filesystem?
3. If hosts are ephemeral containers with a disposable rootfs, reframe C1/C2 as an "export-before-teardown" question rather than a persistence question.

### R4 — Close the line with a four-quadrant answer

Once both probes are complete, report the answer as a 2×2 matrix:

| | Template sets persistent + sysstat | Template does not |
|---|---|---|
| **Hosts ephemeral** | C1 true but inert; C2 true but inert; C4 depends on export logic | C1 false; C2 false; C4 moot |
| **Hosts long-lived** | C1 true and meaningful; C2 true and meaningful; C4 false | C1 false; C2 false; C4 false |

This matrix replaces the false dichotomy with a complete answer space.

---

## Open Threads

### OT1 — Third telemetry class unidentified (F2)

The line references "all three telemetry classes" but names only two. The third is unknown until Probe A is executed. This is a **hard blocker** for C4: you cannot verify that teardown destroys "all three" if you do not know what the third is.

### OT2 — Prior observation files not fully ingested (F5)

The two observation files from 2026-08-25 may already contain answers to both probes. Their full content was truncated or unavailable in the prior beat. This is the **lowest-cost path** to closing the line and should be exhausted before any new measurement.

### OT3 — Teardown semantics unverified (F4, Probe B)

Whether teardown explicitly wipes telemetry or simply discards the filesystem has different implications:
- If explicit wipe: `Storage=persistent` is actively defeated; C1 is false in practice.
- If filesystem discard: `Storage=persistent` is structurally inert; C1 is true in template but meaningless in operation.

This distinction matters for how the finding is reported but does not change whether the template *declares* persistent storage.

### OT4 — External sources not verifiable

The standard systemd journald configuration paths (`/etc/systemd/journald.conf.d/*.conf`, `/var/log/journal/`) and sysstat data paths (`/var/log/sa/`, `/var/log/sar/`) are referenced from general systemd/sysstat documentation. I cannot verify these against the specific hngh-automation template without access to that repository. The prior material asserts these paths as "stock" behavior; this is a reasonable assumption but should be confirmed against the actual template if it overrides defaults.

---

## References

1. **Prior beat (2026-09-15):** Contracted line analysis identifying the false dichotomy, proposing R1–R3, and splitting into Probe A / Probe B. Source: internal research-line state (`research-lines.tsv`), model `unsloth:unsloth/Qwen3.8-27B-GGUF`, wall time 102.0s.

2. **Prior art observation (vault pointer):** `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation of hngh-automation overnight harness build, verified enabled. Full content not ingested into this line; may contain Probe A results.

3. **Prior art observation (vault pointer):** `[[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]]` — Post-rung-11 documentation refresh, attribution record, and audit. Full content not ingested into this line; may contain host lifecycle details relevant to Probe B.

4. **hngh kernel repository:** `~/Projects/etc/hngh` — Referenced as the kernel repository location. Specific file paths within this repository are not cited in this summary because I cannot verify their existence without direct access. The prior material does not cite specific kernel repo file paths relevant to this line.

5. **hngh-automation provisioning template:** Location within the hngh-automation repository is not fully specified in the available prior material. The template source is identified as living in hngh-automation (not on a live host), but the exact file path was not cited in the prior beat. This is a gap that Probe A must resolve.

6. **Standard systemd journald paths:** `/etc/systemd/journald.conf.d/*.conf` (drop-in configuration), `/var/log/journal/` (persistent journal storage). These are standard systemd paths; I cannot verify whether hngh-automation overrides them without access to the template source.

7. **Standard sysstat paths:** `/var/log/sa/` (daily reports), `/var/log/sar/` (raw data). These are stock sysstat paths; I cannot verify whether hngh-automation overrides them without access to the template source.

---

**Line status: CLOSED (contracted).** The line is crystallized as a false dichotomy requiring two independent probes. The four-quadrant matrix in R4 provides the complete answer space. Open threads OT1–OT4 remain for any future re-opening, but the structural analysis is final: the question as posed cannot be answered with a single yes/no; it requires independent answers to both axes plus identification of the third telemetry class.
