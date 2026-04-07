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

remote_name="origin"
branch_spec="main master develop"
target_ref=""

is_pre_push_context() {
  [[ -n "${PRE_COMMIT_FROM_REF:-}" && -n "${PRE_COMMIT_TO_REF:-}" ]]
}

is_commit_msg_context() {
  local arg
  local base_name

  for arg in "$@"; do
    base_name="$(basename -- "$arg")"
    case "$base_name" in
      COMMIT_EDITMSG|MERGE_MSG|SQUASH_MSG)
        return 0
        ;;
    esac
  done

  return 1
}

is_merge_in_progress() {
  local merge_head_path
  merge_head_path="$(git rev-parse --git-path MERGE_HEAD)"
  [[ -f "$merge_head_path" ]]
}

parse_args() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      --remote=*)
        remote_name="${arg#--remote=}"
        ;;
      --branches=*)
        branch_spec="${arg#--branches=}"
        ;;
      --target=*)
        target_ref="${arg#--target=}"
        ;;
    esac
  done
}

main() {
  local script_dir

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  parse_args "$@"

  if is_pre_push_context; then
    "$script_dir/rip0005-rebase-check.sh" "$remote_name" "$branch_spec" "$target_ref"
    "$script_dir/rip0005-no-ff-merge-check.sh" "$branch_spec"
    return 0
  fi

  if is_commit_msg_context "$@"; then
    if is_merge_in_progress; then
      "$script_dir/rip0005-rebase-merge-check.sh" "$remote_name"
    fi

    "$script_dir/rip0005-protected-branch-commit-check.sh" "$branch_spec"
    return 0
  fi

  return 0
}

main "$@"
