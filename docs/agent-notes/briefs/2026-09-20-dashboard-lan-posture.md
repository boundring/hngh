# DECISION-READY brief: hngh dashboard LAN exposure of :8890

Node: `wr-pub-paths-posture-brief` · 2026-09-20 · Brief only — no files edited,
no ufw/sudo/firewall state touched. Every "settled fact" was re-verified live
this session; corrections to the task brief are flagged inline.

## Verified current state

| Fact | Evidence |
|---|---|
| `hngh-dashboard.service` runs `automation/dashboard-server.py`, binds `0.0.0.0:8890` | `automation/README.md:12`, `:53`; bind code at `automation/dashboard-server.py:1152-1153` (`ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("DASHBOARD_PORT", "8890")))`); live `ss -tln` shows `LISTEN 0.0.0.0:8890` |
| ufw allows LAN in to :8890, comment "deck dashboard" | `/etc/ufw/user.rules` line 42: `-A ufw-user-input -p tcp --dport 8890 -s 192.168.0.0/24 -j ACCEPT` (rule is the 6th and last `ufw-user-input` ACCEPT) |
| REMOTE-ACCESS.md claims the opposite of reality | `automation/REMOTE-ACCESS.md:45-46`: "ufw on the desktop blocks LAN :8890 by design; the dashboard is reachable only over the tailnet" — **false** |
| Default ufw input policy is DROP | `/etc/default/ufw:11` `DEFAULT_INPUT_POLICY="DROP"` |
| **No tailscale0 allow rule exists in ufw** | `grep tailscale /etc/ufw/user.rules` → no matches; the only 6 input ACCEPTs are LAN/port-22/loopback-dst rules. With `DEFAULT_INPUT_POLICY="DROP"`, plain rule deletion in Option B would sever tailnet access too, so Option B adds an explicit `allow in on tailscale0`. Whether tailnet→8890 works today under DROP-without-allow was not separately re-tested end-to-end; see Open questions. |
| Anonymous LAN GET surface (curl from localhost, no token) | `/sessions.json` 200, ~881 KB this probe (brief said 2+ MB — size varies with feed contents; the 2 MB+ figure matches heavier feed states), `/data.json` 200 (~11 KB), `/research-routes.json` 200 (~40 KB), `/kb/` 200, `/feedback/` 200. `/hngh-docs/` returned **404** at probe time (see Open questions) |
| `~` literal paths leak in the transcript feed | 265 occurrences in one `/sessions.json` fetch |
| GET `/` embeds the live dashboard token | served HTML head contains `<meta name="hngh-token" content="eda73ba6...">`; injection at `automation/dashboard-server.py:606-619`, guard at `:710-726`; design record `docs/records/2026-09-11-dashboard-p1-server.md:15-16` documents the meta-tag tradeoff, and `:716` documents the same token also riding in digest email |
| Token-gated POSTs exist incl. backup | `automation/dashboard-server.py:105` `POST /system/backup-now {}`; dispatch table `:749` |
| Tailscale remote channel is real and manual-run | `automation/deck/tailscale-serve.sh` (ssh-triggers `sudo tailscale serve --bg 8890` on the desktop; idempotent; "manual-run only" per `automation/REMOTE-ACCESS.md:142`); documented tailnet URL `http://100.83.36.27:8890` (`automation/REMOTE-ACCESS.md:29`) |

**Bottom line:** any device on `192.168.0.0/24` (guest IoT, phones, any
compromised LAN host) can anonymously read the full transcript feed, docs,
and knowledge base, and can harvest the token from `GET /` to issue
token-gated POSTs — including `/system/backup-now`. The documentation states
the inverse posture, so the repo's safety story is currently wrong, not just
stale.

## Option A — "LAN on purpose" (keep 0.0.0.0 bind + ufw allow, fix the docs to match reality)

**Thesis:** the LAN exposure was added deliberately (rule comment "deck
dashboard", README "phone on LAN" line) for couch/phone convenience; keep
the convenience, make the docs honest, and file the token/path leaks as
follow-ups.

- `automation/REMOTE-ACCESS.md:44-46` — replace the last bullet sentence
  (keep the sshd operator-step sentence at `:42-44` intact) with:

  > ufw on the desktop **allows** LAN :8890 by design (rule comment
  > "deck dashboard", added for the deck/phone couch path): the dashboard
  > is reachable from any 192.168.0.0/24 host, not only over the tailnet.
  > GETs are anonymous and GET `/` embeds the POST token as a meta tag, so
  > a LAN client can read the feeds and mint token-gated POSTs — accepted
  > LAN-trust tradeoff (2026-09-20 posture review). Follow-ups: stop
  > serving the token to anonymous GETs, and scrub `~` paths
  > from `/sessions.json` (265 hits per fetch). Remote-over-WAN path is
  > unchanged: tailnet via `http://100.83.36.27:8890` or
  > `tailscale serve`.

- `automation/README.md:53` — replace with:
  `**Dashboard**: 0.0.0.0:8890 — intentionally LAN-open (ufw allows 192.168.0.0/24; ufw comment "deck dashboard"). Remote path: tailnet `http://100.83.36.27:8890`. Phone on LAN: http://192.168.0.186:8890.`

- Exact commands (none required for the posture itself; operator runs):
  ```bash
  # Confirm the rule that makes A true (no change):
  sudo ufw status verbose | grep 8890        # expect: 8890/tcp ALLOW 192.168.0.0/24  # deck dashboard
  # Follow-up 1, stop serving the token to anonymous GET / (code change, no firewall):
  #   in automation/dashboard-server.py:606-619, inject the meta only when the
  #   request carries a valid X-Hngh-Token (or serve index tokenless and move
  #   UI auth to a login form); then rotate: rm automation/dashboard/token.txt
  #   and restart so the harvested value dies: systemctl --user restart hngh-dashboard
  # Follow-up 2, scrub paths from the feed (feed generator change):
  #   sed-level replace $HOME → '~' in the sessions.json producer before serialize.
  ```

- **Residual risk (unchanged by A, made honest by A):** full anonymous read
  of transcripts/docs/KB to every LAN host; token disclosure to every LAN
  host ⇒ anonymous `POST /system/backup-now` and any other token-gated
  mutation by any LAN client; literal home paths leak usernames and layout.
  A WiFi guest = full dashboard read + POST access.
- **Reversibility:** docs edits are plain git reverts. Firewall state is not
  touched. Token rotation is one file delete + service restart.

## Option B — "tailnet-only as documented" (make reality match the docs)

**Thesis:** the documented intent is the safer posture; enforce it at the
firewall, optionally harden the bind, keep tailscale-serve as the remote and
couch path (the deck shortcut works unchanged from anywhere).

- `automation/REMOTE-ACCESS.md:44-46` — replace the last bullet sentence with:

  > ufw on the desktop blocks LAN :8890 and allows :8890 only on
  > `tailscale0` (2026-09-20 posture review made reality match this
  > bullet): the dashboard is reachable only over the tailnet. On the LAN,
  > use the deck's `tailscale-serve.sh` shortcut or any tailnet device at
  > `http://100.83.36.27:8890`.

- `automation/README.md:53` — replace with:
  `**Dashboard**: binds 0.0.0.0:8890 but ufw admits :8890 only on tailscale0 — tailnet-only (http://100.83.36.27:8890; deck couch path = tailscale-serve.sh). No LAN listener.`

- Exact commands (operator runs; firewall change requires sudo):
  ```bash
  # 1. Admit 8890 ONLY from the tailnet interface, then drop the LAN allow.
  #    Order matters: add the tailscale allow BEFORE deleting the LAN rule.
  sudo ufw allow in on tailscale0 to any port 8890 proto tcp comment 'dashboard tailnet-only'
  sudo ufw delete allow from 192.168.0.0/24 to any port 8890 proto tcp
  sudo ufw status numbered                      # verify: tailscale0 allow present, 192.168.0.0/24 8890 gone
  #    (user.rules alternative, no ufw rewrite: delete line 42 only — but with
  #    DEFAULT_INPUT_POLICY=DROP that alone kills tailnet access too, so the
  #    tailscale0 allow above is REQUIRED, not optional.)
  # 2. Optional hardening: bind loopback+tailscale only (config.env:
  #    DASHBOARD_BIND=127.0.0.1 — needs a small code change at
  #    dashboard-server.py:1152 to read it; not required once ufw enforces).
  # 3. Optional LAN-allowlist instead of full close (if couch/LAN phone use
  #    must survive): replace the /24 allow with single-host allows, e.g.
  #    sudo ufw allow from 192.168.0.64 to any port 8890 proto tcp comment 'deck dashboard'
  # 4. Verify from a LAN client (should time out) and over tailnet (should 200):
  #    curl -m 3 http://192.168.0.186:8890/data.json ; curl -m 3 http://100.83.36.27:8890/data.json
  ```
  The repo-side doc edits above are normal working-tree commits; the ufw
  commands are host-state changes outside the repo.

- **Residual risk:** any tailnet-enrolled device (deck, phone with the
  connector installed, anything that later joins `boundring@`) still gets
  anonymous GET + token meta. The token-via-`GET /` leak and
  `~` path leakage persist over the tailnet path — the same two
  follow-ups as Option A apply, with lower urgency. sshd password auth
  being still enabled on the desktop (REMOTE-ACCESS.md:42-44) remains a
  separate open LAN exposure either way.
- **Reversibility:** one command restores today's state exactly:
  `sudo ufw allow from 192.168.0.0/24 to any port 8890 proto tcp comment 'deck dashboard'`
  (plus optionally removing the tailscale0 allow). Firewall changes are
  instant, in-memory-on-reload, and non-destructive to data. Token rotation
  identical to Option A.

## Recommendation

**Option B matches the documented intent.** REMOTE-ACCESS.md's
"vacation topology" (set up 2026-08-28, "trip-hardened" security posture,
key-only deck ssh) is written around tailnet-only reachability, and the ufw
comment "deck dashboard" is satisfied better by the tailnet path — the deck
reaches the dashboard from anywhere via `tailscale-serve.sh`/`hngh-tunnel`,
which is strictly more capable than the LAN rule it supposedly motivated.
Option A is defensible only if the operator actually uses plain-LAN phone
access daily and accepts guest-network read+POST exposure; even then the
token-in-meta leak should be fixed first, since today the token gives LAN
guests write access, not just read.

**FINAL CHOICE: OPERATOR DECISION REQUIRED.** Both options are fully
specified above; executing either Option B's ufw commands or Option A's
token-rotation step requires operator-run sudo and an explicit operator
call. Repo doc-text replacements in either option can be committed by a
machine session only after the operator names the option.

## Open questions / what I did not check

- `/hngh-docs/` returned 404 from localhost at probe time (2026-09-20
  02:38Z), contrary to the task's settled-facts list. Either the route is
  conditionally mounted, the corpus lives at a different path, or that
  fact came from a different feed state. Re-verify before relying on it in
  either option's risk text.
- I did not verify end-to-end that tailnet→8890 currently WORKS given
  `DEFAULT_INPUT_POLICY="DROP"` with no tailscale0 allow in user.rules.
  If it does work, some non-user.rules chain (e.g. ufw-before rules
  accepting established/interface traffic) admits it; if it does not,
  Option B's tailscale0 allow is a fix rather than a no-op and Option A's
  "reachable only over the tailnet is false" framing still holds for LAN.
  The operator should run the step-4 curl pair in Option B before/after
  any change.
- Did not enumerate remaining token-gated POST endpoints beyond
  `/system/backup-now` (`dashboard-server.py:749` dispatch table has more
  entries), did not measure `/sessions.json` size history (2+ MB claim vs
  881 KB probe), and did not audit whether `config/machine.env` overrides
  `DASHBOARD_PORT`/bind on this host (README:111-113 says it can).
- Did not touch: any file in the repo, ufw state, the token file, or
  systemd units.
