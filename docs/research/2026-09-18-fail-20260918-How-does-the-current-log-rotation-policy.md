# How does the current log rotation policy for `/var/log/hngh/audit/` handle concurrent writes from multiple workers during high-volume automation cycles, and are there any race conditions that could cause entry loss?

Status: crystallized 2026-09-18 from research line `fail-20260918-How-does-the-current-log-rotation-policy`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260918-How-does-the-current-log-rotation-policy.md.

# Research Line Summary: Log Rotation Race Conditions in `/var/log/hngh/audit/`

**Line State:** Contracting (Final)
**Date:** 2026-09-18
**Scope:** Analysis of concurrent write safety and data integrity during log rotation for `hngh` audit logs.

## Executive Summary

The investigation into the log rotation policy for `/var/log/hngh/audit/` concludes that standard `logrotate` mechanisms (both `copytruncate` and default rename/create) are **inherently unsafe** for high-volume, multi-worker audit logging without specific application-level coordination or kernel-level support.

Two primary failure modes were identified:
1.  **Silent Data Loss:** With `copytruncate`, writes occurring between the copy and truncate operations are permanently lost.
2.  **Stream Fragmentation/Offset Drift:** With default rename/create, workers holding open file descriptors continue writing to the old inode (now archived), causing logs to split across files with non-linear temporal ordering or potential permission errors if ownership changes.

**Critical Constraint:** POSIX `O_APPEND` atomicity guarantees only protect against interleaving within a single write call to the *same* inode. It provides **zero protection** against rotation-induced inode changes or truncation.

## Findings

### 1. Verified Mechanisms of Failure
Based on standard POSIX I/O semantics and `logrotate` behavior:

*   **`copytruncate` Loss Window:**
    *   Sequence: Copy active file → Truncate original.
    *   Race: Worker writes to fd between copy and truncate.
    *   Result: Bytes are not in the archive (copy completed) and are erased by truncation. **Audit integrity is compromised.**

*   **Rename/Create Offset Drift:**
    *   Sequence: Rename active file → Create new empty file.
    *   Race: Worker holds fd to old inode.
    *   Result: Writes go to the renamed archive file. New log file remains empty until workers restart or reopen. This breaks chronological continuity and may trigger `EACCES` if `logrotate` applies restrictive permissions to the new file that existing workers cannot write to.

### 2. Insufficiency of `O_APPEND`
While `O_APPEND` ensures atomic appends relative to other writers on the *same* inode, it does not resolve the fundamental issue of **inode identity changing** during rotation. A worker writing to an fd pointing to inode X will continue writing to inode X even if the path `/var/log/hngh/audit/audit.log` now points to inode Y.

### 3. Unverified Implementation Details
*   The specific configuration file for `hngh` log rotation (e.g., `/etc/logrotate.d/hngh`) could not be inspected due to lack of filesystem tool access in this environment.
*   The exact write strategy of `hngh-automation` workers (e.g., whether they use `O_APPEND`, buffered I/O, or signal handlers for `SIGHUP`) is **unverified**.
*   The presence of any custom rotation scripts or kernel modules in `[redacted path] handling this specifically is **unverified**.

## Recommendations

To ensure zero-loss audit logging during high-volume cycles:

1.  **Abandon `copytruncate`:** It is unacceptable for audit trails due to the guaranteed loss window.
2.  **Implement Signal-Driven Reopening:**
    *   Configure rotation to use `create` (default).
    *   Send `SIGHUP` or a custom signal to `hngh-automation` workers upon rotation completion.
    *   Workers must close and reopen log file descriptors in response to the signal to bind to the new inode.
3.  **Alternative: Use `inotify`/`fanotify`:**
    *   If signal handling is not feasible, implement a file descriptor watcher that detects when the underlying inode changes (via `stat()` checks on path resolution) and reopens automatically.
4.  **Avoid Permission Drift:**
    *   Ensure `logrotate` configuration uses `create 0640 root adm` (or appropriate group) and that workers have consistent access to the new file without requiring a restart for permission validation.
5.  **Verification Test:**
    *   Implement a stress test: Spawn N workers writing at high frequency, trigger rotation mid-cycle, and verify that all entries appear in exactly one of the rotated files with no gaps or duplicates.

## Open Threads

1.  **Signal Handler Implementation:** Does `hngh-automation` currently handle `SIGHUP`? If not, this is a critical gap.
2.  **Buffering Strategy:** Are workers using unbuffered I/O (`O_WRONLY`) or buffered streams? Buffered writes increase the window for data loss during truncation.
3.  **Kernel Support:** Is there any custom kernel module in `hngh` that provides atomic log rotation (e.g., via `splice()` or specialized syscalls)? This was not found in prior material but remains an open question if standard userspace solutions are deemed insufficient.

## References

*   POSIX I/O Semantics: `O_APPEND` atomicity limits (`PIPE_BUF`).
*   `logrotate(8)` man page: Description of `copytruncate`, `create`, and signal handling.
*   **Unverified/External:** Specific file paths in `[redacted path] or `/var/log/hngh/audit/` configuration files. *Note: Claims about these specific files are hypotheses pending manual inspection.*
