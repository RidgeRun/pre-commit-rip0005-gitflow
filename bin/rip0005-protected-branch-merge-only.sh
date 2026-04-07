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
is_protected=false
for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "$branch_name" == "$protected_branch" ]]; then
    is_protected=true
    break
  fi
done

if [[ "$is_protected" != true ]]; then
  exit 0
fi

while read -r commit_sha; do
  [[ -z "$commit_sha" ]] && continue

  parent_count="$(git rev-list --parents -n 1 "$commit_sha" | awk '{print NF-1}')"
  if [[ "$parent_count" -le 1 ]]; then
    log "RIP 5 check failed: non-merge update detected on '$branch_name'."
    log "Commit '$commit_sha' on the first-parent path is not a merge commit."
    log "Use 'git merge --no-ff <source-branch>' into '$branch_name'."
    exit 1
  fi
done < <(git rev-list --first-parent "${from_ref}..${to_ref}")
