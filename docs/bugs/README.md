# NodeDB upstream bug log

NodeDB-side bugs that affect this gem's SQL builders or connection
layer. This log tracks the **latest upstream only** — resolved bugs
are pruned (git history keeps their docs). Pruned so far: 001, 004.

Re-tested: **2026-07-02** against upstream `main` at `3a06321e`
(post-v0.3.0).

The full cross-gem bug index (open bugs, adapter workarounds,
reproductions) lives in the AR adapter repo:
[`activerecord-nodedb-adapter/docs/bugs`][ar-bugs] and the user-facing
summary in [`docs/KNOWN_ISSUES.md`][ar-known].

[ar-bugs]: https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/bugs/README.md
[ar-known]: https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/KNOWN_ISSUES.md

## Workarounds shipped in this gem

| Bug | Code path |
| --- | --------- |
| BUG-027 | `SQL::Collection.create` picks the engine spelling per flag: `ENGINE = <engine>` suffix when the `BITEMPORAL` flag is present, `WITH (engine=...)` otherwise. Upstream resolves the two spellings through different code paths and each is broken for a different case (WITH+BITEMPORAL builds a broken bitemporal schema; `ENGINE = timeseries` silently fails to apply the engine). Collapse to one spelling when upstream unifies them |

## Builder conventions forced by upstream quirks

- `Vector.search` emits bare column/table names — `SEARCH` rejects
  quoted identifiers.
- Graph builders take the bare collection name for `IN` / `ON`
  clauses — the edge store keys collections by the IN-clause spelling
  verbatim, so double-quoted identifiers create keys that scoped
  `SHOW GRAPH STATS` lookups miss.
- All builders emit unqualified column references — table-qualified
  refs in WHERE silently match zero rows upstream (BUG-025; the AR
  adapter additionally rewrites AR-generated SQL).
