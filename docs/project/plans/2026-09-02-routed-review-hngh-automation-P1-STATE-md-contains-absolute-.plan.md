<!-- plan: status=executed risk=normal accepted=2026-09-02T10:01:26Z executed=2026-09-08T02:44:00Z routed-from=review:hngh-automation:P1-STATE-md-contains-absolute- -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh-automation:P1-STATE-md-contains-absolute-`
at 2026-09-02T10:00:45Z. Alert text: review P0/P1 (hngh-automation): P1: `STATE.md` contains absolute home paths (e.g., `/home/bricker/Projects/etc/hngh-automation/...`) in the new log entries. This violates the "public-content gate" mentioned in the `hngh` lessons (`docs/project/lessons-2026-09-01.md` explicitly notes that absolute home paths are a gate violation and should be normalized to `~/` form).

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

      Executed 2026-09-08 (automation commit e18630e, pushed): every
      STATE.md writer sink now renders $HOME-prefixed paths in ~/-form
      (lib/breadcrumbs.sh guard + night-session.sh printf rows routed
      through breadcrumb() + router-tick.py / jobs/service-state.py
      guards); regression test tests/test-breadcrumbs.sh in the make
      test gate. Named verification: finding's own check — new log
      entries carry no absolute home paths (live 2026-09-08T02:41Z
      cadence tick emits ~/-form, grep of post-fix entries = 0
      matches); `make test` rc=0. Historical rows left as-is
      (gitignored machine data; finding names new entries; scrub, if
      ever re-flagged, lands as a script through the normal gate — no
      ad-hoc sed -i on ledgers).
