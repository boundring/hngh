# Crystallized cutover

The prior Hngh image was retired as a complete local archive. The replacement
starts with a no-daemon kernel and an empty mode-0700 `~/.hngh` directory.

The archive receipt is stored outside this repository in the configured
archive's `metadata/` directory. Verify it with
`HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive`.

No old process, user unit, autostart mask, launcher, compatibility root, or
configured Hermes MCP entry remains active.
