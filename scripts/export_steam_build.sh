#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build/linux}"
BUILD_BIN="${BUILD_BIN:-$BUILD_DIR/gomstalle.x86_64}"

STEAMGODOT_DIR="$ROOT/third_party/godotsteam"
STEAMGODOT_BIN="$STEAMGODOT_DIR/godotsteam"

if [ ! -x "$STEAMGODOT_BIN" ]; then
  echo "SteamGodot binary not found at $STEAMGODOT_BIN"
  exit 1
fi

mkdir -p "$BUILD_DIR"

LD_LIBRARY_PATH="$STEAMGODOT_DIR:${LD_LIBRARY_PATH:-}" \
  "$STEAMGODOT_BIN" --headless --path "$ROOT" --export-debug "Linux" "$BUILD_BIN"

if [ -f "$ROOT/steam_appid.txt" ]; then
  cp -f "$ROOT/steam_appid.txt" "$BUILD_DIR/steam_appid.txt"
fi

if [ -f "$STEAMGODOT_DIR/libsteam_api.so" ]; then
  cp -f "$STEAMGODOT_DIR/libsteam_api.so" "$BUILD_DIR/libsteam_api.so"
fi

echo "Exported build to $BUILD_BIN"
