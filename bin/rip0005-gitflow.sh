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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${PRE_COMMIT_FROM_REF:-}" && -n "${PRE_COMMIT_TO_REF:-}" ]]; then
  "$script_dir/rip0005-branch-rebased.sh"
  "$script_dir/rip0005-protected-branch-merge-only.sh"
  "$script_dir/rip0005-protected-branch-no-overlap.sh"
  exit 0
fi

"$script_dir/rip0005-merge-rebased.sh"
"$script_dir/rip0005-protected-branch-commit.sh"
