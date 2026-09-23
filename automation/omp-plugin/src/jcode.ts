/**
 * hngh_jcode — delegated JCODE swarm lanes for omp sessions working in
 * the Hngh repo (2026-09-14). One bounded session through
 * automation/lib/jcode-delegate.sh, the launch path's only entry: it
 * paces the zai leg (zai-cap-5h/week-calls) BEFORE anything spends and
 * refuses fail-closed (rc=75 -> tool error; unsloth is the local box,
 * unpaced), then rides launch-session.sh's jcode branch — the ONE
 * branch with no key plumbing (jcode holds its own auth in its config
 * for zai and the local unsloth endpoint), no bili MITM, no R2
 * emitter. Sessions land in dashboard/sessions.json as source
 * "jcode/<dir>" via jobs/sessions-feed.py, so swarm lanes are visible
 * on the Sessions tab like every other CLI. One session per
 * invocation; timeout clamps 1..30 min.
 */

import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { clampMaxMinutes, parseResult } from "./opencode.ts";
import { homedir } from "node:os";

const HOME = process.env.HOME ?? homedir();

/** Repo roots carrying the delegate wrapper; session cwd wins. */
export function delegateCandidates(cwd: string): string[] {
  return [cwd, join(HOME, "Projects/etc/hngh")]
    .map((root) => join(root, "automation", "lib", "jcode-delegate.sh"))
    .filter((path) => existsSync(path));
}

const factory: CustomToolFactory = (pi) => {
  const z = pi.zod;
  return {
    name: "hngh_jcode",
    label: "Hngh Jcode Delegate",
    description: `Delegate ONE bounded task to a jcode session via the Hngh launch path: a quota pacer is checked first and a blocked pacer refuses fail-closed with a budget message (no session, no spend). provider selects the leg: zai (default, GLM via jcode's own zai auth, paced) or unsloth (local OpenAI-compatible endpoint, unpaced). The session runs in its own CLI with its own transcript and appears on the dashboard Sessions tab as a jcode row. Returns rc/disposition/cause/log/run_id/provider. Repo root resolves from the session working directory.`,
    parameters: z.object({
      session: z.string().describe("Session slug (ASCII, kebab-case), e.g. plan-step-fix"),
      objective: z.string().describe("What the delegated session must do (the objective)"),
      max_minutes: z.number().int().optional().describe("Wall-clock bound in minutes, 1-30, default 10"),
      provider: z.enum(["zai", "unsloth"]).optional().describe("Leg: zai (default, paced) or unsloth (local, unpaced)"),
    }),

    async execute(_toolCallId, params, onUpdate, _ctx, signal) {
      onUpdate?.({
        content: [{ type: "text", text: `Delegating to jcode: ${params.session}...` }],
      });

      const wrapper = delegateCandidates(pi.cwd)[0];
      if (!wrapper) {
        throw new Error(
          "jcode-delegate.sh not found: no automation/lib/jcode-delegate.sh under the session cwd or ~/Projects/etc/hngh",
        );
      }

      const minutes = clampMaxMinutes(params.max_minutes);
      const deadline = minutes * 60 * 1000 + 120_000; // + teardown grace
      const argv = [wrapper, params.session, params.objective, String(minutes)];
      if (params.provider) argv.push(params.provider);
      const r = await pi.exec("bash", argv, {
        signal,
        timeout: deadline,
        cwd: pi.cwd,
      });
      if (r.killed) throw new Error(`jcode delegation timed out after ${minutes} min`);

      if (r.code !== 0 && r.code !== 1) {
        // 75 = refused before any spend (pacer or bridge); anything else
        // is a wrapper fault — never a session result
        throw new Error(
          `hngh_jcode refused/faulted (exit ${r.code}): ${r.stderr || r.stdout}`,
        );
      }

      const res = parseResult(r.stdout);
      const text = r.code === 0
        ? `Session ${res.session ?? params.session} completed clean.\n${r.stdout.trim()}`
        : `Session ${res.session ?? params.session} died (rc=${res.rc ?? "?"}, cause=${res.cause ?? "?"}).\n${r.stdout.trim()}`;
      return {
        content: [{ type: "text", text }],
        details: { ...res, max_minutes: minutes },
      };
    },
  };
};

export default factory;
