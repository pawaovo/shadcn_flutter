#!/usr/bin/env python3
"""Three independent, failure-preserving Edge startup observations on Linux.

Replays the captured Flutter 3.47 startup requests through the unchanged Edge
adapter. Does not build Flutter, navigate an app, change driver timeouts, retry
a failed session, or infer a browser fix from an unreproduced failure.
"""

import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path
import platform
import signal
import socket
import stat
import subprocess
import sys
import time

from flutter_edge_webdriver import _DeadlineResponseSocket, installed_versions
from edge_resource_observation import ResourceSampler, proc_row
from run_catalog_input_acceptance import executable, start_owned_process, stop_owned_process


ROOT = Path(__file__).resolve().parents[2]
CASE_COUNT = 3
TRANSPORT_SECONDS = 900  # Same as the existing adapter; not pageLoad timeout.
LEGACY = {"acceptInsecureCerts": True, "browserName": "edge"}
SESSION_REQUEST = {"desiredCapabilities": LEGACY,
                   "capabilities": {"alwaysMatch": LEGACY}}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def file_identity(path):
    resolved = Path(path).resolve(strict=True)
    digest = hashlib.sha256()
    with resolved.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"path": str(path), "resolved": str(resolved),
            "bytes": resolved.stat().st_size, "sha256": digest.hexdigest()}


def preread_executable(path, output):
    """One sequential pass, including its hash, before any measured startup."""
    started = time.monotonic()
    report = {"status": "started", "path": str(path), "started_epoch": time.time(),
              "bytes_read": 0, "condition": "preread_actual_browser_executable_once"}
    try:
        resolved = Path(path).resolve(strict=True)
        report["resolved"] = str(resolved)
        if not resolved.is_file() or not os.access(resolved, os.X_OK):
            raise ValueError("Preread target must be an executable regular file")
        digest = hashlib.sha256()
        with resolved.open("rb") as source:
            before = os.fstat(source.fileno())
            if not stat.S_ISREG(before.st_mode):
                raise ValueError("Preread target is not a regular file")
            first = True
            while chunk := source.read(1024 * 1024):
                if first and not chunk.startswith(b"\x7fELF"):
                    raise ValueError("Preread target must be the ELF browser, not its shell launcher")
                first = False
                digest.update(chunk)
                report["bytes_read"] += len(chunk)
            after = os.fstat(source.fileno())
        if first or report["bytes_read"] != before.st_size or (
            before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns
        ) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            raise ValueError("Preread executable changed during the sequential read")
        report.update(status="read_complete", sha256=digest.hexdigest(),
                      bytes=after.st_size)
        return report
    except BaseException as error:
        report.update(status="failed", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        report["elapsed_seconds"] = round(time.monotonic() - started, 6)
        report["completed_epoch"] = time.time()
        write_json(output / "preread.json", report)


def verify_preread_target(preread, report, directory):
    """Bind the target to the actual session browser PID, not any child process."""
    pid = report.get("session", {}).get("capabilities", {}).get("goog:processID")
    snapshot = json.loads((directory / "post-startup-processes.json").read_text())
    matches = [row for row in snapshot["processes"] if row["pid"] == pid]
    if len(matches) != 1 or matches[0].get("exe") != preread["resolved"]:
        raise ValueError(f"Preread target was not verified as this session's actual browser executable: PID {pid}")
    return {"status": "verified", "pid": pid, "exe": matches[0]["exe"],
            "start_ticks": matches[0]["start_ticks"]}


class WebDriverFailure(RuntimeError):
    def __init__(self, record):
        self.record = record
        super().__init__(f"{record['method']} {record['path']}: "
                         f"HTTP {record.get('status')}: {record.get('response_text')}")


class Client:
    def __init__(self, port, trace):
        self.port, self.trace = port, trace

    def request(self, method, path, body=None, timeout=TRANSPORT_SECONDS):
        started = time.monotonic()
        record = {"method": method, "path": path, "body": body,
                  "started_epoch": time.time(), "transport_seconds": timeout}
        payload = b"" if body is None else json.dumps(body).encode()
        wire = (f"{method} {path} HTTP/1.1\r\nHost: 127.0.0.1:{self.port}\r\n"
                "Content-Type: application/json\r\nConnection: close\r\n"
                f"Content-Length: {len(payload)}\r\n\r\n").encode() + payload
        try:
            deadline = started + timeout
            with socket.create_connection(("127.0.0.1", self.port), timeout=timeout) as connection:
                connection.sendall(wire)
                with http.client.HTTPResponse(_DeadlineResponseSocket(connection, deadline)) as response:
                    response.begin()
                    raw = response.read(2 * 1024 * 1024 + 1)
                    if len(raw) > 2 * 1024 * 1024:
                        raise ValueError("WebDriver response exceeds diagnostic 2 MiB bound")
                    record.update(status=response.status, response_text=raw.decode("utf-8"))
            value = json.loads(record["response_text"])
            record["response"] = value
            if not 200 <= record["status"] < 300 or (
                isinstance(value.get("value"), dict) and value["value"].get("error")
            ):
                raise WebDriverFailure(record)
            return value["value"]
        except Exception as error:
            record["error"] = f"{type(error).__name__}: {error}"
            raise
        finally:
            record["elapsed_seconds"] = round(time.monotonic() - started, 6)
            self.trace.write(json.dumps(record) + "\n")
            self.trace.flush()


def startup(client, report):
    """The five observed startup commands, with no interleaved observations."""
    report["phase"] = "status"
    if client.request("GET", "/status").get("ready") is not True:
        raise AssertionError("Real EdgeDriver is not ready")
    report["phase"] = "new_session"
    session = client.request("POST", "/session", SESSION_REQUEST)
    report["session"] = session
    session_id = session["sessionId"]
    if not session_id or not isinstance(session_id, str):
        raise AssertionError("Missing real session identity")
    capabilities = session["capabilities"]
    if capabilities.get("timeouts", {}).get("pageLoad") != 300000:
        raise AssertionError("Original 300000 ms pageLoad deadline was not preserved")
    if capabilities.get("pageLoadStrategy") != "normal":
        raise AssertionError("Original normal pageLoad strategy was not preserved")
    base = f"/session/{session_id}"
    report["phase"] = "get_window"
    if not isinstance(client.request("GET", base + "/window"), str):
        raise AssertionError("WebDriver did not return a window handle")
    report["phase"] = "set_location"
    location = client.request("POST", base + "/window/rect", {"x": 0, "y": 0})
    if (location.get("x"), location.get("y")) != (0, 0):
        raise AssertionError(f"Original location assertion failed: {location}")
    report["phase"] = "set_size"
    size = client.request("POST", base + "/window/rect", {"width": 1440, "height": 900})
    if (size.get("width"), size.get("height")) != (1440, 900):
        raise AssertionError(f"Original requested size was not applied: {size}")
    report["phase"] = "startup_complete"



def wait_for_adapter(process, port):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Adapter exited with {process.returncode}")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return  # TCP only; startup() records the first adapter GET /status.
        except OSError:
            time.sleep(0.1)
    raise TimeoutError("Adapter did not listen within the existing 30-second readiness bound")


def log_signals(path):
    lines = path.read_text(errors="replace").splitlines() if path.exists() else []
    start = next((i for i, line in enumerate(lines) if "COMMAND SetWindowRect" in line), len(lines))
    end = next((i + 1 for i in range(start, len(lines)) if "RESPONSE SetWindowRect" in lines[i]), len(lines))
    first_rectangle = "\n".join(lines[start:end])
    return {
        "initial_rectangle_cdp_counts": {token: first_rectangle.count(token) for token in (
            "DevTools WebSocket Command: Runtime.evaluate", "DevTools WebSocket Response: Runtime.evaluate",
            "Browser.getWindowForTarget", "Browser.setWindowBounds", "Waiting for pending navigations",
        )},
        "pre_rectangle_load_events": [line for line in lines[:start] if any(token in line for token in (
            "Page.frameStartedNavigating", "Page.domContentEventFired", "Page.loadEventFired", "Page.frameStoppedLoading",
        ))][:80],
        "startup_child_errors": [line for line in lines[:start] if any(token in line for token in (
            "with no connection", "Network service crashed", "Terminating child process",
        ))][:80],
        "interpretation": "counts and original log lines only; no causal classification",
    }


def run_case(index, output, binary, driver):
    directory = output / f"session-{index}"
    directory.mkdir()
    report = {"index": index, "status": "started", "cleanup_status": "unverified"}
    report_path = directory / "report.json"
    write_json(report_path, report)
    process = sampler = None
    argv = [sys.executable, str(ROOT / ".github/scripts/flutter_edge_webdriver.py"),
            "--binary", binary, "--driver", driver, "--port", "4444", "--upstream-port", "4445",
            "--log", str(directory / "msedgedriver.log"),
            "--evidence", str(directory / "browser-identity.json"),
            "--diagnostics", str(directory / "diagnostics")]
    report["adapter_command"] = argv
    try:
        for port in (4444, 4445):
            with socket.socket() as reservation:
                reservation.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                reservation.bind(("127.0.0.1", port))
        with (directory / "adapter.log").open("x") as log, (directory / "requests.jsonl").open("x") as trace:
            try:
                process = start_owned_process(argv, stdout=log, stderr=subprocess.STDOUT)
                sampler = ResourceSampler(process.pid, directory / "resources.jsonl")
                client = Client(4444, trace)
                wait_for_adapter(process, 4444)
                try:
                    startup(client, report)
                    report["status"] = "startup_passed_pending_cleanup"
                except Exception as error:
                    report.update(status="failed", error=f"{type(error).__name__}: {error}")
                    if isinstance(error, WebDriverFailure):
                        report["original_failure"] = error.record
                    # Preserve the original failure before issuing any extra observation.
                    write_json(report_path, report)
                    session_id = report.get("session", {}).get("sessionId")
                    if session_id:
                        try:
                            # Vendor CDP endpoint is observation only, after driver timeout/
                            # stopLoading. Its result cannot prove pre-timeout readyState.
                            report["post_failure_document"] = client.request(
                                "POST", f"/session/{session_id}/ms/cdp/execute",
                                {"cmd": "Runtime.evaluate", "params": {
                                    "expression": "JSON.stringify({readyState:document.readyState,url:document.URL,timeOrigin:performance.timeOrigin})",
                                    "returnByValue": True}}, timeout=8)
                        except Exception as observation_error:
                            report["post_failure_document_error"] = str(observation_error)
                # A successful cold start can finish between 1 Hz samples.
                # Read /proc after the original startup sequence, before quit,
                # so the actual browser executable is still observable.
                write_json(directory / "post-startup-processes.json", sampler.snapshot())
                session_id = report.get("session", {}).get("sessionId")
                if session_id:
                    try:
                        client.request("DELETE", f"/session/{session_id}", timeout=8)
                    except Exception as error:
                        report.update(status="failed", quit_error=str(error))
            finally:
                if process is not None:
                    stop_owned_process(process)
                    report["cleanup_status"] = "verified"
    except BaseException as error:
        report.update(status="failed", supervisor_error=f"{type(error).__name__}: {error}")
        if not isinstance(error, Exception):
            raise
    finally:
        if sampler is not None:
            try:
                sampler.close()
            except Exception as error:
                report.update(status="failed", cleanup_status="unverified", observer_error=str(error))
            report["observed_executables"] = sorted(sampler.executables)
        if report["status"] == "startup_passed_pending_cleanup":
            report["status"] = "passed"
        report["log_signals"] = log_signals(directory / "msedgedriver.log")
        write_json(report_path, report)
    return report


def run_cases(output, binary, driver, execute_case=run_case, preread_path=None):
    started = time.monotonic()
    summary = {"status": "started", "planned_sessions": CASE_COUNT,
               "started_epoch": time.time(),
               "startup_condition": "baseline_no_preread" if preread_path is None else "preread_browser_once",
               "sessions": [{"index": index, "status": "not_run"} for index in range(1, CASE_COUNT + 1)]}
    try:
        preread = preread_executable(preread_path, output) if preread_path is not None else None
        if preread is not None:
            summary["preread"] = preread
        for index in range(1, CASE_COUNT + 1):
            report = execute_case(index, output, binary, driver)
            summary["sessions"][index - 1] = report
            write_json(output / "summary.json", summary)
            if report.get("cleanup_status") != "verified":
                raise RuntimeError("Cleanup not verified; remaining independent sessions must not run")
            if preread is not None:
                try:
                    report["preread_identity"] = verify_preread_target(
                        preread, report, output / f"session-{index}")
                except Exception as error:
                    # Keep any original startup error; a mismatched experiment
                    # target must not turn into a passing comparison.
                    report.update(status="failed", preread_identity_error=str(error))
                write_json(output / f"session-{index}" / "report.json", report)
        summary["status"] = "passed" if all(
            item["status"] == "passed" for item in summary["sessions"]
        ) else "failed"
    except BaseException as error:
        summary.update(status="failed", error=str(error))
        if not isinstance(error, Exception):
            raise
    finally:
        summary["elapsed_seconds_including_preread_and_cleanup"] = round(time.monotonic() - started, 6)
        write_json(output / "summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--binary")
    parser.add_argument("--driver")
    parser.add_argument("--preread-browser-executable", type=Path,
                        help="Explicit experiment: read this actual ELF browser once before all three sessions")
    args = parser.parse_args()
    if sys.platform != "linux":
        parser.error("Real cold sessions require Linux /proc; use protocol unit tests elsewhere")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    def interrupted(signum, _frame):
        raise KeyboardInterrupt(f"Interrupted by signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    provenance = {"scope": "three_independent_edge_startups_without_flutter_compile_load",
                  "application_acceptance": "not_measured", "source_sha": subprocess.check_output(
                      ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  "platform": platform.platform(), "python": sys.version,
                  "clock_ticks_per_second": os.sysconf("SC_CLK_TCK"),
                  "page_size_bytes": os.sysconf("SC_PAGE_SIZE"),
                  "runner": {name: os.environ.get(name) for name in (
                      "ImageOS", "ImageVersion", "GITHUB_WORKFLOW_REF", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")},
                  "sources": [file_identity(ROOT / path) for path in (
                      ".github/scripts/probe_edge_cold_start.py", ".github/scripts/flutter_edge_webdriver.py",
                      ".github/scripts/run_catalog_input_acceptance.py", ".github/scripts/run_ios_catalog_journey.py",
                      ".github/scripts/test_probe_edge_cold_start.py", ".github/workflows/beautiful_ai_ui_edge_cold_start.yml",
                      ".github/scripts/edge_resource_observation.py")],
                  "baseline": "Fresh browser process/profile each time; OS page cache is not flushed",
                  "sampling": "1 Hz /proc; disappearance is not a process exit code; executable hashing happens after sessions"}
    provenance["startup_condition"] = (
        "baseline_no_preread" if args.preread_browser_executable is None else "preread_browser_once")
    write_json(output / "provenance.json", provenance)
    try:
        binary = args.binary or executable("microsoft-edge")
        driver = args.driver or executable("msedgedriver", "EDGEWEBDRIVER")
        provenance["installed_version"] = installed_versions(binary, driver)
        provenance["configured_binary"] = binary
        provenance["configured_driver"] = driver
        write_json(output / "provenance.json", provenance)
        summary = run_cases(output, binary, driver, preread_path=args.preread_browser_executable)
        paths = {binary, driver}
        for report in summary["sessions"]:
            paths.update(report.get("observed_executables", []))
        provenance["executables"] = []
        for path in sorted(paths):
            try:
                provenance["executables"].append(file_identity(path))
            except OSError as error:
                provenance["executables"].append({"path": path, "error": str(error)})
        write_json(output / "provenance.json", provenance)
        if summary.get("preread"):
            actual = next((item for item in provenance["executables"] if
                           item.get("resolved") == summary["preread"]["resolved"]), None)
            if actual is None or actual.get("sha256") != summary["preread"]["sha256"]:
                summary.update(status="failed", preread_content_error="Actual executable hash did not match the preread bytes")
                write_json(output / "summary.json", summary)
        return 0 if summary["status"] == "passed" else 1
    except Exception as error:
        write_json(output / "setup-error.json", {"status": "failed", "error": str(error)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
