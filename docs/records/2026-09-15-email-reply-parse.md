# Email reply parse: report-link directive grammar — 2026-09-15

Machine session record (jcode deep task graph node `d2-replyparse`,
swarm lane `session_dolphin_1789472126868_b6fe1d64bcfa1dc6`). Landed in
the working tree via the d2 slice (reply grammar + tests); the code was
audited and validated in-tree at record time. Free-commit automation
lane; no kernel `src/`, `tests/`, `Makefile`, or `hngh.asd` touched.

## Problem

Operator replies to kernel report emails could not drive state: a
reply referencing a report id (`[hngh <report-id>]` in the subject,
the same 8-hex id `docs/project/reports.md` carries) was filed as a
generic operator-item, and the matching open operator-items in
`automation/dashboard/operator-items.json` stayed open until manually
dismissed. The reply became yet another item to read instead of an
instruction.

## Change

- `automation/scripts/imap-poll.py` reply grammar:
  - `REPORT_REF_RE = re.compile(r"\[hngh ([0-9a-f]{8})\]")`
    (imap-poll.py:187) links a reply to a report row; `DIRECTIVES`
    (:189) maps `approve -> handled`, `deny -> dismissed`,
    `note -> annotation only`.
  - `annotate_report()` (:190 block): appends an operator-reply
    annotation block to the report's body sidecar under
    `docs/project/report-bodies/` (pruned sidecars are recreated when
    the ledger still has the row). Never touches
    `docs/project/reports.md`, never deletes anything.
  - `apply_directive()` (:233): scans the reply for the first line
    matching `approve:`/`deny:`/`note:` (colon is part of the grammar;
    bare words never count), transitions matching OPEN operator-items
    whose id/text references the report id, and appends an evidence
    string (`operator reply <word> via imap-poll`). Unknown or missing
    directives default to note (annotation only, no transition).
    Fail-closed: any error leaves `operator-items.json` byte-identical
    (write via tmp + `os.replace`, imap-poll.py:268-279).
  - `handle_report_reply()` (:280): subject-link entry point — no
    `[hngh <id>]` in the subject means behavior is exactly as before.
- `automation/tests/test-imap-poll.py`: new `ReportLinks` class (12
  new cases, tests 449-625 region; suite now 32 tests total): linked
  reply annotates the sidecar; absent sidecar created; approve ->
  handled; deny -> dismissed; note annotates only; missing/unknown
  directive default to note; no matching item annotates only;
  no-link keeps behavior unchanged; malformed body still records
  safely; malformed ids (7-char, non-hex) never annotate; annotation
  never touches the reports ledger or plan drafts.

## Verification

- `python3 -B tests/test-imap-poll.py` → `Ran 32 tests ... OK` (rc 0)
  on the d2 working tree at record time.
- The suite is wired into the 30-minute cadence surface
  (`cadence/30m/56-imap-poll.sh` runs `scripts/imap-poll.py` under a
  120 s timeout); the full automation gate covers the dashboard and
  viz-schema seams it interacts with. Full `make test` for the landing
  slice is owned by the lane that commits the code.
- Fail-closed behavior is pinned by tests: malformed ids, unknown
  directives, missing sidecars, and unmatched items all degrade to
  annotation-only (or no-op) rather than mutating state.

## Open follow-ups

- Feed rebuild clobber: `jobs/` feed rebuilds regenerate
  `operator-items.json` and lose email-driven dismissals/handled
  transitions written by this grammar (dismissed items reappear open).
  Owned by the `fix-email-dismiss-clobber` graph node.
- Patrol/registry admission: the reply-parse surface
  (`scripts/imap-poll.py` report-link path) has no patrol route row.
  Owned by the `admit-lessons-routes-surfaces` graph node.
- The commit of the d2 code slice itself was in flight at record time
  (the tree carries the diff, the lane owns the commit message per the
  plan::gate audit note).
