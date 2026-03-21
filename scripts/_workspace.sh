#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
workspace_root="${SHARED_WORKSPACE_ROOT:-$(dirname "$repo_root")}"

workspace_repos=(
  nix-config
  nix-lib
  nix-secrets
  nix-keys
)

for_each_repo() {
  local repo
  for repo in "${workspace_repos[@]}"; do
    local target="$workspace_root/$repo"
    "$@" "$repo" "$target"
  done
}
