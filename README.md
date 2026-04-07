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
- `pre-push`: checks branch rebase state, blocks non-merge commits on protected branches, and blocks overlapping stale merges on protected branches.

## Defaults

```text
remote: origin
protected branches: main master develop
arguments: none
```
