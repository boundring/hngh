# Is there a verified file path under `~/Projects/etc/hngh` that defines a journald configuration template with `Storage=persistent`?

Status: crystallized 2026-09-16 from research line `fail-20260916-Is-there-a-verified-file-path-under-home`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Is-there-a-verified-file-path-under-home.md.

# Final Structured Summary — Contracted Record

**Line:** Is there a verified file path under `~/Projects/etc/hngh` that defines a journald configuration template with `Storage=persistent`?
**State:** contracting → **closed-unresolved (pending probe)**
**Model:** unsloth:unsloth/Qwen3.8-27B-GGUF

---

## Findings

1. **No positive or negative verdict is reachable from this position.** The research root `~/Projects/etc/hngh` and every subpath beneath it are outside the observable surface available to this beat. No file path under that root can be cited as existing, and no occurrence of `Storage=persistent` in any journald-configuration context can be confirmed or refuted.

2. **The verification bar is fully specified.** A positive result requires the conjunction of three conditions, all established in the prior expanding beat:
   - a concrete file path under `~/Projects/etc/hngh`,
   - an active (non-comment) occurrence of `Storage=persistent`,
   - semantic classification of the file as a journald configuration source or template (static `.conf`, Jinja2/templated config, packaging spec, provisioning script, or CI/container build step), not documentation, test fixture, generated artifact, or incidental string.

3. **Standard systemd conventions are background only.** The well-known path `/etc/systemd/journald.conf` and the drop-in directory `/etc/systemd/journald.conf.d/` are general-knowledge anchors for what a journald configuration *looks like* on a stock system. They are not evidence about this repository. No claim in this record relies on them as repository facts.

4. **The prior-art wiki pointers could not be dereferenced.** Four pointer names were supplied in the research context (see References). The prior beat explicitly recorded that they cannot be resolved from this position. They may contain relevant context about the `hngh` automation harness or the `research-lines.tsv` schema, but their content is unverified here and must not be treated as evidence for or against the line.

5. **The line is narrow and cheap to resolve.** It is a single existence-and-semantics check, not an investigation into journald behavior, systemd packaging policy, or logging architecture. The prior beat correctly scoped it as one probe on an idle host, not a multi-beat expansion.

---

## Recommendations

1. **Do not mark this line verified on naming, convention, or inference.** A positive requires the three-condition conjunction above. Absence of evidence is not evidence of absence; the line stays open until probe output is in hand.

2. **The single next action is to obtain command output from the tree on an idle host.** The exact probes are already specified in the prior beat:
   ```sh
   test -d ~/Projects/etc/hngh && rg -n 'Storage=persistent' ~/Projects/etc/hngh
   test -d ~/Projects/etc/hngh && rg -l 'journald' ~/Projects/etc/hngh
   find ~/Projects/etc/hngh -type f \
     \( -name 'journald.conf' -o -name '*.conf.j2' -o -name '*.spec' -o -name 'Dockerfile*' \) -print
   ```
   These are search patterns, not claims that matching files exist. The output—exact path(s) with context, or a clean negative—is the sole input needed to close this line.

3. **Classify any hit before accepting it.** If `rg` returns matches, each must be inspected for: comment status, semantic role (config source vs. doc/fixture/artifact), and consuming mechanism (how does the file actually configure journald—static install, template render, package spec, provisioning step?). A match that fails any of these is not a positive.

4. **For `hngh/hngh-automation`, treat persistent journald storage as unproven until evidence exists.** If automation logic depends on journald persisting logs across reboots or container restarts, do not rely on an unverified template. Either record the verified path and its rendering/installation mechanism in the automation's config-management surface, or explicitly add/manage the required `Storage=persistent` directive through that surface.

5. **Do not import external systemd assumptions into the line.** If a future beat encounters a file that *looks like* a journald config but lives in an unexpected location (e.g., a vendored copy under `vendor/`, a test fixture under `tests/`, or a generated artifact under `build/`), classify it on its actual role in the tree, not on filename resemblance to `/etc/systemd/journald.conf`.

6. **If the probe returns a clean negative (root exists, no match), close the line as verified-negative.** If the root does not exist, close as unresolvable-from-this-position and note that the research root may have been renamed, moved, or never materialized on the host in question. Either outcome is a valid terminal state for this line.

---

## Open Threads

| Thread | Status | Disposition |
|---|---|---|
| Existence of `~/Projects/etc/hngh` on any reachable host | Unverified | Resolved by `test -d` in the probe |
| Any file under that root containing active `Storage=persistent` | Unverified | Resolved by `rg -n` in the probe |
| Semantic classification of any hit as a journald config template | Unverified (no hit to classify) | Resolved by manual inspection if probe returns matches |
| Content of the four prior-art wiki pointers | Undereferenced | Out of scope for this line; may inform adjacent lines about `hngh` automation or `research-lines.tsv` schema but cannot be used as evidence here |
| Whether `hngh/hngh-automation` has an independent config-management surface that would make the template question moot | Unverified | Adjacent concern; does not change the existence check for this line |

No thread in this table can be closed without filesystem access. The line remains **open** until probe output is obtained.

---

## Explicitly Unverified Items (carried forward)

- I cannot verify that `~/Projects/etc/hngh` exists from this position.
- I cannot verify any subpath under that root.
- I cannot dereference the prior-art wiki pointers supplied in the research context; their content is unknown here.
- I cannot verify whether `hngh/hngh-automation` contains a journald configuration template, a config-management surface, or any logging-related automation logic.
- I cannot verify any external systemd documentation, release notes, or packaging behavior as facts about this repository.

---

## References

All references below are named as they appear in the research context supplied to this beat. **I cannot verify that any of these paths exist on disk or dereference them from this position.** They are listed for provenance and traceability, not as confirmed filesystem artifacts.

- Research line state: `research-lines.tsv` (line identifier as given in the prompt; content not independently verified here)
- Prior beat record: research beat 2026-09-16, model `unsloth:unsloth/Qwen3.8-27B-GGUF`, wall time 357.0 s (supplied in the prompt as prior material; not a filesystem path)
- Prior-art pointer: `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson re: hngh automation observation (undereferenced; content unverified)
- Prior-art pointer: `[[sources/SRC-2026-08-24-037]]` — AGPL-3.0 + DCO inbound-contribution practice (undereferenced; content unverified)
- Prior-art pointer: `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson re: `research-lines.tsv` schema (undereferenced; content unverified)
- Prior-art pointer: `[[obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation re: hngh automation overnight harness (undereferenced; content unverified)

No concrete file path under `~/Projects/etc/hngh` is cited in this record, because none can be verified from this position.
