# Lessons Learned (consolidated)

Dogfood-era lessons, each with the incident that taught it. Distilled from the
M2–M6.2 work sessions (2026-07-31). Read this before the next wave; it is
cheaper than re-learning.

## Engineering

1. **`(make-string (file-length s))` + `read-sequence` leaves NUL padding on
   multi-byte UTF-8** — `file-length` is bytes, not characters. Use
   `(subseq str 0 (read-sequence str s))`. A 13.8KB task got HTTP 400 for it
   (M6.1, task #3); the fix hardened `escape-json-string` to `\u00XX` anyway.
2. **Error handlers that call fallible code mask the real error** —
   `log-cost-entry` called `default-model` unconditionally; its `ecase` covered
   only API tools, so agentic invocations "failed" even when they succeeded
   (M6.2, task #5). Make lookups total; never let accounting code throw for a
   new tool type.
3. **`ecase` is a landmine in extensible systems** — four sites needed a branch
   for `:local-openai-api` (`default-model`, `format-json-payload`,
   `provider-api-headers`, `invoke-agent`'s member list) across M2–M6.2.
   Prefer `case` + fallback or data-driven lookup (`*provider-endpoints*`).
4. **Never gate a service on a long `ExecStartPost`** — systemd's start-post
   timeout killed the whole unsloth unit. Warm-up belongs in a separate
   oneshot pulled in by `Wants=` (M0 lesson).
5. **Brew Cellar paths in autostart break silently on upgrade** — pin to the
   version-agnostic symlink (`/home/linuxbrew/.linuxbrew/bin/<tool>`).
6. **State-store root is `~/.hngh/`, not `~/.hngh/state/`** — the queue lives
   at `~/.hngh/tasks/queue.lisp` (M3 surprise).
7. **Single-completion unified diffs of 300+-line files exceed the local 12b** —
   it produced an import-breaking diff with placeholder values; specs and
   bounded prose suit it fine (svc-dash wave-5 review). Machine-drafted code
   is reviewed, never trusted.
8. **`rtk <cmd> > file` captures rtk's truncated view, not the raw output** —
   run plain `make test > file` when the full log matters.

## Operations

9. **`hermes -z` takes the prompt as its argument** — flags first:
   `hermes -m <model> --provider <p> -z "prompt"`.
10. **python-dotenv doesn't expand `~`** — CA paths must be absolute; bundle
    (`SSL_CERT_FILE` etc., replace semantics) vs append (`NODE_EXTRA_CA_CERTS`)
    differ per variable.
11. **A dead llmtrim daemon + pinned proxy env breaks ALL API calls, local
    included** — `NO_PROXY=127.0.0.1,localhost,::1` matters.
12. **tmux pane indices shift when panes die** — target by content, or re-add
    with `mc add`; don't trust remembered indices.
13. **Chmod your status scripts** — `hngh-status` ran unexecutable for a day
    and the watch pane said so, politely, forever.

## Process

14. **Wave files (context / current-state / target / tasks / verification /
    anti-patterns) make local-model workers effective** — one wave per working
    session; context pollution causes drift (gbd convention, adopted
    everywhere).
15. **Per-model attribution pays for itself immediately** — every artifact
    names agent + model + cost; review quality is judgeable only with
    provenance (now a convention in both repos' AGENTS.md).
