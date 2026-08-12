SHELL := /bin/bash

HNGH_ARCHIVE_ROOT ?=

.PHONY: test check-archive

test:
	python3 tests/scripts/test-lint-parens.py
	sbcl --script tests/run.lisp
	sbcl --non-interactive --eval '(require :asdf)' --eval '(asdf:load-asd "$(CURDIR)/hngh.asd")' --eval '(asdf:load-system :hngh)'

check-archive:
	@set -euo pipefail; \
	archive="$(HNGH_ARCHIVE_ROOT)"; \
	if [ -z "$$archive" ]; then \
	  printf '%s\n' 'HNGH_ARCHIVE_ROOT must name the retirement archive' >&2; \
	  exit 2; \
	fi; \
	metadata="$$archive/metadata"; \
	[ -d "$$archive" ] && [ -f "$$metadata/inventory.py" ]; \
	tmp="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp"' EXIT; \
	sha256sum -c \
	  "$$metadata/pre-move.tsv.sha256" \
	  "$$metadata/post-move.tsv.sha256" \
	  "$$metadata/repository-pre-move.tsv.sha256" \
	  "$$metadata/repository-post-move.tsv.sha256" \
	  "$$metadata/worktree-uncommitted.sha256" \
	  "$$metadata/supplemental-2026-08-11.tsv.sha256"; \
	primary=("$$tmp/primary.tsv" home "$$archive/home/hngh"); \
	for root in "$$archive"/user-bin/*; do \
	  primary+=("launcher/$$(basename "$$root")" "$$root"); \
	done; \
	primary+=("user-config/systemd/app-hngh\\x2dmc@autostart.service" "$$archive/user-config/systemd/app-hngh\\x2dmc@autostart.service"); \
	python3 "$$metadata/inventory.py" "$${primary[@]}"; \
	cmp "$$tmp/primary.tsv" "$$metadata/post-move.tsv"; \
	repository=("$$tmp/repository.tsv"); \
	while IFS= read -r entry; do \
	  [ -n "$$entry" ] && repository+=("repository/$$entry" "$$archive/repository/$$entry"); \
	done < "$$metadata/repository-top-level.txt"; \
	python3 "$$metadata/inventory.py" "$${repository[@]}"; \
	cmp "$$tmp/repository.tsv" "$$metadata/repository-post-move.tsv"; \
	supplemental=("$$tmp/supplemental.tsv"); \
	while IFS=$$'\t' read -r group relative; do \
	  [ -n "$$group" ] && supplemental+=("$$group" "$$archive/$$relative"); \
	done < "$$metadata/supplemental-2026-08-11-roots.tsv"; \
	python3 "$$metadata/inventory.py" "$${supplemental[@]}"; \
	cmp "$$tmp/supplemental.tsv" "$$metadata/supplemental-2026-08-11.tsv"; \
	printf '%s\n' 'archive receipts verified'
