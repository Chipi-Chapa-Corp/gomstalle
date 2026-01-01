#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/setup_godot_steam.sh

DEFAULT_BIN="$ROOT/third_party/godotsteam/godotsteam"
GODOT_BIN="${GODOT_BIN:-$DEFAULT_BIN}"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot binary not found at $GODOT_BIN"
  echo "Set GODOT_BIN to a valid editor binary."
  exit 1
fi

git -C "$ROOT" submodule update --init --recursive

LD_LIBRARY_PATH="$ROOT/third_party/godotsteam:${LD_LIBRARY_PATH:-}" \
  "$GODOT_BIN" --headless --path "$ROOT" --import

LD_LIBRARY_PATH="$ROOT/third_party/godotsteam:${LD_LIBRARY_PATH:-}" \
  "$GODOT_BIN" --headless --path "$ROOT" \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
