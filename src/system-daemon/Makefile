# C system daemon for Hngh
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

# Compiler
CC ?= gcc
CFLAGS = -Wall -Wextra -std=c11 $(shell pkg-config --cflags dbus-1 2>/dev/null || echo "")
LDLIBS = $(shell pkg-config --libs dbus-1 2>/dev/null || echo "-ldbus-1")

BUILD_DIR = ../../build
BINARY = $(BUILD_DIR)/hngh-system

.PHONY: all clean

all: $(BINARY)

$(BINARY): main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $(BINARY) main.c $(LDLIBS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -f $(BINARY)
