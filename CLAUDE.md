# nodedb-ruby — contribution & workflow

This file is consumed by Claude Code (and any other agentic tooling) to keep
contributions consistent. Humans should follow the same rules.

## Project

Framework-agnostic Ruby client and SQL builders for NodeDB. Foundation gem
for `activerecord-nodedb-adapter` and `sequel-nodedb-adapter`. Owns:

- `NodeDB::Connection` — pg-based connection wrapper
- `NodeDB::TypeMap` — vector / geometry / json / uuid casting
- `NodeDB::SQL::*` — raw SQL builders for collections, vector, graph,
  timeseries, spatial, KV, FTS

Status: **alpha** (`0.1.0.alpha.1`). No production deployments.

## Branch & PR workflow

**Never commit directly to `main`.** All work goes through a branch + PR,
even one-line fixes, even by the repo owner. Reasons:

- PR body is the canonical changelog entry — searchable later.
- Every change has CI green + a test plan checkbox before merge.
- Reverts stay clean (single PR = single revert).

### Branch naming

```
<type>/<short-kebab-summary>
```

`<type>` is one of:

| Prefix      | Use for                                                      |
| ----------- | ------------------------------------------------------------ |
| `feat/`     | New user-facing capability (engine concern, DSL helper)      |
| `fix/`      | Bug fix (adapter quirk, NodeDB workaround update)            |
| `docs/`     | README / docs / bug-log only (no code change)                |
| `chore/`    | Dep bumps, gemspec metadata, CI tweaks, release plumbing     |
| `refactor/` | Internal restructure with no behaviour change                |
| `test/`     | Spec-only change                                             |

Examples: `fix/silence-libpq-graph-noise`, `feat/spatial-bbox-helper`,
`chore/bump-rails-8.1`.

### Commit messages

Conventional Commits style. Subject ≤ 70 chars, imperative mood, lowercase.
Body wraps at 80, explains *why* (not *what* — the diff covers that), lists
test plan.

```
fix(graph): silence harmless libpq "could not interpret result" noise

NodeDB returns custom command tags (INSERT EDGE, GRAPH TRAVERSE, ...)
that libpq reports to fd 2 as warnings. Queries succeed regardless.

NodeDB::Graph.silence_libpq_noise wraps each graph_* call: redirects
fd 2 to a pipe, yields, re-emits non-matching lines so real warnings
still surface.

Suite: 13 examples, 0 failures.
```

### PR body template

```
## Summary
<1-3 bullet points: what does this PR change, observably?>

## Why
<the decision context — bug, tracking issue, NodeDB upstream behaviour>

## Changes
- <file/area>: <change>
- ...

## Test plan
- [ ] `bundle exec rspec` — N examples, 0 failures
- [ ] Smoke-tested against sample_rails_app (if relevant)
- [ ] Manual verification against live NodeDB (if relevant)

## Risks / follow-ups
<edge cases left uncovered, related upstream tracking issues, …>

## Linked issues
Closes #N — tracking BUG-XXX
```

### Open the PR

```bash
git push -u origin <branch>
gh pr create --base main --head <branch> --title "<type>(<scope>): <subject>" --body-file ./.github/PR_BODY.md
```

Or pass the body inline with a heredoc. Always link the tracking issue if
the change resolves or partially resolves a `[upstream:NodeDB]` issue.

## Working with NodeDB upstream bugs

Bug docs live in `docs/bugs/`. Each open bug has a matching GitHub issue in
this repo tagged `[upstream:NodeDB]`. Lifecycle:

1. Hit a NodeDB-side bug → reproduce minimally → write
   `docs/bugs/NNN-<slug>.md` with status, reproduction, expected, workaround.
2. File a tracking issue here referencing the doc. Title prefix:
   `[upstream:NodeDB] BUG-NNN: <one-line>`.
3. Ship the workaround in a `fix/` PR linked to the issue.
4. When NodeDB fixes the upstream bug:
   - Retest, update the doc's `## Status` to `RESOLVED`.
   - Open a `chore/remove-bugNNN-workaround` PR removing the adapter code.
   - Close the tracking issue with a link to the removal PR.

## Tests

- This gem currently has **no isolated RSpec suite**. SQL builders and
  connection logic are exercised through `activerecord-nodedb-adapter`'s
  integration suite (13/0/0 against a live NodeDB).
- New behaviour or NodeDB workaround should ship with a spec — adding an
  isolated suite here is on the roadmap (see README *Pending* checklist).
- Until the local suite exists, run `cd ../activerecord-nodedb-adapter &&
  bundle exec rspec` before opening a PR that changes `lib/nodedb/`.

## Versioning

- `0.1.0.alpha.N` for alpha releases. Bump `N` for any user-visible change.
- Promote to `0.1.0.beta.N` once the suite covers all NodeDB engines and
  someone has run the gem against non-disposable data for ≥ 1 month.
- `0.1.0` only after a real production deploy + post-mortem.

## Release checklist (alpha)

1. Bump `lib/nodedb/version.rb`.
2. Update `CHANGELOG.md` (one section per `0.1.0.alpha.N`).
3. PR with `chore/release-0.1.0.alpha.N`. Merge.
4. `git tag v0.1.0.alpha.N && git push --tags`.
5. `gem build && gem push pkg/*.gem` (when ready for rubygems push — not yet).

## What to never do

- Push to `main` directly.
- Force-push to `main` ever.
- Skip pre-merge tests with `--no-verify`.
- Vendor NodeDB source (Rust) or binary into this repo. Connect via `pg`.
- Imply NodeDB endorsement in README, docs, or commit messages.
- Use real customer data, billing data, or anything regulated as test
  fixtures. Disposable data only — gem is alpha.

## License

BSD 2-Clause. Independent third-party client; not affiliated with the
NodeDB project. See `LICENSE.md`.
