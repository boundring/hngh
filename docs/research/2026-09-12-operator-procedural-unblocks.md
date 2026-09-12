# 2026-09-12 — operator procedural unblocks (plan step 1, 2026-09-08-operator-unblocks)

## Question

What exact operator steps still block the 2026-09-03-staging plan and the
remaining operator-side item of the 2026-09-03-capabilities plan, and can the
operator proceed autonomously or is human intervention required?

## Evidence read

- Plan file `docs/project/plans/2026-09-08-operator-unblocks.plan.md` step 1
  RESOLUTION (2026-09-09, job PlatformUnblock): `op` 2.32.1 present via
  linuxbrew; playwright declared unnecessary (ui-audit is puppeteer-core +
  axe-core on system Chrome); only the SMTP credential item-create remained
  operator-side.
- Live re-verification 2026-09-12T11:xxZ (this session, stale-state check per
  the 2026-09-12 obsolete lessons):
  - `op` 2.39.0 installed under the linuxbrew prefix (upgraded since the
    resolution; NOT on the non-login shell PATH — scripts must resolve it
    by absolute path or the operator's login PATH).
  - `/usr/bin/google-chrome-stable` present; `automation/package.json:7-8`
    declares `axe-core ^4.10.0` + `puppeteer-core ^23.0.0` (no playwright
    anywhere in the ui-audit dependency set).
  - `~/.hngh-automation/notify-email.conf` exists (mode 600, mtime
    2026-09-09T14:28Z) — the operator completed the conf-placement step.
  - `automation/logs/notify-email.log` tail: repeated
    `no password available (1password unreadable, conf pass empty) — fail
    closed` — the channel is configured but fails closed at send time.
    Fail-closed site: `automation/scripts/notify-email.py:116` (with the
    `op`-unavailable fallback notice at `:113`).

## Doctrine applied

- Fail-closed contract (automation/README.md): expected missing-credential
  conditions exit 0 and breadcrumb; they are data, not bugs.
- Operator-flexibility doctrine (docs/records/2026-09-09-operator-flexibility-doctrine.md §2):
  credential/secret steps are operator-owned; machine sessions never read or
  write the conf contents (this session verified existence and mode only).
- Stale-state lesson (automation/state/ocgo-agent-lessons.md, 2026-09-12
  obsolete rows): re-verify every earlier claim against current state before
  acting on it.

## Findings

1. Playwright/chromium: NOT needed and NOT installed — confirmed correct.
   The 2026-09-03-staging plan's playwright precondition is void as written;
   its real precondition is the kernel gate (`make test`), which recent
   routed sessions show red (STATE.md 2026-09-12T11:02:14Z plan-blocked rows,
   `kernel-gate-red-rc2`).
2. `op` CLI: installed (2.39.0, linuxbrew). The blocker is not the binary but
   the live session: `op account list` fails from a non-login shell without
   desktop-app integration.
3. SMTP credential: the conf exists, but every send fails closed because
   (a) 1Password is unreadable (no live `op` session) and (b) the conf `pass`
   fallback is empty. The email channel is armed but mute.
4. Verdict: the remaining steps are strictly human — the operator must
   (i) open the 1Password app, Settings > Developer > "Integrate with
   1Password CLI", (ii) run `op signin` in a login shell and confirm with
   `op account list`, and (iii) either create the SMTP item
   (`op item create --vault=<vault> --title=hngh-notify-email email
   <user> password <pass>`) and point the conf `[1password]` item at it, or
   place the app-password in the conf `pass` field by hand. No agent can
   perform (i); autonomous unblock is impossible without the operator.

## Recommended next line

Once the operator completes (i)-(iii), one verification beat:
`bash automation/scripts/setup-notify-email.sh --from-1password "op://<vault>/<item>/password"`
or a single test send, then the email channel goes live and the
2026-09-08-operator-unblocks plan step 3 unblocks (staging steps re-run under
their own plan routing once the kernel gate is green).
