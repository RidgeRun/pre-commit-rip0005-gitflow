# Rebase Check Hooks

Use these hooks with `pre-commit` to prevent pushing or merging branches that are behind required parent branches.

## 1) Add to your `.pre-commit-config.yaml`

```yaml
repos:
  - repo: <hook-repo-url>
    rev: <tag-or-commit>
    hooks:
      - id: rebase-check
      - id: rebase-merge-check
```

If you only want one hook, include only that `id`.

## 2) Install hook types

```bash
pre-commit install --hook-type pre-push --hook-type pre-merge-commit
```

## 3) Optional: override parents/remote for `rebase-check`

`rebase-check` supports args: `remote`, `parents`, `target`.

Example:

```yaml
- id: rebase-check
  args: [upstream, "main develop"]
```

`rebase-merge-check` always checks merge source commit(s) against destination branch on `origin`.
