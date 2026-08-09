# Hngh Makefile
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

# --- Configuration ---

SBCL ?= sbcl
SBCL_FLAGS = --disable-debugger
# When task 93 (qlot pin, Wave C) is in effect, load the project-local
# Quicklisp setup so deps resolve reproducibly from qlfile.lock. No-op when
# qlot is absent (e.g. a machine using global ~/quicklisp only).
ifneq ($(wildcard .qlot/setup.lisp),)
SBCL_FLAGS += --load .qlot/setup.lisp
endif
LISP_FILES = $(wildcard src/*.lisp src/core/*.lisp src/plugins/*.lisp)
C_FILES = src/system-daemon/main.c

FAST_TEST_TIMEOUT ?= 15

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

BUILD_DIR = bin
BINARY = $(BUILD_DIR)/hngh
CLIENT_BINARY = $(BUILD_DIR)/hngh-client
DAEMON_BINARY = $(BUILD_DIR)/hngh-system

# --- Targets ---

.PHONY: all run clean test check test-full test-fast test-suite test-beans test-model-runtime test-squad-dispatch lint-counts lint-parens lint-parens-test lint-deps scrub-pii

all: $(BINARY) $(CLIENT_BINARY)

## Build the Hngh SBCL image as a standalone binary
$(BINARY): hngh.asd $(LISP_FILES) | $(BUILD_DIR)
	$(SBCL) $(SBCL_FLAGS) \
		--eval "(require 'asdf)" \
		--eval "(push (truename \".\") asdf:*central-registry*)" \
		--eval "(asdf:load-system :hngh)" \
		--eval "(sb-ext:save-lisp-and-die \"$(BINARY)\" :executable t :save-runtime-options t :toplevel 'hngh:main)"

## Build the Hngh SBCL image (alias for default target)
build: $(BINARY)

## Build the Hngh client CLI as a standalone binary (M7)
$(CLIENT_BINARY): hngh.asd $(LISP_FILES) $(wildcard src/client/*.lisp) | $(BUILD_DIR)
	$(SBCL) $(SBCL_FLAGS) \
		--eval "(require 'asdf)" \
		--eval "(push (truename \".\") asdf:*central-registry*)" \
		--eval "(asdf:load-system :hngh/client)" \
		--eval "(sb-ext:save-lisp-and-die \"$(CLIENT_BINARY)\" :executable t :save-runtime-options t :toplevel 'hngh.client:main)"

## Build the client CLI (alias)
build-client: $(CLIENT_BINARY)

## Build the system daemon (C)
daemon: $(DAEMON_BINARY)

$(DAEMON_BINARY): $(C_FILES) | $(BUILD_DIR)
	$(CC) -o $(DAEMON_BINARY) $(C_FILES) $(shell pkg-config --cflags --libs dbus-1 2>/dev/null || echo "")
	@echo "Built system daemon: $(DAEMON_BINARY)"

## Run Hngh in dev mode (loads via ASDF, no standalone binary)
run:
	$(SBCL) $(SBCL_FLAGS) \
		--eval "(require 'asdf)" \
		--eval "(push (truename \".\") asdf:*central-registry*)" \
		--eval "(asdf:load-system :hngh)" \
		--eval "(hngh:main)"

## Run the focused default test set
# Keep `make test` short and deterministic. Use `make test-full` for the
# exhaustive suite, which may exercise timers, daemons, filesystems, and GUIs.
test: test-fast

test-fast:
	$(MAKE) test-suite SUITE='(:hngh.hngh-up :hngh.squad-dispatch :hngh.beans :hngh.hngh-planner :hngh.quota-spreader :hngh.signals :hngh.acp-client :hngh.coord :hngh.situation-detectors :hngh.situation-scoring :hngh.situation-judge :hngh.situation-casebase :hngh.model-runtime :hngh.model-probes :hngh.model-routes :hngh.safety-boundary :hngh.sandbox :hngh.scoping :hngh.operation-gate)'

test-beans:
	$(MAKE) test-suite SUITE='(:hngh.beans)'

test-model-runtime:
	$(MAKE) test-suite SUITE='(:hngh.model-runtime)'

test-squad-dispatch:
	$(MAKE) test-suite SUITE='(:hngh.squad-dispatch)'

test-suite: lint-parens lint-parens-test lint-deps
	timeout --foreground $(FAST_TEST_TIMEOUT)s $(SBCL) $(SBCL_FLAGS) \
	--eval "(require 'asdf)" \
	--eval "(push (truename \".\") asdf:*central-registry*)" \
	--eval "(asdf:load-system :hngh/tests)" \
	--eval "(let ((ok t)) (dolist (suite '$(SUITE)) (unless (fiveam:run! suite) (setf ok nil))) (uiop:quit (if ok 0 1)))" \
	--quit

## Lint source for unbalanced parens before running tests (procedural guard).
lint-parens:
	@python3 scripts/lint-parens.py --fix $(LISP_FILES) || true
	@python3 scripts/lint-parens.py $(LISP_FILES) || exit 1

## Regression-test the paren fixer itself (procedural guard, uv-hosted pytest).
lint-parens-test:
	@uv run --with pytest python3 -m pytest tests/scripts/test-lint-parens.py -q || exit 1

lint-deps:
	@python3 scripts/lint-deps.py || exit 1

## Scrub owner identifiers from the tracked tree (report mode; CI non-failing).
## Use `scripts/scrub-pii.py --fix` to apply the ~/ rewrite manually.
scrub-pii:
	@python3 scripts/scrub-pii.py --check

## Run the exhaustive test suite
# Explicit because this can include slow external-service and timer fixtures.
test-full: check

check:
	$(SBCL) $(SBCL_FLAGS) \
	--eval "(require 'asdf)" \
	--eval "(push (truename \".\") asdf:*central-registry*)" \
	--eval "(asdf:load-system :hngh)" \
	--eval "(asdf:load-system :hngh/tests)" \
	--eval "(let ((ok (hngh.tests:run-tests))) (uiop:quit (if ok 0 1)))" \
	--quit

## Run integration tests (end-to-end full stack)
integration-test: build
	@bash tests/integration/m0-full-stack.sh

## Lint test-count references in docs against actual make test count
lint-counts:
	@bash scripts/lint-test-counts.sh

## REPL — start an SBCL REPL with Hngh loaded
repl:
	$(SBCL) $(SBCL_FLAGS) \
		--eval "(require 'asdf)" \
		--eval "(push (truename \".\") asdf:*central-registry*)" \
		--eval "(asdf:load-system :hngh)"

## Install binaries to BINDIR
install: $(BINARY) $(CLIENT_BINARY) $(DAEMON_BINARY)
	install -Dm755 $(BINARY) $(DESTDIR)$(BINDIR)/hngh
	install -Dm755 $(CLIENT_BINARY) $(DESTDIR)$(BINDIR)/hngh-client
	install -Dm755 $(DAEMON_BINARY) $(DESTDIR)$(BINDIR)/hngh-system

## Uninstall binaries
uninstall:
	rm -f $(DESTDIR)$(BINDIR)/hngh $(DESTDIR)$(BINDIR)/hngh-client $(DESTDIR)$(BINDIR)/hngh-system

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

## Clean build artifacts
clean:
	rm -rf $(BUILD_DIR) .build
	find . -name "*.fasl" -delete
	find . -name "*.lx64fsl" -delete
	find . -name "*.x86fsl" -delete
	rm -rf __pycache__ .fasl

## Show this help
help:
	@echo "Hngh Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all            Build the Hngh standalone binary (default)"
	@echo "  build          Alias for all"
	@echo "  daemon         Build the system daemon (C)"
	@echo "  run            Run Hngh in dev mode (loads via ASDF)"
	@echo "  test           Run focused fast tests"
	@echo "  test-full      Run exhaustive test suite"
	@echo "  test-beans     Run Beans suite only"
	@echo "  test-model-runtime  Run model-runtime suite only"
	@echo "  test-squad-dispatch Run squad-dispatch suite only"
	@echo "  lint-counts    Lint doc test-count references vs actual"
	@echo "  integration-test  Run end-to-end integration tests"
	@echo "  repl           Start an SBCL REPL with Hngh loaded"
	@echo "  install        Install binaries to $(PREFIX)/bin"
	@echo "  uninstall      Remove installed binaries"
	@echo "  clean          Remove build artifacts"
	@echo "  help           Show this help"
	@echo ""
	@echo "Configuration:"
	@echo "  SBCL=$(SBCL)"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  BINDIR=$(BINDIR)"
