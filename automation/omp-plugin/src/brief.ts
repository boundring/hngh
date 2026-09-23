/**
 * hngh_brief — one-call project-state brief for SPAWNERS of the hngh
 * subagents (2026-09-13, subagent-folding directive). Wraps
 * scripts/omp-bridge --orient: queue Next, roadmap Next, dirty-tree
 * state, last ceremony commit. hngh-executor / hngh-scout spawns get
 * this brief pre-seeded in their first prompt (the anti-stutter rule:
 * the spawned session must not re-walk orientation files); the spawner
 * adds exactly the slice-relevant context on top. Read-only, 5 s bound.
 */

import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const HOME = process.env.HOME ?? homedir();

/** Repo roots that carry the omp-bridge adapter; session cwd wins. */
export function bridgeCandidates(cwd: string): string[] {
  return [cwd, join(HOME, "Projects/etc/hngh")]
    .map((root) => join(root, "scripts", "omp-bridge"))
    .filter((path) => existsSync(path));
}

const factory: CustomToolFactory = (pi) => {
  const z = pi.zod;

  return {
    name: "hngh_brief",
    label: "Hngh Orient Brief",
    description: `One-call project-state brief (scripts/omp-bridge --orient) for spawners of the hngh-executor / hngh-scout subagents: queue Next, roadmap Next, working-tree dirty state, last ceremony commit. Seed the spawned agent's first prompt with this output plus exactly the slice-relevant context, and instruct it not to re-walk orientation files. Read-only. Repo root resolves from the session working directory.`,
    parameters: z.object({}),

    async execute(_toolCallId, _params, _onUpdate, _ctx, signal) {
      const bridge = bridgeCandidates(pi.cwd)[0];
      if (!bridge) {
        throw new Error(
          "omp-bridge not found: no scripts/omp-bridge under the session cwd or ~/Projects/etc/hngh",
        );
      }

      const r = await pi.exec(
        "python3",
        [bridge, "--orient"],
        { signal, timeout: 5000, cwd: pi.cwd },
      );
      if (r.killed) throw new Error("orient brief timed out (5s bound)");
      if (r.code !== 0) {
        throw new Error(
          `omp-bridge --orient failed (exit ${r.code}): ${r.stderr || r.stdout}`,
        );
      }
      return {
        content: [{ type: "text", text: r.stdout.trim() }],
        details: { brief: r.stdout.trim() },
      };
    },
  };
};

export default factory;
