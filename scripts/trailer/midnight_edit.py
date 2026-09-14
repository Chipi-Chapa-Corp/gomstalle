import argparse
from dataclasses import dataclass
import json
from pathlib import Path

from edit import encode, execute, typography


PROJECT = Path(__file__).resolve().parents[2]
FPS = 60
SHOTS = ('distraction', 'parkour', 'escape')


@dataclass(frozen=True)
class Clip:
    name: str
    source: Path
    start: float
    source_frames: int
    gameplay: bool = False
    caption: str = ''
    rate: float = 1.0

    @property
    def frames(self) -> int:
        return round(self.source_frames / self.rate)

    @property
    def duration(self) -> float:
        return self.frames / FPS


def main() -> None:
    parser = argparse.ArgumentParser(description='Edit verified cooperative gameplay with the Midnight Library cinematics and original score.')
    parser.add_argument('--masters', type=Path, required=True)
    parser.add_argument('--film', type=Path, default=PROJECT / 'build/trailer/midnight')
    parser.add_argument('--output', type=Path, default=PROJECT / 'build/trailer/Gomstalle-Midnight-Escape.mp4')
    parser.add_argument('--finish-ffmpeg', default='ffmpeg', help='FFmpeg with a full H.264 decoder and libx264 encoder for constant-frame-rate delivery.')
    parser.add_argument('--no-voice', action='store_true')
    args = parser.parse_args()
    reports = {name: json.loads((args.masters / name / 'result.json').read_text()) for name in SHOTS}
    if not all(report['passed'] for report in reports.values()):
        raise ValueError('Every cooperative gameplay sequence must pass before editing')
    film_report = json.loads((args.film / 'film.json').read_text())
    film_start = film_report['start_frame'] / 30
    film_source = (args.film / 'master.avi').resolve()

    def cinematic(name: str, start: float, duration: float) -> Clip:
        return Clip(name, film_source, film_start + start, round(duration * FPS))

    def event_frame(shot: str, event_name: str) -> int:
        return next(event['shot_frame'] for event in reports[shot]['events'] if event['name'] == event_name)

    def gameplay(name: str, shot: str, first: int, last: int, caption: str = '', rate: float = 1.0) -> Clip:
        report = reports[shot]
        if not 0 <= first < last <= report['duration_frames']:
            raise ValueError(f'{name} edit range lies outside the verified gameplay recording')
        return Clip(name, (args.masters / shot / 'frame.avi').resolve(), (report['start_frame'] + first) / FPS, last - first, True, caption, rate)

    throw_frame = event_frame('distraction', 'chair_thrown')
    contact_frame = event_frame('distraction', 'knight_stunned')
    reveal_frame = event_frame('escape', 'portal_reveal_start')
    visible_frame = event_frame('escape', 'portal_visible')
    escapes = [event['shot_frame'] for event in reports['escape']['events'] if event['name'].startswith('skeleton_escaped_')]
    if len(escapes) < 2:
        raise ValueError('The escape edit requires two recorded authoritative escapes')
    sequence = [
        cinematic('library', 0.6, 3.2),
        cinematic('curiosity', 6.4, 2.0),
        cinematic('keeper', 11.8, 2.0),
        gameplay('distraction_plan', 'distraction', 0, throw_frame - 6, 'Keep the knight busy.'),
        gameplay('chair_impact', 'distraction', throw_frame - 6, contact_frame + 12, 'Keep the knight busy.', 0.65),
        gameplay('distraction_payoff', 'distraction', contact_frame + 12, reports['distraction']['duration_frames']),
        gameplay('parkour', 'parkour', 0, reports['parkour']['duration_frames'], 'Take the shortcut.'),
        gameplay('shared_shrine', 'escape', 0, reveal_frame, 'Share the work.'),
        cinematic('awakening', 22.0, 3.0),
        gameplay('portal_reveal', 'escape', max(reveal_frame, visible_frame - 15), visible_frame + 126),
        gameplay('escape_first', 'escape', min(escapes) - 90, min(escapes) + 12, 'Get everyone through.'),
        gameplay('escape_last', 'escape', max(escapes) - 90, min(reports['escape']['duration_frames'], max(escapes) + 24), 'Get everyone through.'),
        cinematic('title', 32.4, 5.6),
    ]
    workspace = args.masters.resolve() / 'edit'
    workspace.mkdir(exist_ok=True)
    timeline = []
    destinations = []
    cursor = 0.0
    for clip in sequence:
        destination = workspace / f'{clip.name}.mkv'
        filters = [f'setpts=(PTS-STARTPTS)/{clip.rate}', 'setsar=1', 'fps=60', 'drawbox=x=0:y=0:w=iw:h=138:color=black:t=fill', 'drawbox=x=0:y=ih-138:w=iw:h=138:color=black:t=fill']
        if clip.caption:
            filters.append(typography(clip.caption, 37, 'h-86'))
        audio = f'atrim=duration={clip.source_frames / FPS},asetpts=PTS-STARTPTS,atempo={clip.rate},afade=t=in:d=0.035,afade=t=out:st={clip.duration - 0.07}:d=0.07'
        if not clip.gameplay:
            audio += ',volume=0'
        encode(['-ss', str(clip.start), '-i', str(clip.source), '-vf', ','.join(filters), '-af', audio, '-frames:v', str(clip.frames), '-t', str(clip.duration)], destination)
        timeline.append({'name': clip.name, 'start': cursor, 'duration': clip.duration, 'gameplay': clip.gameplay, 'rate': clip.rate, 'source_start': clip.start, 'source_frames': clip.source_frames})
        destinations.append(destination)
        cursor += clip.duration
    concat = workspace / 'sequence.txt'
    concat.write_text(''.join(f"file '{destination}'\n" for destination in destinations))
    assembled = workspace / 'assembled.mkv'
    execute(['-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', str(assembled)], args.finish_ffmpeg)
    starts = {entry['name']: entry['start'] for entry in timeline}
    plan_time = starts['distraction_plan'] + 0.1
    escape_time = starts['escape_first']
    score_duration = min((38, 60), key=lambda duration: abs(duration - cursor))
    score = PROJECT / 'assets/sounds/midnight' / ('midnight.wav' if score_duration == 38 else 'midnight_60.wav')
    inputs = ['-i', str(assembled), '-i', str(score)]
    mix = ['[0:a]volume=1.05[game]', f'[1:a]atempo={score_duration / cursor},atrim=duration={cursor},volume=0.86[score]']
    channels = '[game][score]'
    if not args.no_voice:
        inputs += ['-i', str(PROJECT / 'assets/sounds/midnight/voice_plan.mp3'), '-i', str(PROJECT / 'assets/sounds/midnight/voice_escape.mp3')]
        duck = f"if(between(t,{plan_time - 0.1},{plan_time + 3.5})+between(t,{escape_time - 0.2},{escape_time + 2.6}),0.44,1)"
        mix[1] += f";[score]volume='{duck}':eval=frame[ducked]"
        mix += [f'[2:a]loudnorm=I=-18:TP=-3:LRA=7,adelay={round(plan_time * 1000)}:all=1[plan]', f'[3:a]loudnorm=I=-18:TP=-3:LRA=7,adelay={round(escape_time * 1000)}:all=1[escape]']
        channels = '[game][ducked][plan][escape]'
    mix.append(f'{channels}amix=inputs={2 if args.no_voice else 4}:duration=longest:normalize=0,alimiter=limit=0.84:level=0:latency=1,afade=t=out:st={cursor - 0.45}:d=0.45[a]')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    execute([*inputs, '-filter_complex', ';'.join(mix), '-map', '0:v', '-map', '[a]', '-vf', 'setpts=N/(60*TB)', '-c:v', 'libx264', '-preset', 'fast', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-fps_mode', 'cfr', '-c:a', 'aac', '-b:a', '320k', '-ar', '48000', '-t', str(cursor), '-movflags', '+faststart', str(args.output)], args.finish_ffmpeg)
    evidence = {'duration_seconds': cursor, 'fps': FPS, 'resolution': [1920, 1080], 'timeline': timeline, 'voice': not args.no_voice, 'voice_times': [plan_time, escape_time], 'gameplay_reports': {name: str((args.masters / name / 'result.json').resolve()) for name in reports}, 'cinematics': str((args.film / 'film.json').resolve()), 'music': str(score.relative_to(PROJECT))}
    args.output.with_suffix('.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(args.output.resolve())


if __name__ == '__main__':
    main()
