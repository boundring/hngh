SHELL := /bin/bash

.PHONY: test verify-candidate

test:
	python3 tests/scripts/test-lint-parens.py
	sbcl --script tests/run.lisp
	sbcl --non-interactive --eval '(require :asdf)' --eval '(asdf:load-asd "$(CURDIR)/hngh.asd")' --eval '(asdf:load-system :hngh)'

verify-candidate:
	@test -n "$(CANDIDATE_MANIFEST)" || { printf '%s\n' 'CANDIDATE_MANIFEST must name a manifest' >&2; exit 2; }
	python3 scripts/verify-candidate.py --manifest "$(CANDIDATE_MANIFEST)"
