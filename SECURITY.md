# Security

Status: draft for review, 2026-08-24, branch `wip-public-readiness`.
Changing this document is a governance change (`GOVERNANCE.md`,
section 4). It is written to the standard of the OpenSSF coordinated
vulnerability disclosure guide for open source projects (wikis:
OpenSSF CVD, 2026-08-24) and it makes only promises the project is
able to keep today.

## 1. Reporting a vulnerability

Do not open a public issue with details of a suspected vulnerability.
Report privately, through one of these channels, in order:

1. GitHub private vulnerability reporting — the repository's
   Security tab, "Report a vulnerability" (available once the
   repository is public and private reporting is enabled).
2. Email — the project's `security@` address on the operator's
   domain, once published. Until then, use channel 1; if you cannot
   use it, open a public issue that states only "I have a security
   concern; please open a private channel" — no details.

What a report needs:

- What is affected: commit, release, or branch.
- The commands or steps that reproduce it, and what you observed.
- Which guarantee is broken: confidentiality, integrity,
  availability, or auditability.
- A fix, if you have one.
- How you wish to be credited, or that you ask for no credit.

What a report must not contain: credentials, secrets, or private
transcript content. Anything sent is treated as confidential until
disclosure.

## 2. What happens after reporting

Every valid report is acknowledged within 1-2 business days —
business days, because the project is a single-operator project and
this is a real, kept promise, not a 24/7 coverage claim. Within the
response process the report is assessed and classified; the finder
is informed of the classification with a reason when it is not a
vulnerability.

For a vulnerability, the process of section 4 runs: embargo
discussion, private patch, CVE, and public disclosure, with the
finder credited unless they decline.

## 3. The responder (VMT)

Who responds is one person: the operator. The OpenSSF guidance sizes
a vulnerability management team at 3-7 members, at least two of whom
can administrate security issues; this project states plainly that
its team is currently the operator alone. Growth of the responder
set is a governance change (GOVERNANCE.md, section 4) and this
document will say so when it happens. The acknowledgment SLA, the
embargo rules, and the disclosure process are set up to be kept by
one person.

## 4. Response process

The sequence below follows the corrected OpenSSF response list
(acknowledge, assess, negotiate embargo, patch privately, CVE,
choose disclosure date and prepare OSV, good day, notify under
embargo, release publicly, disclose fully):

1. Acknowledge within 1-2 business days of a valid report, even
   before triage.
2. Assess: reproduce the report, ask for missing facts, and decide
   vulnerability / not a vulnerability, with a reason. Auditability
   counts: a defect that breaks the recorded-evidence guarantees is
   a vulnerability. A feature request, a usage question, or an
   intended design tradeoff is not.
3. Agree the embargo with the finder as days of risk (below, "The
   response limits").
4. Patch privately: work in a private branch or a GitHub Security
   Advisory private fork, keeping the same quality gates as public
   work (`CONTRIBUTING.md`; private fork CI is not automatic, so
   run the gates locally).
5. Get a CVE via a CNA (below). Ask the finder whether they want
   to help draft it and how they want to be credited.
6. Decide the disclosure date, prepare a machine-readable OSV
   JSON entry (v1.9.0 schema) to publish over HTTP at a stable
   URL, and the advisory text.
7. Prefer a good disclosure weekday (Monday-Wednesday; avoid
   Friday and holidays) unless the issue is already public or
   exploited.
8. If there are downstream distributors to notify, send embargo
   notifications 1-30 working days before disclosure with CVE,
   description, affected versions, credit, mitigation, and
   timeline, and track replies.
9. Cut the release and disclose publicly: publish the OSV JSON
   and the advisory, with the CVE ID in the release notes.
10. Disclose fully: protected exploit details do not survive the
    public diff anyway; publish the cause, the fix, and any
    workarounds. A partial fix is acceptable if it is labeled.

## 5. The response limits (everyday posture)

- Embargo is counted in days of risk — time from first knowledge to
  public disclosure. The default is fewer than 7 days; the absolute
  maximum is about 14 days. Embargo is a coordination preference,
  not a promise that the project will stay quiet longer.
- Named exclusions: when the vulnerability is already public, when
  it is under active exploitation, or when no fix is achievable
  within the maximum, the project discloses early with details and
  workarounds instead of holding.
- Certification: this project holds no PKI the reporters could
  verify against; disclosure artifacts are hash-bound to the
  repository records and re-verifiable locally (decisions
  2026-08-24).

## 6. CVE and IDs

CVE IDs come from a CNA; the CNA of last resort for open source is
MITRE via <https://cveform.mitre.org>. Findings are also tracked as
GitHub Security Advisories when the repository is public. The OSV
vulnerability ID is recorded alongside the CVE.

## 7. What is in scope

The repository as a whole: `src/`, `tests/`, `docs/`, the build
and release gates (`Makefile`, `scripts/`, `.github/`, `hngh.asd`)
and their logic. A gate that can be bypassed or that lies about
what it checked is a security bug, because the runbook above and
the governance below trust the gates.

## 8. What is not

- Bugs with no security impact: use the issue tracker.
- Feature requests and usage questions: same.
- Third-party software: report upstream; dependency pins are
  reviewed at intake.
- Threat only at a scope without policy (no fail-closed guarantee
  there by design; it is reported as configuration error, not as a
  code vulnerability).
- Anything running as a service: this project has no deployed
  service; there is nothing to take down, only code to review and
  fixes to ship.

## 9. Related documents

- `GOVERNANCE.md` — who decides, and how this file changes.
- `CONTRIBUTING.md` — workflow, boundaries, DCO sign-off.
- `docs/project/decisions.md` — the record, including the fail-
  closed and no-PKI decisions this runbook assumes.
- `docs/records/2026-08-24-prior-art-landscape.md` — compared
  prior art (in-toto, SLSA, DSSE, Progent) and divergences.
- OpenSSF CVD guide sources (wiki, 2026-08-24) — the corrected
  runbook this documents.

The promises are bounded on purpose: one operator, business days,
honest embargo. If more is ever promised, the governance change
that says so is filed here first.