# Contributors & attribution

## Author and maintainer

**boundring** is the operator and author of Hngh. All repository history is committed
under this identity (see [CONTRIBUTING.md](CONTRIBUTING.md) for the DCO sign-off binding
every commit).

## Development method

Hngh is built and maintained through oh-my-pi (omp) multi-agent sessions: the operator
drives a plan/check/record/close loop in which model agents do the work, staged evidence
through Hngh's own dogfood pipeline, and a human keeps the final say. Attribution is the
operator's; the running agents are tooling, not co-authors.

Models actually used in recent work (via openrouter):

- `google/gemini-3.7-flash`
- `deepseek/deepseek-v4-flash`, `deepseek/deepseek-v4-pro`
- `kimi-code/k3`

## Historical note: retired daemon-era commits

Commits predating the 2026-08 clean-slate rebuild (the retired oh-my-openagent daemon era)
carry **Sisyphus** co-author trailers emitted by the oh-my-openagent harness that then ran
the loop. That system is retired and archived externally; those trailers describe the old
development tooling, not the current one, and do not imply any ongoing co-authorship.

## Prior art only

Claude/Anthropic appears in this repository solely as cited prior art in
[research](docs/research) and records — never as a contributor.
