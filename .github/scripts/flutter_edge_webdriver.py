#!/usr/bin/env python3
"""Adapt Flutter 3.47's legacy Edge new-session request to real Edge WebDriver.

The pinned SDK sends browserName=edge without EdgeOptions. Only its three exact
JSON Wire / W3C request shapes are normalized. All other requests and upstream
errors retain their status and payload. No browser, driver, or SDK is installed
or modified. The server and its real msedgedriver upstream bind to loopback.
"""

import argparse
import base64
import http.client
import io
import itertools
import json
import re
import signal
import socket
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from edge_resource_observation import ResourceSampler


class _DeadlineReader(io.RawIOBase):
    """Every buffered HTTP read shares the same absolute network deadline."""

    def __init__(self, connection, deadline):
        super().__init__()
        self.connection = connection
        self.deadline = deadline

    def readable(self):
        return True

    def readinto(self, buffer):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Diagnostic total deadline exceeded")
        self.connection.settimeout(remaining)
        return self.connection.recv_into(buffer)


class _DeadlineResponseSocket:
    def __init__(self, connection, deadline):
        self.connection = connection
        self.deadline = deadline

    def makefile(self, _mode):
        return io.BufferedReader(_DeadlineReader(self.connection, self.deadline))


def diagnostic_response(port, path, timeout=2):
    """Read one genuine HTTP response within a total deadline; no worker survives."""
    deadline = time.monotonic() + timeout
    request = (
        f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n"
        "Connection: close\r\n\r\n"
    ).encode("ascii")
    with socket.create_connection(("127.0.0.1", port), timeout=timeout) as connection:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Diagnostic total deadline exceeded")
        connection.settimeout(remaining)
        connection.sendall(request)
        with http.client.HTTPResponse(_DeadlineResponseSocket(connection, deadline)) as response:
            response.begin()
            # Do not retain an unbounded response from an unhealthy driver.
            limit = 16 * 1024 * 1024
            body = response.read(limit + 1)
            if time.monotonic() >= deadline:
                raise TimeoutError("Diagnostic total deadline exceeded")
            if len(body) > limit:
                raise ValueError("Diagnostic response exceeds 16 MiB")
            return response.status, json.loads(body)


def normalize_session(body, binary):
    try:
        request = json.loads(body)
    except (ValueError, UnicodeDecodeError):
        return body, False
    legacy = {"acceptInsecureCerts": True, "browserName": "edge"}
    shapes = [
        {"desiredCapabilities": legacy, "capabilities": {"alwaysMatch": legacy}},
        {"capabilities": {"alwaysMatch": legacy}},
        {"desiredCapabilities": legacy},
    ]
    if request not in shapes:
        return body, False
    modern = {
        "acceptInsecureCerts": True,
        "browserName": "MicrosoftEdge",
        "ms:edgeOptions": {
            "binary": binary,
            "args": [
                "--headless=new", "--no-sandbox", "--no-first-run",
                "--no-default-browser-check", "--force-device-scale-factor=1",
                "--disable-background-timer-throttling",
            ],
        },
    }
    if "desiredCapabilities" in request:
        request["desiredCapabilities"] = modern
    if "capabilities" in request:
        request["capabilities"]["alwaysMatch"] = modern
    return json.dumps(request).encode(), True


def edge_identity(body, expected_version):
    value = json.loads(body)["value"]
    capabilities = value["capabilities"]
    if capabilities["browserName"] not in ("MicrosoftEdge", "msedge"):
        raise ValueError(f"Expected Microsoft Edge, got {capabilities['browserName']!r}")
    browser_version = capabilities["browserVersion"]
    driver_version = capabilities.get("msedge", {}).get("msedgedriverVersion", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", browser_version):
        raise ValueError("WebDriver did not return a complete Edge browser version")
    driver_match = re.match(r"\d+\.\d+\.\d+\.\d+", driver_version)
    if not driver_match or browser_version != expected_version:
        raise ValueError(f"Expected installed Edge {expected_version}, got {browser_version!r}")
    if browser_version.rsplit(".", 1)[0] != driver_match[0].rsplit(".", 1)[0]:
        raise ValueError("Edge browser and driver builds do not match")
    if not value.get("sessionId"):
        raise ValueError("WebDriver did not return a session identity")
    return {"sessionId": value["sessionId"], "capabilities": capabilities}


class EdgeAdapter(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port, upstream_port, binary, version, evidence, diagnostics=None):
        super().__init__(("127.0.0.1", port), EdgeRequest)
        self.upstream_port = upstream_port
        self.binary = binary
        self.version = version
        self.evidence = evidence
        self.diagnostics = diagnostics
        self.request_ids = itertools.count(1)

    def capture_failure(self, request_id, session_id, command):
        """Collect bounded real driver evidence without retrying the failed action."""
        if self.diagnostics is None:
            return
        try:
            self.diagnostics.mkdir(parents=True, exist_ok=True)
            report = {"failed_command": command}
            # These are observation commands only. Each gets at most 2 seconds;
            # an unresponsive renderer may make both fail, which is evidence too.
            for endpoint in ("url", "screenshot"):
                try:
                    status, value = diagnostic_response(
                        self.upstream_port, f"/session/{session_id}/{endpoint}",
                    )
                    report[endpoint] = {"status": status}
                    if endpoint == "screenshot" and 200 <= status < 300:
                        png = base64.b64decode(value["value"], validate=True)
                        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
                            raise ValueError("WebDriver screenshot is not PNG")
                        filename = f"failure-{request_id}.png"
                        (self.diagnostics / filename).write_bytes(png)
                        report[endpoint]["file"] = filename
                    else:
                        report[endpoint]["response"] = value
                except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError) as error:
                    report[endpoint] = {"diagnostic_error": str(error)}
            (self.diagnostics / f"failure-{request_id}.json").write_text(
                json.dumps(report, indent=2) + "\n",
            )
        except OSError as error:
            print(f"Edge failure diagnostics unavailable: {error}", flush=True)


class EdgeRequest(BaseHTTPRequestHandler):
    def _send(self, status, body, headers=()):
        self.send_response_only(status)
        for name, value in headers:
            if name.lower() not in ("content-length", "transfer-encoding", "connection"):
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def _fail(self, status, error, message):
        self._send(status, json.dumps({"value": {
            "error": error, "message": message, "stacktrace": "",
        }}).encode(), [("Content-Type", "application/json")])

    def _forward(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        request_id = next(self.server.request_ids)
        started = time.monotonic()
        command = {"request_id": request_id, "method": self.command, "path": self.path}
        # Record geometry verbatim, without dumping execute-script arguments or
        # page contents into the concise adapter command trace.
        if self.path.endswith("/window/rect") and body:
            command["parameters"] = body.decode("utf-8", errors="replace")
        print(json.dumps({"event": "webdriver_request", **command}), flush=True)
        normalized = False
        if self.command == "POST" and self.path == "/session":
            body, normalized = normalize_session(body, self.server.binary)
        headers = {
            name: value for name, value in self.headers.items()
            if name.lower() not in ("host", "content-length", "connection")
        }
        connection = http.client.HTTPConnection(
            "127.0.0.1", self.server.upstream_port, timeout=900,
        )
        try:
            connection.request(self.command, self.path, body=body, headers=headers)
            response = connection.getresponse()
            data = response.read()
            response_headers = response.getheaders()
            result = {
                **command, "status": response.status,
                "elapsed_seconds": round(time.monotonic() - started, 3),
            }
            if self.path.endswith("/window/rect"):
                result["response"] = data.decode("utf-8", errors="replace")
            print(json.dumps({"event": "webdriver_response", **result}), flush=True)
            if normalized and 200 <= response.status < 300:
                try:
                    identity = edge_identity(data, self.server.version)
                    self.server.evidence.write_text(json.dumps(identity, indent=2) + "\n")
                    print(f"Verified real Microsoft Edge {self.server.version}", flush=True)
                except (ValueError, KeyError, TypeError, AttributeError, OSError) as error:
                    self._fail(502, "session not created", str(error))
                    return
            session_command = re.fullmatch(r"/session/([^/]+)/.+", self.path)
            if response.status >= 500 and session_command:
                self.server.capture_failure(request_id, session_command[1], result)
            self._send(response.status, data, response_headers)
        except (OSError, http.client.HTTPException) as error:
            print(json.dumps({
                "event": "webdriver_transport_error", **command,
                "elapsed_seconds": round(time.monotonic() - started, 3),
                "error": str(error),
            }), flush=True)
            self._fail(502, "unknown error", f"Local Microsoft Edge WebDriver unavailable: {error}")
        finally:
            connection.close()

    do_GET = do_POST = do_DELETE = do_PUT = _forward


def installed_versions(binary, driver):
    versions = []
    for command, label in ((binary, "Microsoft Edge"), (driver, "Microsoft Edge WebDriver")):
        output = subprocess.check_output([command, "--version"], text=True, timeout=10).strip()
        print(output, flush=True)
        match = re.search(r"\d+\.\d+\.\d+\.\d+", output)
        if not output.startswith(label) or not match:
            raise ValueError(f"Expected installed {label}: {command}")
        versions.append(match[0])
    if versions[0].rsplit(".", 1)[0] != versions[1].rsplit(".", 1)[0]:
        raise ValueError("Installed Microsoft Edge and msedgedriver builds do not match")
    return versions[0]


def wait_for_driver(driver, port):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if driver.poll() is not None:
            raise RuntimeError(f"Microsoft Edge WebDriver exited with {driver.returncode}")
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=1)
        try:
            connection.request("GET", "/status")
            response = connection.getresponse()
            if response.status == 200 and json.loads(response.read())["value"]["ready"]:
                return
        except (OSError, http.client.HTTPException, ValueError, KeyError):
            pass
        finally:
            connection.close()
        time.sleep(0.2)
    raise RuntimeError("Microsoft Edge WebDriver did not become ready within 30 seconds")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--driver", required=True)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--port", type=int, default=4444)
    parser.add_argument("--upstream-port", type=int, default=4445)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--diagnostics", type=Path,
                        help="Directory for bounded URL/screenshot evidence after upstream server errors")
    parser.add_argument("--resources", type=Path,
                        help="Optional Linux PID-scoped, 1 Hz read-only startup/resource evidence")
    args = parser.parse_args()
    if not (0 < args.port < 65536 and 0 < args.upstream_port < 65536) or args.port == args.upstream_port:
        parser.error("Use two distinct local ports from 1 to 65535")

    def stop(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)
    driver = None
    observer = None
    resource_report = {"scope": "driver_pid_start_time_and_descendants", "interval_seconds": 1,
                       "browser_commands_changed": False, "process_cleanup_claimed": False}
    try:
        args.evidence.unlink(missing_ok=True)
        version = installed_versions(args.binary, args.driver)
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        with args.log.open("w") as log:
            # Omitting --allowed-ips preserves the driver's loopback-only bind.
            # Supplying that switch enables remote binding even for an allowlist.
            driver = subprocess.Popen(
                [args.driver, f"--port={args.upstream_port}",
                 "--verbose", "--enable-chrome-logs"],
                stdout=log, stderr=subprocess.STDOUT,
            )
            if args.resources is not None:
                try:
                    args.resources.mkdir(parents=True, exist_ok=True)
                    if sys.platform != "linux":
                        raise RuntimeError("Resource evidence requires actual Linux /proc")
                    observer = ResourceSampler(None, args.resources / "resources.jsonl", root_pid=driver.pid)
                    resource_report.update(status="observing", root_pid=observer.root_identity[0],
                                           root_start_ticks=observer.root_identity[1])
                except (OSError, ValueError, RuntimeError) as error:
                    resource_report.update(status="unavailable", error=str(error))
            wait_for_driver(driver, args.upstream_port)
            with EdgeAdapter(args.port, args.upstream_port, args.binary, version,
                             args.evidence, args.diagnostics) as server:
                print(f"Edge session adapter listening on 127.0.0.1:{args.port}", flush=True)
                server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Edge WebDriver startup failed: {error}", file=sys.stderr, flush=True)
        return 1
    finally:
        if observer is not None:
            try:
                observer.stop_observing()
                resource_report.update(status="recorded", observed_process_identities=sorted(observer.observed_processes))
            except RuntimeError as error:
                resource_report.update(status="failed", error=str(error))
        if args.resources is not None:
            try:
                (args.resources / "observation.json").write_text(json.dumps(resource_report, indent=2) + "\n")
            except OSError as error:
                print(f"Edge resource evidence unavailable: {error}", file=sys.stderr, flush=True)
        if driver is not None and driver.poll() is None:
            driver.terminate()
            try:
                driver.wait(timeout=5)
            except subprocess.TimeoutExpired:
                driver.kill()
                driver.wait(timeout=5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
