# operator-item.sh -- file one operator-item for the dashboard feed
# (2026-09-09 budget-governance directive:
# docs/records/2026-09-09-budget-governance-directive.md): when a spend
# cap blocks an operator-priority plan, request the amendment as an
# operator-item instead of waiting or burning filler; caps are never
# amended by machine sessions. The alert row is the report-queue
# contract; the alert crumb is what jobs/operator-items-feed.py reads.
# Requires lib/breadcrumbs.sh + lib/notify-email.sh sourced first.
# Deduped by identity within 7 days (refiles bump the xN marker).
operator_item() { # identity text
  alert_row "$1" 604800 "[hngh] $1" "$2"
  breadcrumb "${JOB_NAME:-operator-item}" "alert" "$2"
}
