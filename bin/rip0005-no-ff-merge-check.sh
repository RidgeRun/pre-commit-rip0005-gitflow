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

is_merge_commit() {
  local commit_sha="$1"
  local parent_count

  parent_count="$(git rev-list --parents -n 1 "$commit_sha" | awk '{print NF-1}')"
  [[ "$parent_count" -gt 1 ]]
}

check_no_ff_update() {
  local branch_name="$1"
  local remote_sha="$2"
  local local_sha="$3"
  local commit_sha

  while read -r commit_sha; do
    [[ -z "$commit_sha" ]] && continue

    if ! is_merge_commit "$commit_sha"; then
      log "RIP 5 check failed: non-merge update detected on '$branch_name'."
      log "Commit '$commit_sha' on the first-parent path is not a merge commit."
      log "Use 'git merge --no-ff <source-branch>' into '$branch_name'."
      return 1
    fi
  done < <(git rev-list --first-parent "${remote_sha}..${local_sha}")

  return 0
}

main() {
  local protected_spec="${1:-main master develop}"
  local from_ref="${PRE_COMMIT_FROM_REF:-}"
  local to_ref="${PRE_COMMIT_TO_REF:-}"
  local remote_branch_ref="${PRE_COMMIT_REMOTE_BRANCH:-}"
  local branch_name

  if [[ -z "$from_ref" || -z "$to_ref" ]]; then
    return 0
  fi

  if [[ "$remote_branch_ref" != refs/heads/* ]]; then
    return 0
  fi

  branch_name="${remote_branch_ref#refs/heads/}"
  if ! is_protected_branch "$branch_name" "$protected_spec"; then
    return 0
  fi

  if ! check_no_ff_update "$branch_name" "$from_ref" "$to_ref"; then
    return 1
  fi

  return 0
}

main "$@"
