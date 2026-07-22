# graph-build-mixed

**This graph is committed on purpose. Do not delete it as a stray build output.**

Every other `graphify-out/` directory in this repository is derived and git-ignored
(Constitution Principle XVII). This one is test data: a hand-built graph whose
`links[].confidence` values include all three evidence labels — `EXTRACTED`, `INFERRED`,
and `AMBIGUOUS` — with `confidence_score` present on the inferred ones.

It exists because the deterministic build emits only `EXTRACTED` links. Without a
committed mixed graph, the provenance assertion would run against a graph that is 100%
`EXTRACTED`, pass, and prove nothing about whether the other two labels survive to the
report.
