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

main() {
  local remote_name="${1:-origin}"
  local destination_branch
  local merge_head_path
  local script_dir
  local rebase_check_script
  local source_commit

  destination_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$destination_branch" ]]; then
    log "Rebase-check: detached HEAD. Skipping."
    return 0
  fi

  merge_head_path="$(git rev-parse --git-path MERGE_HEAD)"
  if [[ ! -f "$merge_head_path" ]]; then
    log "Rebase-check: no MERGE_HEAD. Skipping."
    return 0
  fi

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  rebase_check_script="$script_dir/rip0005-rebase-check.sh"

  while read -r source_commit; do
    [[ -z "$source_commit" ]] && continue
    if ! "$rebase_check_script" "$remote_name" "$destination_branch" "$source_commit"; then
      return 1
    fi
  done < "$merge_head_path"

  return 0
}

main "$@"
