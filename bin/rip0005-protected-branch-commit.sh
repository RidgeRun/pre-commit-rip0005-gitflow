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

log() { printf "%s\n" "$*" >&2; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -z "$current_branch" ]]; then
  log "RIP 5 check: detached HEAD. Skipping."
  exit 0
fi

if [[ -f "$(git rev-parse --git-path MERGE_HEAD)" ]]; then
  exit 0
fi

if "$script_dir/rip0005-protected-branch-merge-only.sh" HEAD "$current_branch"; then
  exit 0
fi

log "RIP 5 check failed: direct commits to '$current_branch' are not allowed."
log "Create a feature/release/hotfix branch and use --no-ff to merge it."
exit 1
