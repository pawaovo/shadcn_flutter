#!/usr/bin/env python3
"""Bounded real-Orca capability probe for a disposable CI X11/D-Bus session.

This native GTK fixture does not certify the Flutter application. Exit 0 means
the four machine-observable fixture layers were observed; 2 means a capability
was missing. Application acceptance and human review always remain unaccepted.
"""

from __future__ import annotations

import argparse
import array
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import wave

from run_catalog_input_acceptance import start_owned_process, stop_owned_process
from owned_pty_capture import OwnedPtyCapture


TITLE = "Real Orca capability fixture"
ALPHA = "Orca capability alpha"
BETA = "Orca capability beta"
LAYERS = (
    "native_accessibility", "at_navigation", "utterance_output",
    "synthesized_audio", "human_review",
)


def fixture(events: Path) -> None:
    import gi

    gi.require_version("Gtk", "3.0")
    from gi.repository import GLib, Gtk

    def emit(value: str) -> None:
        with events.open("a", encoding="utf-8") as stream:
            stream.write(value + "\n")

    window = Gtk.Window(title=TITLE)
    window.set_default_size(480, 200)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
    box.set_border_width(24)
    window.add(box)
    alpha = Gtk.Button(label=ALPHA)
    beta = Gtk.CheckButton(label=BETA)
    for name, control in (("alpha", alpha), ("beta", beta)):
        box.pack_start(control, False, False, 0)
        control.connect("focus-in-event", lambda _w, _e, n=name: emit("focus=" + n))
    alpha.connect("clicked", lambda _w: emit("clicked=alpha"))
    beta.connect("toggled", lambda w: emit("checked=" + str(w.get_active()).lower()))
    window.connect("destroy", Gtk.main_quit)
    window.show_all()
    alpha.grab_focus()
    window.present()
    GLib.timeout_add_seconds(55, lambda: (Gtk.main_quit(), False)[1])
    emit("ready")
    Gtk.main()


def inspect_fixture() -> None:
    """Run out of process so a hung AT-SPI call has a hard subprocess timeout."""
    import pyatspi

    pending = [pyatspi.Registry.getDesktop(0)]
    nodes = []
    for _ in range(256):
        if not pending:
            break
        node = pending.pop(0)
        try:
            name = node.name
            if name in (TITLE, ALPHA, BETA):
                states = node.getState()
                nodes.append({
                    "name": name, "role": node.getRoleName(),
                    "focused": states.contains(pyatspi.STATE_FOCUSED),
                    "checked": states.contains(pyatspi.STATE_CHECKED),
                })
            pending.extend(node[i] for i in range(min(node.childCount, 64)))
        except Exception:
            continue
    print(json.dumps(nodes))


class Probe:
    def __init__(self, output: Path, seconds: int, allow_local: bool = False):
        self.output = output.resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        self.started = time.monotonic()
        self.deadline = self.started + seconds
        self.children: list[subprocess.Popen] = []
        self.handles = []
        self.orca_capture = None
        self.runtime = tempfile.TemporaryDirectory(prefix="orca-probe-")
        self.temp = Path(self.runtime.name)
        self.env = os.environ.copy()
        self.allow_local = allow_local
        self.report = {
            "schema_version": 1, "platform": "linux", "scope": "native_fixture_capability",
            "status": "not_accepted", "application_acceptance": "not_accepted",
            "explanation": "A GTK fixture cannot accept the Flutter catalog or replace human review.",
            "runtime": {"platform": platform.platform(), "python": sys.version,
                        "runner_image": os.environ.get("ImageVersion"),
                        "display": os.environ.get("DISPLAY")},
            "layers": {name: {"status": "not_accepted", "reason": "Not observed"} for name in LAYERS},
            "evidence": {}, "errors": [],
        }

    def remaining(self, maximum: float = 5) -> float:
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Probe deadline exceeded")
        return min(maximum, remaining)

    def run(self, argv: list[str], *, check: bool = True, timeout: float = 5):
        return subprocess.run(argv, env=self.env, text=True, capture_output=True,
                              check=check, timeout=self.remaining(timeout))

    def spawn(self, argv: list[str], name: str, *, stdout=None):
        log = (self.output / (name + ".log")).open("wb")
        self.handles.append(log)
        if name == "orca":
            debug_files = [arg.split("=", 1)[1] for arg in argv if arg.startswith("--debug-file=")]
            if len(debug_files) != 1 or stdout is not None:
                raise RuntimeError("The probe requires exactly one owned Orca debug destination")
            debug_path = Path(debug_files[0]).resolve()
            captured_log = str(debug_path.relative_to(self.output))
            # Orca opens its debug file independently; PYTHONUNBUFFERED cannot
            # flush that file. A PTY selects line buffering for /dev/stdout.
            command = ["--debug-file=/dev/stdout" if arg.startswith("--debug-file=") else arg for arg in argv]
            self.orca_capture = OwnedPtyCapture(command, debug_path, env=self.env, stderr=log)
            child = self.orca_capture.process
            self.children.append(child)
            self.report["evidence"]["orca_debug_transport"] = {
                "kind": "owned_raw_pty", "producer_debug_file": "/dev/stdout",
                "captured_log": captured_log,
                "content_policy": "Original diagnostic bytes; no injected utterances or handler records",
            }
            return child
        child = start_owned_process(argv, env=self.env, stdin=subprocess.DEVNULL,
                                    stdout=stdout if stdout is not None else log,
                                    stderr=log)
        self.children.append(child)
        return child

    def wait_for(self, predicate, seconds: float = 5) -> None:
        until = time.monotonic() + self.remaining(seconds)
        while time.monotonic() < until:
            if predicate():
                return
            time.sleep(0.15)
        raise TimeoutError("Timed out waiting for a capability response")

    def observed(self, layer: str, **evidence) -> None:
        self.report["layers"][layer] = {"status": "observed", **evidence}

    def stop(self, child) -> None:
        # An exited leader can leave a live speech/backend descendant behind.
        if self.orca_capture is not None and child is self.orca_capture.process:
            self.orca_capture.close(grace=1, kill_timeout=1)
            return
        stop_owned_process(child, grace=1, kill_timeout=1)

    def execute(self) -> None:
        if self.env.get("GITHUB_ACTIONS") != "true" and not self.allow_local:
            raise RuntimeError("CI-only probe: GITHUB_ACTIONS=true or explicit --allow-local is required")
        if not self.env.get("DISPLAY") or not self.env.get("DBUS_SESSION_BUS_ADDRESS"):
            raise RuntimeError("Run inside dbus-run-session and xvfb-run; DISPLAY and session bus are required")
        required = ("orca", "speech-dispatcher", "espeak-ng", "pulseaudio", "pactl", "parec", "xdotool")
        missing = [name for name in required if not shutil.which(name)]
        if missing:
            raise RuntimeError("Missing executables: " + ", ".join(missing))
        self.run([sys.executable, "-c", "import gi, pyatspi, speechd; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk"])
        for command in ("orca", "speech-dispatcher", "pulseaudio", "espeak-ng"):
            result = self.run([command, "--version"], check=False, timeout=3)
            self.report["runtime"][command] = (result.stdout + result.stderr).strip()[:1000]

        # Keep audio/configuration private even if a caller has a desktop audio server.
        self.env.update({
            "PULSE_SERVER": "unix:" + str(self.temp / "pulse.sock"),
            "PULSE_RUNTIME_PATH": str(self.temp / "pulse-runtime"),
            "PULSE_STATE_PATH": str(self.temp / "pulse-state"),
            "PULSE_SINK": "at_probe", "SPEECHD_ADDRESS": "unix_socket:" + str(self.temp / "speechd.sock"),
            "GTK_MODULES": "gail:atk-bridge", "NO_AT_BRIDGE": "0", "GDK_BACKEND": "x11",
            "LC_ALL": "C.UTF-8",
        })
        for name in ("pulse-runtime", "pulse-state", "speechd-config", "speechd-logs", "orca-prefs"):
            (self.temp / name).mkdir(mode=0o700)
        pulse = self.spawn([
            "pulseaudio", "-n", "--daemonize=no", "--use-pid-file=no", "--exit-idle-time=-1",
            "--log-level=info", "--log-target=stderr",
            "--load=module-native-protocol-unix socket=" + str(self.temp / "pulse.sock") + " auth-anonymous=1",
            "--load=module-null-sink sink_name=at_probe rate=16000 channels=1",
        ], "pulseaudio")
        self.wait_for(lambda: self.run(["pactl", "info"], check=False, timeout=1).returncode == 0)
        if pulse.poll() is not None:
            raise RuntimeError("Private PulseAudio exited")
        self.report["evidence"]["audio_endpoints"] = self.run(["pactl", "list", "short", "sources"]).stdout
        config = self.temp / "speechd-config"
        (self.output / "speechd-logs").mkdir(exist_ok=True)
        module_config = Path("/etc/speech-dispatcher/modules/espeak-ng.conf")
        if not module_config.is_file():
            raise RuntimeError("Missing real espeak-ng Speech Dispatcher module configuration")
        (config / "speechd.conf").write_text(
            'LogLevel 4\nDefaultModule espeak-ng\nAudioOutputMethod "pulse"\n'
            f'AddModule "espeak-ng" "sd_espeak-ng" "{module_config}"\n', encoding="utf-8")
        speechd = self.spawn([
            "speech-dispatcher", "--run-single", "--config-dir", str(config),
            "--socket-path", str(self.temp / "speechd.sock"),
            "--pid-file", str(self.temp / "speechd.pid"),
            "--log-dir", str(self.output / "speechd-logs"),
        ], "speech-dispatcher")
        self.wait_for(lambda: (self.temp / "speechd.sock").exists())
        backend = self.run([sys.executable, "-c",
            "import speechd,json; c=speechd.SSIPClient('capability-inspection'); "
            "print(json.dumps({'module':c.get_output_module(),'modules':c.list_output_modules(),"
            "'voices':c.list_synthesis_voices()})); c.close()"])
        self.report["evidence"]["speech_backend"] = json.loads(backend.stdout)
        if self.report["evidence"]["speech_backend"]["module"] != "espeak-ng":
            raise RuntimeError("Speech Dispatcher did not select the real espeak-ng backend")
        prefs = {"general": {"firstStart": False, "startingProfile": ["Default", "default"],
                             "enableSpeech": True, "enableBraille": False, "keyboardLayout": 0,
                             "speechServerFactory": "speechdispatcherfactory",
                             "speechServerInfo": ["Default Synthesizer", "default"]},
                 "profiles": {"default": {"profile": ["Default", "default"]}},
                 "pronunciations": {}, "keybindings": {}}
        (self.temp / "orca-prefs" / "user-settings.conf").write_text(json.dumps(prefs), encoding="utf-8")
        debug = self.output / "orca-debug.log"
        orca = self.spawn(["orca", "--enable=speech", "--disable=braille",
                           "--user-prefs-dir=" + str(self.temp / "orca-prefs"),
                           "--debug-file=" + str(debug)], "orca")
        self.wait_for(lambda: debug.exists() and "SPEECH: Using speech server factory:" in debug.read_text(errors="replace"), 8)
        if orca.poll() is not None or speechd.poll() is not None:
            raise RuntimeError("Orca or Speech Dispatcher exited during startup")

        events = self.output / "fixture-events.log"
        events.write_text("", encoding="utf-8")
        local_flag = ["--allow-local"] if self.allow_local else []
        native = self.spawn([sys.executable, __file__, "--fixture", str(events)] + local_flag, "fixture")
        self.wait_for(lambda: events.exists() and "ready" in events.read_text())
        window = self.run(["xdotool", "search", "--onlyvisible", "--pid", str(native.pid), "--name", TITLE]).stdout.splitlines()[0]
        self.run(["xdotool", "windowfocus", "--sync", window])
        nodes = json.loads(self.run([sys.executable, __file__, "--inspect"] + local_flag).stdout)
        self.report["evidence"]["native_tree"] = nodes
        if {ALPHA, BETA}.issubset({node["name"] for node in nodes}):
            self.observed("native_accessibility", controls=nodes)

        # Begin capture after startup. Only our real Speech Dispatcher uses this sink.
        time.sleep(self.remaining(0.5))
        offset = debug.stat().st_size
        pcm_path = self.output / "orca-task.pcm"
        pcm = pcm_path.open("wb")
        self.handles.append(pcm)
        recorder = self.spawn(["parec", "--device=at_probe.monitor", "--format=s16le",
                               "--rate=16000", "--channels=1", "--raw"], "audio-capture", stdout=pcm)
        # Normal keyboard focus change, then Orca's own Where Am I command.
        self.run(["xdotool", "key", "--clearmodifiers", "Tab"])
        self.wait_for(lambda: "focus=beta" in events.read_text())
        self.wait_for(lambda: any(BETA in line and "SPEECH OUTPUT:" in line
                                 for line in debug.read_bytes()[offset:].decode(errors="replace").splitlines()), 5)
        time.sleep(self.remaining(0.5))
        command_offset = debug.stat().st_size
        self.run(["xdotool", "key", "--clearmodifiers", "KP_Enter"])
        self.wait_for(lambda: any(BETA in line and "SPEECH OUTPUT:" in line
                                 for line in debug.read_bytes()[command_offset:].decode(errors="replace").splitlines()), 6)
        command_text = debug.read_bytes()[command_offset:].decode(errors="replace")
        self.run(["xdotool", "key", "--clearmodifiers", "space"])
        self.wait_for(lambda: "checked=true" in events.read_text())
        time.sleep(self.remaining(2.5))
        self.report["evidence"]["audio_clients"] = self.run(["pactl", "list", "sink-inputs"], check=False).stdout
        self.stop(recorder)
        pcm.flush()
        pcm.close()
        text = debug.read_bytes()[offset:].decode(errors="replace")
        utterances = [line for line in text.splitlines() if "SPEECH OUTPUT:" in line]
        self.report["evidence"]["utterances"] = utterances
        (self.output / "task-utterances.log").write_text("\n".join(utterances), encoding="utf-8")
        beta_spoken = any(BETA in line for line in utterances)
        # A command receipt/handler is separate from ordinary keyboard focus speech.
        command_seen = bool(re.search(r"(?:whereAmI|where_am_i|Where Am I|KP_Enter)", command_text))
        if beta_spoken:
            self.observed("utterance_output", source="real Orca debug output with real espeak-ng backend",
                          utterances=utterances, limitation="Text output alone does not prove audible speech")
        if beta_spoken and command_seen and "checked=true" in events.read_text():
            self.observed("at_navigation", commands=["Tab", "Orca Where Am I (KP_Enter)", "Space"],
                          limitation="Observed native fixture response; not Flutter task acceptance")
        samples = array.array("h")
        raw = pcm_path.read_bytes()
        samples.frombytes(raw[:len(raw) // 2 * 2])
        if sys.byteorder != "little":
            samples.byteswap()
        rms = math.sqrt(sum(value * value for value in samples) / len(samples)) if samples else 0
        audio = {"frames": len(samples), "rms": rms, "sample_rate": 16000,
                 "capture": "private PulseAudio monitor with real Speech Dispatcher espeak-ng"}
        with wave.open(str(self.output / "orca-task.wav"), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(16000)
            output.writeframes(raw)
        self.report["evidence"]["audio"] = audio
        if beta_spoken and len(samples) >= 1600 and rms >= 20:
            self.observed("synthesized_audio", **audio,
                          limitation="PCM confirms synthesis in this isolated session; a human must assess words and intelligibility")
        if all(self.report["layers"][name]["status"] == "observed" for name in LAYERS[:-1]):
            self.report["status"] = "capability_observed"

    def finish(self) -> int:
        for child in reversed(self.children):
            try:
                self.stop(child)
            except Exception as error:
                self.report["errors"].append(f"Owned process cleanup: {error}")
                self.report["status"] = "not_accepted"
        for handle in self.handles:
            if not handle.closed:
                try:
                    handle.close()
                except Exception as error:
                    self.report["errors"].append(f"Evidence handle cleanup: {error}")
                    self.report["status"] = "not_accepted"
        try:
            self.runtime.cleanup()
        except Exception as error:
            self.report["errors"].append(f"Temporary directory cleanup: {error}")
            self.report["status"] = "not_accepted"
        self.report["elapsed_seconds"] = round(time.monotonic() - self.started, 3)
        self.report["layers"]["human_review"] = {"status": "not_accepted", "reason": "No human listened or completed a Flutter task"}
        destination = self.output / "report.json"
        destination.write_text(json.dumps(self.report, indent=2), encoding="utf-8")
        print(json.dumps(self.report, indent=2))
        return 0 if self.report["status"] == "capability_observed" else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("artifacts/real-at-linux"))
    parser.add_argument("--seconds", type=int, default=50, choices=range(30, 56), metavar="30..55")
    parser.add_argument("--fixture", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--inspect", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--allow-local", action="store_true", help="Explicitly allow launching GUI/AT outside disposable CI")
    args = parser.parse_args()
    if (args.fixture or args.inspect) and os.environ.get("GITHUB_ACTIONS") != "true" and not args.allow_local:
        print("CI-only helper: explicit --allow-local is required outside GitHub Actions", file=sys.stderr)
        return 2
    if args.fixture:
        fixture(args.fixture)
        return 0
    if args.inspect:
        inspect_fixture()
        return 0
    probe = Probe(args.output, args.seconds, args.allow_local)
    try:
        probe.execute()
    except Exception as error:
        probe.report["errors"].append(f"{type(error).__name__}: {error}")
        probe.report["status"] = "not_accepted"
    finally:
        result = probe.finish()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
