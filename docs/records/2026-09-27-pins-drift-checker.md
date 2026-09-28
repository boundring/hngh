# pins-drift checker (2026-09-27)

Design: docs/research/2026-09-26-arc-20260925-os-package-pairing.md (the
os-package-pairing line's answer: a comparator, never an actuator).

automation/jobs/pins-drift.py is the pure function pins x pacman-db ->
report: reads the pins file fresh each run (moment-of-action freshness),
queries pacman read-only (`pacman -Q`, fallback `pacman -Qq`), and diffs.
Drift kinds: `missing` (pinned, absent from db) and `older` (db version
below the pin's min_version floor; a floor, not an exact pin -- db newer
is not drift). db-explicit packages without pins are counted, never
alerted individually. The checker never installs, upgrades, or removes
anything: the only pacman invocations in the tree are -Q/-Qq (auditable
by grep). Dual-surface failure rule honored: an unreadable pins file, a
missing pacman, or a failing query is a fail-closed error (exit 2,
mirroring scripts/report-queue conventions), never coerced into "no
drift"; --json shape is {drift:[{name,pin,db,kind}], unpinned_count, ok}
(consumer: daily/31-omarchy-readiness.sh reads "ok": true|false).

Path deviation (approved by operator 2026-09-27): the pins file is
automation/config/hngh-pins.tsv, NOT hngh-packages.tsv -- that path is
the 2026-09-11 collected-repositories registry with its own schema and
guard test (test-hngh-packages.py). Created on first run with header
`name|min_version|note` plus seed rows from lib/prereqs.sh's prereq_pkg
map (names only, no versions; deliberately not a mass `pacman -Qqe`
import). # ponytail: version compare is naive epoch+dot-numeric
(vercmp-lite); upgrade to pyalpm.vercmp if lettered pkgvers ever matter.

automation/cadence/calendar/daily/30-pins-drift.sh runs the module daily
(python3 -B): drift>0 files ONE identity-deduped alert
(pins-drift:summary, 7d window) with counts + up to 5 names; a module
error files pins-drift:error with the exception repr; clean files
nothing. Every path exits 0; on success only breadcrumbs escape.

Verification: automation/tests/test-pins-drift.sh (41 checks, hermetic
sandbox, stub pacman FIRST ON PATH driven by a fixture): seed-on-absent,
clean match, json shape, missing/older kinds, epoch floors both
directions, malformed-row skip, pacman failure/absence fail-closed,
beat clean/drift/error rows, identity-window dedupe. Red-first: 6/40
passed before the module existed.
