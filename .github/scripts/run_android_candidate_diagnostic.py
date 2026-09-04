#!/usr/bin/env python3
"""One Android IME-candidate commit around the original full journey.

Native input is restricted to one observed exact candidate; no text, composing,
focus, keyboard or Send mutation is issued by this supervisor. Public VM state
and an earlier device-monotonic ticket bind permission to invoke an action.
Android can delay delivery inside
its public API; the Dart fixture stays mounted until actual native drain, and
an unverified drain requires teardown of this exclusively owned emulator.
"""

from __future__ import annotations

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from run_catalog_input_acceptance import start_owned_process, stop_owned_process

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "packages/beautiful_ai_ui_catalog"
APP = "dev.beautifulai.beautiful_ai_ui_catalog"
HELPER = "dev.beautifulai.androidcandidateprobe"
EXTENSION = "ext.beautiful.androidCandidate"
TEXT = "Check cone inventory"
MAX_JSON = 512 * 1024
SOURCE_SCOPES = (
    "pubspec.yaml", "pubspec.lock", "packages/beautiful_ai_ui/pubspec.yaml",
    "packages/shadcn_flutter/pubspec.yaml", "packages/beautiful_ai_ui_catalog/pubspec.yaml",
    "packages/beautiful_ai_ui/lib", "packages/beautiful_ai_ui/assets",
    "packages/shadcn_flutter/lib", "packages/shadcn_flutter/assets",
    "packages/beautiful_ai_ui_catalog/lib", "packages/beautiful_ai_ui_catalog/assets",
    "packages/beautiful_ai_ui_catalog/android", "packages/beautiful_ai_ui_catalog/integration_test",
    "tool/android_candidate_probe", ".github/scripts/run_android_candidate_diagnostic.py",
    ".github/scripts/run_catalog_input_acceptance.py", ".github/scripts/run_ios_catalog_journey.py",
    ".github/workflows/beautiful_ai_ui.yml",
    ".github/workflows/beautiful_ai_ui_android_candidate.yml",
)


def write_json(path, data):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def checked_vm_url(raw):
    parsed = urllib.parse.urlsplit(raw)
    if (parsed.scheme not in ("http", "ws") or parsed.hostname not in ("127.0.0.1", "localhost")
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.port is None or not 1024 <= parsed.port <= 65535):
        raise ValueError("VM service must be an observed loopback endpoint")
    path = parsed.path
    if parsed.scheme == "ws" and path.endswith("/ws"):
        path = path[:-2]
    if not path.endswith("/"):
        path += "/"
    return urllib.parse.urlunsplit(("http", parsed.netloc, path, "", ""))


def validate_stage(state, nonce, source_sha, *, claimed=False, candidate_id=None, lease_id=None):
    if (state.get("protocol_version") != 1 or state.get("nonce") != nonce
            or state.get("source_sha") != source_sha or state.get("terminal") is True):
        raise ValueError("VM stage identity is absent, stale or terminal")
    expected = "action_claimed" if claimed else "awaiting_candidate"
    if state.get("stage") != expected:
        raise ValueError(f"Expected VM stage {expected}, got {state.get('stage')}")
    snapshot = state.get("snapshot", {})
    editing = snapshot.get("input", {})
    if (editing.get("text") != TEXT or editing.get("selectionBase") != 20
            or editing.get("selectionExtent") != 20 or editing.get("composingBase") != 11
            or editing.get("composingExtent") != 20
            or snapshot.get("editor_primary_focus") is not True
            or snapshot.get("send_count") != 1
            or snapshot.get("send_enabled_semantics") != "isFalse"
            or not isinstance(snapshot.get("view_insets_bottom_physical"), (int, float))
            or snapshot["view_insets_bottom_physical"] <= 0):
        raise ValueError("Live VM input/focus/composition/keyboard/Send state changed")
    if claimed and (state.get("can_click") is not True
                    or not isinstance(lease_id, str) or not lease_id
                    or state.get("candidate_id") != candidate_id
                    or state.get("lease_id") != lease_id
                    or not isinstance(state.get("lease_remaining_ms"), (int, float))
                    or state["lease_remaining_ms"] < 1500):
        raise ValueError("Native click lease is stale, mismatched or too close to expiry")


class Runner:
    def __init__(self, args):
        self.args = args
        self.output = args.output.resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self.nonce = uuid.uuid4().hex
        self.token = uuid.uuid4().hex + uuid.uuid4().hex
        self.children = []
        self.handles = []
        self.command_sequence = 0
        self.lock = threading.RLock()
        self.deadline = time.monotonic() + 1200
        self.native_url = None
        self.vm_url = None
        self.isolate = None
        self.app_identity = None
        self.inspection = None
        self.inspected_at = None
        self.click_attempted = False
        self.trace_attempted = False
        self.forward = None
        self.server = None
        self.server_thread = None
        self.helper_reader = None
        self.http_errors = []
        self.active = True
        self.native_stopped = False
        self.owned_packages = set()
        self.report = {"schema_version": 1, "scope": "manual_original_journey_with_one_native_IME_candidate_tap",
                       "source_sha": args.source_sha, "nonce": self.nonce, "status": "started",
                       "application_acceptance": "not_accepted", "human_IME_acceptance": "not_accepted",
                       "original_android_gate_changed": False, "errors": [], "cleanup_errors": []}
        write_json(self.output / "owner.json", {"pid": os.getpid(), "nonce": self.nonce,
                                               "source_sha": args.source_sha, "device": args.device})

    def checkpoint(self):
        write_json(self.output / "summary.json", self.report)

    def sources(self, label):
        # Unrelated generated workspace targets are recorded, not confused with
        # this Android experiment's actual source, package, and driver inputs.
        self.command(["git", "status", "--porcelain=v1", "--untracked-files=normal"],
                     "workspace-status-" + label)
        self.command(["git", "diff", "--exit-code", "HEAD", "--", *SOURCE_SCOPES],
                     "relevant-source-clean-" + label)
        names = self.command(["git", "ls-files", "-z", "--", *SOURCE_SCOPES],
                             "relevant-source-files-" + label).split("\0")
        inputs = {name: digest(ROOT / name) for name in names if name}
        package_config = ROOT / ".dart_tool/package_config.json"
        inputs[str(package_config.relative_to(ROOT))] = digest(package_config)
        write_json(self.output / ("source-inputs-" + label + ".json"), inputs)
        return inputs

    def command(self, argv, name, *, timeout=5, check=True):
        with self.lock:
            self.command_sequence += 1
            identifier = f"{self.command_sequence:03d}-{name}"
        record = {"argv": argv, "timeout_seconds": timeout, "started_epoch_ns": time.time_ns()}
        child = None
        primary_error = None
        try:
            child = start_owned_process(argv, stdin=subprocess.DEVNULL,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.children.append(child)
            stdout, stderr = child.communicate(timeout=timeout)
            (self.output / (identifier + ".stdout")).write_bytes(stdout)
            (self.output / (identifier + ".stderr")).write_bytes(stderr)
            record["exit_code"] = child.returncode
            if check and child.returncode:
                raise RuntimeError(f"{name} exited {child.returncode}: {stderr.decode(errors='replace')[-1500:]}")
            return stdout.decode("utf-8", errors="replace")
        except BaseException as error:
            primary_error = error
            if isinstance(error, subprocess.TimeoutExpired):
                (self.output / (identifier + ".stdout")).write_bytes(error.output or b"")
                (self.output / (identifier + ".stderr")).write_bytes(error.stderr or b"")
            record["error"] = f"{type(error).__name__}: {error}"
            raise
        finally:
            try:
                if child is not None:
                    stop_owned_process(child, grace=1, kill_timeout=2)
            except Exception as error:
                record["cleanup_error"] = str(error)
                self.report["cleanup_errors"].append(f"{name}: {error}")
                if primary_error is None:
                    raise
            finally:
                if child is not None:
                    for stream in (child.stdout, child.stderr):
                        if stream is not None:
                            stream.close()
                record["ended_epoch_ns"] = time.time_ns()
                write_json(self.output / (identifier + ".json"), record)

    def adb(self, *arguments, name, timeout=5, check=True):
        return self.command([self.args.adb, "-s", self.args.device, *arguments], name,
                            timeout=timeout, check=check)

    def spawn(self, argv, name, *, env=None):
        log = (self.output / (name + ".log")).open("wb")
        self.handles.append(log)
        child = start_owned_process(argv, cwd=CATALOG, env=env,
                                    stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
        self.children.append(child)
        return child

    def request_json(self, url, payload=None, *, timeout=1):
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *_args, **_kwargs):
                raise RuntimeError("Diagnostic loopback transport must not redirect")
        body = None if payload is None else json.dumps(payload).encode()
        request = urllib.request.Request(url, data=body,
                                         headers={"Content-Type": "application/json"})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        with opener.open(request, timeout=timeout) as response:
            raw = response.read(MAX_JSON + 1)
        if len(raw) > MAX_JSON:
            raise RuntimeError("Protocol response exceeded the evidence bound")
        return json.loads(raw)

    def native(self, route, payload=None, *, timeout=1):
        if self.native_url is None:
            raise RuntimeError("Native helper has no owned forwarded endpoint")
        value = self.request_json(self.native_url + route,
                                  {"nonce": self.nonce, **(payload or {})}, timeout=timeout)
        if value.get("source_sha") != self.args.source_sha or value.get("protocol_version") != 1:
            raise RuntimeError("Native helper response source/protocol mismatch")
        return value

    def state(self):
        if self.vm_url is None:
            raise RuntimeError("Driver did not attach a VM service")
        query = urllib.parse.urlencode({"isolateId": self.isolate, "action": "state", "nonce": self.nonce,
                                       "source_sha": self.args.source_sha})
        reply = self.request_json(self.vm_url + EXTENSION + "?" + query)
        if reply.get("error") is not None:
            raise RuntimeError(f"VM service refused state query: {reply['error']}")
        return reply.get("result", reply)

    def process_identity(self, package):
        raw = self.adb("shell", "pidof", package, name="pid-" + package.rsplit(".", 1)[-1], timeout=1, check=False)
        if not re.fullmatch(r"\s*[1-9][0-9]*\s*", raw):
            raise RuntimeError(f"Expected one running owned {package} process, got {raw!r}")
        pid = int(raw)
        stat = self.adb("shell", "run-as", package, "cat", f"/proc/{pid}/stat", name="start-ticks", timeout=1)
        if not stat.startswith(str(pid) + " ("):
            raise RuntimeError("Android process identity response mismatched")
        ticks = int(stat[stat.rfind(")") + 2:].split()[19])
        return {"package": package, "pid": pid, "start_ticks": ticks}

    def attach(self, body):
        if self.vm_url is not None:
            raise RuntimeError("Only one VM attachment is allowed")
        if body.get("nonce") != self.nonce or body.get("source_sha") != self.args.source_sha:
            raise RuntimeError("Driver attachment identity mismatch")
        self.vm_url = checked_vm_url(body["vm_service_url"])
        self.isolate = body["isolate_id"]
        if not isinstance(self.isolate, str) or not self.isolate.startswith("isolates/"):
            raise RuntimeError("Driver did not provide an observed app isolate")
        self.app_identity = self.process_identity(APP)
        if body.get("vm_pid") != self.app_identity["pid"]:
            raise RuntimeError("VM PID is not the owned Catalog process")
        self.report["app_process"] = self.app_identity
        self.report["vm_service_endpoint_sha256"] = hashlib.sha256(self.vm_url.encode()).hexdigest()
        self.checkpoint()
        return {"ok": True}

    def inspect_native(self):
        if not self.active:
            raise RuntimeError("Native action authorization has been revoked")
        if self.inspection is not None:
            raise RuntimeError("A native candidate inspection ticket already exists")
        if self.process_identity(APP) != self.app_identity:
            raise RuntimeError("Catalog process changed before native inspection")
        before = self.state()
        validate_stage(before, self.nonce, self.args.source_sha)
        write_json(self.output / "vm-before-native-inspect.json", before)
        started = time.monotonic()
        candidate = self.native("/inspect", timeout=1)
        write_json(self.output / "native-inspection.json", candidate)
        if candidate.get("ok") is not True:
            raise RuntimeError(f"Native candidate inspection failed: {candidate.get('error')}")
        if (not candidate.get("candidate_id") or candidate.get("focused_app_package") != APP
                or not candidate.get("ime_package") or not candidate.get("ime_component")
                or not isinstance(candidate.get("expires_at_device_ms"), int)
                or not isinstance(candidate.get("device_elapsed_ms"), int)
                or not 0 < candidate["expires_at_device_ms"] - candidate["device_elapsed_ms"] <= 2000):
            raise RuntimeError("Native candidate ticket is incomplete or expired")
        self.inspection, self.inspected_at = candidate, started
        return candidate

    def click_native(self, body):
        if not self.active:
            raise RuntimeError("Native action authorization has been revoked")
        if self.click_attempted:
            raise RuntimeError("Native candidate tap is never retried")
        if self.inspection is None or time.monotonic() - self.inspected_at > 1.4:
            raise RuntimeError("Native candidate inspection is missing or stale")
        if body.get("nonce") != self.nonce or body.get("source_sha") != self.args.source_sha:
            raise RuntimeError("Native action identity mismatch")
        candidate = body.get("candidate", {})
        claim = body.get("claim", {})
        if candidate.get("candidate_id") != self.inspection["candidate_id"]:
            raise RuntimeError("Driver changed the native candidate identity")
        fresh = self.state()
        write_json(self.output / "vm-immediately-before-native-tap.json", fresh)
        validate_stage(fresh, self.nonce, self.args.source_sha, claimed=True,
                       candidate_id=self.inspection["candidate_id"], lease_id=claim.get("lease_id"))
        if time.monotonic() - self.inspected_at > 1.4:
            raise RuntimeError("Candidate expired while revalidating the VM lease")
        # The device rejects expired invocations. Android may then block inside
        # injection; only its completed response/serial STOP proves drain.
        self.click_attempted = True
        self.report["native_tap_attempts"] = 1
        self.checkpoint()
        response = self.native("/tap", {"candidate_id": self.inspection["candidate_id"]}, timeout=1)
        self.report["native_call_drained"] = True
        write_json(self.output / "native-tap.json", response)
        if (response.get("ok") is not True or response.get("injected_down") is not True
                or response.get("injected_up") is not True or response.get("cancelled") is not False
                or response.get("used_candidate_id") != self.inspection["candidate_id"]):
            raise RuntimeError(f"Native candidate tap failed: {response.get('error')}")
        self.report["native_tap"] = response
        self.checkpoint()
        return {**response, "clicked": True, "native_drained": True}

    def abort(self, body):
        if body.get("nonce") != self.nonce or body.get("source_sha") != self.args.source_sha:
            raise RuntimeError("Abort identity mismatch")
        self.active = False
        result = {"ok": True, "native_authorization_revoked": True,
                  "native_drained": self.report.get("native_call_drained", False)}
        if self.native_url and not self.native_stopped:
            try:
                # The helper processes requests serially. Its STOP response
                # proves a preceding injection call has actually returned;
                # HTTP timeout by itself is never called a native cancellation.
                reply = self.native("/stop", timeout=35)
                if reply.get("ok") is not True:
                    raise RuntimeError(str(reply))
                self.native_stopped = True
                result["native_helper_stopped"] = True
                result["native_drained"] = True
            except Exception as error:
                result["secondary_error"] = f"{type(error).__name__}: {error}"
                result["native_drained"] = False
                result["drain_scope"] = "unverified; owned fresh emulator teardown required before any later run"
                self.report["cleanup_errors"].append("Driver abort: " + result["secondary_error"])
        self.report["driver_abort"] = {**result, "reason": body.get("error")}
        self.checkpoint()
        return result

    def serve(self):
        owner = self
        class Handler(BaseHTTPRequestHandler):
            def setup(self):
                super().setup()
                self.connection.settimeout(2)

            def log_message(self, *_args):
                pass

            def do_GET(self):
                self.dispatch(None)

            def do_POST(self):
                try:
                    length = int(self.headers.get("Content-Length", "-1"))
                    if not 0 < length <= 65536:
                        raise ValueError("Invalid protocol Content-Length")
                    self.connection.settimeout(2)
                    body = self.rfile.read(length)
                    if len(body) != length:
                        raise ValueError("Truncated protocol request")
                    self.dispatch(json.loads(body))
                except Exception as error:
                    self.respond(400, {"ok": False, "error": str(error)})

            def respond(self, status, body):
                encoded = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)

            def dispatch(self, body):
                if self.headers.get("Authorization") != "Bearer " + owner.token:
                    self.respond(403, {"ok": False, "error": "Unauthorized diagnostic request"})
                    return
                try:
                    with owner.lock:
                        if self.path == "/abort" and self.command == "POST":
                            result = owner.abort(body)
                        elif not owner.active:
                            raise RuntimeError("Native action authorization has been revoked")
                        elif self.path == "/attach" and self.command == "POST":
                            result = owner.attach(body)
                        elif self.path == "/native/inspect" and self.command == "GET":
                            result = owner.inspect_native()
                        elif self.path == "/native/click" and self.command == "POST":
                            result = owner.click_native(body)
                        else:
                            raise ValueError("Unknown diagnostic operation")
                    self.respond(200, result)
                except Exception as error:
                    with owner.lock:
                        owner.http_errors.append({"path": self.path, "error": f"{type(error).__name__}: {error}"})
                        write_json(owner.output / "host-protocol-errors.json", owner.http_errors)
                    self.respond(409, {"ok": False, "error": f"{type(error).__name__}: {error}"})
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = False
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        return f"http://127.0.0.1:{self.server.server_port}"

    def start_native_helper(self):
        command = [self.args.adb, "-s", self.args.device, "shell", "am", "instrument", "-w", "-r",
                   "-e", "nonce", self.nonce, "-e", "source_sha", self.args.source_sha,
                   HELPER + "/.ProbeInstrumentation"]
        child = start_owned_process(command, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.children.append(child)
        fields = {}
        ready = threading.Event()
        log = (self.output / "native-instrumentation.log").open("wb")
        self.handles.append(log)
        def read():
            for line in iter(child.stdout.readline, b""):
                log.write(line)
                log.flush()
                match = re.match(rb"INSTRUMENTATION_STATUS: ([a-z_]+)=(.*)\r?\n", line)
                if match:
                    fields[match.group(1).decode()] = match.group(2).decode().strip()
                    if all(key in fields for key in ("port", "source_sha", "nonce", "pid")):
                        ready.set()
        self.helper_reader = threading.Thread(target=read, daemon=True)
        self.helper_reader.start()
        if not ready.wait(20) or child.poll() is not None:
            raise RuntimeError("Native instrumentation did not expose a live owned endpoint")
        if fields["source_sha"] != self.args.source_sha or fields["nonce"] != self.nonce:
            raise RuntimeError("Native instrumentation source/nonce differs")
        port = int(fields["port"])
        if not 1024 <= port <= 65535:
            raise RuntimeError("Native instrumentation returned an invalid port")
        identity = self.process_identity(HELPER)
        if identity["pid"] != int(fields["pid"]):
            raise RuntimeError("Instrumentation reported a different Android process")
        self.report["helper_process"] = identity
        allocated = self.adb("forward", "tcp:0", f"tcp:{port}", name="forward-owned-helper").strip()
        if not allocated.isdigit() or not 1024 <= int(allocated) <= 65535:
            raise RuntimeError("ADB did not allocate an owned helper forward")
        self.forward = "tcp:" + allocated
        self.native_url = "http://127.0.0.1:" + allocated

    def execute(self):
        if sys.platform != "linux" or os.environ.get("GITHUB_ACTIONS") != "true":
            raise RuntimeError("Live execution requires the fresh Linux GitHub Actions emulator")
        if not re.fullmatch(r"[0-9a-f]{40}", self.args.source_sha):
            raise ValueError("An exact source SHA is required")
        actual = self.command(["git", "rev-parse", "HEAD"], "source-head").strip()
        if actual != self.args.source_sha:
            raise RuntimeError("Checkout differs from requested source")
        self.report["source_inputs_before"] = self.sources("before")
        sdk = json.loads(self.command([self.args.flutter, "--version", "--machine"], "flutter-sdk", timeout=15))
        if sdk.get("frameworkRevision") != "4cf24164269a5ebf0c16a028a00727d0e77bbb05":
            raise RuntimeError("Diagnostic requires the pinned Flutter 3.47 SDK source")
        self.report["flutter_sdk"] = sdk
        helper = json.loads(self.args.helper_report.read_text())
        if (helper.get("source_sha") != self.args.source_sha
                or helper.get("apk_sha256", helper.get("sha256")) != digest(self.args.helper_apk)):
            raise RuntimeError("Fresh helper APK does not match its source build report")
        self.report["helper_build"] = helper
        for package in (APP, HELPER):
            existing = self.adb("shell", "pm", "path", package, name="require-fresh-" + package.rsplit(".", 1)[-1], check=False)
            if existing.strip():
                raise RuntimeError(f"Fresh emulator already contains {package}")
        self.report["device_fingerprint"] = self.adb("shell", "getprop", "ro.build.fingerprint", name="fingerprint").strip()
        self.report["initial_ime"] = self.adb("shell", "settings", "get", "secure", "default_input_method", name="ime-component").strip()
        self.adb("shell", "ime", "list", "-s", name="ime-list")
        self.adb("shell", "dumpsys", "input_method", name="input-method-before", timeout=10)
        self.adb("shell", "atrace", "--list_categories", name="atrace-categories")
        self.owned_packages.add(HELPER)
        self.adb("install", "-t", str(self.args.helper_apk.resolve()), name="install-fresh-helper", timeout=30)
        self.start_native_helper()
        host_url = self.serve()
        self.spawn([self.args.adb, "-s", self.args.device, "logcat", "-v", "monotonic"], "android-logcat")
        self.trace_attempted = True
        self.adb("shell", "atrace", "--async_start", "-b", "16384", "input", name="atrace-start", timeout=10)
        self.adb("shell", "cat", "/sys/kernel/tracing/trace_clock", name="trace-clock", check=False)
        environment = {**os.environ, "ANDROID_CANDIDATE_HOST_URL": host_url,
                       "ANDROID_CANDIDATE_HOST_TOKEN": self.token, "ANDROID_CANDIDATE_NONCE": self.nonce,
                       "ANDROID_CANDIDATE_SOURCE_SHA": self.args.source_sha,
                       "BEAUTIFUL_INPUT_EVIDENCE": str(self.output / "driver")}
        command = [self.args.flutter, "drive", "--driver=integration_test/driver/catalog_android_candidate_driver.dart",
                   "--target=integration_test/catalog_android_candidate_test.dart", "--device-id=" + self.args.device,
                   "--dart-define=CATALOG_ANDROID_CANDIDATE=true",
                   "--dart-define=CATALOG_ANDROID_CANDIDATE_NONCE=" + self.nonce,
                   "--dart-define=CATALOG_ANDROID_CANDIDATE_SOURCE_SHA=" + self.args.source_sha,
                   "--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false",
                   "--no-pub"]
        self.report["flutter_command"] = command
        self.checkpoint()
        self.owned_packages.add(APP)
        flutter = self.spawn(command, "flutter-drive", env=environment)
        self.report["flutter_exit_code"] = flutter.wait(timeout=max(1, self.deadline - time.monotonic()))
        if flutter.returncode:
            raise RuntimeError(f"Original full journey/driver exited {flutter.returncode}")
        driver_path = self.output / "driver/driver-summary.json"
        driver = json.loads(driver_path.read_text())
        self.report["driver_summary"] = driver
        if (driver.get("status") != "passed" or driver.get("all_tests_passed") is not True
                or driver.get("source_sha") != self.args.source_sha
                or driver.get("nonce") != self.nonce or not self.report.get("native_tap")
                or self.report.get("native_tap_attempts") != 1 or self.http_errors):
            raise RuntimeError("Required complete driver/native candidate evidence is absent")
        self.report["source_inputs_after"] = self.sources("after")
        if self.report["source_inputs_before"] != self.report["source_inputs_after"]:
            raise RuntimeError("Relevant Android experiment inputs changed during execution")
        self.report["status"] = "original_full_journey_with_native_candidate_observed"

    def finish(self):
        # Every cleanup step runs independently. Never let later cleanup replace
        # the primary driver/native failure, or infer cleanup from leader exit.
        def clean(label, action):
            try:
                action()
            except Exception as error:
                self.report["cleanup_errors"].append(f"{label}: {type(error).__name__}: {error}")
        with self.lock:
            self.active = False
        if self.server:
            clean("host server shutdown", self.server.shutdown)
            clean("host request drain", self.server.server_close)
        if self.trace_attempted:
            def stop_trace():
                raw = self.adb("exec-out", "atrace", "--async_stop", name="atrace-stop", timeout=15)
                (self.output / "input-connection.atrace").write_text(raw)
                if self.app_identity:
                    pid = str(self.app_identity["pid"])
                    entries = [line for line in raw.splitlines()
                               if "InputConnection#" in line and re.search(r"(?:-|\|)" + pid + r"(?:\s|\|)", line)]
                    (self.output / "input-connection-app-slices.txt").write_text("\n".join(entries) + "\n")
                    if not any("InputConnection#commitText" in line or "InputConnection#finishComposingText" in line
                               for line in entries):
                        raise RuntimeError("No owned-app native commit/finish dispatch slice was captured")
            clean("stock input trace", stop_trace)
        if self.native_url and not self.native_stopped:
            def stop_native():
                reply = self.native("/stop", timeout=2)
                if reply.get("ok") is not True:
                    raise RuntimeError(str(reply))
                self.native_stopped = True
            clean("native helper stop", stop_native)
        for package in sorted(self.owned_packages):
            def stop_app(package=package):
                self.adb("shell", "am", "force-stop", package, name="stop-owned-" + package.rsplit(".", 1)[-1])
                live = self.adb("shell", "pidof", package, name="verify-stopped", check=False).strip()
                if live:
                    raise RuntimeError(f"Owned Android process remains: {package}: {live}")
            clean(package + " cleanup", stop_app)
        if HELPER in self.owned_packages:
            def preserve_native_events():
                raw = self.adb("exec-out", "run-as", HELPER, "cat", "files/probe-events.jsonl",
                               name="native-private-event-log", timeout=5, check=False)
                (self.output / "native-helper-events.jsonl").write_text(raw)
                if self.native_url is not None and not raw.strip():
                    raise RuntimeError("Started native helper did not retain its complete event log")
            clean("native event evidence", preserve_native_events)
        if self.forward:
            clean("owned adb forward", lambda: self.adb("forward", "--remove", self.forward, name="remove-owned-forward"))
        for child in reversed(self.children):
            clean("host process group", lambda child=child: stop_owned_process(child, grace=1, kill_timeout=2))
        if self.helper_reader:
            self.helper_reader.join(timeout=3)
            if self.helper_reader.is_alive():
                self.report["cleanup_errors"].append("Native helper output reader did not stop")
        for handle in self.handles:
            clean("evidence handle", handle.close)
        self.report["host_protocol_errors"] = self.http_errors
        app_apk = CATALOG / "build/app/outputs/flutter-apk/app-debug.apk"
        if app_apk.is_file():
            self.report["catalog_test_apk"] = {"path": str(app_apk), "sha256": digest(app_apk),
                                               "bytes": app_apk.stat().st_size}
        self.report["cleanup"] = "verified" if not self.report["cleanup_errors"] else "failed"
        if self.report["errors"] or self.report["cleanup_errors"]:
            self.report["status"] = "failed"
        self.checkpoint()
        files = {str(path.relative_to(self.output)): {"sha256": digest(path), "bytes": path.stat().st_size}
                 for path in sorted(self.output.rglob("*")) if path.is_file() and path.name != "artifact-manifest.json"}
        write_json(self.output / "artifact-manifest.json", {"source_sha": self.args.source_sha, "files": files})
        return 0 if self.report["status"] == "original_full_journey_with_native_candidate_observed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--helper-apk", type=Path, required=True)
    parser.add_argument("--helper-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--device", default="emulator-5554", choices=("emulator-5554",))
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--flutter", default="flutter")
    args = parser.parse_args()
    runner = Runner(args)
    try:
        runner.execute()
    except BaseException as error:
        runner.report["errors"].append(f"{type(error).__name__}: {error}")
        runner.checkpoint()
    return runner.finish()


if __name__ == "__main__":
    raise SystemExit(main())
