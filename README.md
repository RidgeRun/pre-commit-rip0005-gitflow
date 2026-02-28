# RIP 5 Git Hooks

Use these hooks with `pre-commit` to enforce RIP 5 GitFlow rules.

## 1) Add to your `.pre-commit-config.yaml`

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

## 2) Install hook types

```bash
pre-commit install --hook-type pre-push --hook-type pre-merge-commit
```

## 3) Install commit guard hook type

```bash
pre-commit install --hook-type commit-msg
```

## 4) Optional: override parents/remote for `rip0005-rebase-check`

`rip0005-rebase-check` supports args: `remote`, `parents`, `target`.

Example:

```yaml
- id: rip0005-rebase-check
  args: [upstream, "main develop"]
```

`rip0005-no-ff-merge-check` blocks fast-forward/direct updates on protected
branches by requiring merge commits on the first-parent path.

`rip0005-rebase-merge-check` always checks merge source commit(s) against
destination branch on `origin`.

`rip0005-protected-branch-commit-check` blocks direct commits on
`main`, `master`, and `develop` by default.
