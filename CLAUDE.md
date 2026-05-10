# nodedb-ruby — project rules

Workspace-wide rules (branch/PR workflow, upstream-bug lifecycle,
versioning, release checklist, "what to never do") live in the monorepo
root: `../../CLAUDE.md`. **Read that first.** Anything below adds or
overrides for this gem only.

## Project

Framework-agnostic Ruby client and SQL builders for NodeDB. Foundation
gem for `activerecord-nodedb-adapter` and `sequel-nodedb-adapter`.
Owns:

- `NodeDB::Connection` — pg-based connection wrapper
- `NodeDB::TypeMap` — vector / geometry / json / uuid casting
- `NodeDB::SQL::*` — raw SQL builders for collections, vector, graph,
  timeseries, spatial, KV, FTS

Status: **alpha** (`0.1.0.alpha.N`).

## Tests

This gem has **no isolated RSpec suite yet**. SQL builders and connection
logic are exercised through `activerecord-nodedb-adapter`'s integration
suite. Until a local suite lands:

```bash
cd ../activerecord-nodedb-adapter && bundle exec rspec
```

before opening a PR that changes anything in `lib/nodedb/`.

## Release checklist additions

Standard alpha release flow lives in `../../CLAUDE.md`. The version file
for this gem is `lib/nodedb/version.rb`.

## License

BSD 2-Clause. See `LICENSE.md`.
