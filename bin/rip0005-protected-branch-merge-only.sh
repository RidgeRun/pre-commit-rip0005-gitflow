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

readonly PROTECTED_BRANCHES=(main master develop)

log() { printf "%s\n" "$*" >&2; }

is_protected_branch() {
  local branch_name="$1"
  local protected_branch

  for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$branch_name" == "$protected_branch" ]]; then
      return 0
    fi
  done

  return 1
}

check_merge_only() {
  local commit_sha="$1"
  local branch_name="$2"
  local parent_count

  if ! is_protected_branch "$branch_name"; then
    return 0
  fi

  parent_count="$(git rev-list --parents -n 1 "$commit_sha" | awk '{print NF-1}')"
  if [[ "$parent_count" -gt 1 ]]; then
    return 0
  fi

  log "RIP 5 check failed: non-merge update detected on '$branch_name'."
  log "Commit '$commit_sha' on the first-parent path is not a merge commit."
  log "Use 'git merge --no-ff <source-branch>' into '$branch_name'."
  exit 1
}

if [[ "$#" -gt 0 ]]; then
  check_merge_only "$1" "$2"
  exit 0
fi

from_ref="${PRE_COMMIT_FROM_REF:-}"
to_ref="${PRE_COMMIT_TO_REF:-}"
remote_branch_ref="${PRE_COMMIT_REMOTE_BRANCH:-}"

if [[ -z "$from_ref" || -z "$to_ref" ]]; then
  exit 0
fi

if [[ "$remote_branch_ref" != refs/heads/* ]]; then
  exit 0
fi

branch_name="${remote_branch_ref#refs/heads/}"
if ! is_protected_branch "$branch_name"; then
  exit 0
fi

while read -r commit_sha; do
  check_merge_only "$commit_sha" "$branch_name"
done < <(git rev-list --first-parent "${from_ref}..${to_ref}")
