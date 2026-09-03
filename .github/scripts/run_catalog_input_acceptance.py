#!/usr/bin/env python3
"""Run the separate Catalog input suites without altering the full journey gate."""

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import urllib.request
import uuid
from pathlib import Path

from run_ios_catalog_journey import live_group_members


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "packages/beautiful_ai_ui_catalog"
BROWSERS = ("chrome", "edge", "firefox", "safari")


def executable(name, directory_variable=None):
    suffix = ".exe" if os.name == "nt" else ""
    if directory_variable and os.environ.get(directory_variable):
        candidate = Path(os.environ[directory_variable]) / (name + suffix)
        if candidate.is_file():
            return str(candidate)
    found = shutil.which(name)
    if not found:
        raise RuntimeError(f"Required installed executable is unavailable: {name}")
    return found


def start_owned_process(argv, **kwargs):
    if os.name == "nt":
        from windows_owned_process import start_owned_process as start_windows
        return start_windows(argv, **kwargs)
    if "start_new_session" in kwargs:
        raise ValueError("Process session ownership is managed by this launcher")
    process = subprocess.Popen(argv, **kwargs, start_new_session=True)
    process._input_owned_group = process.pid
    process._input_cleanup_complete = False
    return process


def stop_owned_process(process, grace=5, kill_timeout=5):
    if os.name == "nt":
        from windows_owned_process import stop_owned_process as stop_windows
        return stop_windows(process, grace=grace, kill_timeout=kill_timeout)
    if getattr(process, "_input_cleanup_complete", False):
        return
    group = getattr(process, "_input_owned_group", None)
    if group != process.pid:
        raise RuntimeError("Refusing to stop a process without recorded group ownership")

    def members():
        process.poll()  # Reap the leader; its exit never proves descendants exited.
        return live_group_members(group)

    def signal_owned_group(sig):
        try:
            os.killpg(group, sig)
        except ProcessLookupError:
            pass
        except PermissionError:
            # Darwin can reject signals to a group containing only zombies.
            if members():
                raise

    if members():
        signal_owned_group(signal.SIGTERM)
        deadline = time.monotonic() + grace
        while members() and time.monotonic() < deadline:
            time.sleep(0.02)
    if members():
        signal_owned_group(signal.SIGKILL)
        deadline = time.monotonic() + kill_timeout
        while members() and time.monotonic() < deadline:
            time.sleep(0.02)
    remaining = members()
    if remaining:
        raise RuntimeError(f"Owned process group still has live members after cleanup: {remaining}")
    process.wait(timeout=kill_timeout)
    process._input_cleanup_complete = True


def run(args):
    flutter = executable("flutter")
    output = args.artifacts.resolve()
    output.mkdir(parents=True, exist_ok=True)
    suites = ["framework", "browser"] if args.platform in BROWSERS else ["framework"]
    if args.include_journey:
        suites.insert(0, "journey")
    if (output / "input-acceptance-summary.json").exists() or any((output / suite).exists() for suite in suites):
        raise FileExistsError(f"Refusing to reuse existing suite evidence; choose a fresh artifact directory: {output}")
    run_id = uuid.uuid4().hex
    with (output / "input-acceptance-owner.json").open("x", encoding="utf-8") as owner:
        json.dump({"run_id": run_id, "platform": args.platform, "pid": os.getpid()}, owner)
    summary = {"platform": args.platform, "run_id": run_id, "status": "started", "suites": []}
    try:
        for suite in suites:
            directory = output / suite
            directory.mkdir(parents=True)
            environment = dict(os.environ, BEAUTIFUL_INPUT_EVIDENCE=str(directory),
                               BEAUTIFUL_INPUT_BROWSER=args.platform)
            command = [flutter]
            process = None
            driver_log = None
            entry = {"suite": suite, "status": "started"}
            summary["suites"].append(entry)
            try:
                target = ("catalog_browser_input_test.dart" if suite == "browser"
                          else "catalog_platform_input_test.dart")
                if suite == "journey":
                    target = "catalog_journey_test.dart"
                if args.platform in BROWSERS:
                    if args.platform == "edge":
                        driver_command = [sys.executable, str(ROOT / ".github/scripts/flutter_edge_webdriver.py"),
                                          "--driver", executable("msedgedriver", "EDGEWEBDRIVER"),
                                          "--binary", executable("microsoft-edge"),
                                          "--log", str(directory / "msedgedriver.log"),
                                          "--evidence", str(directory / "browser-identity.json"),
                                          "--diagnostics", str(directory / "diagnostics")]
                    elif args.platform == "chrome":
                        driver_command = [executable("chromedriver", "CHROMEWEBDRIVER"), "--port=4444", "--verbose"]
                    elif args.platform == "firefox":
                        driver_command = [executable("geckodriver", "GECKOWEBDRIVER"), "--host", "127.0.0.1", "--port", "4444"]
                    else:
                        driver_command = [executable("safaridriver"), "--port", "4444"]
                    driver_log = (directory / "webdriver.log").open("w")
                    process = start_owned_process(driver_command, cwd=CATALOG, stdout=driver_log,
                                                  stderr=subprocess.STDOUT)
                    deadline = time.monotonic() + 30
                    while True:
                        if process.poll() is not None:
                            raise RuntimeError(f"WebDriver exited with {process.returncode}")
                        try:
                            with urllib.request.urlopen("http://127.0.0.1:4444/status", timeout=2) as response:
                                if json.load(response)["value"]["ready"]:
                                    break
                        except (OSError, ValueError, KeyError):
                            pass
                        if time.monotonic() >= deadline:
                            raise TimeoutError("WebDriver readiness deadline exceeded")
                        time.sleep(0.2)
                    driver = ("catalog_browser_input_driver.dart" if suite == "browser"
                              else "catalog_platform_input_driver.dart")
                    driver_path = ("integration_test/driver/catalog_trusted_journey_driver.dart" if suite == "journey"
                                   else f"integration_test/driver/{driver}")
                    command += ["drive", f"--driver={driver_path}",
                                f"--target=integration_test/{target}", "--device-id=web-server",
                                f"--browser-name={args.platform}", "--driver-port=4444",
                                "--browser-dimension=1440x900", "--no-pub"]
                    if args.platform == "chrome":
                        command += ["--web-browser-flag=--force-device-scale-factor=1"]
                    if suite == "journey":
                        command += ["--dart-define=CATALOG_TRUSTED_BROWSER_COPY=true"]
                else:
                    device = args.device or args.platform
                    command += ["test", f"integration_test/{target}", f"--device-id={device}",
                                "--no-pub", "--timeout=10m", "--reporter=expanded",
                                f"--file-reporter=json:{directory / 'test-events.json'}"]
                    if args.platform == "linux" and not os.environ.get("DISPLAY"):
                        command = [executable("xvfb-run"), "--auto-servernum", *command]
                entry["command"] = command
                (directory / "command.json").write_text(json.dumps(command, indent=2) + "\n")
                try:
                    with (directory / "run.log").open("w", encoding="utf-8") as log:
                        flutter_process = start_owned_process(command, cwd=CATALOG, env=environment,
                                                              stdout=log, stderr=subprocess.STDOUT)
                        try:
                            entry["exit_code"] = flutter_process.wait(timeout=900)
                        finally:
                            stop_owned_process(flutter_process)
                finally:
                    # Keep partial scenario evidence even when Flutter fails or times out.
                    for line in (directory / "run.log").read_text(encoding="utf-8", errors="replace").splitlines():
                        if "CATALOG_INPUT_REPORT: " in line:
                            try:
                                data = json.loads(line.split("CATALOG_INPUT_REPORT: ", 1)[1])
                                (directory / "framework-input.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
                            except ValueError as error:
                                entry["report_error"] = str(error)
                if entry["exit_code"] != 0:
                    raise RuntimeError(f"{args.platform} {suite} input suite failed with {entry['exit_code']}; see {directory / 'run.log'}")
                if suite != "journey":
                    required_report = directory / ("browser-input.json" if suite == "browser" else "framework-input.json")
                    if not required_report.is_file():
                        raise RuntimeError(f"Successful process did not supply required evidence: {required_report}")
                    data = json.loads(required_report.read_text(encoding="utf-8"))
                    if not isinstance(data, dict):
                        raise RuntimeError(f"Input evidence is not a report object: {required_report}")
                    outcome = data.get("catalog_framework_input", data) if suite == "framework" else data
                    if not isinstance(outcome, dict) or outcome.get("status") != "passed":
                        raise RuntimeError(f"Input report did not accept this run: {required_report}")
                entry["status"] = "completed_pending_cleanup"
            except Exception as error:
                entry.update(status="failed", error=str(error))
                raise
            finally:
                try:
                    if process is not None:
                        stop_owned_process(process)
                except Exception as error:
                    entry.update(status="failed", cleanup_error=str(error))
                    raise
                finally:
                    if driver_log is not None:
                        driver_log.close()
            entry["status"] = "passed"
            print(f"{args.platform} {suite}: passed", flush=True)
        summary["status"] = "passed"
    except Exception as error:
        summary.update(status="failed", error=str(error))
        raise
    finally:
        (output / "input-acceptance-summary.json").write_text(json.dumps(summary, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True,
                        choices=(*BROWSERS, "macos", "windows", "linux", "android", "ios"))
    parser.add_argument("--device", help="Explicit connected device/simulator ID for native runs")
    parser.add_argument("--include-journey", action="store_true",
                        help="Run the original complete Catalog journey before the added input suites")
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    if args.platform in ("android", "ios") and not args.device:
        parser.error("Mobile acceptance requires an explicit connected device or simulator ID")
    run(args)


if __name__ == "__main__":
    main()
