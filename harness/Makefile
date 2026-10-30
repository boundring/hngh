# hngh Makefile — builds the hngh-owned C tools.
# House rules: canonical file in ~/Projects/hngh/bin/, symlink into ~/.local/bin/.
#   make            build bin/hngh-pointer
#   make check      build, then run the pointer selfcheck (sandboxed; never
#                   opens /dev/uinput)
#   make install    symlink bin/hngh-pointer into ~/.local/bin/
#   make clean      remove the built binary

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra
PREFIX  ?= $(HOME)/.local/bin

BIN     := bin/hngh-pointer
SRC     := src/hngh-pointer.c
SELFCHECK := bin/hngh-pointer-selfcheck

.PHONY: all check install clean

all: $(BIN)

$(BIN): $(SRC)
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $<

check: $(BIN)
	$(SELFCHECK)

install: $(BIN)
	@mkdir -p $(PREFIX)
	ln -sf $(CURDIR)/$(BIN) $(PREFIX)/hngh-pointer

clean:
	rm -f $(BIN)
