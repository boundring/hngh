/**
 * hngh-bridge — hngh_propose custom tool for omp sessions working in the
 * Hngh repo (plan step 4 of 2026-09-09-omp-hngh-integration).
 *
 * Wraps scripts/omp-bridge: --propose writes a NEW
 * docs/project/plans/<UTC-date>-<slug>.plan.md with status=proposed
 * front-matter (never overwrites), then --plan-status reads the plan's
 * front-matter + dashboard status back as JSON. Fail-closed: omp-bridge's
 * house exit protocol (0 ok, 1 duplicate/refused, 2 malformed, 3 fault)
 * surfaces as tool errors carrying the CLI's stderr — never swallowed.
 */

import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const HOME = process.env.HOME ?? homedir();

/** Repo roots that carry the omp-bridge adapter; session cwd wins. */
function bridgeCandidates(cwd: string): string[] {
  const roots = [cwd, join(HOME, "Projects/etc/hngh")];
  return roots
    .map((root) => join(root, "scripts", "omp-bridge"))
    .filter((path) => existsSync(path));
}

const factory: CustomToolFactory = (pi) => {
  const z = pi.zod;

  return {
    name: "hngh_propose",
    label: "Hngh Propose",
    description: `Propose a new plan file in the Hngh repo via its omp-bridge adapter: writes docs/project/plans/<UTC-date>-<slug>.plan.md with status=proposed front-matter (ASCII slug, refuses duplicates), then returns the propose output plus the plan's status JSON. Repo root resolves from the session working directory.`,
    parameters: z.object({
      slug: z.string().describe("Plan slug (ASCII, kebab-case), e.g. mcp-smoke-ab12"),
      title: z.string().describe("One-line plan title"),
      risk: z.enum(["normal", "critical"]).optional().describe("Plan risk (default normal)"),
    }),

    async execute(_toolCallId, params, onUpdate, _ctx, signal) {
      onUpdate?.({
        content: [{ type: "text", text: `Proposing ${params.slug}...` }],
      });

      const bridge = bridgeCandidates(pi.cwd)[0];
      if (!bridge) {
        throw new Error(
          "omp-bridge not found: no scripts/omp-bridge under the session cwd or ~/Projects/etc/hngh",
        );
      }

      const args = ["--propose", params.slug, "--title", params.title];
      if (params.risk) args.push("--risk", params.risk);
      const propose = await pi.exec("python3", [bridge, ...args], { signal, cwd: pi.cwd });
      if (propose.killed) throw new Error("Propose cancelled");
      if (propose.code !== 0) {
        throw new Error(
          `omp-bridge --propose failed (exit ${propose.code}): ${propose.stderr || propose.stdout}`,
        );
      }

      // --plan-status keys plans by the full date-prefixed stem
      // (<UTC-date>-<slug>); --propose prints the written path first.
      const stem = propose.stdout.trim().split("\n")[0]?.match(/([^/]+)\.plan\.md$/)?.[1];
      if (!stem) throw new Error(`propose output missing plan path: ${propose.stdout.trim()}`);
      const status = await pi.exec("python3", [bridge, "--plan-status", stem], {
        signal,
        cwd: pi.cwd,
      });
      if (status.killed) throw new Error("Plan-status read cancelled");
      if (status.code !== 0) {
        throw new Error(
          `omp-bridge --plan-status failed (exit ${status.code}): ${status.stderr || status.stdout}`,
        );
      }

      const text = `${propose.stdout.trim()}\n\nPlan status JSON:\n${status.stdout.trim()}`;
      return {
        content: [{ type: "text", text }],
        details: { slug: params.slug, proposed: true, status: status.stdout.trim() },
      };
    },
  };
};

export default factory;
