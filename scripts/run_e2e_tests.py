import json
import os
import re
from pathlib import Path
import shlex
import signal
import socket
import subprocess
import tempfile
import time


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def available_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)


def wait_for_file(path: Path, process: subprocess.Popen, deadline: float) -> None:
    while not path.exists():
        if process.poll() is not None:
            raise RuntimeError(f"Game exited before writing {path.name}: {process.returncode}")
        if time.monotonic() >= deadline:
            raise TimeoutError(f"Timed out waiting for {path.name}")
        time.sleep(0.1)


def make_video(directory: Path, frame_rate: int) -> None:
    host_frames = sorted((directory / "host").glob("frame_*.jpg"))
    client_frames = sorted((directory / "client").glob("frame_*.jpg"))
    frame_count = min(len(host_frames), len(client_frames))
    if frame_count == 0:
        raise RuntimeError("The graphical scenario produced no captured frames")
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    for role in ["host", "client"]:
        command.extend(["-framerate", str(frame_rate), "-i", str(directory / role / "frame_%06d.jpg")])
    command.extend([
        "-filter_complex", "hstack=inputs=2", "-frames:v", str(frame_count),
        "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p",
        str(directory / "gomstalle-e2e.mp4"),
    ])
    subprocess.run(command, check=True, timeout=120)


def main() -> None:
    output_root = Path(os.environ.get("GOMSTALLE_E2E_DIR", PROJECT_ROOT / ".ci/e2e"))
    output_root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="run-", dir=output_root))
    binary = Path(os.environ.get("GODOT_BIN", PROJECT_ROOT / "third_party/godotsteam/godotsteam"))
    capture = os.environ.get("GOMSTALLE_E2E_CAPTURE", "1") == "1"
    frame_rate = 12
    timeout = float(os.environ.get("GOMSTALLE_E2E_TIMEOUT", "150"))
    environment = os.environ.copy()
    environment.setdefault("GOMSTALLE_LOCAL_PORT", str(available_port()))
    environment["LD_LIBRARY_PATH"] = str(binary.parent) + os.pathsep + environment.get("LD_LIBRARY_PATH", "")
    command = shlex.split(environment.get("GODOT_RUNNER", "")) + [str(binary), "--path", str(PROJECT_ROOT)]
    command.extend(shlex.split(environment.get("GODOT_EXTRA_ARGS", "")))
    command.extend(["--script", "res://tests/scenarios/network_round.gd"])
    command.append("--capture" if capture else "--headless")
    processes: list[subprocess.Popen] = []
    logs = []
    try:
        deadline = time.monotonic() + timeout
        for role in ["HOST", "CLIENT"]:
            capture_dir = directory / role.lower()
            capture_dir.mkdir()
            role_environment = environment | {
                "GOMSTALLE_CAPTURE_DIR": str(capture_dir),
                "GOMSTALLE_E2E_ROLE": role,
                "GOMSTALLE_E2E_RESULT": str(directory / f"{role.lower()}_result.json"),
                "GOMSTALLE_E2E_READY": str(directory / "host_ready"),
            }
            log = (directory / f"{role}.log").open("w")
            logs.append(log)
            process = subprocess.Popen(command + ["--label", role], cwd=PROJECT_ROOT, env=role_environment,
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            processes.append(process)
            if role == "HOST":
                wait_for_file(directory / "host_ready", process, deadline)
        for role, process in zip(["host", "client"], processes):
            result_path = directory / f"{role}_result.json"
            wait_for_file(result_path, process, deadline)
            result = json.loads(result_path.read_text())
            if not result["passed"]:
                raise RuntimeError(f"{role} scenario failed: {result}")
            print(f"{role}: {json.dumps(result)}", flush=True)
        for role, process in zip(["HOST", "CLIENT"], processes):
            process.wait(timeout=max(1, deadline - time.monotonic()))
            if process.returncode != 0:
                raise RuntimeError(f"{role} exited with code {process.returncode}")
            errors = [line for line in (directory / f"{role}.log").read_text().splitlines()
                      if re.match(r"^(?:SCRIPT ERROR|ERROR):", line)]
            if errors:
                raise RuntimeError(f"{role} produced runtime errors: {errors}")
    finally:
        for process in reversed(processes):
            stop_process(process)
        for log in logs:
            log.close()
        print(f"Evidence: {directory}", flush=True)
    if capture:
        make_video(directory, frame_rate)
        print(f"Video: {directory / 'gomstalle-e2e.mp4'}", flush=True)


if __name__ == "__main__":
    main()
