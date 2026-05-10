# NodeDB upstream bug log

NodeDB-side bugs that affect this gem's SQL builders or connection layer.

Re-tested: **2026-05-10**.

| ID | Title | Status |
| -- | ----- | ------ |
| 001 | INSERT returns `ResourcesExhausted` on non-timeseries engines | RESOLVED — fixed upstream in `nodedb/src/config/engine.rs` + `memory/startup.rs` |
| 004 | `DROP COLLECTION IF EXISTS` parses `IF` as a name when collection exists | OPEN (partial fix — works when collection is missing) |

## Workarounds shipped here

| Bug | Code path |
| --- | --------- |
| 004 | `NodeDB::SQL::Collection.drop_if_exists` emits a plain `DROP COLLECTION` and the caller rescues a not-found error |
