#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "$command_name" >&2
    exit 127
  fi
}

require_command git
require_command pre-commit
require_command python3

python3 -m py_compile tests/test_pre_commit_integration.py
python3 -m unittest -v "${@:-tests.test_pre_commit_integration}"
