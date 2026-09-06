import argparse
from datetime import datetime
import json
import os
import socket
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
SHOTS = ('library', 'kitchen', 'grand_hall', 'offering', 'escape')


def main():
    parser = argparse.ArgumentParser(description='Exercise production gameplay trailer shots; record native 60 FPS video and audio masters after castle lighting is finalized.')
    parser.add_argument('--shot', choices=(*SHOTS, 'all'), default='all')
    parser.add_argument('--record', action='store_true', help='Record 1920x1080 video and native audio on an isolated desktop. Requires baked lighting.')
    parser.add_argument('--format', choices=('png', 'avi'), default='avi')
    parser.add_argument('--output', type=Path, default=PROJECT / '.ci' / 'trailer' / datetime.now().strftime('%Y%m%d-%H%M%S'))
    parser.add_argument('--lighting', choices=('source', 'baked'), default='source')
    parser.add_argument('--desktop', type=Path, default=Path.home() / '.codex/skills/isolated-gui/scripts/desktop.py')
    parser.add_argument('--session', default='castle-trailer')
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    if args.record and args.lighting != 'baked':
        parser.error('--record requires --lighting baked and the completed whole-castle bake')
    binary = Path(os.environ.get('GODOT_BIN', PROJECT / 'third_party/godotsteam/godotsteam.451.editor.x86_64'))
    if args.record:
        subprocess.run([sys.executable, str(args.desktop), '--session', args.session, 'start', '--size', '1920x1080', '--gpu', 'nvidia'], check=True)
    args.output.mkdir(parents=True, exist_ok=True)
    chosen = SHOTS if args.shot == 'all' else (args.shot,)
    results = []
    for shot in chosen:
        directory = args.output.resolve() / shot
        directory.mkdir(exist_ok=True)
        result_path = directory / 'result.json'
        result_path.unlink(missing_ok=True)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        environment = os.environ | {'GOMSTALLE_TRAILER_SHOT': shot, 'GOMSTALLE_TRAILER_RESULT': str(directory / 'result.json'), 'GOMSTALLE_LIGHTING_MODE': args.lighting, 'GOMSTALLE_LOCAL_PORT': str(port)}
        command = [str(binary), '--path', str(PROJECT), '--script', 'res://tests/scenarios/trailer.gd', '--fixed-fps', '60', '--resolution', '1920x1080']
        if args.record:
            command += ['--display-driver', 'x11', '--borderless', '--position', '0,0', '--write-movie', str(directory / f'frame.{args.format}'), '--disable-vsync']
            command = [sys.executable, str(args.desktop), '--session', args.session, 'run', '--cwd', str(PROJECT), '--', *command]
        else:
            command.append('--headless')
        with (directory / 'run.log').open('w') as log:
            completed = subprocess.run(command, cwd=PROJECT, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
        if not result_path.exists():
            raise RuntimeError(f'{shot} produced no result; inspect {directory / "run.log"}')
        if args.record:
            launch = json.loads((directory / 'run.log').read_text().splitlines()[0])
            (directory / 'desktop.json').write_text(json.dumps(launch, indent=2) + '\n')
            (directory / 'run.log').write_text(Path(launch['log']).read_text())
        result = json.loads(result_path.read_text())
        results.append(result)
        engine_errors = [line for line in (directory / 'run.log').read_text().splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))]
        succeeded = completed.returncode == 0 and result['passed'] and not engine_errors
        print(f'{shot}: {"PASS" if succeeded else "FAIL"}, {result["duration_frames"]} frames; {result_path}', flush=True)
        if not succeeded:
            raise RuntimeError(f'{shot} failed; inspect {directory / "run.log"}')
    (args.output / 'shots.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'Trailer evidence: {args.output.resolve()}', flush=True)


if __name__ == '__main__':
    main()
