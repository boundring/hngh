# 2026-09-16 — accepted-risk dispositions: STEER_MODEL URL argv, git-push stderr, event text on argv

Lane: automation free-commit (docs + one site comment; no behavior
change). Closes the accepted-risk-candidate class left open by the
2026-09-16 credential-argv sweep with explicit, recorded decisions
instead of silent carry-over. The sweep's needs-fix items were fixed
the same day: notify.sh telegram+webhook moved to `curl -K -` stdin
config (docs/records/2026-09-16-notify-token-argv-exposure.md),
launch-session env(1) key-argv eliminated
(docs/records/2026-09-16-launchsession-key-argv-elimination.md), and
scripts/probe-model-route gained its 0600 token-file gate (kernel
candidate d100bff0bddec0608b0f02e1437c06cdd389d7c99c4578ce0d72be7223593470).
What remained were dispositions, not fixes. Also answers the notify
record's open question about webhook URLs: e2 judged them
secret-bearing and fixed them; that decision stands.

## 1. STEER_MODEL endpoint URL on curl argv — ACCEPTED (operator trust class)

Site: `automation/jobs/oversight-tick.sh` `steer_leg` (curl at ~:386):
the agentic steer prompt is POSTed to `"$STEER_MODEL"` as a curl argv
URL; the body goes via `-d @-` stdin, the reply is capped
(`head -c 400`). STEER_MODEL is operator-set with NO default (empty ->
leg disabled, breadcrumb `none (no STEER_MODEL)`).

Disposition: ACCEPTED RISK, argv form kept, binding requirement added
at the site. Rationale: STEER_MODEL is set by the operator in the same
act that arms the whole automation (cron/systemd environment) — whoever
can set it already owns the credential store and every secret this tree
touches. It is configuration in the operator trust class, not a
per-run credential transiting a trust boundary; the class this sweep
fixes is credential VALUES reaching a world-readable
`/proc/<pid>/cmdline`. The no-embedded-key requirement is now binding
and record-checked: never point STEER_MODEL at a key-in-URL route
(OpenRouter-style `?key=` or `:key@host` shapes); use an env-exported
key on a header-based route instead.

Conversion to `curl -K -` stdin config considered and REJECTED with
evidence: it would introduce a hole, not close one. The -K config
grammar keeps parsing after a quoted value ends, so a URL value
carrying a newline or an embedded double quote lets following lines
execute as arbitrary curl directives. Verified against a loopback
server on this host: `url = "http://127.0.0.1:PORT/x\nproxy =
http://127.0.0.1:9"` -> curl exit 5 (injected proxy could not
resolve); `url = "http://127.0.0.1:PORT/x" ` + newline + `proxy =
"http://127.0.0.1:9"` -> exit 7 (connection refused via the injected
proxy); the clean control delivered HTTP 200. The notify.sh -K form is
safe in ITS context (bot token is digit:alnum; webhook URL is
600-gated) but STEER_MODEL gains nothing from stdin config while
gaining this injection class — argv stands.

## 2. git-push.sh failure text into breadcrumbs/alert rows — ACCEPTED (git redaction verified)

Site: `automation/lib/git-push.sh`: push stderr (`$out`, :17) is
echoed into the fail breadcrumb (:23-24) and the alert row (:25-26).
Exposure class: IF the origin URL embedded a token, a failed push
could carry it into the report queue.

Empirical verification (scratch repos on this host, git 2.55.0,
remote `https://robot:ghp_FAKEtoken…@host/owner/repo.git`): observed
failure text for three classes — (a) DNS failure: ``fatal: unable to
access 'https://invalid.invalid/owner/repo.git/': Could not resolve
host: invalid.invalid``; (b) connection refused: ``fatal: unable to
access 'https://127.0.0.1:9/owner/repo.git/': … Could not connect to
server``; (c) HTTP 401 from a local server: ``fatal: Authentication
failed for 'http://127.0.0.1:PORT/owner/repo.git/'``. In ALL three
classes the userinfo (`robot:TOKEN@`) is stripped from every stderr
line; raw-token grep count was 0 in each. git redacts credentials from
transport error output by design.

Boundary note, also verified: `git remote -v` DOES echo the embedded
token — but git-push.sh never invokes it; the only remote inspection
is `git remote get-url "$remote" >/dev/null` (:14), output discarded,
exit status only.

Disposition: ACCEPTED, no code change. The redaction is git's own
verified behavior, cited here so the next sweep does not re-litigate
it. Residual, documented not actioned: git's redaction of FUTURE
failure shapes is upstream behavior we do not control, and the
report-queue sink-side redaction landing from the concurrent
emitter-boundary lane (docs/records/2026-09-16-emitter-boundary-redaction.md)
is path-scoped, not credential-scoped. An optional
belt-and-suspenders follow-up could strip `://user:pass@` shapes from
`$out` before the alert; rejected for now to keep the fail path
byte-faithful for debugging.

Residual amendment (2026-09-20, graph node gap-loose-6-credential-helper,
read-only adjudication): the verification above predates a runtime fact
the sweep did not inspect — ~/.gitconfig defines
credential.https://github.com.helper= (empty reset) followed by
helper=!/home/linuxbrew/.linuxbrew/bin/gh auth git-credential (same pair
for https://gist.github.com; gh 2.86.0, only config layer — no
/etc/gitconfig, no url.*.insteadOf rewrites). Today the helper is inert
for this repo: origin is SSH-form (git@github.com:boundring/hngh.git)
and credential.<url>.helper only fires on matching https URLs, so push
and fetch never consult it. IF origin ever flips to https://github.com,
the helper supplies credentials out-of-band: token attributes ride the
credential-helper stdout protocol into git's memory and never appear in
URLs, argv, or push stderr — the token-embedded-URL exposure class
verified above is structurally absent on that path, not merely redacted
at transport-error time. New failure shapes would reach sink A's
full-stderr alert (git-push.sh :17 -> :23-26 -> notify-email.sh :56-69
report-queue row + immediate-class email) and sink B's 200-char crumb
(16-remote-push.sh :109-113): gh helper nonzero exit (not logged in /
revoked token) with diagnostics on stderr, git's post-helper no-TTY
prompt fallback (`fatal: could not read Username for 'https://…'`), and
auth-rejected-token 401s already covered by class (c) above. Reasoned
from the documented protocol split (gitcredentials(7): helpers print
credential attributes on stdout; stderr is free-form diagnostics; gh
auth git-credential emits the token only in the stdout response) — no
auth flow re-run, per this record's scratch-repo boundary. None of these
shapes carry the token; the only credential-bearing channel they add is
opt-in: GIT_TRACE_CURL/GIT_TRACE curl tracing prints the Authorization
header (Basic base64 of login:token) into push stderr. Ops rule recorded
here: never enable git trace env in alert-producing paths (nothing in
automation/, scripts/, or Makefile sets it today, verified 2026-09-20).
Identity (not credential) residue: GitHub remote refusal text can name
the gh login. Sink C (16-remote-push.sh :99-104 gate tail) is a
make-test output window, not a git-credential path — no helper shape.
No test pins origin URL form, helper presence, or insteadOf rewrites
(automation/tests + kernel tests grepped 2026-09-20; sink-side
redaction family at scripts/test-report-queue.py:317-349 unaffected).
Disposition unchanged: ACCEPTED, no code change; this amendment exists
so the helper fact and the https-flip conditional are on record and the
next sweep does not re-litigate them.

## 3. Notification/event TEXT on argv — ACCEPTED (no credential channel)

Sites: notify.sh `--data-urlencode "text=…"` and the webhook JSON
built via `python3 -c '…' sys.argv` (class/subject/body ride python's
argv); omp/jcode prompt bodies on executor argv (launch-session.sh
command arrays); breadcrumbs and report-queue rows carrying failure
TEXT.

Disposition: ACCEPTED as a class under this invariant: CREDENTIAL
VALUES NEVER FLOW THROUGH TEXT CHANNELS. Text fields carry http codes,
file paths, source names, and prompt bodies by design; TEXT on argv is
not a credential exposure. Verified exemplars: notify failure strings
are `telegram-notify failed: HTTP $code` / `webhook-notify failed:
HTTP $code` (notify.sh); breadcrumbs report key SOURCE names only
(`env KIMI_AI_KEY`, `key file` — never values; credential-health.sh
kimi/ocgo probe preamble, notify.sh KEY RULE); alert failure strings
carry http codes and paths only. Boundary rule that keeps the
invariant true: any new emitter that wants to include a resolved
credential VALUE in a message, prompt, breadcrumb, or report row is a
needs-fix, not a disposition — and is additionally caught by
verify-candidate.py's credential-pattern guard at ceremony.

## Disposition summary

| Sweep candidate | Disposition | Action |
|---|---|---|
| oversight-tick.sh STEER_MODEL URL argv | accepted-risk (operator trust class) | binding no-embedded-key requirement at site + here |
| git-push.sh `$out` into report queue | accepted-risk (git redaction verified) | none; citation + residual note |
| event/notification TEXT on argv | accepted-risk (no-credential-values invariant) | recorded invariant |
| credential-health bearer argv headers | NOT dispositioned here | open fix candidate (graph node g3-credhealth-bearer-stdin) |

## Validation

Experiments run 2026-09-16 on this host against scratch dirs only (no
repo file touched by experiments): git push/fetch stderr token
probes across DNS-failure, connection-refused, and HTTP-401 endpoints
(git 2.55.0); curl `-K -` injection probes (newline and embedded-quote
payloads vs clean control) against a loopback python http.server.
`bash -n` clean on the touched script. Suites re-run green the same
day during this slice's audit pass: test-notify-seam,
test-notify-send-path.py, test-ocgo-launch.py,
tests/scripts/test-probe-model-route.py.
