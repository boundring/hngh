---
name: Feature request
about: Propose a named outcome with acceptance evidence.
title: "[feature] "
labels: enhancement
---

A feature request is a proposal: it names one problem and its smallest
useful outcome, the source it relies on, and the acceptance evidence
(design/autonomous-development-control.md, "Proposal"). Features without
acceptance evidence are not admitted.

## Problem and outcome

What the requested outcome is and what it solves. Name the smallest useful
outcome that would satisfy the request, not the largest.

## Evidence

The evidence a reviewer would accept once the outcome is built:

- the source manifest and fixed fixture `make test` contract, if behavior
  changes;
- the acceptance check and what it proves;
- candidate paths and content hash, if it becomes a candidate manifest.

## Risks

What might break, and the decision record that would cover it. Call out the
never clauses (GOVERNANCE.md, section 2) if the request touches one:
unbounded mutation, history rewrite around a review, or ambient execution.

## DCO

Every commit of a submitted change-set ends with a `Signed-off-by:` line
matching its author (CONTRIBUTING.md, "Contributor sign-off (DCO)").