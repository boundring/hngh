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
const autoApprove = process.env.JCODE_WORKER_APPROVE === "1";

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
      // Permission requests with no approver are denied, never parked:
      // the worker lane is bounded, and a parked prompt is a stall.
      if (ev.ev === "permission_request" && !autoApprove) {
        client.respondToPermission(session.session_id, ev.request_id, "deny");
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
  process.exit(0);
} catch (err) {
  console.error(`jcode-worker: ${err.code || "error"}: ${err.message || err}`);
  process.exit(1);
} finally {
  await client.close().catch(() => {});
  process.exit(process.exitCode ?? 0);
}
