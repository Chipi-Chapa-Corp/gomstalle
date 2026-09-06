import argparse
import json
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
FONT = PROJECT / 'assets/fonts/MedievalSharp-Regular.ttf'
FPS = 60
LENGTH = 40 * FPS
END_FRAMES = 200
SHOTS = ('library', 'kitchen', 'grand_hall', 'offering', 'escape')
CAPTIONS = {
    'library': 'Outrun the knight.',
    'kitchen': 'Take the shortcuts.',
    'grand_hall': '',
    'offering': 'Feed the shrines.',
    'escape': 'Make your escape.',
}
VIEWS = (
    "overview_04_the_alchemist's_still.png",
    "overview_18_the_astronomer's_tower.png",
    'overview_10_the_candle_chapel.png',
    'overview_15_the_treasury.png',
)


def execute(arguments, binary='ffmpeg'):
    subprocess.run([binary, '-hide_banner', '-loglevel', 'error', '-y', *arguments], check=True)


def typography(text, size, vertical, enable='1'):
    return f"drawtext=fontfile='{FONT}':text='{text}':fontsize={size}:fontcolor=0xf0ddad:shadowcolor=black@0.9:shadowx=3:shadowy=4:borderw=2:bordercolor=0x171714:x=(w-tw)/2:y={vertical}:enable='{enable}'"


def encode(arguments, destination):
    execute([*arguments, '-c:v', 'h264_nvenc', '-preset', 'p6', '-cq', '17', '-b:v', '0', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-c:a', 'pcm_s16le', '-ar', '48000', '-ac', '2', str(destination)])


def finish(assembled, destination, binary):
    execute(['-i', str(assembled), '-i', str(PROJECT / 'assets/sounds/castle/trailer_score.wav'), '-filter_complex', '[0:v]setpts=N/(60*TB)[v];[0:a]volume=1.2[game];[1:a]volume=0.9[score];[game][score]amix=inputs=2:normalize=0,alimiter=limit=0.89:level=0,afade=t=out:st=39.65:d=0.35[a]', '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-preset', 'fast', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-fps_mode', 'cfr', '-c:a', 'aac', '-b:a', '320k', '-t', '40', '-movflags', '+faststart', str(destination)], binary)


def main():
    parser = argparse.ArgumentParser(description='Edit verified native gameplay and castle detail renders into the original 40-second music trailer.')
    parser.add_argument('--masters', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=PROJECT / 'build/trailer/Gomstalle-Trailer.mp4')
    parser.add_argument('--finish-ffmpeg', default='ffmpeg', help='FFmpeg with a full H.264 decoder and libx264 encoder for the constant-frame-rate delivery.')
    args = parser.parse_args()
    workspace = args.masters.resolve() / 'edit'
    workspace.mkdir(exist_ok=True)
    results = {shot: json.loads((args.masters / shot / 'result.json').read_text()) for shot in SHOTS}
    if not all(result['passed'] for result in results.values()):
        raise ValueError('All gameplay shots must pass before editing')
    detail_frames = LENGTH - END_FRAMES - sum(result['duration_frames'] for result in results.values())
    if detail_frames < FPS * 4:
        raise ValueError('Gameplay exceeds the planned musical edit')
    pieces = {}
    for shot, result in results.items():
        folder = args.masters.resolve() / shot
        frames = result['duration_frames']
        duration = frames / FPS
        video_filter = 'setsar=1'
        if CAPTIONS[shot]:
            video_filter += ',' + typography(CAPTIONS[shot], 48, 'h-100', 'between(t,0.35,3.8)')
        destination = workspace / f'{shot}.mkv'
        if (folder / 'frame.avi').exists():
            inputs = ['-ss', str(result['start_frame'] / FPS), '-i', str(folder / 'frame.avi')]
        else:
            inputs = ['-framerate', str(FPS), '-start_number', str(result['start_frame']), '-i', str(folder / 'frame%08d.png'), '-ss', str(result['start_frame'] / FPS), '-i', str(folder / 'frame.wav')]
        encode([*inputs, '-vf', video_filter, '-af', f'atrim=duration={duration},asetpts=PTS-STARTPTS,afade=t=in:d=0.08,afade=t=out:st={max(0, duration - 0.12)}:d=0.12', '-frames:v', str(frames), '-t', str(duration)], destination)
        pieces[shot] = destination
    for index, view in enumerate(VIEWS):
        frames = detail_frames // len(VIEWS) + (1 if index < detail_frames % len(VIEWS) else 0)
        duration = frames / FPS
        zoom = f"scale=2304:1296:force_original_aspect_ratio=increase,crop=2304:1296,zoompan=z='1.02+on*0.00025':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d={frames}:s=1920x1080:fps={FPS},setsar=1"
        if index == 0:
            zoom += ',' + typography('18 rooms. Plenty of hiding places.', 44, 'h-100')
        destination = workspace / f'detail-{index}.mkv'
        encode(['-i', str(PROJECT / '.ci/lighting/after' / view), '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-vf', zoom, '-frames:v', str(frames), '-t', str(duration)], destination)
        pieces[f'detail-{index}'] = destination
    end_filter = ','.join([
        'drawbox=x=570:y=365:w=780:h=2:color=0x806b45:t=fill',
        typography('GOMSTALLE', 128, '440'),
        typography('A castle chase for 2–4 players', 36, '625'),
        'drawbox=x=570:y=725:w=780:h=2:color=0x806b45:t=fill',
        'fade=t=in:d=0.25',
    ])
    end = workspace / 'end.mkv'
    encode(['-f', 'lavfi', '-i', f'color=c=0x10130f:s=1920x1080:r={FPS}', '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-vf', end_filter, '-frames:v', str(END_FRAMES), '-t', str(END_FRAMES / FPS)], end)
    order = ['library', 'detail-0', 'detail-1', 'kitchen', 'grand_hall', 'detail-2', 'detail-3', 'offering', 'escape']
    sequence = [pieces[name] for name in order] + [end]
    concat = workspace / 'sequence.txt'
    concat.write_text(''.join(f"file '{path}'\n" for path in sequence))
    assembled = workspace / 'assembled.mkv'
    execute(['-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', str(assembled)])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    finish(assembled, args.output, args.finish_ffmpeg)
    evidence = {'fps': FPS, 'duration_seconds': 40, 'resolution': [1920, 1080], 'gameplay': results, 'edit_order': order + ['end'], 'detail_frames': detail_frames, 'music': 'Original score by scripts/audio/trailer_score.py'}
    args.output.with_suffix('.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(args.output.resolve())


if __name__ == '__main__':
    main()
