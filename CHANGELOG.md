# Changelog

All notable changes to `nodedb-ruby` are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-`1.0` alpha line: APIs may change between alpha releases without
deprecation. Bump `N` in `0.1.0.alpha.N` for any user-visible change.

## [0.1.0.alpha.10] — 2026-07-20

Tracks NodeDB upstream v0.4.0 final at `eea86b279`.

### Added

- `Native::Connection#connection_parameters` — exposes the connect
  params (host, port, database, username, password, connect_timeout)
  so downstream adapters can implement `reset`-style reconnects.

### Fixed

- `SQL` WITH-clause option values escape embedded quotes; option keys
  are validated.
- `TypeMap.resolve` falls back to text on a nil/empty type name
  instead of raising.

### Tooling

- Gemspec ships `LICENSE.md`, uniform metadata, `rubygems_mfa_required`.
- CI matrix adds Ruby 4.0.
- Daemon-independent unit specs for SQL builders, TypeMap, and Pool.

## [0.1.0.alpha.9] — 2026-07-08

Tracks NodeDB upstream `main` at `8e84501a`.

### Changed (breaking)

- `SQL::Graph.delete_edge` now requires `in_collection:` and renders
  `GRAPH DELETE EDGE IN <collection> ...` — current upstream rejects
  the IN-less form with a parse error (same syntax change that
  previously hit `insert_edge`). (#31)

### Added

- `Schema.normalize(rows, internal:)` — pure, connection-free
  normalization of raw DESCRIBE hashes for adapters that fetch
  DESCRIBE through their own connection machinery; `Schema.columns`
  delegates to it. (#32)

### Tooling

- Daemon-less GitHub Actions CI (Ruby 3.2 + 3.4; integration specs
  skip). (#33)
- standardrb baseline, all offenses fixed, CI-gated. (#34)

## [0.1.0.alpha.8] — 2026-07-08

Tracks NodeDB upstream `main` at `8e84501a` (unchanged since alpha.7).

### Added

- `NodeDB::Pool` — thread-safe connection pool over either transport
  (wraps the `connection_pool` gem; lazy connect; `with` / `exec` /
  `reload` / `shutdown`). (#27)
- `NodeDB::Streaming.each_row` — row-at-a-time result iteration via
  libpq single-row mode for large vector / FTS / timeseries scans;
  Enumerator form; early break cancels and drains, connection stays
  usable. `:pg` transport only. (#28)
- `NodeDB::Schema.columns` / `.collections` — typed DESCRIBE
  introspection: raw + pg types, oid, nullable, primary-key collapse
  of DESCRIBE's duplicate rows, `__`-internal filtering. (#29)

### Dependencies

- New runtime dependency: `connection_pool >= 2.4`.

## [0.1.0.alpha.7] — 2026-07-07

Tracks NodeDB upstream `main` at `8e84501a` (post-v0.3.0), which
unified the CREATE COLLECTION engine-clause code paths (BUG-027
fixed).

### Removed

- `SQL::Collection.create` per-flag engine-spelling picker: the
  builder now emits the single `WITH (engine=..., <options>)` form
  for every engine/flag combination, BITEMPORAL included (#25).
  Reverts the alpha.6 workaround below.

## [0.1.0.alpha.6] — 2026-07-04

Tracks NodeDB upstream `main` at `f8a4df44` (post-v0.3.0).

### Fixed

- `SQL::Collection.create` emits the `ENGINE = <engine>` suffix for
  BITEMPORAL collections and keeps `WITH (engine=...)` for everything
  else — the two spellings diverge upstream (BUG-027): the WITH form
  plus the BITEMPORAL flag builds a broken schema (#18).

### Documentation / tests

- README refreshed for the upstream response-shaping rework: BUG-018
  resolved (`:native` at result-shape parity with pgwire; schemaless
  `SELECT *` projects flat columns), BUG-030 GROUP BY alias-drop
  caveat added; `:pg` stays the primary transport pending the official
  SDK (#21). Known-issues list trimmed to the latest upstream only
  (#19).
- Stale specs aligned with current behaviour: BITEMPORAL builder
  expectation (ENGINE suffix) and the native round-trip now asserting
  projected columns instead of the `{data,id}` blob (#20).

## [0.1.0.alpha.5] — 2026-06-07

NodeDB v0.3.0 (commit `25040fdf`) compatibility release. Adds SQL
builders for three new pgwire-exposed surfaces and a defensive option
encoder for the existing graph DSL.

### Added
- `NodeDB::SQL::Graph.stats(collection:, verbose:, as_of:)` — renders
  `SHOW GRAPH STATS [<collection>] [VERBOSE] [AS OF SYSTEM TIME <ms>]`
  for NodeDB v0.3.0's persistent O(1) graph-stats counters. Collection
  is treated as a pre-quoted literal, consistent with the other
  `SQL::Graph` builders. (#14)
- `NodeDB::SQL::Collection.create` accepts a `flags:` keyword for
  NodeDB v0.3.0's free-standing column-list modifier keywords:
  `BITEMPORAL`, `APPEND_ONLY`, `HASH_CHAIN`. Flags are uppercased and
  joined into the same parens as the column list. (#15)

### Changed
- `NodeDB::SQL::Graph.algo` now JSON-encodes Hash and Array option
  values via `JSON.generate`. Motivating case: NodeDB v0.3.0's
  `PERSONALIZATION { "alice": 1.0 }` clause on `GRAPH ALGO PAGERANK`
  rejected Ruby's `{"alice"=>1.0}` hash-rocket form. Scalar options
  are unaffected. (#13)

### Internal
- Seeded `spec/sql/` with focused unit specs for `Graph.algo`,
  `Graph.stats`, and `Collection.create`. Suite grew from 0 SQL specs
  to 14. Downstream `activerecord-nodedb-adapter` continues to provide
  integration coverage.

## [0.1.0.alpha.4] — 2026-05-18

### Changed
- **FTS engine removed upstream.** NodeDB dropped the standalone `fts`
  engine; full-text search is now a `document_strict` collection plus a
  separate `CREATE FULLTEXT INDEX`. `NodeDB::SQL::Collection` maps
  `engine: :fts` → `engine='document_strict'` so legacy callers don't
  break.
- `NodeDB::SQL::FTS.search` no longer projects `bm25_score` or orders by
  it (`text_match()` now filters rows server-side and bm25 was unusable
  for ranking on small corpora). Emits `SELECT id … WHERE text_match()`.

### Added
- `NodeDB::SQL::FTS.create_index(name:, collection:, column:)` →
  `CREATE FULLTEXT INDEX …`.
- `NodeDB::SQL::FTS.drop_index(name)` → `DROP INDEX …` (NodeDB has no
  `DROP FULLTEXT INDEX`).

## [0.1.0.alpha.3] — 2026-05-16

### Added
- Native binary-protocol transport — no libpq / `pg` gem on this path.
  `NodeDB::Native::Connection` speaks NodeDB's MessagePack-framed native
  protocol over TCP (default port `6433`): handshake, Trust + Password
  auth, SQL/DDL, transactions, `set`/`show` params, ping, and a
  `PG::Result`-shaped `NodeDB::Native::Result` so the existing
  `NodeDB::SQL::*` builders + `NodeDB::TypeMap` work unchanged over it.
- `NodeDB::Connection.connect` gains a `protocol:` selector — `:pg`
  (default, unchanged behaviour, port 6432) or `:native` (port 6433).
- First isolated RSpec suite for this gem (unit + live-NodeDB
  integration, the latter auto-skipped when `6433` is unreachable).

### Dependencies
- Added `msgpack ~> 1.7` (native codec). `pg ~> 1.5` retained — the
  default `:pg` path and downstream adapters are untouched.

## [0.1.0.alpha.2] — 2026-05-15

### Added
- `NodeDB::SQL::Collection.create` accepts an `engine_options:` kwarg
  serialised into the `WITH (...)` clause. ([#4])

### Changed
- README and bug log refreshed against NodeDB v0.2.1 retest:
  - **BUG-004** (`DROP COLLECTION IF EXISTS` parser quirk) is now
    **resolved upstream**. `NodeDB::SQL::Collection.drop_if_exists`
    workaround is kept for compatibility with older NodeDB binaries.
  - Known issues split into _Resolved upstream_ vs _Still in play_.
    ([#8], [#9])
- `CLAUDE.md` slimmed to defer to the workspace root for shared
  branch/PR/commit conventions. ([#7])

### Docs
- Installation snippets switched to Bundler `github:` shorthand. ([#6])
- `Collection.create` `engine_options:` kwarg documented in the README
  usage section. ([#5])
- Companion packages cross-link table added.
- Bug log cross-links to the activerecord-nodedb-adapter master index.

### Internal
- Relative path references corrected after the move into `./gems/`. ([#3])

## [0.1.0.alpha.1] — 2026-05-09

Initial alpha. Framework-agnostic Ruby client and SQL builders for
NodeDB.

### Added
- `NodeDB::Connection` — pg-based connection wrapper.
- `NodeDB::TypeMap` — vector / geometry / json / uuid casting.
- `NodeDB::SQL::*` SQL builders:
  - `Collection` — `create`, `drop`, `drop_if_exists`, `show`.
  - `Vector` — `search` (`SEARCH ... USING VECTOR(col, ARRAY[...], limit)`).
  - `Graph` — `insert_edge`, `traverse`, `algo`, `delete_edge` (with
    required `IN 'collection'` clause).
  - `Timeseries` — `create`, `time_bucket`, range helpers.
  - `Spatial` — `distance`, `within_distance`, `intersects`.
  - `KV` — `set`, `get`, `delete`.
  - `FTS` — `search` (`text_match()` + `bm25_score()`).
- Upstream bug log: BUG-001 (resolved), BUG-004 (open at alpha.1).

[0.1.0.alpha.4]: https://github.com/mkhairi/nodedb-ruby/compare/v0.1.0.alpha.3...v0.1.0.alpha.4
[0.1.0.alpha.3]: https://github.com/mkhairi/nodedb-ruby/compare/v0.1.0.alpha.2...v0.1.0.alpha.3
[0.1.0.alpha.2]: https://github.com/mkhairi/nodedb-ruby/compare/v0.1.0.alpha.1...v0.1.0.alpha.2
[0.1.0.alpha.1]: https://github.com/mkhairi/nodedb-ruby/releases/tag/v0.1.0.alpha.1

[#3]: https://github.com/mkhairi/nodedb-ruby/pull/3
[#4]: https://github.com/mkhairi/nodedb-ruby/pull/4
[#5]: https://github.com/mkhairi/nodedb-ruby/pull/5
[#6]: https://github.com/mkhairi/nodedb-ruby/pull/6
[#7]: https://github.com/mkhairi/nodedb-ruby/pull/7
[#8]: https://github.com/mkhairi/nodedb-ruby/pull/8
[#9]: https://github.com/mkhairi/nodedb-ruby/pull/9
