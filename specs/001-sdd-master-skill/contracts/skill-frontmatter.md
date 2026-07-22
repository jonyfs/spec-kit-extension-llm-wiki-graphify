# Contract: Skill Package Structure

**Phase**: 1 — Design & Contracts
**Consumer**: The Claude Code skill loader; a maintainer updating the skill

---

## Frontmatter

`SKILL.md` opens with YAML frontmatter carrying exactly two required keys.

```yaml
---
name: sdd-master
description: <trigger text — see below>
---
```

| Key | Constraint |
|---|---|
| `name` | `sdd-master`. Must match the directory name |
| `description` | Names both what the skill does and the concrete situations that should activate it. Must include an explicit non-trigger clause |

**Why the description carries the non-trigger clause**: it is the only text always in
context, so it is the only place that can prevent activation. FR-001 and FR-002 pull in
opposite directions and both resolve here. The near-misses that must not fire —
interface specifications, hardware specs, unrelated task lists — share vocabulary with
the domain, so the description must name them rather than hoping the model infers the
boundary.

The final wording is set by the trigger evaluation (research D8), not by authoring
taste. SC-006 is the acceptance criterion.

---

## Body

| Constraint | Value | Why |
|---|---|---|
| Length | Under 500 lines | Loaded on every activation; the cheap path must stay cheap |
| Contains | Band definitions, signal table, reference pointers | This is the judgment layer |
| Does not contain | Per-command facts, tool version details, extension catalogs | Those belong in references (FR-015) |
| Language | English | Constitution Principle IX |
| Placeholders | None | Constitution Principle III — no `CUSTOMIZE:` markers may ship |

---

## References

```text
references/
├── workflow.md      # Steps, prerequisites, artifacts
├── craft.md         # Spec writing, sizing, layering, drift
├── recovery.md      # Broken-state diagnosis and repair
└── ecosystem.md     # Installed capabilities; competing tools
```

Every reference file opens with a header recording its provenance:

```markdown
**Source of truth**: <where these facts come from>
**Verified against**: <tool name and version>
**Verified on**: <YYYY-MM-DD>
```

**Rules**

- Mandatory header on every reference (FR-008). A reference without it cannot be
  trusted to be current, and staleness becomes invisible.
- One fact, one owner. Two references must never assert the same fact — that is how
  they drift apart (FR-016).
- Files over 300 lines carry a table of contents, so the model can read a section
  rather than the whole file.
- The body points at references by name and by question class. A reference the body
  never points at is unreachable and should be removed or merged.

---

## Evaluation assets

```text
evals/
├── evals.json           # Behavioral cases, one per user story
└── trigger-evals.json   # Activation queries
```

| Asset | Shape | Measures |
|---|---|---|
| `evals.json` | `{skill_name, evals: [{id, name, prompt, expected_output, files}]}` | SC-001 through SC-003 |
| `trigger-evals.json` | `[{query, should_trigger}]` | SC-006 |

**Rules**

- Behavioral cases run **with and without** the skill. Given that added context can be
  net-negative (research D6), an output that merely looks good is not evidence the
  skill helped.
- Trigger queries are weighted toward near-misses. A negative case that is obviously
  unrelated tests nothing.
- Evaluation output lands in `.claude/skills/sdd-master-workspace/`, already excluded
  by `.gitignore`.

---

## What is deliberately absent

| Absent | Why |
|---|---|
| `scripts/` | Nothing here is deterministic enough to script. Constitution Principle V would then require bash and PowerShell parity for no gain |
| `assets/` | The skill produces prose, not files |
| Hook declarations | Not an extension. Constitution Principle IV does not apply |
| Slash commands | Would defeat FR-001 — a command must be named to run, which is the opposite of proactive |
