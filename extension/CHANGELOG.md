# Changelog

All notable changes to the `llm-wiki-graphify` extension are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this extension adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `speckit.llm-wiki-graphify.build` — verifies the graphify installation, reports what a
  build would examine, obtains confirmation, and then builds or refreshes the project
  knowledge graph. Delegates all graph construction to the maintainer's own graphify
  installation; implements no extraction, clustering, or rendering of its own.
- Nine distinguishable build outcomes, each with its own exit code, so an automated check
  can assert which failure occurred rather than only that something failed.
- A coverage statement on every completed build: code was interpreted, prose was not, and
  no exclusions were applied.
- An opt-in `after_specify` hook that offers a build once a specification is written.

[Unreleased]: https://github.com/jonyfs/spec-kit-extension-llm-wiki-graphify/commits/main
