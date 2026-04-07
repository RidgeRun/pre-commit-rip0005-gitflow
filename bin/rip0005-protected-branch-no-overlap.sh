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

  parents=($(git rev-list --parents -n 1 "$commit_sha"))
  if [[ "${#parents[@]}" -le 2 ]]; then
    continue
  fi

  mainline_parent="${parents[1]}"
  for merged_parent in "${parents[@]:2}"; do
    if ! git merge-base --is-ancestor "$mainline_parent" "$merged_parent"; then
      log "RIP 5 check failed: overlapping merge detected on '$branch_name'."
      log "Merge commit '$commit_sha' was created from a branch that was not rebased on '$branch_name'."
      log "Rebase the source branch onto '$branch_name' before merging."
      exit 1
    fi
  done
done < <(git rev-list --first-parent "${from_ref}..${to_ref}")
