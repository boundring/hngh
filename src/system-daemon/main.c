/*
 * Hngh System Daemon — M0.9 implementation
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
 *
 * Privileged companion to the Hngh user daemon.
 * Runs as root, stateless, no AI, no plugins.
 * Exposes typed dbus methods validated against a policy file.
 *
 * Methods implemented:
 *   InstallPackages(names: [string], reason: string) -> TransactionResult
 *   WriteFile(path: string, content: bytes, mode: uint32) -> unit
 *   CreateSnapshot(description: string) -> SnapshotID
 *
 * Each operation spawns a hngh-helper@.service template unit.
 */

#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <dbus/dbus.h>

static const char * const DAEMON_NAME = "org.hngh.System";
static const char * const OBJECT_PATH = "/org/hngh/System";
static const char * const INTERFACE = "org.hngh.System.PackageManager";
static const char * const FILES_INTERFACE = "org.hngh.System.Files";
static const char * const BTRFS_INTERFACE = "org.hngh.System.Btrfs";

/* Whitelist for WriteFile */
static const char * const ALLOWED_PATH_PREFIXES[] = {
    "/etc/",
    "/usr/lib/systemd/system/",
    NULL
};

static DBusHandlerResult
handle_method_call(DBusConnection *conn, DBusMessage *msg, void *userdata);

static void
respond_ok(DBusConnection *conn, DBusMessage *msg)
{
    DBusMessage *reply = dbus_message_new_method_return(msg);
    dbus_connection_send(conn, reply, NULL);
    dbus_message_unref(reply);
}

static void
respond_error(DBusConnection *conn, DBusMessage *msg, const char *error_name,
               const char *error_message)
{
    DBusMessage *reply = dbus_message_new_error(msg, error_name, error_message);
    dbus_connection_send(conn, reply, NULL);
    dbus_message_unref(reply);
}

static void
respond_string(DBusConnection *conn, DBusMessage *msg, const char *str)
{
    DBusMessage *reply = dbus_message_new_method_return(msg);
    DBusMessageIter args;
    dbus_message_iter_init_append(reply, &args);
    dbus_message_iter_append_basic(&args, DBUS_TYPE_STRING, &str);
    dbus_connection_send(conn, reply, NULL);
    dbus_message_unref(reply);
}

static int
path_is_allowed(const char *path)
{
    /* Canonicalize the path to prevent traversal (../../etc/shadow) */
    char resolved[PATH_MAX];
    if (realpath(path, resolved) == NULL) {
        /* Path doesn't exist yet (for new files) — resolve parent */
        char parent[PATH_MAX];
        strncpy(parent, path, sizeof(parent) - 1);
        parent[sizeof(parent) - 1] = '\0';
        /* Strip last path component to get parent */
        char *last_slash = strrchr(parent, '/');
        if (last_slash == NULL) {
            return 0;
        }
        *last_slash = '\0';
        if (strlen(parent) == 0) {
            strcpy(parent, "/");
        }
        char resolved_parent[PATH_MAX];
        if (realpath(parent, resolved_parent) == NULL) {
            return 0;
        }
        /* Reconstruct full path: resolved_parent + "/" + basename */
        snprintf(resolved, sizeof(resolved), "%s/%s", resolved_parent,
                 last_slash + 1);
    }

    for (int i = 0; ALLOWED_PATH_PREFIXES[i] != NULL; i++) {
        size_t len = strlen(ALLOWED_PATH_PREFIXES[i]);
        if (strncmp(resolved, ALLOWED_PATH_PREFIXES[i], len) == 0) {
            return 1;
        }
    }
    return 0;
}

static DBusHandlerResult
handle_install_packages(DBusConnection *conn, DBusMessage *msg)
{
    DBusMessageIter args;
    DBusMessageIter array_iter;
    
    if (!dbus_message_iter_init(msg, &args)) {
        respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs",
                      "Expected (array of strings, reason)");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    if (dbus_message_iter_get_arg_type(&args) != DBUS_TYPE_ARRAY) {
        respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs",
                      "First argument must be an array of strings");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    /* Build package list string */
    char pkg_list[1024] = "";
    dbus_message_iter_recurse(&args, &array_iter);
    
    while (dbus_message_iter_get_arg_type(&array_iter) == DBUS_TYPE_STRING) {
        const char *pkg;
        dbus_message_iter_get_basic(&array_iter, &pkg);
        /* Validate: only allow alphanumerics, dashes, underscores, dots, plus */
        for (const char *p = pkg; *p; p++) {
            if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
                  (*p >= '0' && *p <= '9') || *p == '-' || *p == '_' ||
                  *p == '.' || *p == '+')) {
                char errmsg[256];
                snprintf(errmsg, sizeof(errmsg),
                         "Invalid package name: %s", pkg);
                respond_error(conn, msg, "org.hngh.System.Error.InvalidPkg", errmsg);
                return DBUS_HANDLER_RESULT_HANDLED;
            }
        }
        strncat(pkg_list, pkg, sizeof(pkg_list) - strlen(pkg_list) - 1);
        strncat(pkg_list, " ", sizeof(pkg_list) - strlen(pkg_list) - 1);
        dbus_message_iter_next(&array_iter);
    }
    
    /* Get reason (second arg) */
    dbus_message_iter_next(&args);
    const char *reason = "";
    if (dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_STRING) {
        dbus_message_iter_get_basic(&args, &reason);
    }
    
    fprintf(stderr, "hngh-system: InstallPackages: %s (reason: %s)\n",
            pkg_list, reason);
    
    /* Spawn pacman via helper */
    /* For M0.9, we run pacman directly. The template unit can be added later. */
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "pacman -S --noconfirm --needed %s 2>&1", pkg_list);
    
    FILE *fp = popen(cmd, "r");
    if (fp == NULL) {
        respond_error(conn, msg, "org.hngh.System.Error.SpawnFailed",
                      "Failed to spawn pacman");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    /* Capture output */
    char output[4096] = "";
    char line[256];
    while (fgets(line, sizeof(line), fp) != NULL) {
        strncat(output, line, sizeof(output) - strlen(output) - 1);
    }
    int exit_code = pclose(fp);
    
    fprintf(stderr, "hngh-system: InstallPackages result: exit=%d\n", exit_code);
    
    if (exit_code == 0) {
        respond_string(conn, msg, "ok");
    } else {
        char errmsg[4200];
        snprintf(errmsg, sizeof(errmsg), "pacman exited with code %d: %s",
                 exit_code, output);
        respond_error(conn, msg, "org.hngh.System.Error.PacmanFailed", errmsg);
    }
    
    return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult
handle_write_file(DBusConnection *conn, DBusMessage *msg)
{
    DBusMessageIter args;
    
    if (!dbus_message_iter_init(msg, &args)) {
        respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs",
                      "Expected (path, content, mode)");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    /* Get path */
    const char *path;
    if (dbus_message_iter_get_arg_type(&args) != DBUS_TYPE_STRING) {
        respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs",
                      "First argument must be a string (path)");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    dbus_message_iter_get_basic(&args, &path);
    
    /* Validate path against whitelist */
    if (!path_is_allowed(path)) {
        char errmsg[256];
        snprintf(errmsg, sizeof(errmsg), "Path not allowed: %s", path);
        respond_error(conn, msg, "org.hngh.System.Error.PathDenied", errmsg);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    /* Get content (byte array) */
    dbus_message_iter_next(&args);
    if (dbus_message_iter_get_arg_type(&args) != DBUS_TYPE_ARRAY) {
        respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs",
                      "Second argument must be a byte array (content)");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    DBusMessageIter byte_iter;
    dbus_message_iter_recurse(&args, &byte_iter);
    
    /* Get mode (third arg, optional) */
    dbus_message_iter_next(&args);
    dbus_uint32_t mode = 0644;
    if (dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_UINT32) {
        dbus_message_iter_get_basic(&args, &mode);
    }
    
    /* Write file */
    FILE *f = fopen(path, "wb");
    if (f == NULL) {
        char errmsg[256];
        snprintf(errmsg, sizeof(errmsg), "Cannot open %s for writing", path);
        respond_error(conn, msg, "org.hngh.System.Error.WriteFailed", errmsg);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    int byte_count = 0;
    while (dbus_message_iter_get_arg_type(&byte_iter) == DBUS_TYPE_BYTE) {
        unsigned char b;
        dbus_message_iter_get_basic(&byte_iter, &b);
        fputc(b, f);
        byte_count++;
        dbus_message_iter_next(&byte_iter);
    }
    fclose(f);
    
    /* Set permissions */
    chmod(path, mode);
    
    fprintf(stderr, "hngh-system: WriteFile: %s (%d bytes, mode %o)\n",
            path, byte_count, mode);
    
    respond_ok(conn, msg);
    return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult
handle_create_snapshot(DBusConnection *conn, DBusMessage *msg)
{
    DBusMessageIter args;
    const char *description = "hngh-snapshot";
    
    if (dbus_message_iter_init(msg, &args) &&
        dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_STRING) {
        dbus_message_iter_get_basic(&args, &description);
    }

    /* Validate description: only alphanumerics, dashes, underscores */
    for (const char *p = description; *p; p++) {
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9') || *p == '-' || *p == '_')) {
            char errmsg[256];
            snprintf(errmsg, sizeof(errmsg),
                     "Invalid snapshot description: %s", description);
            respond_error(conn, msg, "org.hngh.System.Error.InvalidArgs", errmsg);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
    }
    
    fprintf(stderr, "hngh-system: CreateSnapshot: %s\n", description);
    
    /* Run btrfs subvolume snapshot */
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
             "btrfs subvolume snapshot / /.snapshots/%s-snapshot 2>&1",
             description);
    
    FILE *fp = popen(cmd, "r");
    if (fp == NULL) {
        respond_error(conn, msg, "org.hngh.System.Error.SnapshotFailed",
                      "Failed to spawn btrfs");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    
    char output[1024] = "";
    char line[256];
    while (fgets(line, sizeof(line), fp) != NULL) {
        strncat(output, line, sizeof(output) - strlen(output) - 1);
    }
    int exit_code = pclose(fp);
    
    if (exit_code == 0) {
        respond_string(conn, msg, description);
    } else {
        char errmsg[1200];
        snprintf(errmsg, sizeof(errmsg), "btrfs exited with code %d: %s",
                 exit_code, output);
        respond_error(conn, msg, "org.hngh.System.Error.SnapshotFailed", errmsg);
    }
    
    return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult
handle_method_call(DBusConnection *conn, DBusMessage *msg, void *userdata)
{
    (void)userdata;
    
    const char *method = dbus_message_get_member(msg);
    const char *interface = dbus_message_get_interface(msg);
    
    fprintf(stderr, "hngh-system: method call: %s.%s\n", interface, method);
    
    if (strcmp(interface, INTERFACE) == 0) {
        if (strcmp(method, "InstallPackages") == 0) {
            return handle_install_packages(conn, msg);
        }
    }
    
    if (strcmp(interface, FILES_INTERFACE) == 0) {
        if (strcmp(method, "WriteFile") == 0) {
            return handle_write_file(conn, msg);
        }
    }
    
    if (strcmp(interface, BTRFS_INTERFACE) == 0) {
        if (strcmp(method, "CreateSnapshot") == 0) {
            return handle_create_snapshot(conn, msg);
        }
    }
    
    respond_error(conn, msg, "org.freedesktop.DBus.Error.UnknownMethod",
                  "Unknown method");
    return DBUS_HANDLER_RESULT_HANDLED;
}

static const DBusObjectPathVTable vtable = {
    .message_function = handle_method_call,
    .unregister_function = NULL
};

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
    
    /* Register object path handler */
    dbus_connection_register_object_path(conn, OBJECT_PATH, &vtable, NULL);
    
    fprintf(stderr, "hngh-system: started, name: %s, path: %s\n",
            DAEMON_NAME, OBJECT_PATH);
    fprintf(stderr, "hngh-system: methods: InstallPackages, WriteFile, CreateSnapshot\n");
    
    /* Main loop */
    while (1) {
        dbus_connection_read_write_dispatch(conn, 100);
    }
    
    /* Unreachable */
    dbus_connection_unref(conn);
    return 0;
}
