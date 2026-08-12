# Component map

The map names the public boundaries Hngh may add. A component is admitted only
when it has its stated reason to change, public API, allowed dependencies, and
deployment form.

| Component | Reason to change | Public API | Allowed dependencies | Deployment form | Owner / reviewer role |
|---|---|---|---|---|---|
| `hngh.domain` | Run policy and immutable values change | Domain values and pure policy functions | Common Lisp | Library | Domain builder / boundary reviewer |
| `hngh.application` | A named use case or port changes | Use-case input and output records; ports | `hngh.domain` | Library | Use-case builder / boundary reviewer |
| `hngh.adapters.filesystem` | Restricted local record transport changes | Application port implementations | Application ports and Common Lisp I/O | Library, manually composed | Adapter builder / fixture reviewer |
| `hngh.adapters.git` | Repository fact collection changes | Repository-inspection port implementation | Application ports and Git transport detail | Library, manually composed | Adapter builder / fixture reviewer |
| `hngh.adapters.model.*` | A model transport changes | Completion-port implementation | Application ports and transport detail | Disabled library, manually composed | Adapter builder / cost reviewer |
| `hngh.adapters.terminal` | Allowlisted command transport changes | Tool-executor port implementation | Application ports and process detail | Disabled library, manually composed | Adapter builder / safety reviewer |
| `hngh.presentation` | Operator-facing rendering changes | Render functions over application output | Application output and renderer resources | Manual CLI or report library | Presentation builder / factual-status reviewer |
| `hngh.main` | Composition and explicit entry behavior change | One operator command entry | All outer components | Executable entrypoint | Integrator / release reviewer |
| `hngh.test-support` | Fakes and deterministic fixtures change | Fixture constructors and fake ports | Public inward APIs | Test-only library | Test builder / independent reviewer |

## Existing API

`hngh.domain` is active. Its public API validates profile, mission, role,
loadout, run, and evidence values, plus the closed run transition policy.
`hngh.application` is active with `create-run`, explicit creation ports, and
closed application results. `hngh:validate-profile` is a compatibility facade
over the domain validator. No adapter, presentation package, composition root,
or runtime outer component exists in active source.

## Dependency and deployment rules

- Component dependencies follow
  [the charter](clean-architecture-charter.md#dependency-law).
- A package export is public only when a test uses it through its named
  component boundary.
- An adapter remains a library until a use case, fake-backed fixture, and
  operator-visible composition rule justify it.
- Deployment form is not a right to run. In particular, a model or terminal
  adapter remains disabled until a separately approved run loadout admits it.
