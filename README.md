# nodedb-ruby

> ## ⚠️ ALPHA — DO NOT USE IN PRODUCTION
>
> Version: **`0.1.0.alpha.10`**. Requires NodeDB **0.4.0 or newer**
> (verified against post-0.4.0 upstream `main` at `87053aa7b`).
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
| [`mkhairi/sequel-nodedb-adapter`](https://github.com/mkhairi/sequel-nodedb-adapter) | Sequel adapter (experimental — Dataset CRUD + model plugins) |
| [`mkhairi/nodedb-on-rails`](https://github.com/mkhairi/nodedb-on-rails) | Rails 8 sample app exercising every NodeDB engine |

## Status

| Component        | State |
| ---------------- | ----- |
| Connection       | Working — `:pg` (pg gem, simple-query mode, 6432) and `:native` (MessagePack binary protocol, 6433, no libpq) |
| Type map         | Working (vector, geometry, json, uuid, …) |
| SQL builders     | Vector / Graph / Timeseries / Spatial / KV / FTS / Collection DDL — transport-agnostic (work over `:pg` and `:native`) |
| NodeDB versions  | **0.4.0+** (latest retest 2026-07-28 against `main` at `87053aa7b`) |
| Test suite       | own suite: 69 examples, 0 failures; also exercised via `activerecord-nodedb-adapter`'s suite (see that repo's Known issues for current status) |

## Requirements

- Ruby 3.2+ (tested on 4.0.1)
- `pg` gem (libpq client) — only for the default `:pg` transport
- `msgpack` gem — for the `:native` transport
- **NodeDB 0.4.0 or newer.** Earlier lines are not supported: the
  builders emit DDL and engine clauses that 0.3.x rejects, and its
  on-disk format is incompatible (a pre-0.4 data directory makes the
  daemon panic at boot — start fresh). Verified against post-0.4.0
  upstream `main` at `87053aa7b`.
- A running NodeDB instance — `pgwire` on `localhost:6432` for `:pg`,
  and/or the native protocol on `localhost:6433` for `:native`. `:pg`
  is the primary transport.

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
  dbname:   "default",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"]
)
conn.query("SELECT 1+1 AS r").first  # => {"r" => "2"}

# :native transport — NodeDB binary protocol, port 6433, no libpq
nat = NodeDB::Connection.connect(
  dbname:   "default",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"],
  protocol: :native
)
nat.run("SELECT 1+1 AS r").first  # => {"r" => "2"}
nat.close
```

### Connection pool

Thread-safe pool over either transport (wraps the `connection_pool`
gem; connections are created lazily on first checkout):

```ruby
pool = NodeDB::Pool.new(
  size: 5, timeout: 5,
  dbname: "default", user: "nodedb", password: ENV["NODEDB_PASSWORD"]
)

pool.with { |conn| conn.exec("SELECT 1+1 AS r") }
pool.exec("SELECT 1+1 AS r")   # checkout + exec + checkin
pool.reload                    # discard idle connections, reconnect lazily
pool.shutdown
```

Every other keyword (`protocol: :native`, `host:`, `port:`, …) passes
through to `NodeDB::Connection.connect`. A connection that dies stays
in the pool — call `reload` to cycle them.

### Streaming results

Row-at-a-time iteration for large scans, via libpq single-row mode
(`:pg` transport only — `:native` buffers whole results by design):

```ruby
NodeDB::Streaming.each_row(conn, "SELECT id, embedding FROM big_scan") do |row|
  # row is a Hash; rows arrive as the server produces them
end

NodeDB::Streaming.each_row(conn, sql).lazy.take(100).to_a  # Enumerator form
```

Breaking out early cancels the in-flight query and drains the wire, so
the connection stays usable.

### Schema introspection

Typed DESCRIBE wrapper (either transport):

```ruby
NodeDB::Schema.columns(conn, "articles")
# => [#<data Column name="id", type="TEXT", pg_type="text", oid=25,
#            nullable=false, primary_key=true>, ...]
NodeDB::Schema.columns(conn, "articles", internal: true)  # include __storage etc.
NodeDB::Schema.collections(conn)                          # => ["articles", ...]
```

Normalizes the raw DESCRIBE quirks (duplicate primary-key rows,
`__`-prefixed internals) so adapters don't have to.

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
# CREATE COLLECTION metrics (timestamp BIGINT TIME_KEY, value FLOAT)
# WITH (engine='timeseries', retention='7d', compression='zstd')

# flags: free-standing column-list modifiers (NodeDB v0.3.0+).
# Accepts :bitemporal / :append_only / :hash_chain. BITEMPORAL
# collections get the ENGINE = suffix spelling, which works on every
# build (the WITH form built a broken bitemporal schema on older ones).
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
- [x] Connection pooling helper (`NodeDB::Pool`, wraps `connection_pool`)
- [x] Streaming result iterator (`NodeDB::Streaming.each_row`, libpq
      single-row mode; `:pg` transport)
- [ ] Async / fiber-based adapter for `async-pg`
- [x] Schema introspection helpers (`NodeDB::Schema.columns` /
      `.collections` — typed, deduped, internals filtered)
- [ ] First-class `RETURNING` parsing for `INSERT … RETURNING id`
- [x] CHANGELOG.md
- [x] RSpec coverage for SQL builders in isolation (`spec/sql/`, 14 examples on alpha.5; expanding per release)

## Known issues

NodeDB-side quirks the SQL builders work around are tracked centrally,
not here: the user-facing rollup is the AR adapter's
[KNOWN_ISSUES.md][ar-known], and per-bug reproductions, workaround
history and retests live in its [issue tracker][ar-bugs].

[ar-bugs]: https://github.com/mkhairi/activerecord-nodedb-adapter/issues?q=%22%5Bupstream%3ANodeDB%5D%22
[ar-known]: https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/KNOWN_ISSUES.md

### Builder conventions

- **Graph builders take bare collection names** — quoted identifiers
  create edge-store keys that scoped stats lookups miss; scoped
  `Graph.stats` needs the single-quoted literal form. No MATCH builder
  ships yet.
- **Timeseries builders assume a `timestamp` TIME_KEY** —
  `Timeseries.since_clause` / `until_clause` / `time_bucket` all filter
  on `timestamp`, which is what `Collection.create(engine: :timeseries)`
  declares. A collection declaring another TIME_KEY name needs its own
  WHERE fragments.
- **`Vector.search` output does not compose into an `IN` predicate** —
  wrap it in a derived table (`FROM (SEARCH ...) s`) or take the ids
  and issue a second query.
- **`:native` transport** — result shapes are at pgwire parity, but
  `:pg` remains the primary transport; the plan is still to adopt the
  official NodeDB SDK after an official release.
- **No prepared statement support** — NodeDB sends `DataRow` without
  `RowDescription` for prepared statements; use simple-query mode.

## License

Released under the **BSD 2-Clause License**. Full text: [LICENSE.md](LICENSE.md).

Independent third-party client. Not affiliated with, endorsed by, or
maintained by the NodeDB project. "NodeDB" is referenced solely to identify
the database this gem connects to.
