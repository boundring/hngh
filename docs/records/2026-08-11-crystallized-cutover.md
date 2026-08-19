# Crystallized cutover

> Superseded on 2026-08-19: the archive gate was retired
> (`docs/records/2026-08-19-archive-gate-retired.md`). The archive remains
> historical evidence outside the repository; no active gate verifies it.

The prior Hngh image was retired as a complete local archive. The replacement
starts with a no-daemon kernel and an empty mode-0700 `~/.hngh` directory.

The archive receipt is stored outside this repository in the configured
archive's `metadata/` directory. Historically verified with
`HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive`, which has
since been removed.

No old process, user unit, autostart mask, launcher, compatibility root, or
configured Hermes MCP entry remains active.
