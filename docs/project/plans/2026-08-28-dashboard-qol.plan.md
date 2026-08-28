<!-- plan: status=accepted risk=normal accepted=2026-08-28T17:35:00Z -->
# 2026-08-28 — dashboard QoL

Dashboard quality-of-life wave per operator directives: the logs page
gets a known-good-pattern design brief, the research page gets a
lifecycle display brief, and a stale-digest regression found by review
is closed. Autonomy rule (also in the overnight-cycle prompt): hngh
docs changes land via certificate ceremony with a green `make test`;
hngh kernel src/tests/Makefile/hngh.asd changes are FORBIDDEN — park
them. Never touch provider/credential config, systemd unit state,
tracked deletions outside the 48h prune, or secrets.

## Steps

- [x] Close the review P1: stale "Morning report 2026-08-26" no longer
      embedded in dashboard/data.json /digest (hngh-automation
      `be984d2` — the dead logs/MORNING-REPORT.md feed removed from
      lib/common.sh update_dashboard).
- [ ] Read docs/research/2026-08-28-log-presentation-patterns.md and
      write docs/design/logs-page-spec.md: known-good logs organization
      (12-factor event streams, structured events, severity/facet
      filtering, rate histograms, retention tiers, redaction) mapped
      onto the hngh-automation dashboard's logs tab with concrete
      component notes.
- [ ] Write docs/design/research-page-spec.md: the research tab renders
      the research-line lifecycle (research-lines.tsv via research.json
      `lines` array) as a campaign board — per-line state, next beat,
      crystallized results linking to docs/research/ — design only,
      implementation rides a later build wave.
- [ ] File a progress row for each spec via report-queue and leave the
      two spec files in the working tree for the next ceremony.
