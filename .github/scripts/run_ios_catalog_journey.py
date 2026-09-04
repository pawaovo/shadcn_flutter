#!/usr/bin/env python3
"""Launch the real iOS Catalog, discover its VM Service, then native Flutter drive.

Flutter 3.47's simulator startApp waits without a separate deadline for filtered
unified logs to announce the VM Service. This launcher waits for a bounded,
non-console launch command to exit, validates its bundle/PID response, and reads
PID/time-scoped unified history before connecting the unchanged native driver.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import queue
import re
import selectors
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


def launch_pid(output, bundle_id):
    matches = [re.fullmatch(re.escape(bundle_id) + r":\s*(\d+)", line.strip())
               for line in output.splitlines()]
    pids = [int(match[1]) for match in matches if match]
    if len(pids) != 1 or pids[0] <= 1:
        raise RuntimeError("simctl launch did not return exactly one valid PID for the expected bundle")
    return pids[0]


def unified_service_uri(line, pid, executable, launched_at):
    match = re.match(
        rf"^(\d{{4}}-\d{{2}}-\d{{2}} \d{{2}}:\d{{2}}:\d{{2}}\.\d{{3}})\s+"
        rf"\S+\s+{re.escape(executable)}\[{pid}:[^\]]+\]", line,
    )
    if not match:
        return None
    emitted_at = datetime.fromisoformat(match[1]).replace(tzinfo=timezone.utc)
    # Compact log timestamps have millisecond precision.
    lower_bound = launched_at.replace(microsecond=(launched_at.microsecond // 1000) * 1000)
    if emitted_at < lower_bound:
        return None
    return service_uri(line)


def live_group_members(group_id):
    try:
        os.killpg(group_id, 0)
    except ProcessLookupError:
        return []
    except PermissionError:
        pass  # The group may still contain live members; inspect it below.
    try:
        snapshot = subprocess.check_output(
            ["/bin/ps", "-axo", "pid=,pgid=,stat="], text=True, timeout=1,
        )
    except subprocess.SubprocessError as error:
        raise RuntimeError("Cannot verify process group membership") from error
    members = []
    for line in snapshot.splitlines():
        pid, pgid, state = line.split()
        if int(pgid) == group_id and not state.startswith("Z"):
            members.append(int(pid))
    return members


def stop_process_group(process, grace=5):
    def signal_group(sig):
        # Darwin can report EPERM for a group containing only zombies.
        process.poll()
        try:
            os.killpg(process.pid, sig)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            if live_group_members(process.pid):
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
    process.wait(timeout=5)


def capture_query_snapshot(command, path, timeout):
    """Capture a finite query by its exit status, without requiring inherited EOF.

    CoreSimulator can proxy output through processes outside the host CLI's
    process group. Successful command completion plus a finite available-byte
    drain defines this snapshot; it does not claim those external services ended.
    Generic LoggedProcess intentionally retains its strict EOF requirement.
    """
    start = time.monotonic()
    status = {"exit_code": None, "timed_out": False, "stdout_eof": False,
              "bytes_read": 0, "host_group_clean": False}
    process = None
    lines = []
    pending = b""
    try:
        with path.open("w", encoding="utf-8") as log, selectors.DefaultSelector() as selector:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       bufsize=0, start_new_session=True)
            descriptor = process.stdout.fileno()
            capture_ready = False

            def drain(deadline):
                nonlocal pending
                while True:
                    while b"\n" in pending:
                        if time.monotonic() >= deadline:
                            return False
                        raw, pending = pending.split(b"\n", 1)
                        line = raw.decode("utf-8", errors="replace") + "\n"
                        lines.append(line)
                        log.write(redact(line))
                        log.flush()
                    if time.monotonic() >= deadline:
                        return False
                    if status["stdout_eof"]:
                        return True
                    try:
                        data = os.read(descriptor, 65536)
                    except BlockingIOError:
                        return time.monotonic() < deadline
                    if not data:
                        status["stdout_eof"] = True
                        selector.unregister(descriptor)
                        continue
                    status["bytes_read"] += len(data)
                    if status["bytes_read"] > 1024 * 1024:
                        raise RuntimeError("VM Service snapshot exceeded its 1 MiB output bound")
                    pending += data

            try:
                os.set_blocking(descriptor, False)
                selector.register(descriptor, selectors.EVENT_READ)
                capture_ready = True
                deadline = start + timeout
                while process.poll() is None:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        status.update(exit_code=124, timed_out=True)
                        break
                    if status["stdout_eof"]:
                        time.sleep(min(0.02, remaining))
                    elif selector.select(min(0.05, remaining)):
                        if not drain(deadline):
                            status.update(exit_code=124, timed_out=True)
                            break
                if status["exit_code"] is None:
                    if time.monotonic() >= deadline:
                        status.update(exit_code=124, timed_out=True)
                    else:
                        status["exit_code"] = process.returncode
            finally:
                # The real CLI and all live members of its own host PGID must
                # still end. An inherited descriptor alone is not a live PID.
                try:
                    stop_process_group(process, grace=0)
                    members = live_group_members(process.pid)
                    if members:
                        raise RuntimeError(f"Snapshot host process group still has live members: {members}")
                    status["host_group_clean"] = True
                    if capture_ready:
                        # This one-second tail budget fits inside the caller's
                        # cleanup reserve; byte limits still apply to the total.
                        final_deadline = time.monotonic() + 1
                        complete = drain(final_deadline)
                        if pending and complete and time.monotonic() < final_deadline:
                            # Preserve an incomplete diagnostic tail, but never
                            # expose it as a candidate URI.
                            log.write(redact(pending.decode("utf-8", errors="replace")))
                            log.flush()
                            pending = b""
                        complete = complete and time.monotonic() < final_deadline
                        status["final_drain_complete"] = complete
                        if not complete:
                            status.update(exit_code=124, timed_out=True)
                finally:
                    process.stdout.close()
            if pending:
                status["discarded_tail_bytes"] = len(pending)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        status["error"] = redact(str(error))
        if error.__cause__ is not None:
            cause = error.__cause__
            status["cause"] = {"type": type(cause).__name__, "message": redact(str(cause))}
            if isinstance(cause, subprocess.TimeoutExpired):
                status["cause"]["timeout"] = cause.timeout
            elif isinstance(cause, subprocess.CalledProcessError):
                status["cause"]["returncode"] = cause.returncode
        raise
    finally:
        status["host_returncode"] = process.returncode if process is not None else None
        status["elapsed_seconds"] = round(time.monotonic() - start, 3)
        path.with_suffix(".json").write_text(json.dumps(status, indent=2) + "\n")
    code = status["exit_code"]
    return lines if code == 0 else [], code


def query_unified_service(device, pid, launched_at, path, timeout):
    command = [
        "xcrun", "simctl", "spawn", device, "log", "show", "--no-pager", "--style", "compact",
        "--timezone", "UTC", "--info", "--debug",
        "--start", launched_at.strftime("%Y-%m-%d %H:%M:%S%z"),
        "--predicate", f'processIdentifier == {pid} AND composedMessage CONTAINS "Dart VM service is listening on"',
    ]
    return capture_query_snapshot(command, path, timeout)


def discover_service(pid, device, executable, directory,
                     launched_at, deadline, details):
    details["application_pid"] = pid
    attempts = details.setdefault("history_queries", [])
    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()
        # Reserve eight seconds for forced query-process cleanup. Each lookup
        # consumes this same discovery deadline; retries never reset it.
        if remaining <= 8:
            break
        budget = min(15, remaining - 8)
        path = directory / f"vm-service-history-{len(attempts) + 1}.log"
        print(f"[ios-journey] inspect unified VM log for PID {pid}", flush=True)
        attempt = {"exit_code": None, "log": path.name,
                   "capture_status": path.with_suffix(".json").name,
                   "timeout_seconds": round(budget, 3)}
        attempts.append(attempt)
        lines, code = query_unified_service(device, pid, launched_at, path, budget)
        attempt["exit_code"] = code
        if time.monotonic() >= deadline:
            break
        for event in lines:
            uri = unified_service_uri(event, pid, executable, launched_at)
            if uri:
                details["source"] = "unified-log-history"
                return uri
        time.sleep(min(1, max(0, deadline - time.monotonic())))
    raise TimeoutError("No matching Dart VM Service discovered before the launch deadline")


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

    def close(self, grace=5):
        # Stop the whole CLI process group, including log-reader/compiler children.
        stop_process_group(self.process, grace)
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

        command = ["xcrun", "simctl", "launch", "--terminate-running-process",
                   args.device, bundle_id, "--enable-dart-profiling", "--enable-checked-mode",
                   "--verify-entry-points"]
        launched_at = datetime.now(timezone.utc)
        start = time.monotonic()
        # Non-console simctl returns after launch, so even block-buffered PID
        # output is collected at EOF. Do not wait for a long-lived PTY to flush.
        output = journey.run("launch", command, 30)
        pid = launch_pid(output, bundle_id)
        stage = {"name": "vm-service-discovery",
                 "required": True, "passed": False, "launched_at": launched_at.isoformat(),
                 "discovery": {}}
        journey.report["stages"].append(stage)
        journey.save()
        print(f"[ios-journey] launched PID {pid}; VM deadline is 120s from launch start", flush=True)
        uri = discover_service(
            pid, args.device, executable, journey.directory,
            launched_at, start + 120, stage["discovery"],
        )
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
        journey.save()
    print("[ios-journey] " + ("PASS" if journey.report["passed"] else "FAIL"), flush=True)
    return 0 if journey.report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
