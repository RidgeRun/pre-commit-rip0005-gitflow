# RIP 5 Git Hooks

Use these hooks with `pre-commit` to enforce RIP 5 GitFlow rules.

## 1) Available hooks

This repository currently exposes these hook IDs:

- `rip0005-rebase-check`
- `rip0005-no-ff-merge-check`
- `rip0005-rebase-merge-check`
- `rip0005-protected-branch-commit-check`

## 2) Add to your `.pre-commit-config.yaml`

```yaml
repos:
  - repo: <hook-repo-url>
    rev: <tag-or-commit>
    hooks:
      - id: rip0005-rebase-check
      - id: rip0005-no-ff-merge-check
      - id: rip0005-rebase-merge-check
      - id: rip0005-protected-branch-commit-check
```

If you only want one hook, include only that `id`.

## 3) Install hook types

```bash
pre-commit install --hook-type pre-push --hook-type pre-merge-commit --hook-type commit-msg
```

## 4) Hook behavior

`rip0005-rebase-check`

- Stage: `pre-push`
- Purpose: ensure the target branch or commit already contains the latest tip of
  its parent branch or branches.
- Defaults: remote `origin`, parents `main master develop`, target current
  branch.

`rip0005-no-ff-merge-check`

- Stage: `pre-push`
- Purpose: block direct commits and fast-forward updates on protected branches.
- Rule: every new commit on the protected branch first-parent path must be a
  merge commit.
- Defaults: protected branches `main master develop`.

`rip0005-rebase-merge-check`

- Stage: `pre-merge-commit`
- Purpose: during a merge, ensure the incoming merge source commit or commits
  were rebased onto the current destination branch.
- Behavior: always checks against `origin/<destination-branch>`.

`rip0005-protected-branch-commit-check`

- Stage: `commit-msg`
- Purpose: block creating a normal commit directly on a protected branch.
- Exception: merge commits are allowed.
- Defaults: protected branches `main master develop`.

## 5) Optional: override parents/remote for `rip0005-rebase-check`

`rip0005-rebase-check` supports args: `remote`, `parents`, `target`.

Example:

```yaml
- id: rip0005-rebase-check
  args: [upstream, "main develop"]
```
