import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

PROJECT = Path(__file__).resolve().parents[2]
LIGHTING = PROJECT / "assets/lighting"
MANIFEST = LIGHTING / "manifest.json"
SESSION = "castle-lighting"


def source_hashes() -> dict[str, str]:
    paths = [path for path in (PROJECT / "assets").rglob("*") if path.is_file() and LIGHTING not in path.parents]
    paths.extend(PROJECT / name for name in [
        "scenes/world/scene.tscn", "scenes/world/castle_dressing.gd", "scenes/chair/scene.tscn",
        "scenes/chair/script.gd", "scripts/lighting/prepare.gd",
    ])
    return {str(path.relative_to(PROJECT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(paths)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare, bake and visually verify the current castle on a private GPU desktop.")
    parser.add_argument("--check", action="store_true", help="Report whether the saved bake matches the current source assets.")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    arguments = parser.parse_args()
    if arguments.check:
        if not MANIFEST.exists():
            raise SystemExit("No completed castle bake manifest exists.")
        saved = json.loads(MANIFEST.read_text())["sources"]
        current = source_hashes()
        changed = sorted(path for path in saved.keys() | current.keys() if saved.get(path) != current.get(path))
        if changed:
            print("Castle bake is stale:\n" + "\n".join(changed))
            return 1
        print("Castle bake matches the current source assets.")
        return 0
    desktop = Path(os.environ.get("ISOLATED_GUI_HELPER", Path.home() / ".codex/skills/isolated-gui/scripts/desktop.py"))
    if not desktop.is_file():
        raise SystemExit("Install the isolated-gui skill or set ISOLATED_GUI_HELPER to its desktop.py helper.")
    godot = Path(os.environ.get("GODOT_BIN", PROJECT / "third_party/godotsteam/godotsteam.451.editor.x86_64")).resolve()
    environment = os.environ.copy()
    environment.pop("GOMSTALLE_LIGHTMAP_SCENE", None)
    environment["GOMSTALLE_LIGHTING_MODE"] = "source"
    environment["LD_LIBRARY_PATH"] = os.pathsep.join(filter(None, [str(godot.parent), environment.get("LD_LIBRARY_PATH", "")]))
    subprocess.run([str(godot), "--headless", "--editor", "--path", str(PROJECT), "--import"], cwd=PROJECT, env=environment, check=True)
    environment["GOMSTALLE_LIGHTMAP_SCENE"] = "res://assets/lighting/castle.scn"
    environment["GOMSTALLE_LIGHTMAP_QUALITY"] = arguments.quality
    bake_sources = source_hashes()
    subprocess.run([str(godot), "--headless", "--path", str(PROJECT), "--script", "res://scripts/lighting/prepare.gd"], cwd=PROJECT, env=environment, check=True)
    desktop_command = [sys.executable, str(desktop), "--session", SESSION]
    subprocess.run(desktop_command + ["start", "--size", "1600x1000", "--gpu", "nvidia"], cwd=PROJECT, check=True)
    try:
        run_command = desktop_command + ["run", "--cwd", str(PROJECT), "--", str(godot), "--path", str(PROJECT), "--display-driver", "x11"]
        capture_directory = PROJECT / ".ci/lighting"
        environment["GOMSTALLE_LIGHTMAP_CAPTURE_DIR"] = str(capture_directory / "before")
        subprocess.run(run_command + ["--script", "res://scripts/lighting/capture.gd"], cwd=PROJECT, env=environment, check=True)
        subprocess.run(run_command + ["--editor"], cwd=PROJECT, env=environment, check=True)
        environment["GOMSTALLE_LIGHTMAP_CAPTURE_DIR"] = str(capture_directory / "after")
        subprocess.run(run_command + ["--script", "res://scripts/lighting/capture.gd"], cwd=PROJECT, env=environment, check=True)
        MANIFEST.write_text(json.dumps({"generated_at": datetime.now(timezone.utc).isoformat(), "quality": arguments.quality,
            "sources": bake_sources}, indent=2) + "\n")
        if source_hashes() != bake_sources:
            raise RuntimeError("Source assets changed during the bake. Run --check to inspect them, then bake again after source edits finish.")
        print(f"Castle lighting saved in {LIGHTING}; gameplay views and render timings in {capture_directory}.")
    finally:
        subprocess.run(desktop_command + ["stop"], cwd=PROJECT, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
