#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  local cmd="$1"
  if ! need_cmd "$cmd"; then
    echo "$cmd is required"
    exit 1
  fi
}

require_cmd curl
require_cmd tar

STEAMGODOT_VERSION="${STEAMGODOT_VERSION:-v4.17}"
STEAMGODOT_URL="https://codeberg.org/godotsteam/godotsteam/releases/download/${STEAMGODOT_VERSION}/linux64-g451-s163-gs417.tar.xz"
STEAMGODOT_SHA256="73ef614d27bc77cdc5a96c1034bafb41f45a025af8b19e5597dc19a7a56881ea"
STEAMGODOT_TEMPLATES_URL="https://codeberg.org/godotsteam/godotsteam/releases/download/${STEAMGODOT_VERSION}/godotsteam-g451-s163-gs417-templates.tar.xz"
STEAMGODOT_TEMPLATES_SHA256="3f2f4e4093e5500a4027d66b4ba8fb2baac83ec703b0daefded8c427e7973e94"
STEAMGODOT_DIR="$ROOT/third_party/godotsteam"
STEAMGODOT_BIN_NAME="godotsteam.451.editor.x86_64"
STEAMGODOT_BIN="$STEAMGODOT_DIR/$STEAMGODOT_BIN_NAME"
STEAMGODOT_TEMPLATES_DIR="$STEAMGODOT_DIR/templates"
STEAMGODOT_STAMP="$STEAMGODOT_DIR/.steamgodot_version"
STEAMGODOT_TEMPLATES_STAMP="$STEAMGODOT_TEMPLATES_DIR/.steamgodot_templates_version"

download_and_verify() {
  local url="$1"
  local expected_sha="$2"
  local output="$3"
  curl -L -o "$output" "$url"
  echo "${expected_sha}  ${output}" | sha256sum -c -
}

if [ ! -x "$STEAMGODOT_BIN" ] || [ "$(cat "$STEAMGODOT_STAMP" 2>/dev/null)" != "${STEAMGODOT_VERSION}:${STEAMGODOT_SHA256}" ]; then
  mkdir -p "$STEAMGODOT_DIR"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  download_and_verify "$STEAMGODOT_URL" "$STEAMGODOT_SHA256" "$tmpdir/steamgodot.tar.xz"
  tar -xf "$tmpdir/steamgodot.tar.xz" -C "$STEAMGODOT_DIR"
  chmod +x "$STEAMGODOT_BIN"
  ln -sf "$STEAMGODOT_BIN" "$STEAMGODOT_DIR/godotsteam"
  echo "${STEAMGODOT_VERSION}:${STEAMGODOT_SHA256}" > "$STEAMGODOT_STAMP"
fi

if [ ! -f "$STEAMGODOT_TEMPLATES_DIR/godotsteam.451.template.x86_64" ] || \
  [ ! -f "$STEAMGODOT_TEMPLATES_DIR/godotsteam.451.debug.template.x86_64" ] || \
  [ "$(cat "$STEAMGODOT_TEMPLATES_STAMP" 2>/dev/null)" != "${STEAMGODOT_VERSION}:${STEAMGODOT_TEMPLATES_SHA256}" ]; then
  mkdir -p "$STEAMGODOT_TEMPLATES_DIR"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  download_and_verify "$STEAMGODOT_TEMPLATES_URL" "$STEAMGODOT_TEMPLATES_SHA256" "$tmpdir/templates.tar.xz"
  tar -xf "$tmpdir/templates.tar.xz" -C "$STEAMGODOT_TEMPLATES_DIR"
  echo "${STEAMGODOT_VERSION}:${STEAMGODOT_TEMPLATES_SHA256}" > "$STEAMGODOT_TEMPLATES_STAMP"
fi

if [ ! -f "$ROOT/steam_appid.txt" ]; then
  echo "warning: steam_appid.txt not found in project root"
fi

echo "SteamGodot installed at: $STEAMGODOT_BIN"
echo "Run with: LD_LIBRARY_PATH=\"$STEAMGODOT_DIR:\${LD_LIBRARY_PATH:-}\" $STEAMGODOT_DIR/godotsteam --path ."
