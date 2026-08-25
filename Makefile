SHELL := /bin/bash

.PHONY: test lint-fix verify-candidate

LISP_SOURCES := $(shell find src tests -name '*.lisp' -not -path '*/.git/*' -not -path '*/fixtures/lint-parens/*')

test:
	python3 tests/scripts/test-lint-parens.py
	python3 tests/scripts/test-loop-history-guard.py
	python3 tests/scripts/test-doc-numbers.py
	python3 tests/scripts/test-timeline-events.py
	python3 scripts/lint-parens.py $(LISP_SOURCES)
	sbcl --script tests/run.lisp
	sbcl --non-interactive --eval '(require :asdf)' --eval '(asdf:load-asd "$(CURDIR)/hngh.asd")' --eval '(asdf:load-system :hngh)'

lint-fix:
	python3 scripts/lint-parens.py --fix $(LISP_SOURCES)

verify-candidate:
	@test -n "$(CANDIDATE_MANIFEST)" || { printf '%s\n' 'CANDIDATE_MANIFEST must name a manifest' >&2; exit 2; }
	python3 scripts/verify-candidate.py --manifest "$(CANDIDATE_MANIFEST)"
