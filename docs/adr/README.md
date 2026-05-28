# Architecture Decision Records

Short records of the load-bearing decisions behind `simple_permissions_native`.
Each ADR captures **context · decision · alternatives considered ·
consequences · resolution trigger** (the last only when the decision is
bounded). New decisions land here as numbered files (`NNNN-kebab-title.md`).

| # | Decision | Status |
| --- | --- | --- |
| _none yet_ | — | — |

## Prior design notes to formalize

These existing docs capture decisions that predate this directory and
should be folded into numbered ADRs as they're revisited:

- [`../ENUMS_TO_SEALED.md`](../ENUMS_TO_SEALED.md) — the enums→sealed-classes migration.
- [`../PROJECT_WHITEPAPER.md`](../PROJECT_WHITEPAPER.md) — original design rationale.
- [`../INTEGRATION_GUIDE.md`](../INTEGRATION_GUIDE.md) — how consumers wire the plugin in.

> Per the Simple Zen standard, the Notion **Architecture** concern doc
> indexes ADRs. As a Plugin (not an App), `simple-permissions` has no
> per-concern Notion docs — these records are self-contained here.
