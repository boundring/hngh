# Browser-based messaging automation against active logins

Status: RESEARCH RECORD — operator open question 2026-09-03 (directive
6): can the browser-based messaging approach be automated, targeting
active logins (Google Messages web, Discord, WhatsApp, etc.)? The
email channel is already procedural; this line is about a
browser-driven channel with near-zero token cost. **No browsing
happened in this beat** — probes were filesystem/PATH existence checks
only.

## 1. Machine probes (run 2026-09-04, read-only)

| Probe | Result |
|---|---|
| `command -v chromium google-chrome-stable chromium-browser` | none found in PATH — no Chrome-family binary on PATH |
| `python3 -c "import playwright"` | ModuleNotFoundError — Playwright not installed for python3 |
| profile dirs under `~/.config` (EXISTENCE only, never opened) | `~/.config/chromium` and `~/.config/google-chrome` both exist |

Interpretation: browser profile data exists (the operator uses
Chromium-family browsers), but no automation-ready driver is
installed. `~/.config/google-chrome` existing without a
`google-chrome-stable` binary on PATH suggests a Google Chrome
install outside PATH, a removed binary, or only partial profile
remnants — **not established** which. Profile contents were never
read; existence is the only claim.

## 2. Candidate architectures

**A — CDP attach to the operator's running browser**
(`--remote-debugging-port` on the operator's own profile).

- Pros: zero login work (uses live sessions), true "active logins".
- Cons: requires the operator's daily browser to run with a debug
  port (a standing security-posture change — any local process can
  drive the browser); automation shares the operator's session
  cookies, history, and tabs; a crash in automation is a crash in the
  operator's browser. This inverts the isolation boundary and touches
  the security posture → critical-class by the standing rules.

**B — Playwright persistent context with an isolated profile the
operator logs into once.**

- Pros: full isolation (own profile dir, own cookies — session
  credentials never touch the operator's daily browser); the login
  persists across runs so it is a ONE-TIME human step; Playwright's
  API is stable; headless or headed per need.
- Cons: requires installing playwright + a browser build; first
  login per service is manual (acceptable — exactly the kind of
  one-time setup step the near-autonomous posture turns into a
  prompted setup item); some services (WhatsApp Web especially) may
  notice automation and require periodic re-verification.

**C — Native/app channels (Discord bot token, email relays)** —
outside this line's scope for WhatsApp/Google Messages (no bot API
for the latter; Discord already has bot infrastructure but the
operator's directive targets active personal logins).

## 3. Token-cost analysis

The old browser-based Google-Messages notifications were retired
because an LLM DRIVING a browser burns real tokens per notification.
A scripted sender flips this: once the flow is procedural (compose →
send to a fixed recipient with a fixed body template), the marginal
token cost per message is **near zero** — the same economics as the
email digest channel (scripts/email-digest.py), which already
operates procedurally. The LLM is involved only in authoring the
message body, which the digest composer already does for email.
Browser automation here is TRANSPORT, not intelligence.

## 4. Risks

- **Session credentials ARE credentials**: the isolated profile stores
  live session cookies for the operator's messaging accounts. Rules
  inherited from [../design/credentials-posture.md](../design/credentials-posture.md):
  the profile dir is 700-mode territory, never exfiltrated, never
  copied into backups or repos, never logged; its loss is an
  incident, not an inconvenience.
- **ToS and fragility**: driving messaging webapps by script likely
  violates their ToS; DOM changes break selectors without notice.
  Mitigation: one channel first (the most stable), template-based
  sends only (no freeform scraping), failures recorded as lessons and
  tuning — never retried in a loop against a service that refused.
- **Rate/human signals**: a machine that sends messages must look
  nothing like a spammer: single recipient (the operator), low
  volume, explicit enablement before the first send.
- **Scope creep**: each added service multiplies fragility. One
  channel first; others only after the first is boring.

## 5. Recommendation

Prototype slice scoped to **Google Messages web** via **Playwright
persistent context, isolated profile** (architecture B), because:
Google Messages web is the channel the operator previously used for
notifications (known-good recipient and message shape); its web UI is
comparatively stable; and messages-web pairing is QR-based one-time
rather than per-session. Gated on the probes: the slice requires
`playwright` installed (and its chromium build) — currently absent.
Until that install happens (a normal-risk hngh-automation dependency
step) the slice is **parked**; it enters execution only when a plan
admits it with the probe gate re-run at execution time.

Discord and WhatsApp remain future candidates behind the same
pattern, deliberately not prototyped here.

## 6. Re-probe 2026-09-04 (admit/park gate — capabilities plan step 6)

The §1 battery re-run 2026-09-04, same probes, verbatim results:

| Probe | Result |
|---|---|
| `command -v chromium google-chrome-stable chromium-browser google-chrome` | no output, exit 1 — still no Chrome-family binary on PATH |
| `python3 -c "import playwright"` | `ModuleNotFoundError: No module named 'playwright'` — still not installed for python3 |
| profile dirs under `~/.config` (EXISTENCE only, never opened) | `~/.config/chromium` and `~/.config/google-chrome` both still exist |

Verdict: **PARK** (step 7 does not admit). The exact missing piece is
unchanged from 2026-09-03: `playwright` is not importable, and with
no package there is no chromium build available to it either — both
halves of the ADMIT condition fail. Per the plan's boundary record:
the playwright pip install (+ `playwright install chromium`) is a
normal-risk hngh-automation dependency step, but browser acquisition
on this host has NOT been granted to machine sessions — the missing
binary is the operator-procedural step, so the slice stays parked
until a plan admits it with this gate re-run at execution time.

Credentials rules the isolated profile will inherit when it admits
(credentials-posture.md §4, standing): no plaintext secrets in any
repo; no secret values in logs, breadcrumbs, report rows, or digests;
the profile dir is 700-mode, never backed up, never copied; session
credentials ARE credentials and redact to paths, never values; a
world-readable secret-bearing file is alert-class.

Successor doc 2026-09-04: docs/research/2026-09-04-browser-relay-architecture.md
— what omp's browser relay actually does (evidence-quoted), the
post-install Route A verdict, and the operator-authorized extension
relay (Route B) design.
