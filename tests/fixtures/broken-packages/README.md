# Broken-package fixtures

**Every package in this directory is deliberately broken. Do not "fix" them.**

They exist so the installed-extension validation harness can be observed *failing* —
Constitution Principle XV: a validation harness that has only ever run against a working
package could be a script that prints "passed" unconditionally. Each fixture makes exactly
one harness scenario fail, for one reason.

| Fixture | Break | Harness scenario it must fail |
|---|---|---|
| `missing-command-file/` | `commands/build.md` deleted; the manifest still names it | install/register |
| `wrong-command-name/` | command name is `graphify-build`, violating `speckit.{id}.{command}` | install/register |
| `missing-script/` | command frontmatter references `scripts/bash/does-not-exist.sh` | command prose registered (its declared script does not resolve) |
