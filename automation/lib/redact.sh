# redact.sh — backstop shims over the single-source scrub module.
# Since the 2026-09-16 consolidation (llc-gate-scrub-site-divergence)
# the one path-token definition lives in automation/lib/scrub.py;
# this file keeps the historical redact_home() name every emitter
# already sources and routes it (and scrub_paths) through scrub.sh.
# Markers: scrub_paths fails closed to "[redacted path]"; redact_home
# renders the kernel-ledger tilde convention (~ = /home/<user>,
# ~tmp = /tmp) so alert rows stay readable. Both die on absolute
# machine-local paths; the token family is ONE family
# (lib/scrub.py: home/users/root/tmp/scheme-relative/tilde + URL
# userinfo), not two regex copies.
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scrub.sh"

# compat name: emitters keep calling redact_home; same family, tilde
# rendering (the kernel ledger sink convention).
redact_home() { redact_home_impl "$@"; }
