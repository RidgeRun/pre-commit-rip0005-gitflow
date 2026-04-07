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

log() { printf "%s\n" "$*" >&2; }

destination_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -z "$destination_branch" ]]; then
  log "Rebase-check: detached HEAD. Skipping."
  exit 0
fi

merge_head_path="$(git rev-parse --git-path MERGE_HEAD)"
if [[ ! -f "$merge_head_path" ]]; then
  log "Rebase-check: no MERGE_HEAD. Skipping."
  exit 0
fi

if ! git ls-remote --exit-code --heads "$REMOTE_NAME" "$destination_branch" >/dev/null 2>&1; then
  log "Rebase-check: parent '$REMOTE_NAME/$destination_branch' does not exist. Skipping."
  exit 0
fi

if ! git fetch -q "$REMOTE_NAME" "$destination_branch"; then
  log "Rebase-check: failed to fetch '$REMOTE_NAME/$destination_branch'."
  exit 1
fi

parent_ref="refs/remotes/$REMOTE_NAME/$destination_branch"
parent_sha="$(git rev-parse "$parent_ref")"

while read -r source_commit; do
  [[ -z "$source_commit" ]] && continue

  if ! git merge-base --is-ancestor "$parent_sha" "$source_commit"; then
    log "Rebase-check failed: '$source_commit' is behind '$REMOTE_NAME/$destination_branch'."
    log "Rebase onto '$REMOTE_NAME/$destination_branch' before continuing."
    log "Parent tip: $parent_sha"
    log "Target head: $source_commit"
    exit 1
  fi
done < "$merge_head_path"
