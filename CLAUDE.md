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

```bash
bundle exec rspec
```

Own suite: SQL-builder unit specs plus `:pg` / `:native` integration
specs (the latter need a live NodeDB on `localhost:6432` / `:6433`;
they skip when unreachable). Must stay 0 failures before any PR
merges. The gem is also exercised end-to-end through
`activerecord-nodedb-adapter`'s suite — run that too before a PR that
changes anything in `lib/nodedb/`:

```bash
cd ../activerecord-nodedb-adapter && bundle exec rspec
```

## Release checklist additions

Standard alpha release flow lives in `../../CLAUDE.md`. The version file
for this gem is `lib/nodedb/version.rb`.

## License

BSD 2-Clause. See `LICENSE.md`.
