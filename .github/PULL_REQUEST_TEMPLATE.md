## Change

One linked change: the behavior or smallest useful outcome, and the
decision record it relies on (`docs/project/decisions.md` or a matching
record). Unlinked or unrecorded changes are held out.

## Evidence

- Focused check: name it and its result.
- `make test`: the reader-guard count, the check count, and the ASDF load.
- `git diff --check`: clean.
- Candidate paths and content hash, if this is a candidate
  (`make verify-candidate CANDIDATE_MANIFEST=path/to/manifest`).

## Never clauses

Confirm the review does not cross a governance boundary (GOVERNANCE.md,
section 2).

- [ ] One bounded, admitted action; no unbounded mutation.
- [ ] No history rewrite around the review (no force-push, amend, rebase,
      or filter over reviewed history).
- [ ] No ambient execution: no daemon, watcher, scheduler, or background
      process introduced.

## Risk note

Anything that could break, and the record that covers it. If none, say so.

## DCO

Every commit in this pull request ends with a `Signed-off-by:` trailer
matching its author. A commit without one is held out and amended before
admission, never padded by rewriting closed history.

    Signed-off-by: Your Name <you@example.com>