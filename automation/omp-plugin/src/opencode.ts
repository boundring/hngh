/**
 * hngh_opencode — delegated OPENCODE sessions for omp sessions working in
 * the Hngh repo (2026-09-13). One bounded session through
 * automation/lib/ocgo-delegate.sh, which is the launch path's only entry:
 * it checks the 5h pacer (ocgo+ocgo-agent vs opencode-cap-5h-calls)
 * BEFORE anything spends and refuses fail-closed with a budget message
 * (rc=75 -> tool error), then rides launch-session.sh's opencode branch
 * (context pack, OPENCODE_CONFIG pin to the hngh config layer, bili
 * env-only MITM compression, R2 attribution emitter, lesson loop, budget
 * row). One session per invocation; timeout clamps to the opencode-agent
 * leg budget (max 30 min = 1800s).
 */

import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const HOME = process.env.HOME ?? homedir();

/** Bounded wall-clock: default 10 min, clamped 1..30 (leg budget 1800s). */
export function clampMaxMinutes(m?: number | string): number {
  const n = Math.floor(Number(m ?? 10));
  if (!Number.isFinite(n)) return 10;
  return Math.min(30, Math.max(1, n));
}

/** Repo roots carrying the delegate wrapper; session cwd wins. */
export function delegateCandidates(cwd: string): string[] {
  return [cwd, join(HOME, "Projects/etc/hngh")]
    .map((root) => join(root, "automation", "lib", "ocgo-delegate.sh"))
    .filter((path) => existsSync(path));
}

/** The wrapper's key=value result lines -> map. */
export function parseResult(stdout: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const line of stdout.trim().split("\n")) {
    const eq = line.indexOf("=");
    if (eq > 0) out[line.slice(0, eq)] = line.slice(eq + 1);
  }
  return out;
}

const factory: CustomToolFactory = (pi) => {
  const z = pi.zod;

  return {
    name: "hngh_opencode",
    label: "Hngh OpenCode Delegate",
    description: `Delegate ONE bounded task to an opencode session via the Hngh launch path: a quota pacer is checked first and a blocked pacer refuses fail-closed with a budget message (no session, no spend). provider selects the quota leg: opencode-go (default, 5h pacer opencode-cap-5h-calls) or kimi (Kimi Code K3 quota, daily kimi-daily-cap pacer). Launched sessions ride bili compression, the hngh-owned OPENCODE_CONFIG layer, the pre-digested context pack, the R2 attribution emitter, and the lessons loop. Returns rc/disposition/cause/log/run_id/provider. Repo root resolves from the session working directory.`,
    parameters: z.object({
      session: z.string().describe("Session slug (ASCII, kebab-case), e.g. plan-step-fix"),
      objective: z.string().describe("What the delegated session must do (the objective)"),
      max_minutes: z.number().int().optional().describe("Wall-clock bound in minutes, 1-30, default 10 (leg budget ceiling 1800s)"),
      provider: z.enum(["opencode-go", "kimi", "zai"]).optional().describe("Quota leg: opencode-go (default), kimi, or zai"),
    }),

    async execute(_toolCallId, params, onUpdate, _ctx, signal) {
      onUpdate?.({
        content: [{ type: "text", text: `Delegating to opencode: ${params.session}...` }],
      });

      const wrapper = delegateCandidates(pi.cwd)[0];
      if (!wrapper) {
        throw new Error(
          "ocgo-delegate.sh not found: no automation/lib/ocgo-delegate.sh under the session cwd or ~/Projects/etc/hngh",
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
      if (r.killed) throw new Error(`opencode delegation timed out after ${minutes} min`);

      if (r.code !== 0 && r.code !== 1) {
        // 75 = refused before any spend (pacer or bridge); anything else
        // is a wrapper fault — never a session result
        throw new Error(
          `hngh_opencode refused/faulted (exit ${r.code}): ${r.stderr || r.stdout}`,
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
