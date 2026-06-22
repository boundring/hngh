/*
 * Hngh System Daemon — skeleton
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
 *
 * This is the privileged companion to the Hngh user daemon.
 * It runs as root, is stateless, has no AI, and exposes a minimal
 * set of typed dbus methods validated against a policy file.
 *
 * Full implementation: M0.9 (GitHub issue #9).
 * For now, this is a skeleton that compiles and links against dbus.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dbus/dbus.h>

static const char * const DAEMON_NAME = "org.hngh.System";
static const char * const OBJECT_PATH = "/org/hngh/System";

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    DBusError error;
    DBusConnection *conn;

    dbus_error_init(&error);

    conn = dbus_bus_get(DBUS_BUS_SYSTEM, &error);
    if (dbus_error_is_set(&error)) {
        fprintf(stderr, "Failed to connect to system bus: %s\n", error.message);
        dbus_error_free(&error);
        return 1;
    }

    /* Register well-known name */
    int ret = dbus_bus_request_name(conn, DAEMON_NAME,
                                    DBUS_NAME_FLAG_DO_NOT_QUEUE, &error);
    if (dbus_error_is_set(&error)) {
        fprintf(stderr, "Failed to acquire name %s: %s\n", DAEMON_NAME, error.message);
        dbus_error_free(&error);
        return 1;
    }
    if (ret != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
        fprintf(stderr, "Could not become primary owner of %s\n", DAEMON_NAME);
        return 1;
    }

    printf("hngh-system: started, name acquired: %s\n", DAEMON_NAME);
    printf("hngh-system: skeleton — no methods implemented yet (M0.9)\n");

    /*
     * TODO (M0.9):
     * - Implement InstallPackages method
     * - Implement WriteFile method (with path whitelist)
     * - Implement CreateSnapshot / RestoreSnapshot
     * - Implement SubscribeJournal
     * - Add dbus policy file validation
     * - Add journald logging
     * - Add hngh-helper@.service template unit spawning
     */

    /* For now, just loop forever keeping the connection alive */
    while (1) {
        DBusMessage *msg = dbus_connection_pop_message(conn);
        if (msg == NULL) {
            dbus_connection_read_write(conn, 100);  /* 100ms timeout */
            continue;
        }
        /* No method handlers yet — just log and free */
        dbus_message_unref(msg);
    }

    /* Unreachable, but clean */
    dbus_connection_unref(conn);
    return 0;
}
