# Does the hngh-automation teardown script explicitly call `journalctl --vacuum-size=0` or `rm -rf /var/log/journal` before container destruction, or does it rely solely on filesystem discard?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-hngh-automation-teardown-script`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-hngh-automation-teardown-script.md.

# Contraction: hngh-automation teardown log-discard question

**Line:** Does the hngh-automation teardown script explicitly call `journalctl --vacuum-size=0` or `rm -rf /var/log/journal` before container destruction, or does it rely solely on filesystem discard?

**State:** contracted (final)

---

## Findings

**The question is unresolved.** No file under `~/Projects/etc/hngh` was inspected in either beat of this line. Zero verified evidence exists about the teardown script's contents, its invocation order relative to container destruction, or whether any explicit journal-vacuuming step is present.

What *is* established at title level only:

- An hngh-automation overnight harness was built, verified, and enabled (per `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`). The observation confirms existence and operational status but does not expose the teardown script's body.
- A post-rung-11 documentation refresh and attribution record exists (`obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au`), but its content is not available in this context and cannot be cited for technical detail.

No claim can be made—positive or negative—about the presence or absence of `journalctl --vacuum-size=0`, `rm -rf /var/log/journal`, or any equivalent log-purge step in the teardown path. The expanding beat correctly refused to guess; the contracting beat confirms that refusal was warranted.

## Recommendations

1. **Inspect the teardown script directly.** Identify the entry point (likely a shell or Python script under `~/Projects/etc/hngh` or an adjacent automation directory) and read its container-destruction sequence. Grep for `journalctl`, `vacuum`, `/var/log/journal`, `rm -rf`, and `podman stop|rm` / `docker stop|rm` to determine ordering.
2. **Check for filesystem-discard-only reliance.** If no explicit journal purge is found, verify whether the underlying volume uses a discard-capable filesystem (e.g., XFS with `discard` mount option or btrfs) and whether container storage drivers are configured to propagate discards. This would confirm the "rely solely on filesystem discard" hypothesis.
3. **Record the finding as a new observation** in the vault once verified, linking back to this line so the question is closed with evidence rather than inference.

## Open threads

- The teardown script's exact contents remain unexamined. This is the sole blocking gap.
- Whether container storage (e.g., overlay2 on a discard-enabled volume) actually frees journal space without an explicit purge is a secondary question that depends on the filesystem configuration, which was not inspected in either beat.
- No external source (man pages, systemd documentation, kernel docs) was consulted or needed; the answer is entirely internal to the repository and its runtime configuration.

## References

- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — confirms harness existence and overnight operation; does not expose teardown script contents.
- `[[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]]` — documentation refresh record; content not available in this context, no technical claims drawn from it here.

No file paths under `~/Projects/etc/hngh` are cited because none were verified to exist or contain relevant content during either beat of this line.
