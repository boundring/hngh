# Ponytail Decision Ladder — Prompt Discipline

**Source**: [ponytail-improved](https://github.com/0xwilliamortiz/ponytail-improved) by 0xwilliamortiz
**Attribution**: Prompt fragments verbatim from README. 54% less code, 100% safety guards kept.

---

## The Decision Ladder (Rungs 1–7)

Before writing code, go down the ladder and stop at the first rung that holds:

1. **Does this need to exist?** → No. Skip it. (YAGNI)
2. **Is it already in this repo?** → Reuse it
3. **Does the stdlib do it?** → Use it
4. **Does the platform do it?** → Use it
5. **Does an installed dep do it?** → Use it
6. **Can it be one line?** → Write the line
7. **Nothing above held** → The minimum that works

> "The ladder runs after the problem is understood, never instead of understanding it. Lazy about the solution, thorough about reading."

---

## Lazy, Not Negligent (Guards Never Chopped)

**Lazy, not negligent.** Validation, error handling, security and accessibility never go on the chopping block. The 100% figure below is that promise, measured.

---

## Slash Commands

| Command | What it does |
|---|---|
| `/ponytail [lite \| full \| ultra \| off]` | Set the intensity, or turn it off |
| `/ponytail-review` | Review the current diff for over-engineering |
| `/ponytail-audit` | Audit the whole repo, not just the diff |
| `/ponytail-debt` | Collect the shortcuts you deferred into a ledger |
| `/ponytail-help` | Quick reference |

---

## Measured Results

- **54% less code, 20% cheaper, 27% faster, 100% of safety guards kept**
- Measured over real Claude Code sessions on a real repository
- On tasks where agents over-build hardest, the drop reaches **94% less code**

---

## Integration Notes

- Not a package — a prompt discipline
- Works with: Claude Code, Codex, Copilot CLI, OpenCode, Pi, Antigravity, Hermes, OpenClaw, and more
- Node required for lifecycle hooks; skills still load without it
- Two hooks: "always-on activation" + pre-write ladder enforcement
