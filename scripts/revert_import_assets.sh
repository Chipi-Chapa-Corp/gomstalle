#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git restore --source=HEAD --staged --worktree \
  "**/*.gltf.import" \
  "**/*.res" \
  "**/*.mesh"
