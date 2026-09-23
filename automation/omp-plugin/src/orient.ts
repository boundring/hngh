/**
 * hngh-bridge orient — context-seeding extension entry (plan step 8).
 *
 * Separate from src/index.ts (a CustomToolFactory): CustomToolAPI has no
 * lifecycle events or message-injection APIs, so session_start wiring lives
 * on its own ExtensionAPI entry declared in package.json "omp.extensions".
 *
 * On session_start, when the session cwd IS the hngh repo, runs
 * `python3 scripts/omp-bridge --orient` (read-only, 5 s bound via
 * ctx.setTimeout) and injects the brief with sendMessage — a custom-role
 * session message that reaches the model context without going through
 * prompt flow (sendUserMessage with any deliverAs throws AgentBusyError
 * during session_start in print mode, because the -p prompt is already
 * streaming). Works headless: ctx.hasUI is false and ctx.ui no-ops, but
 * sendMessage does not touch ctx.ui. Fail-open: any failure logs via
 * pi.logger and never breaks session startup. Dedup: one orient per
 * session, keyed on a com.hngh.orient custom session entry (the
 * omp://extensions.md state reconstruction pattern).
 */

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";

export const ORIENT_ENTRY_TYPE = "com.hngh.orient";
const ORIENT_TIMEOUT_MS = 5000;

/** The hngh repo root if the session cwd carries the omp-bridge adapter, else null. */
export function repoRoot(cwd: string): string | null {
  return existsSync(join(cwd, "scripts", "omp-bridge")) ? cwd : null;
}

export interface SessionEntryLike {
  type: string;
  customType?: string;
}

/** True if this session already received an orient brief. */
export function hasOriented(entries: SessionEntryLike[]): boolean {
  return entries.some((e) => e.type === "custom" && e.customType === ORIENT_ENTRY_TYPE);
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    try {
      const root = repoRoot(ctx.cwd);
      if (!root) return;
      if (hasOriented(ctx.sessionManager.getBranch())) return;

      const ac = new AbortController();
      ctx.setTimeout(() => ac.abort(), ORIENT_TIMEOUT_MS);
      const res = await pi.exec("python3", [join(root, "scripts", "omp-bridge"), "--orient"], {
        signal: ac.signal,
        cwd: root,
      });
      if (res.killed || res.code !== 0) {
        pi.logger.error(
          `hngh-bridge orient failed (exit ${res.code}): ${res.stderr || res.stdout}`,
        );
        return;
      }

      pi.appendEntry(ORIENT_ENTRY_TYPE, { repo: root });
      pi.sendMessage({
        customType: "com.hngh.orient-brief",
        content: res.stdout.trim(),
        display: true,
        attribution: "agent",
      });
      pi.logger.debug("hngh-bridge: orient brief injected");
    } catch (err) {
      // Fail-open: orient is a convenience; never break session startup.
      pi.logger.error(`hngh-bridge orient failed (fail-open): ${err}`);
    }
  });
}
