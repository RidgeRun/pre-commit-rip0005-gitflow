# RIP 5 Git Hooks

Use these hooks with `pre-commit` to enforce RIP 5 GitFlow rules.

## 1) Available hooks

This repository exposes a single hook ID:

- `rip0005-gitflow`

## 2) Add to your `.pre-commit-config.yaml`

```yaml
repos:
  - repo: <hook-repo-url>
    rev: <tag-or-commit>
    hooks:
      - id: rip0005-gitflow
```

## 3) Install hook types

```bash
pre-commit install --hook-type pre-push --hook-type commit-msg
```

## 4) Hook behavior

`rip0005-gitflow` runs different RIP 5 checks depending on the Git hook stage.

- Stage: `pre-push`
- Checks: ensure the pushed branch already contains the latest tip of the
  shared branches and block direct commits or fast-forward updates on protected
  branches.
- Rule: every new commit on the protected branch first-parent path must be a
  merge commit.
- Defaults: remote `origin`, shared/protected branches `main master develop`,
  target current branch.

- Stage: `commit-msg`
- Checks: block creating a normal commit directly on a protected branch. During
  merge commits, also ensure the incoming merge source commit or commits were
  rebased onto the current destination branch.
- Exception: merge commits are allowed.
- Behavior: merge validation checks against `origin/<destination-branch>`.

## 5) Optional: override defaults

`rip0005-gitflow` supports optional named arguments:

- `--remote=<name>`
- `--branches=<space-or-comma-separated-branch-list>`
- `--target=<commit-ish>` for the `pre-push` rebase check only

Example:

```yaml
- id: rip0005-gitflow
  args: [--remote=upstream, "--branches=main develop"]
```
