# RIP 5 Git Hooks

Single hook ID:

- `rip0005-gitflow`

## Configure

```yaml
repos:
  - repo: <hook-repo-url>
    rev: <tag-or-commit>
    hooks:
      - id: rip0005-gitflow
```

## Install

```bash
pre-commit install --install-hooks --hook-type commit-msg --hook-type pre-push
```

## What It Checks

- `commit-msg`: blocks direct commits to `main`, `master`, and `develop`, and rejects stale merge commits.
- `pre-push`: checks that topic branches include the latest tip of their GitFlow base, blocks non-merge commits on protected branches, and blocks overlapping stale merges on protected branches.

The rebase check supports these topic branch prefixes and selects a base accordingly:

- `feature/*` and `release/*` use `develop`.
- `hotfix/*` use `main` (or `master` when `main` is absent).
- `main`, `master`, and `develop` are checked against their own remote tips.
- Other topic branch names are rejected.
- The required base branch must exist on `origin`; otherwise, the push is rejected with an error.

## Defaults

```text
remote: origin
protected branches: main master develop
arguments: none
```
