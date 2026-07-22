# Spec Kit Extension Template

A template for building [GitHub Spec Kit](https://github.com/github/spec-kit)
extensions — with the rules, reference docs, and CI gates that keep a published
extension from breaking in someone else's project.

## What an extension is

A Spec Kit extension is a package that adds namespaced slash commands and
lifecycle hooks to any Spec Kit project. It installs with:

```bash
specify extension add --dev /path/to/my-extension
```

An extension is a manifest plus its referenced files:

```text
my-extension/
├── extension.yml            # the contract the CLI validates
├── README.md
├── LICENSE
├── CHANGELOG.md
├── commands/                # one Markdown file per slash command
├── scripts/
│   ├── bash/                # both variants required — the CLI picks by platform
│   └── powershell/
└── config-template.yml
```

## Getting started

1. Read [`.specify/memory/constitution.md`](.specify/memory/constitution.md).
   It is the source of truth for every rule this repository enforces.
2. Read [`docs/PACKAGING.md`](docs/PACKAGING.md) to understand how your extension
   will actually reach users.
3. Read [`docs/HOOKS.md`](docs/HOOKS.md) before declaring any hook.
4. Copy [`template/`](template/) and adapt it. It is a working extension, not a
   skeleton — see below.
5. Prove it:

```bash
python scripts/validate-extension.py path/to/my-extension
bash scripts/install-test.sh
```

## The reference extension

[`template/`](template/) holds `trace`, a small read-only extension that checks a
feature's artifacts are mechanically consistent — a user story with no tagged tasks, a
task citing a requirement the spec never defines, duplicate IDs, surviving
`[NEEDS CLARIFICATION]` markers.

It exists to be copied. Every rule this repository enforces is visible in it working
rather than described: namespaced commands, a hook that is `optional: true` with a real
prompt, bash and PowerShell scripts at parity, config that tolerates being absent, and
no placeholder markers anywhere. Start from it rather than from a blank directory.

It is also what keeps `scripts/install-test.sh` honest. Before it existed the script had
nothing to install and exited green having tested nothing.

## The sdd-master skill

[`.claude/skills/sdd-master/`](.claude/skills/sdd-master/) is a Claude Code skill that
decides how much process a piece of work warrants and routes accordingly. It is not part
of the extension template — it is how this repository is built — but it is included
because the judgment it encodes applies to any spec-driven project.

Its evaluation record is in `specs/001-sdd-master-skill/`, including the round where the
evaluation disproved one of the spec's own success criteria and the criterion was
rewritten rather than quietly dropped.

## Documentation

| Document | What it answers |
|---|---|
| [`.specify/memory/constitution.md`](.specify/memory/constitution.md) | What are the non-negotiable rules? |
| [`docs/PACKAGING.md`](docs/PACKAGING.md) | How does an extension reach a user, and what must the package look like for each path? |
| [`docs/HOOKS.md`](docs/HOOKS.md) | What are the two hook layers, and how do I avoid confusing them? |

## The rules, in brief

The constitution defines thirteen principles. The ones that most often bite:

- **Commands are namespaced.** `speckit.{extension-id}.{command}`, and the middle
  segment must equal your `extension.id`. Command registration is a flat namespace
  across every installed extension, so a collision silently overwrites someone's
  working workflow.
- **Hooks are opt-in.** `optional` defaults to `true`. Omitting it does not make a
  hook mandatory — and an auto-executing hook fires inside someone else's project,
  on someone else's branch.
- **Scripts come in pairs.** Ship `bash` without `powershell` and the extension
  simply does not work for half its users.
- **`--dev` passing is not a release.** It proves the working tree is valid. It does
  not prove the ZIP has the manifest at the right depth or that the release URL
  resolves. Install the published artifact before submitting a catalog entry.

## Validation tooling

| Script | Enforces |
|---|---|
| `scripts/validate-extension.py` | Manifest shape, command namespacing, hook events and priorities, script parity |
| `scripts/check-placeholders.sh` | No `CUSTOMIZE:` markers survive into a package |
| `scripts/install-test.sh` | The install → list → info → remove cycle |

All three run in CI on every pull request.

## Contributing

Work happens on feature branches and lands on `main` through a pull request. CI
must be green before merge. See the constitution's "Development Workflow & Quality
Gates" section for the full sequence.

## License

MIT — see [LICENSE](LICENSE).

Spec Kit is a project of GitHub, Inc. This template is not affiliated with or
endorsed by GitHub, Inc.
