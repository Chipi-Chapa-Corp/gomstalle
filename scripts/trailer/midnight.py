import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[2]
TIMES = (3.0, 8.5, 13.5, 18.5, 24.0, 29.0, 34.5)
FPS = 30


def engine_run(environment: dict[str, str], extra: list[str], session: str, directory: Path) -> None:
    desktop = Path.home() / '.codex/skills/isolated-gui/scripts/desktop.py'
    binary = PROJECT / 'third_party/godotsteam/godotsteam'
    command = [sys.executable, str(desktop), '--session', session, 'run', '--cwd', str(PROJECT), '--', str(binary), '--display-driver', 'x11', '--path', str(PROJECT), '--script', 'res://scripts/trailer/midnight.gd', '--fixed-fps', str(FPS), '--disable-vsync', *extra]
    result = subprocess.run(command, env=os.environ | environment, text=True, capture_output=True, timeout=1200)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    launch = json.loads(result.stdout)
    log = Path(launch['log']).read_text()
    (directory / 'render.log').write_text(log)
    errors = [line for line in log.splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))]
    if errors:
        raise RuntimeError('\n'.join(errors))


def main() -> None:
    parser = argparse.ArgumentParser(description='Render the playable Midnight Library film and camera proofs.')
    parser.add_argument('--record', action='store_true')
    parser.add_argument('--time', type=float)
    parser.add_argument('--session', default='midnight-film')
    parser.add_argument('--output', type=Path, default=PROJECT / 'build/trailer/midnight')
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    desktop = Path.home() / '.codex/skills/isolated-gui/scripts/desktop.py'
    subprocess.run([sys.executable, str(desktop), '--session', args.session, 'start', '--size', '1920x1080', '--gpu', 'nvidia'], check=True, stdout=subprocess.DEVNULL)
    if args.record:
        master = args.output / 'master.avi'
        manifest = args.output / 'film.json'
        engine_run({'GOMSTALLE_FILM_RECORD': '1', 'GOMSTALLE_FILM_RESULT': str(manifest)}, ['--write-movie', str(master)], args.session, args.output)
        report = json.loads(manifest.read_text())
        destination = args.output / 'Gomstalle-Midnight-Library.mp4'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', str(report['start_frame'] / FPS), '-i', str(master), '-t', str(report['duration_seconds']), '-c:v', 'h264_nvenc', '-preset', 'p6', '-cq', '17', '-b:v', '0', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', str(destination)], check=True)
        print(destination)
    else:
        for time in TIMES if args.time is None else (args.time,):
            directory = args.output / f'shot-{time:04.1f}'
            directory.mkdir(exist_ok=True)
            target = directory / 'frame.png'
            engine_run({'GOMSTALLE_FILM_TIME': str(time), 'GOMSTALLE_FILM_CAPTURE': str(target)}, [], args.session, directory)
            print(target, flush=True)


if __name__ == '__main__':
    main()
