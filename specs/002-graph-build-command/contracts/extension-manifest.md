# Contract: Extension Manifest

**Artifact**: `extension/extension.yml`
**Binds**: Constitution Principles I, II, IV, V, VIII

This fixes every field the manifest must carry. `scripts/validate-extension.py` checks the
shape; this contract fixes the values, so a manifest that parses but says the wrong thing
is still a contract violation.

## Required shape

```yaml
---
schema_version: "1.0"

extension:
  id: "llm-wiki-graphify"
  name: "LLM Wiki Graphify"
  version: "1.0.0"
  description: >-
    Builds and refreshes a graphify knowledge graph of the project, and makes
    it available to the Spec Kit workflow. Delegates all graph construction to
    the maintainer's own graphify installation.
  author: "jonyfs"
  repository: "https://github.com/jonyfs/spec-kit-extension-llm-wiki-graphify"
  license: "MIT"
  homepage: "https://github.com/jonyfs/spec-kit-extension-llm-wiki-graphify"
  category: "context"
  effect: "read-write"

requires:
  speckit_version: ">=0.2.0"

provides:
  commands:
    - name: "speckit.llm-wiki-graphify.build"
      file: "commands/build.md"
      description: >-
        Verify the graphify installation, report what a build would examine,
        and — once confirmed — build or refresh the project knowledge graph.
  config:
    - name: "config.yml"
      template: "config-template.yml"
      required: false
      description: "Scope root and the supported graphify version range"

hooks:
  after_specify:
    command: "speckit.llm-wiki-graphify.build"
    optional: true
    priority: 20
    prompt: "Build or refresh the project knowledge graph now?"
    description: >-
      Offers a graph build after a new specification is written, so planning
      has current project context. Declining has no effect on the
      specification. Never builds without confirmation.

tags:
  - "context"
  - "knowledge-graph"
  - "graphify"
```

## Constraints

| Field | Constraint | Principle |
|---|---|---|
| `extension.id` | Exactly `llm-wiki-graphify`; matches `^[a-z0-9-]+$` | I |
| `extension.version` | `X.Y.Z`, no prefix, no pre-release suffix; `1.0.0` at first release | VIII |
| `extension.effect` | `read-write` — the extension causes writes to `graphify-out/`, and claiming `read-only` would be a false statement about what installing it does | VI |
| Command name | `speckit.llm-wiki-graphify.build`; middle segment equals `extension.id`; shadows no core command | II |
| `requires.speckit_version` | A specifier with no spaces; never a bare version, never `latest` | I |
| graphify version range | `>=0.9.9,<0.10.0`, enforced by the script and documented in the README. The ceiling is not optional: the dependency is pre-1.0, so a `0.10.0` may rename `links`, change the `confidence` vocabulary, or drop `update` — each of which breaks installed copies silently (research R14) | XVI |
| Every referenced path | `commands/build.md` and `config-template.yml` MUST exist in the package | I |
| `hooks.*.optional` | `true`. A build is expensive and touches every file; it is never automatic | IV, XIX |
| `hooks.*.priority` | Explicit integer. `20` places it after `agent-context` (`10`) on the same event, so context refresh — which is cheap and unconditional — is offered first | IV |
| `hooks.*.prompt` / `description` | Both present and non-empty | IV |

## Deliberately absent

- **No `before_*` hook.** A build must never precede a lifecycle step, because a step that
  waits on a build is a step gated on the graph (FR-023, Principle XIX).
- **No `after_implement` hook.** Implementation already carries the `ship` and
  `staff-review` offers; adding a third is hook noise, and the graph is equally useful
  refreshed on demand.
- **No scripts declared at manifest level.** Script paths are referenced from the command
  frontmatter, per the upstream schema. See [build-command.md](build-command.md).

## Verification

- `python scripts/validate-extension.py extension` passes.
- `bash scripts/check-placeholders.sh` reports no `CUSTOMIZE:` markers in the package.
- The manifest is proven by an install-run-remove cycle before any tag (Principle VII),
  not by parsing alone.
