#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$root_dir/scripts/setup_godot_steam.sh"

preset_name="${EXPORT_PRESET:-Linux}"
build_mode="${BUILD_MODE:-debug}"
export_path="${EXPORT_PATH:-}"
steam_app_id="${STEAM_APP_ID:-}"

export_presets_path="$root_dir/export_presets.cfg"

godotsteam_dir="$root_dir/third_party/godotsteam"
godot_bin="$godotsteam_dir/godotsteam"

if [ ! -x "$godot_bin" ]; then
  echo "GodotSteam binary not found at $godot_bin"
  exit 1
fi

if [ -n "$steam_app_id" ]; then
  echo "$steam_app_id" > "$root_dir/steam_appid.txt"
  echo "$steam_app_id" > "$godotsteam_dir/steam_appid.txt"
  export SteamAppId="$steam_app_id"
  export SteamGameId="$steam_app_id"
else
  echo "steam_appid.txt is missing. Set STEAM_APP_ID to generate it."
fi

export_args=(--headless --path "$root_dir")

if [ "$build_mode" = "release" ]; then
  export_args+=(--export-release "$preset_name")
elif [ "$build_mode" = "debug" ]; then
  export_args+=(--export-debug "$preset_name")
else
  echo "Unsupported BUILD_MODE: $build_mode"
  echo "Use BUILD_MODE=debug or BUILD_MODE=release"
  exit 1
fi

resolved_export_path="$export_path"

if [ -z "$resolved_export_path" ] && [ -f "$export_presets_path" ]; then
  resolved_export_path="$(awk -v target_preset="$preset_name" -F= '
    /^\[preset\.[0-9]+\]$/ { in_preset = 1; preset_name = ""; next }
    /^\[/ { in_preset = 0 }
    in_preset && $1 == "name" { gsub(/"/, "", $2); preset_name = $2 }
    in_preset && $1 == "export_path" {
      gsub(/"/, "", $2)
      if (preset_name == target_preset) {
        print $2
        exit
      }
    }
  ' "$export_presets_path")"
fi

if [ -z "$resolved_export_path" ]; then
  echo "Export path not found for preset: $preset_name"
  echo "Set EXPORT_PATH or update export_presets.cfg"
  exit 1
fi

if [ "${resolved_export_path:0:1}" != "/" ]; then
  resolved_export_path="$root_dir/$resolved_export_path"
fi

export_directory="$(dirname "$resolved_export_path")"
mkdir -p "$export_directory"

export_args+=("$resolved_export_path")

LD_LIBRARY_PATH="$godotsteam_dir:${LD_LIBRARY_PATH:-}" "$godot_bin" "${export_args[@]}"

steam_appid_source="$root_dir/steam_appid.txt"
if [ -f "$steam_appid_source" ]; then
  cp "$steam_appid_source" "$export_directory/steam_appid.txt"
fi

steam_library_source=""
for candidate in "$godotsteam_dir/libsteam_api.so" "$godotsteam_dir/templates/libsteam_api.so"; do
  if [ -f "$candidate" ]; then
    steam_library_source="$candidate"
    break
  fi
done

if [ -n "$steam_library_source" ]; then
  cp "$steam_library_source" "$export_directory/libsteam_api.so"
else
  echo "libsteam_api.so not found in $godotsteam_dir or templates"
fi
