#!/usr/bin/env python3
"""Adapt Flutter 3.47's legacy Edge new-session request to real Edge WebDriver.

The pinned SDK sends browserName=edge without EdgeOptions. Only its three exact
JSON Wire / W3C request shapes are normalized. All other requests and upstream
errors retain their status and payload. No browser, driver, or SDK is installed
or modified. The server and its real msedgedriver upstream bind to loopback.
"""

import argparse
import http.client
import json
import re
import signal
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


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

    def __init__(self, port, upstream_port, binary, version, evidence):
        super().__init__(("127.0.0.1", port), EdgeRequest)
        self.upstream_port = upstream_port
        self.binary = binary
        self.version = version
        self.evidence = evidence


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
            if normalized and 200 <= response.status < 300:
                try:
                    identity = edge_identity(data, self.server.version)
                    self.server.evidence.write_text(json.dumps(identity, indent=2) + "\n")
                    print(f"Verified real Microsoft Edge {self.server.version}", flush=True)
                except (ValueError, KeyError, TypeError, AttributeError, OSError) as error:
                    self._fail(502, "session not created", str(error))
                    return
            self._send(response.status, data, response_headers)
        except (OSError, http.client.HTTPException) as error:
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
    args = parser.parse_args()
    if not (0 < args.port < 65536 and 0 < args.upstream_port < 65536) or args.port == args.upstream_port:
        parser.error("Use two distinct local ports from 1 to 65535")

    def stop(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)
    driver = None
    try:
        args.evidence.unlink(missing_ok=True)
        version = installed_versions(args.binary, args.driver)
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        with args.log.open("w") as log:
            # Omitting --allowed-ips preserves the driver's loopback-only bind.
            # Supplying that switch enables remote binding even for an allowlist.
            driver = subprocess.Popen(
                [args.driver, f"--port={args.upstream_port}"],
                stdout=log, stderr=subprocess.STDOUT,
            )
            wait_for_driver(driver, args.upstream_port)
            with EdgeAdapter(args.port, args.upstream_port, args.binary, version, args.evidence) as server:
                print(f"Edge session adapter listening on 127.0.0.1:{args.port}", flush=True)
                server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Edge WebDriver startup failed: {error}", file=sys.stderr, flush=True)
        return 1
    finally:
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
