#!/usr/bin/env bash
# Copyright (C) 2026 RidgeRun, LLC (http://www.ridgerun.com)
# All Rights Reserved.
#
# The contents of this software are proprietary and confidential to
# RidgeRun, LLC. No part of this program may be photocopied,
# reproduced or translated into another programming language without
# prior written consent of RidgeRun, LLC. The user is free to modify
# the source code after obtaining a software license from RidgeRun.
# All source code changes must be provided back to RidgeRun without
# any encumbrance.

set -euo pipefail
readonly REMOTE_NAME="origin"
readonly PROTECTED_BRANCHES=(main master develop)
readonly MAIN_BRANCHES=(main master)
readonly DEVELOP_BRANCH="develop"
readonly DEVELOP_BRANCH_PREFIXES=(feature/ release/)
readonly MAIN_BRANCH_PREFIXES=(hotfix/)

log() { printf "%s\n" "$*" >&2; }

remote_branch_exists() {
  git ls-remote --exit-code --heads "$REMOTE_NAME" "$1" >/dev/null 2>&1
}

check_rebased() {
  local target_commit="$1"
  local base_branch="$2"
  local target_label="$3"
  local parent_ref="refs/remotes/$REMOTE_NAME/$base_branch"
  local parent_sha

  if ! remote_branch_exists "$base_branch"; then
    log "Rebase-check: parent '$REMOTE_NAME/$base_branch' does not exist. Skipping."
    return 0
  fi

  if ! git fetch -q "$REMOTE_NAME" "$base_branch"; then
    log "Rebase-check: failed to fetch '$REMOTE_NAME/$base_branch'."
    exit 1
  fi

  parent_sha="$(git rev-parse "$parent_ref")"

  if ! git merge-base --is-ancestor "$parent_sha" "$target_commit"; then
    log "Rebase-check failed: '$target_label' is behind '$REMOTE_NAME/$base_branch'."
    log "Rebase onto '$REMOTE_NAME/$base_branch' before continuing."
    log "Parent tip: $parent_sha"
    log "Target head: $target_commit"
    exit 1
  fi
}

remote_base_exists() {
  local branch="$1"
  git ls-remote --exit-code --heads "$REMOTE_NAME" "$branch" >/dev/null 2>&1
}

has_branch_prefix() {
  local branch="$1"
  shift

  local prefix
  for prefix in "$@"; do
    if [[ "$branch" == "$prefix"* && "$branch" != "$prefix" ]]; then
      return 0
    fi
  done

  return 1
}

select_base_branch() {
  local branch="$1"
  local protected_branch
  local main_branch

  # Protected branches are checked against their own remote tip.
  for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$branch" == "$protected_branch" ]]; then
      printf '%s\n' "$protected_branch"
      return
    fi
  done

  if has_branch_prefix "$branch" "${DEVELOP_BRANCH_PREFIXES[@]}"; then
    if remote_base_exists "$DEVELOP_BRANCH"; then
      printf '%s\n' "$DEVELOP_BRANCH"
    else
      log "Rebase-check failed: required base '$REMOTE_NAME/$DEVELOP_BRANCH' does not exist."
      log "Create '$REMOTE_NAME/$DEVELOP_BRANCH' before pushing '$branch'."
      exit 1
    fi
  elif has_branch_prefix "$branch" "${MAIN_BRANCH_PREFIXES[@]}"; then
    for main_branch in "${MAIN_BRANCHES[@]}"; do
      if remote_base_exists "$main_branch"; then
        printf '%s\n' "$main_branch"
        return
      fi
    done

    log "Rebase-check failed: required base '$REMOTE_NAME/main' or '$REMOTE_NAME/master' does not exist."
    log "Create one of these branches before pushing '$branch'."
    exit 1
  else
    log "Rebase-check failed: unsupported branch '$branch'."
    log "Use 'feature/<name>', 'release/<name>', or 'hotfix/<name>'."
    exit 1
  fi
}

if [[ "$#" -gt 0 ]]; then
  check_rebased "$1" "$2" "$3"
  exit 0
fi

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  log "Rebase-check: detached HEAD. Skipping."
  exit 0
fi

base_branch="$(select_base_branch "$branch")"
check_rebased HEAD "$base_branch" "$branch"

log "Rebase-check passed: '$branch' is up to date with '$REMOTE_NAME/$base_branch'."
