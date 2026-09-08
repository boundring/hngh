# params.sh -- read loop tunables from the cadence-params.tsv inventory at
# the repo root. get_param KEY DEFAULT -> value on stdout. Fail-open: a
# missing or malformed file/row yields DEFAULT; comment lines starting with
# # are ignored. Callers keep their own env override ahead of the tsv row
# (that precedence is per-caller and unchanged).

get_param() { # key default -> value on stdout
 local key="$1" def="$2" root file row
 root="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
 file="$root/cadence-params.tsv"
 [ -f "$file" ] || {
  printf '%s' "$def"
  return 0
 }
 row="$(awk -F'\t' -v k="$key" '$1==k && $2!="" {print $2; exit}' "$file" 2>/dev/null)"
 printf '%s' "${row:-$def}"
}
