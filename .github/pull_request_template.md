## What this changes

<!-- One paragraph. What is different after this merges, and why. -->

## Linked artifacts

<!-- For feature work, link the Spec Kit artifacts this implements. -->

- Spec: `specs/NNN-feature/spec.md`
- Plan: `specs/NNN-feature/plan.md`
- Tasks: `specs/NNN-feature/tasks.md`
- Review report: `specs/NNN-feature/reviews/review-*.md`

## Constitution check

<!-- Delete any row that does not apply to this change. -->

- [ ] **I. Manifest** — every path referenced by `extension.yml` exists
- [ ] **II. Namespacing** — command names match `speckit.{id}.{command}`, no core shadowing
- [ ] **III. Placeholders** — `CUSTOMIZE:` markers exist only under `template/`, never in the shipped package
- [ ] **IV. Hooks** — new hooks are `optional: true`, or the auto-execute is justified here
- [ ] **V. Script parity** — bash and powershell variants both present
- [ ] **VII. Install-test** — `add --dev` → `list` → run commands → `remove` passed locally
- [ ] **VIII. Versioning** — version bumped and `CHANGELOG.md` updated in this change
- [ ] **IX. English** — every file in this diff is written in English
- [ ] **XII. Distribution** — if releasing, the published ZIP was installed from its release URL
- [ ] **XVI. Graphify dependency** — graph work is delegated to graphify, and a missing install fails loudly
- [ ] **XVII. Derived artifacts** — no `graphify-out/` content is committed or hand-edited
- [ ] **XVIII. Provenance** — `EXTRACTED` / `INFERRED` / `AMBIGUOUS` labels are carried through unchanged
- [ ] **XIX. Lifecycle** — no core command is bypassed or gated, and no graph build runs unprompted

## Verification

<!-- What did you actually run? Paste the decisive output, not the whole log. -->

```text

```

## Notes for the reviewer

<!-- Anything that would be hard to infer from the diff. Trade-offs, things
     you deliberately left out, follow-ups you plan to open separately. -->
