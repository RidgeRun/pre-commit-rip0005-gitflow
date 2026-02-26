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

remote_exists() {
  local remote_name="$1"
  git remote get-url "$remote_name" >/dev/null 2>&1
}

parent_exists_in_remote() {
  local remote_name="$1"
  local parent_branch="$2"
  git ls-remote --exit-code --heads "$remote_name" "$parent_branch" >/dev/null 2>&1
}

parent_exists_locally() {
  local parent_branch="$1"
  git rev-parse -q --verify "refs/heads/$parent_branch" >/dev/null
}

check_target_includes_parent() {
  local parent_ref="$1"
  local parent_label="$2"
  local target_ref="$3"
  local target_sha="$4"
  local parent_sha

  parent_sha="$(git rev-parse "$parent_ref")"

  if ! git merge-base --is-ancestor "$parent_sha" "$target_sha"; then
    log "Rebase-check failed: '$target_ref' is behind '$parent_label'."
    log "Rebase onto '$parent_label' before continuing."
    log "Parent tip: $parent_sha"
    log "Target head: $target_sha"
    return 1
  fi

  return 0
}

check_remote_parent() {
  local remote_name="$1"
  local parent_branch="$2"
  local target_ref="$3"
  local target_sha="$4"
  local parent_ref="${remote_name}/${parent_branch}"

  if ! remote_exists "$remote_name"; then
    log "Rebase-check: remote '$remote_name' not found."
    return 1
  fi

  if ! parent_exists_in_remote "$remote_name" "$parent_branch"; then
    log "Rebase-check: parent '$parent_ref' does not exist. Skipping."
    return 0
  fi

  if ! git fetch -q "$remote_name" "$parent_branch"; then
    log "Rebase-check: failed to fetch '$parent_ref'."
    return 1
  fi

  if ! check_target_includes_parent "refs/remotes/$parent_ref" "$parent_ref" "$target_ref" "$target_sha"; then
    return 1
  fi

  return 0
}

check_local_parent() {
  local parent_branch="$1"
  local target_ref="$2"
  local target_sha="$3"

  if ! parent_exists_locally "$parent_branch"; then
    log "Rebase-check: parent '$parent_branch' does not exist locally. Skipping."
    return 0
  fi

  if ! check_target_includes_parent "refs/heads/$parent_branch" "$parent_branch" "$target_ref" "$target_sha"; then
    return 1
  fi

  return 0
}

check_rebased_on_parent() {
  local remote_name="$1"
  local parent_branch="$2"
  local target_ref="$3"
  local target_sha="$4"

  if ! check_remote_parent "$remote_name" "$parent_branch" "$target_ref" "$target_sha"; then
    return 1
  fi

  if ! check_local_parent "$parent_branch" "$target_ref" "$target_sha"; then
    return 1
  fi

  return 0
}

main() {
  local remote_name="${1:-origin}"
  local parent_spec="${2:-main master develop}"
  local target_ref="${3:-}"
  local target_sha
  local normalized_parent_spec
  local parent_branch

  if is_detached_head; then
    log "Rebase-check: detached HEAD. Skipping."
    return 0
  fi

  if [[ -z "$target_ref" ]]; then
    target_ref="$(get_current_branch)"
  fi

  if ! target_sha="$(git rev-parse --verify "${target_ref}^{commit}" 2>/dev/null)"; then
    log "Rebase-check: target '$target_ref' is not a valid commit-ish."
    return 1
  fi

  normalized_parent_spec="${parent_spec//,/ }"

  if [[ -z "${normalized_parent_spec//[[:space:]]/}" ]]; then
    log "Rebase-check: no parent candidates provided. Skipping."
    return 0
  fi

  for parent_branch in $normalized_parent_spec; do
    if ! check_rebased_on_parent "$remote_name" "$parent_branch" "$target_ref" "$target_sha"; then
      return 1
    fi
  done

  log "Rebase-check passed: '$target_ref' is up to date."
  return 0
}

main "$@"
