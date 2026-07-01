#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USE_STEAMGODOT="${USE_STEAMGODOT:-1}"
SCENARIO_SECONDS="${GOMSTALLE_E2E_SECONDS:-16}"
CAPTURE_FPS="${GOMSTALLE_E2E_FPS:-12}"
ATTEMPTS="${GOMSTALLE_E2E_ATTEMPTS:-3}"
OUTPUT_DIR="${GOMSTALLE_E2E_DIR:-$ROOT/.ci/e2e}"
HOST_DIR="$OUTPUT_DIR/host"
CLIENT_DIR="$OUTPUT_DIR/client"
HOST_RESULT="$OUTPUT_DIR/host_result.json"
READY_MARKER="$OUTPUT_DIR/host_ready"

if [ "$USE_STEAMGODOT" != "0" ]; then
  ./scripts/setup_godot_steam.sh
fi
git -C "$ROOT" submodule update --init --recursive >/dev/null 2>&1 || true
mkdir -p "$ROOT/addons"
ln -sfn ../third_party/gut/addons/gut "$ROOT/addons/gut"

GODOT_BIN="${GODOT_BIN:-$ROOT/third_party/godotsteam/godotsteam}"
RUNNER=()
if [ -n "${GODOT_RUNNER:-}" ]; then
  read -r -a RUNNER <<< "$GODOT_RUNNER"
fi
export LD_LIBRARY_PATH="$ROOT/third_party/godotsteam:${LD_LIBRARY_PATH:-}"

"${RUNNER[@]}" "$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

launch() {
  local capture_dir="$1"; local label="$2"; shift 2
  GOMSTALLE_CAPTURE_DIR="$capture_dir" "${RUNNER[@]}" "$GODOT_BIN" --path "$ROOT" \
    --dev --capture --label "$label" "$@" >"$OUTPUT_DIR/${label}.log" 2>&1 &
  echo $!
}

wait_for_file() {
  local path="$1"; local timeout_seconds="$2"; local waited=0
  while [ ! -s "$path" ] && [ "$waited" -lt "$timeout_seconds" ]; do
    sleep 1
    waited=$((waited + 1))
  done
  [ -s "$path" ]
}

run_attempt() {
  rm -rf "$OUTPUT_DIR" 2>/dev/null || true
  mkdir -p "$HOST_DIR" "$CLIENT_DIR"
  local port=$(( (RANDOM % 10000) + 20000 ))
  export GOMSTALLE_LOCAL_PORT="$port"
  echo "attempt on port $port"

  local host_pid
  host_pid="$(GOMSTALLE_E2E_RESULT="$HOST_RESULT" GOMSTALLE_E2E_READY="$READY_MARKER" \
    launch "$HOST_DIR" HOST --host --e2e)"

  if ! wait_for_file "$READY_MARKER" 20; then
    echo "host failed to start hosting (port $port busy or crash)"
    kill "$host_pid" >/dev/null 2>&1 || true
    wait "$host_pid" 2>/dev/null || true
    return 1
  fi

  local client_pid
  client_pid="$(launch "$CLIENT_DIR" CLIENT +connect_lobby 1)"

  sleep "$SCENARIO_SECONDS"
  kill "$host_pid" "$client_pid" >/dev/null 2>&1 || true
  wait "$host_pid" "$client_pid" 2>/dev/null || true
  pkill -9 -f "$GODOT_BIN" >/dev/null 2>&1 || true

  if [ ! -s "$HOST_RESULT" ]; then
    echo "host produced no e2e result"
    return 1
  fi
  return 0
}

pkill -9 -f "$GODOT_BIN" >/dev/null 2>&1 || true
sleep 1

ok=0
for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "=== e2e attempt $attempt/$ATTEMPTS ==="
  if run_attempt; then ok=1; break; fi
  echo "--- HOST.log tail ---"; tail -n 15 "$OUTPUT_DIR/HOST.log" 2>/dev/null || true
  pkill -9 -f "$GODOT_BIN" >/dev/null 2>&1 || true
  sleep 2
done

if [ "$ok" -ne 1 ]; then
  echo "FAIL: end-to-end multiplayer test did not pass in $ATTEMPTS attempts"
  exit 1
fi

frames=$(ls "$HOST_DIR"/frame_*.png 2>/dev/null | wc -l)
client_frames=$(ls "$CLIENT_DIR"/frame_*.png 2>/dev/null | wc -l)
echo "captured host=$frames client=$client_frames frames"
echo "host result: $(cat "$HOST_RESULT")"
python3 - "$HOST_RESULT" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
assert result["player_count"] >= 2, "host did not see two players: %s" % result
assert result["game_started"], "host never started the match: %s" % result
assert result["door_opened"], "host door interaction did not open the door: %s" % result
print("E2E assertions passed:", result)
PY

count=$(( frames < client_frames ? frames : client_frames ))
if [ "$count" -lt 1 ]; then
  echo "FAIL: no frames captured"
  exit 1
fi

for i in $(seq 0 $((count - 1))); do
  idx=$(printf "%06d" "$i")
  ffmpeg -y -i "$HOST_DIR/frame_$idx.png" -i "$CLIENT_DIR/frame_$idx.png" \
    -filter_complex "hstack=inputs=2" "$OUTPUT_DIR/pair_$idx.png" >/dev/null 2>&1 || true
done

ENCODER="libx264"
if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q ' libx264 '; then
  ENCODER="mpeg4"
fi
ffmpeg -y -framerate "$CAPTURE_FPS" -i "$OUTPUT_DIR/pair_%06d.png" \
  -c:v "$ENCODER" -pix_fmt yuv420p "$OUTPUT_DIR/gomstalle-e2e.mp4" >/dev/null 2>&1
echo "wrote $OUTPUT_DIR/gomstalle-e2e.mp4 (host | client)"
