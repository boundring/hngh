#!/usr/bin/env bash
# cadence/1m — crumbs-mirror tick: byte-offset sync of the STATE.md crumb
# journal into state/crumbs.db (lib/crumbs-db.py; read-only wrt STATE.md).
# Fail-closed: exit 0 always (the lib itself is fail-open).
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/lib/crumbs-db.py" sync
