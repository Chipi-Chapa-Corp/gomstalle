#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USE_STEAMGODOT="${USE_STEAMGODOT:-1}"
STEAM_APP_ID="${STEAM_APP_ID:-}"
GODOT_IMPORT_DISABLE_EDITOR_PLUGINS="${GODOT_IMPORT_DISABLE_EDITOR_PLUGINS:-0}"
GODOT_IMPORT_DISABLE_AUTOLOADS="${GODOT_IMPORT_DISABLE_AUTOLOADS:-0}"
GODOT_IMPORT_BIN="${GODOT_IMPORT_BIN:-}"
GODOT_IMPORT_HEADLESS="${GODOT_IMPORT_HEADLESS:-1}"
GODOT_SKIP_IMPORT="${GODOT_SKIP_IMPORT:-0}"

if [ "$USE_STEAMGODOT" != "0" ]; then
  ./scripts/setup_godot_steam.sh
fi

git -C "$ROOT" submodule update --init --recursive

mkdir -p "$ROOT/addons"
if [ -e "$ROOT/addons/gut" ] && [ ! -L "$ROOT/addons/gut" ]; then
  rm -rf "$ROOT/addons/gut"
fi
ln -sfn ../third_party/gut/addons/gut "$ROOT/addons/gut"

DEFAULT_BIN="$ROOT/third_party/godotsteam/godotsteam"
GODOT_BIN="${GODOT_BIN:-$DEFAULT_BIN}"
JUNIT_XML_FILE="${JUNIT_XML_FILE:-}"
JUNIT_ARGS=()
RUNNER=()
IMPORT_RUNNER=()
EXTRA_ARGS=()
IMPORT_EXTRA_ARGS=()
TEST_EXTRA_ARGS=()
HEADLESS_ARGS=()
VERBOSE_ARGS=()
IMPORT_HEADLESS_ARGS=()

if [ -n "$JUNIT_XML_FILE" ]; then
  JUNIT_ARGS+=("-gjunit_xml_file=$JUNIT_XML_FILE" "-gjunit_xml_timestamp=false")
fi

if [ -n "${GODOT_RUNNER:-}" ]; then
  read -r -a RUNNER <<< "$GODOT_RUNNER"
fi

if [ -n "${GODOT_IMPORT_RUNNER:-}" ]; then
  read -r -a IMPORT_RUNNER <<< "$GODOT_IMPORT_RUNNER"
else
  IMPORT_RUNNER=("${RUNNER[@]}")
fi

if [ -n "${GODOT_EXTRA_ARGS:-}" ]; then
  read -r -a EXTRA_ARGS <<< "$GODOT_EXTRA_ARGS"
fi

if [ -n "${GODOT_IMPORT_EXTRA_ARGS:-}" ]; then
  read -r -a IMPORT_EXTRA_ARGS <<< "$GODOT_IMPORT_EXTRA_ARGS"
else
  IMPORT_EXTRA_ARGS=("${EXTRA_ARGS[@]}")
fi

if [ -n "${GODOT_TEST_EXTRA_ARGS:-}" ]; then
  read -r -a TEST_EXTRA_ARGS <<< "$GODOT_TEST_EXTRA_ARGS"
else
  TEST_EXTRA_ARGS=("${EXTRA_ARGS[@]}")
fi

if [ "${GODOT_HEADLESS:-1}" != "0" ]; then
  HEADLESS_ARGS+=("--headless")
fi

if [ "${GODOT_VERBOSE:-0}" != "0" ]; then
  VERBOSE_ARGS+=("--verbose")
fi

if [ "${GODOT_IMPORT_HEADLESS:-1}" != "0" ]; then
  IMPORT_HEADLESS_ARGS+=("--headless")
fi

if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot binary not found at $GODOT_BIN"
  echo "Set GODOT_BIN to a valid editor binary."
  exit 1
fi

if [ "$USE_STEAMGODOT" != "0" ] && [ -n "$STEAM_APP_ID" ]; then
  echo "$STEAM_APP_ID" > "$ROOT/steam_appid.txt"
  echo "$STEAM_APP_ID" > "$ROOT/third_party/godotsteam/steam_appid.txt"
  export SteamAppId="$STEAM_APP_ID"
  export SteamGameId="$STEAM_APP_ID"
fi

PROJECT_GODOT_BAK=""
prepare_project_for_import() {
  local proj="$ROOT/project.godot"
  local bak="$ROOT/project.godot.ci.bak"
  cp -f "$proj" "$bak"
  PROJECT_GODOT_BAK="$bak"

  awk -v disable_autoloads="$GODOT_IMPORT_DISABLE_AUTOLOADS" \
      -v disable_plugins="$GODOT_IMPORT_DISABLE_EDITOR_PLUGINS" '
    BEGIN { in_autoload=0; in_plugins=0 }
    /^\[autoload\]$/ { in_autoload=1; in_plugins=0; print; next }
    /^\[editor_plugins\]$/ { in_plugins=1; in_autoload=0; print; next }
    /^\[/ { in_autoload=0; in_plugins=0; print; next }
    {
      if (in_plugins==1 && disable_plugins != "0" && $0 ~ /^enabled=/) {
        print "enabled=PackedStringArray()"
        next
      }
      if (in_autoload==1 && disable_autoloads != "0") {
        next
      }
      print
    }
  ' "$bak" > "$proj"
}

restore_project_godot() {
  if [ -n "$PROJECT_GODOT_BAK" ] && [ -f "$PROJECT_GODOT_BAK" ]; then
    mv -f "$PROJECT_GODOT_BAK" "$ROOT/project.godot"
    PROJECT_GODOT_BAK=""
  fi
}

if [ "$GODOT_SKIP_IMPORT" = "0" ]; then
  if [ "$GODOT_IMPORT_DISABLE_EDITOR_PLUGINS" != "0" ] || [ "$GODOT_IMPORT_DISABLE_AUTOLOADS" != "0" ]; then
    prepare_project_for_import
    trap restore_project_godot EXIT
  fi

  IMPORT_BIN="$GODOT_BIN"
  IMPORT_LD_LIBRARY_PATH="$ROOT/third_party/godotsteam:${LD_LIBRARY_PATH:-}"
  if [ -n "$GODOT_IMPORT_BIN" ]; then
    IMPORT_BIN="$GODOT_IMPORT_BIN"
    IMPORT_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
  fi

  if [ "$USE_STEAMGODOT" != "0" ] && [ -z "$GODOT_IMPORT_BIN" ]; then
    LD_LIBRARY_PATH="$IMPORT_LD_LIBRARY_PATH" \
      "${IMPORT_RUNNER[@]}" "$IMPORT_BIN" "${IMPORT_HEADLESS_ARGS[@]}" "${VERBOSE_ARGS[@]}" --path "$ROOT" --import "${IMPORT_EXTRA_ARGS[@]}"
  else
    "${IMPORT_RUNNER[@]}" "$IMPORT_BIN" "${IMPORT_HEADLESS_ARGS[@]}" "${VERBOSE_ARGS[@]}" --path "$ROOT" --import "${IMPORT_EXTRA_ARGS[@]}"
  fi

  restore_project_godot
  trap - EXIT
else
  echo "Skipping Godot import (GODOT_SKIP_IMPORT=$GODOT_SKIP_IMPORT)"
  if [ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ]; then
    echo "Missing .godot/global_script_class_cache.cfg; GUT requires it when import is skipped."
    echo "Run Godot with --import or commit the cache file."
    exit 1
  fi
fi

if [ "$USE_STEAMGODOT" != "0" ]; then
  LD_LIBRARY_PATH="$ROOT/third_party/godotsteam:${LD_LIBRARY_PATH:-}" \
    "${RUNNER[@]}" "$GODOT_BIN" "${HEADLESS_ARGS[@]}" "${VERBOSE_ARGS[@]}" --path "$ROOT" \
    -s res://addons/gut/gut_cmdln.gd "${JUNIT_ARGS[@]}" "${TEST_EXTRA_ARGS[@]}" \
    -gdir=res://tests -ginclude_subdirs -gexit
else
  "${RUNNER[@]}" "$GODOT_BIN" "${HEADLESS_ARGS[@]}" "${VERBOSE_ARGS[@]}" --path "$ROOT" \
    -s res://addons/gut/gut_cmdln.gd "${JUNIT_ARGS[@]}" "${TEST_EXTRA_ARGS[@]}" \
    -gdir=res://tests -ginclude_subdirs -gexit
fi
