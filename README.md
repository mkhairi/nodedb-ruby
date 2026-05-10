# nodedb-ruby

> ## ⚠️ ALPHA — DO NOT USE IN PRODUCTION
>
> Version: **`0.1.0.alpha.1`**.
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

## Status

| Component        | State |
| ---------------- | ----- |
| Connection       | Working (pg gem, simple-query mode) |
| Type map         | Working (vector, geometry, json, uuid, …) |
| SQL builders     | Vector / Graph / Timeseries / Spatial / KV / FTS / Collection DDL |
| Bundled NodeDB version | 0.1.x (built from `../nodedb`) |
| Test suite       | covered indirectly via `activerecord-nodedb-adapter` (13/0/0) |

## Requirements

- Ruby 3.2+ (tested on 4.0.1)
- `pg` gem (libpq client)
- A running NodeDB instance on `pgwire` (default `localhost:6432`)

## Installation

```ruby
gem "nodedb-ruby"
```

Or from source while the gem is unreleased:

```ruby
gem "nodedb-ruby", path: "../nodedb-ruby"
```

## Usage

### Direct connection

```ruby
require "nodedb"

conn = NodeDB::Connection.connect(
  host:     "localhost",
  port:     6432,
  database: "nodedb",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"]
)

conn.query("SELECT 1+1 AS r").first  # => {"r" => "2"}
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
# SELECT *, bm25_score(body, 'machine learning') AS bm25_score
# FROM posts WHERE text_match(body, 'machine learning')
# ORDER BY bm25_score DESC LIMIT 20

NodeDB::SQL::Collection.create("articles", engine: :document_strict, columns: [
  "id TEXT PRIMARY KEY",
  "title TEXT",
  "body TEXT"
])
# CREATE COLLECTION articles (id TEXT PRIMARY KEY, title TEXT, body TEXT)
# WITH (engine='document_strict')
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
  - [x] `Collection.create` / `drop` / `show` / `drop_if_exists`
  - [x] `Vector.search` (`SEARCH … USING VECTOR(col, ARRAY[…], limit)`)
  - [x] `Graph.insert_edge` / `traverse` / `algo` / `delete_edge` (with required `IN 'collection'` clause)
  - [x] `Timeseries.create` / `time_bucket` / range helpers
  - [x] `Spatial.distance` / `within_distance` / `intersects`
  - [x] `KV.set` / `get` / `delete`
  - [x] `FTS.search` (uses `text_match()` + `bm25_score()`)

### Pending
- [ ] Connection pooling helper (caller currently manages `pg` connections)
- [ ] Streaming result iterator for large vector / FTS scans
- [ ] Async / fiber-based adapter for `async-pg`
- [ ] Schema introspection helpers (DESCRIBE wrapper that yields typed columns)
- [ ] First-class `RETURNING` parsing for `INSERT … RETURNING id`
- [ ] CHANGELOG.md
- [ ] RSpec coverage for builders in isolation (currently exercised only through ActiveRecord adapter)

## Known issues

These are NodeDB-side parser quirks that the SQL builders intentionally work
around. They are documented in `docs/bugs/` and may be fixed upstream over time.

- **Quoted identifiers rejected by `SEARCH`** — `Vector.search` emits bare
  `column` / `table` names; quoting via `"col"` returns no rows.
- **Qualified column refs return nil** — `articles.id` and `"articles"."id"`
  resolve to nil. ActiveRecord callers must select unqualified columns.
- **`CREATE COLLECTION IF EXISTS` half-broken (BUG-004)** — partial fix
  upstream; `Collection.drop_if_exists` rescues the not-found error rather
  than relying on `IF EXISTS`.
- **Document INSERTs require `document_strict` engine for typed columns** —
  schemaless collections silently drop fields that aren't `id`. (Resolved as
  of BUG-001 fix in NodeDB source; see `docs/bugs/001-*.md`.)
- **No prepared statement support** — NodeDB sends `DataRow` without
  `RowDescription` for prepared statements, so callers must use simple-query
  mode.

## License

Released under the **BSD 2-Clause License**. Full text: [LICENSE.md](LICENSE.md).

Independent third-party client. Not affiliated with, endorsed by, or
maintained by the NodeDB project. "NodeDB" is referenced solely to identify
the database this gem connects to.
