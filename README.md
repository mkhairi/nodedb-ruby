# nodedb-ruby

> ## ⚠️ ALPHA — DO NOT USE IN PRODUCTION
>
> Version: **`0.1.0.alpha.5`**. Tracks NodeDB **v0.3.0** (commit `25040fdf`, 2026-06-07).
>
> This gem is **experimental and unaudited**. It has **never been used or tested
> in any production environment**. APIs, SQL builders, and connection semantics
> may change without notice between alpha releases. NodeDB itself is also in an
> early state, with multiple parser quirks and an evolving wire protocol.
>
> Run it on disposable data only. Do not point it at customer data, billing
> systems, anything regulated, or any system you cannot trivially rebuild from
> scratch.

Framework-agnostic Ruby client and SQL builders for [NodeDB](https://nodedb.dev) —
a distributed multi-model database that exposes vector, graph, document,
columnar, timeseries, spatial, KV, and full-text-search engines through a single
PostgreSQL-wire-compatible binary on port 6432.

This gem is the **core** that `activerecord-nodedb-adapter` and
`sequel-nodedb-adapter` build on. Use it directly when you don't want a full ORM.

## Companion packages

| Repo | Role |
| ---- | ---- |
| [`mkhairi/nodedb-ruby`](https://github.com/mkhairi/nodedb-ruby) | **this gem** — framework-agnostic core |
| [`mkhairi/activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) | Rails ActiveRecord adapter built on this gem |
| [`mkhairi/sequel-nodedb-adapter`](https://github.com/mkhairi/sequel-nodedb-adapter) | Sequel adapter (stub) |
| [`mkhairi/nodedb-on-rails`](https://github.com/mkhairi/nodedb-on-rails) | Rails 8 sample app exercising every NodeDB engine |

## Status

| Component        | State |
| ---------------- | ----- |
| Connection       | Working — `:pg` (pg gem, simple-query mode, 6432) and `:native` (MessagePack binary protocol, 6433, no libpq) |
| Type map         | Working (vector, geometry, json, uuid, …) |
| SQL builders     | Vector / Graph / Timeseries / Spatial / KV / FTS / Collection DDL — transport-agnostic (work over `:pg` and `:native`) |
| NodeDB versions  | 0.1.x through post-v0.3.0 `main` (latest retest 2026-07-04 against `67c4572d` — see *Known issues*) |
| Test suite       | own suite: 53 examples; also exercised via `activerecord-nodedb-adapter` (69/0 against `67c4572d`) |

## Requirements

- Ruby 3.2+ (tested on 4.0.1)
- `pg` gem (libpq client) — only for the default `:pg` transport
- `msgpack` gem — for the `:native` transport
- A running NodeDB instance — `pgwire` on `localhost:6432` for `:pg`,
  and/or the native protocol on `localhost:6433` for `:native`
  (`:pg` remains the primary transport — see *Known issues*).
  **Latest upstream `main` recommended** (verified against `67c4572d`:
  native result-shape parity, scoped graph stats, spatial geometry
  constructors, `version()` / `current_setting()` probes). Note:
  post-June builds changed the on-disk format — old data directories
  make the daemon panic at boot; start fresh.

## Installation

The gem isn't on rubygems yet — it's alpha (`0.1.0.alpha.N`). Pull from
GitHub via Bundler's `github:` shorthand:

```ruby
gem "nodedb-ruby", github: "mkhairi/nodedb-ruby", branch: "main"
```

For SSH-only setups: `bundle config github.https false` (one-time).

For monorepo development against a local checkout:

```ruby
gem "nodedb-ruby", path: "../nodedb-ruby"
```

Once the gem ships to rubygems, the standard form will work:

```ruby
gem "nodedb-ruby"
```

## Usage

### Direct connection

```ruby
require "nodedb"

# Default :pg transport (PostgreSQL wire via the pg gem, port 6432)
conn = NodeDB::Connection.connect(
  host:     "localhost",
  dbname:   "nodedb",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"]
)
conn.query("SELECT 1+1 AS r").first  # => {"r" => "2"}

# :native transport — NodeDB binary protocol, port 6433, no libpq
nat = NodeDB::Connection.connect(
  dbname:   "nodedb",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"],
  protocol: :native
)
nat.run("SELECT 1+1 AS r").first  # => {"r" => "2"}
nat.close
```

### SQL builders

The builders return raw SQL strings; they do not run anything. Pass the result
to `pg`, ActiveRecord, Sequel, or whatever you use to talk to NodeDB.

```ruby
NodeDB::SQL::Vector.search(
  table:     "articles",
  column:    "embedding",
  embedding: [0.1, 0.2, 0.3],
  limit:     10
)
# => "SEARCH articles USING VECTOR(embedding, ARRAY[0.1, 0.2, 0.3], 10)"

NodeDB::SQL::Graph.insert_edge(
  in_collection:   "'social_nodes'",
  from:            "'alice'",
  to:              "'bob'",
  type:            "'knows'",
  properties_json: "'{\"since\":2020}'"
)
# GRAPH INSERT EDGE IN 'social_nodes' FROM 'alice' TO 'bob'
# TYPE 'knows' PROPERTIES '{"since":2020}'

NodeDB::SQL::FTS.search(
  table:  "posts",
  column: "body",
  query:  "'machine learning'",
  limit:  20
)
# SELECT id FROM posts WHERE text_match(body, 'machine learning') LIMIT 20

NodeDB::SQL::Collection.create("articles", engine: :document_strict, columns: [
  "id TEXT PRIMARY KEY",
  "title TEXT",
  "body TEXT"
])
# CREATE COLLECTION articles (id TEXT PRIMARY KEY, title TEXT, body TEXT)
# WITH (engine='document_strict')

# engine_options: arbitrary key/value pairs serialised into the WITH clause
NodeDB::SQL::Collection.create("metrics", engine: :timeseries,
  engine_options: { retention: "7d", compression: "zstd" })
# CREATE COLLECTION metrics (ts TIMESTAMP TIME_KEY, value FLOAT)
# WITH (engine='timeseries', retention='7d', compression='zstd')

# flags: free-standing column-list modifiers (NodeDB v0.3.0+).
# Accepts :bitemporal / :append_only / :hash_chain. BITEMPORAL
# collections get the ENGINE = suffix spelling — the WITH form builds
# a broken bitemporal schema upstream (BUG-027).
NodeDB::SQL::Collection.create("orders", engine: :document_strict,
  columns: ["id TEXT PRIMARY KEY", "total NUMERIC"],
  flags:   [:bitemporal])
# CREATE COLLECTION orders (id TEXT PRIMARY KEY, total NUMERIC, BITEMPORAL)
# ENGINE = document_strict

# Personalized PageRank — Hash options are JSON-encoded so the
# rendered SQL matches NodeDB v0.3.0's PERSONALIZATION clause.
NodeDB::SQL::Graph.algo(
  table: "'users'", algo: :pagerank,
  damping: 0.85, personalization: { "alice" => 1.0, "bob" => 0.5 }
)
# GRAPH ALGO PAGERANK ON 'users' DAMPING 0.85
# PERSONALIZATION {"alice":1.0,"bob":0.5}

# SHOW GRAPH STATS — persistent O(1) edge-store counters.
NodeDB::SQL::Graph.stats(collection: "'social_nodes'", verbose: true,
  as_of: 1_700_000_000_000)
# SHOW GRAPH STATS 'social_nodes' VERBOSE AS OF SYSTEM TIME 1700000000000
```

### Type map

```ruby
NodeDB::TypeMap.cast("vector", "[0.1, 0.2, 0.3]")  # => [0.1, 0.2, 0.3]
NodeDB::TypeMap.cast("uuid",   "f5d297…")          # => "f5d297…"
```

## Feature checklist

### Implemented
- [x] PG-based connection wrapper
- [x] Type map for NodeDB-specific types (vector, geometry, json, uuid)
- [x] SQL builders
  - [x] `Collection.create` (with `engine_options:` for WITH-clause settings + `flags:` for `BITEMPORAL` / `APPEND_ONLY` / `HASH_CHAIN`, v0.3.0+) / `drop` / `show` / `drop_if_exists`
  - [x] `Vector.search` (`SEARCH … USING VECTOR(col, ARRAY[…], limit)`)
  - [x] `Graph.insert_edge` / `traverse` / `algo` (Hash/Array options JSON-encoded for v0.3.0's `PERSONALIZATION`) / `delete_edge` / `stats` (`SHOW GRAPH STATS`, v0.3.0+)
  - [x] `Timeseries.create` / `time_bucket` / range helpers
  - [x] `Spatial.distance` / `within_distance` / `intersects`
  - [x] `KV.set` / `get` / `delete`
  - [x] `FTS.search` (uses `text_match()` server-side filtering; bm25 projection retired upstream 2026-05-18) + `create_index` / `drop_index`

### Pending
- [ ] Connection pooling helper (caller currently manages `pg` connections)
- [ ] Streaming result iterator for large vector / FTS scans
- [ ] Async / fiber-based adapter for `async-pg`
- [ ] Schema introspection helpers (DESCRIBE wrapper that yields typed columns)
- [ ] First-class `RETURNING` parsing for `INSERT … RETURNING id`
- [x] CHANGELOG.md
- [x] RSpec coverage for SQL builders in isolation (`spec/sql/`, 14 examples on alpha.5; expanding per release)

## Known issues

NodeDB-side quirks the SQL builders work around, tracking the
**latest upstream only** (resolved issues are pruned; git history and
the CHANGELOG keep the record). Last retested: **2026-07-04** against
upstream `main` at `f8a4df44` (post-v0.3.0). The canonical per-bug
records (reproductions, workaround history, retests) live in the
[AR adapter issue tracker][ar-bugs] — titles prefixed
`[upstream:NodeDB] BUG-NNN`; the user-facing summary is
[KNOWN_ISSUES.md][ar-known].

[ar-bugs]: https://github.com/mkhairi/activerecord-nodedb-adapter/issues?q=%22%5Bupstream%3ANodeDB%5D%22
[ar-known]: https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/KNOWN_ISSUES.md

### Affecting this gem's surface

- **BUG-025 — table-qualified WHERE refs silently match zero rows**
  (except TEXT-PK equality). All builders emit unqualified columns;
  raw-SQL callers must do the same (the AR adapter rewrites
  AR-generated SQL automatically).
- **BUG-027 — engine spellings diverge upstream.** `Collection.create`
  picks per flag: `ENGINE =` suffix for BITEMPORAL, `WITH (engine=...)`
  otherwise. Don't hand-write the other combination.
- **Bitemporal write caveats** — INSERT/DELETE committed inside
  explicit transactions are lost on bitemporal collections (BUG-024);
  write autocommit. DROP + CREATE of a bitemporal collection
  resurrects the old version history (BUG-028). A user column named
  `bitemporal_id` triggers the same txn loss on plain collections
  (BUG-026).
- **Graph scoping** — `MATCH ... IN <collection>` ignores the
  collection scope upstream (BUG-023); no MATCH builder ships until it
  works. Graph builders take bare collection names (quoted identifiers
  create edge-store keys that scoped stats lookups miss).
- **BUG-003** — libpq's `PQserverVersion()` still raises
  (`server_version` ParameterStatus is not numeric-parseable). Query
  `current_setting('server_version_num')` instead — it returns a real
  value on current upstream.
- **BUG-030 — GROUP BY output drops group-key column aliases** and
  returns empty cells for unaliased aggregates (regression on
  `67c4572d`). Alias aggregates; read group keys by base column name
  (the AR adapter re-aliases automatically).
- **`:native` transport** — at result-shape parity with pgwire since
  the upstream response-shaping rework fixed BUG-018, but `:pg`
  (pgwire) remains the primary transport; the plan is still to adopt
  the official NodeDB SDK after an official release.

### Builder-level quirks (upstream conventions, no fix expected)

- **Quoted identifiers rejected by `SEARCH`** — `Vector.search` emits
  bare `column` / `table` names; quoting via `"col"` returns no rows.
- **No prepared statement support** — NodeDB sends `DataRow` without
  `RowDescription` for prepared statements; use simple-query mode.

## License

Released under the **BSD 2-Clause License**. Full text: [LICENSE.md](LICENSE.md).

Independent third-party client. Not affiliated with, endorsed by, or
maintained by the NodeDB project. "NodeDB" is referenced solely to identify
the database this gem connects to.
