# Changelog

All notable changes to `nodedb-ruby` are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-`1.0` alpha line: APIs may change between alpha releases without
deprecation. Bump `N` in `0.1.0.alpha.N` for any user-visible change.

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

[0.1.0.alpha.2]: https://github.com/mkhairi/nodedb-ruby/compare/v0.1.0.alpha.1...v0.1.0.alpha.2
[0.1.0.alpha.1]: https://github.com/mkhairi/nodedb-ruby/releases/tag/v0.1.0.alpha.1

[#3]: https://github.com/mkhairi/nodedb-ruby/pull/3
[#4]: https://github.com/mkhairi/nodedb-ruby/pull/4
[#5]: https://github.com/mkhairi/nodedb-ruby/pull/5
[#6]: https://github.com/mkhairi/nodedb-ruby/pull/6
[#7]: https://github.com/mkhairi/nodedb-ruby/pull/7
[#8]: https://github.com/mkhairi/nodedb-ruby/pull/8
[#9]: https://github.com/mkhairi/nodedb-ruby/pull/9
