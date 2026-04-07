# RIP 5 Git Hooks

Use these hooks with `pre-commit` to enforce RIP 5 GitFlow rules.

## 1) Available hooks

This repository exposes these hook IDs:

- `rip0005-branch-rebased`
- `rip0005-merge-rebased`
- `rip0005-protected-branch-commit`
- `rip0005-protected-branch-merge-only`
- `rip0005-protected-branch-no-overlap`

## 2) Add to your `.pre-commit-config.yaml`

```yaml
repos:
  - repo: <hook-repo-url>
    rev: <tag-or-commit>
    hooks:
      - id: rip0005-branch-rebased
      - id: rip0005-merge-rebased
      - id: rip0005-protected-branch-commit
      - id: rip0005-protected-branch-merge-only
      - id: rip0005-protected-branch-no-overlap
```

## 3) Install hook types

```bash
pre-commit install --hook-type pre-push --hook-type pre-merge-commit --hook-type commit-msg
```

## 4) Hook behavior

`rip0005-branch-rebased`

- Stage: `pre-push`
- Checks that the current branch contains the latest tips of `origin/main`,
  `origin/master`, and `origin/develop`.

`rip0005-merge-rebased`

- Stage: `commit-msg`
- Checks that the merge source is rebased on the current destination branch in
  `origin`.

`rip0005-protected-branch-commit`

- Stage: `commit-msg`
- Blocks direct commits on `main`, `master`, and `develop`.
- Merge commits are allowed.

`rip0005-protected-branch-merge-only`

- Stage: `pre-push`
- Blocks protected-branch updates whose new mainline commits are not merge
  commits.

`rip0005-protected-branch-no-overlap`

- Stage: `pre-push`
- Blocks protected-branch updates whose new merge commits were created from
  stale branches.

## 5) Optional: override defaults

These hooks have no arguments.

It always checks against `origin` and treats `main`, `master`, and `develop`
as the protected/shared branches.
