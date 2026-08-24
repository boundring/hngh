---
name: Bug report
about: Report a defect claim with reproducing evidence
title: "[bug] "
labels: bug
---

An issue is a claim, accepted only with evidence (GOVERNANCE.md, "Intake
policy"). A report without a reproduced observation is refused, not
committed to. Fill every section; say what you observed, do not assume it.

## What changed

The observed behavior, and, if known, the change that introduced it
(slice, record, or revision).

## Guarantees broken

Which guarantee did this break? Mark each that failed and state the breach.

- [ ] Confidentiality — something was disclosed that should not be.
- [ ] Integrity — state changed without the recorded check and evidence.
- [ ] Availability — a run or command refused or ceased when it should not.
- [ ] Auditability — a decision, change, or run cannot be reproduced from
      the recorded evidence.

## Reproduce

The concrete steps, each with its own evidence (command, output, run).
A failure the maintainer cannot reproduce from these steps is not a fixable
bug claim.

## Candidate evidence

If the defect is in a candidate or certificate, attach what a reviewer
would need to verify it:

- candidate paths, and the content hash if one was produced
  (`make verify-candidate CANDIDATE_MANIFEST=path/to/manifest`);
- the focused check or failing test, if one exists;
- the revision where it reproduces.

## Privacy

May the details be shared? If not, say which parts must be redacted and
why. Private transcripts, credentials, secrets, and raw dumps of private
data are refused, not recycled.