# NodeDB upstream bug log

NodeDB-side bugs that affect this gem's SQL builders or connection layer.

Re-tested: **2026-05-15** against **NodeDB v0.2.1**.

For the full cross-gem bug log (17 entries spanning adapter, type map, and
engine surfaces), see
[`../../../activerecord-nodedb-adapter/docs/bugs/README.md`][ar-bugs].

[ar-bugs]: ../../../activerecord-nodedb-adapter/docs/bugs/README.md

| ID  | Title                                                          | Status |
| --- | -------------------------------------------------------------- | ------ |
| 001 | INSERT returns `ResourcesExhausted` on non-timeseries engines  | RESOLVED — fixed in `nodedb/src/config/engine.rs` + `memory/startup.rs` |
| 004 | `DROP COLLECTION IF EXISTS` parses `IF` as a name when collection exists | **RESOLVED** in v0.2.1 — `Collection.drop_if_exists` workaround redundant but kept |

## Workarounds shipped here

| Bug | Code path |
| --- | --------- |
| 004 | `NodeDB::SQL::Collection.drop_if_exists` emits a plain `DROP COLLECTION` and the caller rescues a not-found error (redundant on v0.2.1+, kept for older binaries) |

## Workaround retirement

When this gem drops support for NodeDB < 0.2.1 (likely at beta release),
remove the BUG-004 workaround in
`NodeDB::SQL::Collection.drop_if_exists` via a `chore/remove-bug004-workaround`
PR.
