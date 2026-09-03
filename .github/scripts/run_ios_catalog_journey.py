#!/usr/bin/env python3
"""Launch the real iOS Catalog through simctl console, then native Flutter drive.

Flutter 3.47's simulator startApp waits without a separate deadline for filtered
unified logs to announce the VM Service. This launcher observes the application's
console directly, bounds install and discovery, and connects the unchanged
integration driver to the discovered authenticated loopback service.
"""

import argparse
import json
import os
from pathlib import Path
import plistlib
import queue
import re
import signal
import subprocess
import sys
import threading
import time
from urllib.parse import urlparse


SERVICE = re.compile(r"Dart VM service is listening on\s+(https?://\S+)", re.IGNORECASE)
LOCAL_URL = re.compile(r"((?:https?|wss?)://(?:127\.0\.0\.1|localhost|\[::1\]):\d+)/[^\s\"']*")


def redact(text):
    return LOCAL_URL.sub(r"\1/<REDACTED>", text)


def service_uri(line):
    match = SERVICE.search(line)
    if not match:
        return None
    uri = match[1].rstrip("\r\n")
    parsed = urlparse(uri)
    if parsed.hostname not in ("127.0.0.1", "::1", "localhost") or not parsed.port:
        raise ValueError("Simulator announced a non-loopback VM Service")
    return uri


class LoggedProcess:
    def __init__(self, command, path):
        self.lines = queue.Queue()
        self.output = []
        self.log = path.open("w", encoding="utf-8")
        self.process = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", start_new_session=True,
        )
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self):
        for line in self.process.stdout:
            clean = redact(line)
            self.log.write(clean)
            self.log.flush()
            self.output.append(clean)
            self.lines.put(line)
        self.lines.put(None)

    def wait_for_service(self, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                line = self.lines.get(timeout=min(0.2, max(0.001, deadline - time.monotonic())))
            except queue.Empty:
                continue
            if line is None:
                raise RuntimeError(f"simctl console exited before VM Service (exit {self.process.poll()})")
            uri = service_uri(line)
            if uri:
                return uri
        raise TimeoutError(f"No Dart VM Service announced within {timeout} seconds of console launch")

    def close(self, grace=5):
        # Stop the whole CLI process group, including log-reader/compiler children.
        def live_group_members():
            try:
                snapshot = subprocess.check_output(
                    ["/bin/ps", "-axo", "pid=,pgid=,stat="], text=True, timeout=1,
                )
            except subprocess.SubprocessError as error:
                raise RuntimeError("Cannot verify process group membership after EPERM") from error
            members = []
            for line in snapshot.splitlines():
                pid, pgid, state = line.split()
                if int(pgid) == self.process.pid and not state.startswith("Z"):
                    members.append(int(pid))
            return members

        def signal_group(sig):
            # Darwin skips zombies in killpg1 and can return EPERM when the
            # remaining group has no signalable members. Reap our leader first;
            # never treat EPERM as absence while a non-zombie member remains.
            self.process.poll()
            try:
                os.killpg(self.process.pid, sig)
                return True
            except ProcessLookupError:
                return False
            except PermissionError:
                if live_group_members():
                    raise
                return False

        signal_group(signal.SIGTERM)
        deadline = time.monotonic() + grace
        while time.monotonic() < deadline:
            if not signal_group(0):
                break
            time.sleep(0.02)
        if signal_group(0):
            signal_group(signal.SIGKILL)
        self.process.wait(timeout=5)
        self.reader.join(timeout=2)
        if self.reader.is_alive():
            raise RuntimeError("CLI process group retained its output pipe after forced termination")
        self.process.stdout.close()
        self.log.close()


class Journey:
    def __init__(self, directory, device):
        self.directory = directory
        self.device = device
        self.report = {"passed": False, "device_id": device, "stages": []}
        self.save()

    def save(self):
        (self.directory / "ios-journey.json").write_text(json.dumps(self.report, indent=2) + "\n")

    def run(self, name, command, timeout, required=True):
        print(f"[ios-journey] {name}: limit {timeout}s", flush=True)
        start = time.monotonic()
        stage = {"name": name, "command": [redact(value) for value in command],
                 "required": required, "passed": False}
        self.report["stages"].append(stage)
        self.save()
        process = LoggedProcess(command, self.directory / f"{name}.log")
        try:
            try:
                code = process.process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                code = 124
                stage["error"] = f"Command exceeded {timeout} seconds"
        finally:
            process.close()
        stage.update(exit_code=code, passed=code == 0,
                     elapsed_seconds=round(time.monotonic() - start, 3))
        self.save()
        if code != 0 and required:
            raise RuntimeError(f"{name} failed (exit {code}); see {name}.log")
        return "".join(process.output)

    def diagnostics(self, executable):
        predicate = f'process == {json.dumps(executable)} OR eventMessage CONTAINS "Flutter"'
        for name, command in (
            ("simulator-state", ["xcrun", "simctl", "list", "devices", "--json"]),
            ("simulator-processes", ["xcrun", "simctl", "spawn", self.device, "launchctl", "list"]),
            ("simulator-log", ["xcrun", "simctl", "spawn", self.device, "log", "show",
                               "--last", "3m", "--style", "compact", "--predicate", predicate]),
            ("simulator-screenshot", ["xcrun", "simctl", "io", self.device, "screenshot",
                                      str(self.directory / "ios-failure.png")]),
        ):
            try:
                self.run(name, command, 15, required=False)
            except OSError as error:
                print(f"[ios-journey] Diagnostic unavailable: {error}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=True)
    journey = Journey(args.artifacts.resolve(), args.device)
    console = None
    bundle_id = None
    executable = "Runner"
    try:
        journey.run("selected-xcode", ["xcodebuild", "-version"], 20)
        journey.run("simulator-sdk", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], 20)
        bundles = list(Path("build/ios/iphonesimulator").glob("*.app"))
        if len(bundles) != 1:
            raise RuntimeError("Expected exactly one built simulator application")
        bundle = bundles[0].resolve()
        with (bundle / "Info.plist").open("rb") as file:
            metadata = plistlib.load(file)
        bundle_id = metadata["CFBundleIdentifier"]
        executable = metadata["CFBundleExecutable"]
        journey.report.update(bundle_id=bundle_id, bundle=str(bundle), executable=executable)
        journey.run("install", ["xcrun", "simctl", "install", args.device, str(bundle)], 60)

        command = ["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process",
                   args.device, bundle_id, "--enable-dart-profiling", "--enable-checked-mode",
                   "--verify-entry-points"]
        stage = {"name": "console-launch-and-vm-service", "command": command,
                 "required": True, "passed": False}
        journey.report["stages"].append(stage)
        journey.save()
        print("[ios-journey] console launch: VM Service must appear within 120s", flush=True)
        start = time.monotonic()
        console = LoggedProcess(command, journey.directory / "application-console.log")
        uri = console.wait_for_service(120)
        stage.update(passed=True, elapsed_seconds=round(time.monotonic() - start, 3),
                     vm_service=redact(uri))
        journey.save()
        print("[ios-journey] discovered authenticated loopback VM Service", flush=True)
        output = journey.run("native-flutter-driver", [
            args.flutter, "drive", "--verbose", f"--device-id={args.device}",
            "--driver=test_driver/integration_test.dart",
            "--target=integration_test/catalog_journey_test.dart",
            f"--use-existing-app={uri}", "--timeout=600", "--no-pub",
        ], 600)
        if "All tests passed." not in output:
            raise RuntimeError("Native integration driver did not confirm all tests passed")
        journey.report["passed"] = True
    except (OSError, ValueError, KeyError, RuntimeError, TimeoutError) as error:
        journey.report["error"] = redact(str(error))
        journey.save()
        print(f"[ios-journey] FAIL: {redact(str(error))}", file=sys.stderr, flush=True)
        journey.diagnostics(executable)
    finally:
        try:
            if bundle_id is not None:
                journey.run("terminate", ["xcrun", "simctl", "terminate", args.device, bundle_id], 15, required=False)
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            journey.report.update(passed=False, cleanup_error=redact(str(error)))
        try:
            if console is not None:
                console.close()
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            journey.report.update(passed=False, cleanup_error=redact(str(error)))
        journey.save()
    print("[ios-journey] " + ("PASS" if journey.report["passed"] else "FAIL"), flush=True)
    return 0 if journey.report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
