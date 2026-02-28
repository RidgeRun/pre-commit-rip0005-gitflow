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

log(){ printf "%s\n" "$*" >&2; }

is_detached_head() {
  ! git symbolic-ref --quiet HEAD >/dev/null 2>&1
}

get_current_branch() {
  git symbolic-ref --quiet --short HEAD
}

is_merge_commit() {
  local merge_head_path
  merge_head_path="$(git rev-parse --git-path MERGE_HEAD)"
  [[ -f "$merge_head_path" ]]
}

is_protected_branch() {
  local branch_name="$1"
  local protected_spec="$2"
  local normalized_spec
  local protected_branch

  normalized_spec="${protected_spec//,/ }"
  for protected_branch in $normalized_spec; do
    if [[ "$branch_name" == "$protected_branch" ]]; then
      return 0
    fi
  done

  return 1
}

main() {
  local protected_spec="${1:-main master develop}"
  local current_branch

  if is_detached_head; then
    log "RIP 5 check: detached HEAD. Skipping."
    return 0
  fi

  current_branch="$(get_current_branch)"

  if ! is_protected_branch "$current_branch" "$protected_spec"; then
    return 0
  fi

  if is_merge_commit; then
    log "RIP 5 check: merge commit on '$current_branch'. Allowed."
    return 0
  fi

  log "RIP 5 check failed: direct commits to '$current_branch' are not allowed."
  log "Create a feature/release/hotfix branch and use --no-ff to merge it."
  return 1
}

main "$@"
