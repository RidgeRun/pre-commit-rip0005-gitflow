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
readonly BASE_BRANCHES=(main master develop)

log() { printf "%s\n" "$*" >&2; }

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || true
}

remote_branch_exists() {
  git ls-remote --exit-code --heads "$REMOTE_NAME" "$1" >/dev/null 2>&1
}

branch="$(current_branch)"
if [[ -z "$branch" ]]; then
  log "Rebase-check: detached HEAD. Skipping."
  exit 0
fi

for base_branch in "${BASE_BRANCHES[@]}"; do
  if ! remote_branch_exists "$base_branch"; then
    log "Rebase-check: parent '$REMOTE_NAME/$base_branch' does not exist. Skipping."
    continue
  fi

  if ! git fetch -q "$REMOTE_NAME" "$base_branch"; then
    log "Rebase-check: failed to fetch '$REMOTE_NAME/$base_branch'."
    exit 1
  fi

  parent_ref="refs/remotes/$REMOTE_NAME/$base_branch"
  parent_sha="$(git rev-parse "$parent_ref")"
  target_sha="$(git rev-parse HEAD)"

  if ! git merge-base --is-ancestor "$parent_sha" "$target_sha"; then
    log "Rebase-check failed: '$branch' is behind '$REMOTE_NAME/$base_branch'."
    log "Rebase onto '$REMOTE_NAME/$base_branch' before continuing."
    log "Parent tip: $parent_sha"
    log "Target head: $target_sha"
    exit 1
  fi
done

log "Rebase-check passed: '$branch' is up to date."
