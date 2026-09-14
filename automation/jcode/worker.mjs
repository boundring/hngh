#!/usr/bin/env node
// worker.mjs — Jcode worker shim for the hngh delegated-session lane
// (operator-directed 2026-09-14, plan step 3 of
// docs/project/plans/2026-09-14-jcode-primary-harness.plan.md).
//
// Contract: one prompt in on argv, one plain-text turn out on stdout,
// fail-closed exit codes. Bounded read-only default: tools that can
// mutate are refused unless JCODE_WORKER_APPROVE=1 AND the lane is
// certificate-scoped (the bash wrapper enforces that; this shim only
// refuses to lie about it). One runtime dir per lane; the instance
// home is created once and pinned (update disabled) — a fresh bare
// home auto-updates the daemon mid-session and severs the connection
// (verified 2026-09-14, plan step 2).

import { JcodeClient } from "@1jehuang/jcode-sdk";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  buildEnvelope,
  formatRenderSection,
  writeSideChannel,
} from "./render-blocks.mjs";

const HOME = process.env.JCODE_WORKER_HOME || join(process.env.HOME, ".hngh-jcode-worker");

function ensurePinnedHome() {
  // Fail-closed on unsafe homes: never the live user home or a link.
  if (HOME === process.env.HOME || HOME === join(process.env.HOME, ".jcode")) {
    console.error("jcode-worker: refusing unsafe instance home");
    process.exit(2);
  }
  mkdirSync(HOME, { recursive: true });
  const cfg = join(HOME, "config.toml");
  if (!existsSync(cfg)) {
    // Pin the binary BEFORE first run: a fresh home auto-updates and
    // restarts the daemon mid-session (plan step 2 finding).
    writeFileSync(cfg, "update:\n  auto: false\n");
  } else if (!/auto:\s*false/.test(readFileSync(cfg, "utf8"))) {
    console.error("jcode-worker: instance home is not update-pinned; refusing");
    process.exit(2);
  }
}

const prompt = process.argv[2];
if (!prompt) {
  console.error("usage: worker.mjs <prompt>");
  process.exit(2);
}
const timeoutMs = Number(process.env.JCODE_WORKER_TIMEOUT_MS || 300000);
const certFile = process.env.JCODE_WORKER_CERT || "";

// Certificate-scoped approval (plan step 4). JCODE_WORKER_APPROVE=1 alone
// is NOT sufficient: a scope file must exist, parse, and be unexpired.
// Scope format (one JSON object): {"actions": ["Bash","Read","..."],
// "expires": "<ISO-8601>"}. A permission_request is allowed only when
// its tool name is in "actions" and the certificate is unexpired;
// everything else is denied. Every decision is logged to stderr so the
// lane log carries the audit trail.
let scope = null;
const autoApprove = process.env.JCODE_WORKER_APPROVE === "1";
if (autoApprove) {
  if (!certFile || !existsSync(certFile)) {
    console.error("jcode-worker: approve set but certificate file absent; refusing approve mode");
    process.exit(2);
  }
  try {
    scope = JSON.parse(readFileSync(certFile, "utf8"));
  } catch {
    console.error("jcode-worker: certificate file unparsable; refusing approve mode");
    process.exit(2);
  }
  if (!Array.isArray(scope.actions) || typeof scope.expires !== "string") {
    console.error("jcode-worker: certificate missing actions/expires; refusing approve mode");
    process.exit(2);
  }
  if (Date.parse(scope.expires) <= Date.now()) {
    console.error("jcode-worker: certificate expired; refusing approve mode");
    process.exit(2);
  }
}

function certAllows(toolName) {
  return scope && scope.actions.includes(toolName);
}

ensurePinnedHome();
const client = await JcodeClient.launch({
  workingDir: process.env.JCODE_WORKER_DIR || process.cwd(),
  jcodeHome: HOME,
});
const deadline = Date.now() + timeoutMs;
try {
  const session = await client.createSession();
  const runPromise = client.run(session.session_id, prompt, {
    autoApprove,
    onEvent(ev) {
      if (ev.ev !== "permission_request") return;
      if (!autoApprove) {
        // No certificate lane: deny every request, never park (a parked
        // prompt is a stall).
        client.respondToPermission(session.session_id, ev.request_id, "deny");
        console.error(`jcode-worker: denied ${ev.tool_name} (no certificate lane)`);
        return;
      }
      if (certAllows(ev.tool_name)) {
        client.respondToPermission(session.session_id, ev.request_id, "allow");
        console.error(`jcode-worker: allowed ${ev.tool_name} (certificate scope)`);
      } else {
        client.respondToPermission(session.session_id, ev.request_id, "deny");
        console.error(`jcode-worker: denied ${ev.tool_name} (outside certificate scope)`);
      }
    },
  });
  const turn = await Promise.race([
    runPromise,
    new Promise((_, rej) =>
      setTimeout(() => rej(new Error("jcode-worker: turn timeout")), Math.max(deadline - Date.now(), 1)),
    ),
  ]);
  process.stdout.write(turn.text || "");
  // Render passthrough (viz-transport slice): opt-in via
  // JCODE_WORKER_RENDER=markers|fd3|both (default off, stdout contract
  // unchanged). Markers append a parseable section after the turn text;
  // fd3 writes one JSON envelope line to the side-channel fd (ignored
  // when the fd is not open). Envelopes never carry the prompt.
  try {
    const mode = process.env.JCODE_WORKER_RENDER || "off";
    if (mode !== "off") {
      const envelope = buildEnvelope(turn);
      if (mode === "markers" || mode === "both") {
        process.stdout.write(formatRenderSection(envelope));
      }
      if (mode === "fd3" || mode === "both") {
        const fd = Number(process.env.JCODE_WORKER_RENDER_FD || 3);
        writeSideChannel(envelope, fd);
      }
    }
  } catch {
    // Render transport must never fail a turn.
  }
  process.exit(0);
} catch (err) {
  console.error(`jcode-worker: ${err.code || "error"}: ${err.message || err}`);
  process.exit(1);
} finally {
  await client.close().catch(() => {});
  process.exit(process.exitCode ?? 0);
}
