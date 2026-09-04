#!/usr/bin/env python3
"""Experimental, CI-only real-Orca evidence for three ordinary Flutter Catalog tasks.

This does not change a release gate or grant human/application acceptance.
--describe and importing this module are safe without a desktop. All live modes
require Linux and GITHUB_ACTIONS=true; there is deliberately no local override.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import wave

from probe_real_at_linux import Probe
from owned_pty_capture import OwnedPtyCapture
from run_catalog_input_acceptance import start_owned_process, stop_owned_process


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "packages/beautiful_ai_ui_catalog"
TASKS = (
    {"id": "theme_keyboard_toggle", "target": "Theme: system",
     "result": "Focused button becomes Theme: light after Space"},
    {"id": "thinking_disclosure", "target": "Hide steps thinking details",
     "result": "Space collapses exactly one trace; Space restores it"},
    {"id": "search_query_and_selection", "target": "Search flavors",
     "result": "Keyboard query cone, focus result, Return commits Find waffle cone suppliers"},
)
RESULT = "Find waffle cone suppliers"
SEARCH_RESULTS = (
    "Forecast summer demand", RESULT, "Compare seasonal flavors",
    "Draft flavor launch plan", "Check cold-chain status", "Audit sugar costs",
    "Retire low sellers",
)
LAYERS = ("native_accessibility", "keyboard_action", "orca_command",
          "utterance_output", "synthesized_audio", "application_result")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def require_ci() -> None:
    if sys.platform != "linux" or os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Live execution requires a disposable Linux GitHub Actions runner")


def source_inventory() -> dict[str, str]:
    paths = set()
    for folder in (ROOT / "packages/shadcn_flutter/lib", ROOT / "packages/shadcn_flutter/assets",
                   ROOT / "packages/beautiful_ai_ui/lib", ROOT / "packages/beautiful_ai_ui/assets",
                   CATALOG / "lib", CATALOG / "assets", CATALOG / "linux"):
        paths.update(p for p in folder.rglob("*") if p.is_file()
                     and "flutter/ephemeral" not in p.as_posix())
    paths.update(ROOT / name for name in (
        "pubspec.yaml", "pubspec.lock", ".dart_tool/package_config.json",
        "packages/beautiful_ai_ui/pubspec.yaml", "packages/beautiful_ai_ui_catalog/pubspec.yaml",
        "packages/shadcn_flutter/pubspec.yaml",
        ".github/scripts/probe_catalog_orca_linux.py", ".github/scripts/probe_real_at_linux.py",
        ".github/scripts/owned_pty_capture.py",
        ".github/scripts/run_catalog_input_acceptance.py", ".github/scripts/run_ios_catalog_journey.py",
    ))
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def bundle_inventory(bundle: Path) -> dict[str, str]:
    return {str(p.relative_to(bundle)): sha(p) for p in sorted(bundle.rglob("*")) if p.is_file()}


def build_catalog(output: Path, flutter: str) -> int:
    require_ci()
    output.mkdir(parents=True, exist_ok=False)
    before = source_inventory()
    command = [flutter, "build", "linux", "--release", "--no-pub", "--target=lib/main.dart"]
    report = {"schema_version": 1, "status": "not_bound", "command": command,
              "cwd": str(CATALOG), "source_sha256_before": before}
    try:
        with (output / "build.log").open("wb") as log:
            child = start_owned_process(command, cwd=CATALOG, stdin=subprocess.DEVNULL,
                                        stdout=log, stderr=subprocess.STDOUT)
            try:
                report["exit_code"] = child.wait(timeout=600)
            finally:
                stop_owned_process(child, grace=2, kill_timeout=2)
        report["source_sha256_after"] = source_inventory()
        if report["exit_code"] or report["source_sha256_after"] != before:
            raise RuntimeError("Build failed or source/configuration changed during compilation")
        candidates = list((CATALOG / "build/linux").glob("*/release/bundle/beautiful_ai_ui_catalog"))
        if len(candidates) != 1:
            raise RuntimeError(f"Expected exactly one release Catalog executable, found {candidates}")
        executable = candidates[0].resolve()
        report.update(status="compiled_snapshot_bound", executable=str(executable),
                      bundle_sha256=bundle_inventory(executable.parent),
                      git_head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                      flutter=json.loads(subprocess.check_output([flutter, "--version", "--machine"], text=True)))
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
    write_json(output / "build-provenance.json", report)
    print(json.dumps({"status": report["status"], "report": str(output / "build-provenance.json")}))
    return 0 if report["status"] == "compiled_snapshot_bound" else 2


def read_interface_text(atspi, interface) -> str:
    """Read text through the GI text interface without changing app state."""
    count = atspi.Text.get_character_count(interface)
    return atspi.Text.get_text(interface, 0, min(count, 1024))


def parent_chain_evidence(subject, known_nodes, frames, maximum=32) -> dict:
    """Observe actual upward edges and reciprocal getters; never alter the tree."""
    def identity(node):
        known = known_nodes.get(node)
        if known is not None:
            return {key: known[key] for key in ("path", "name", "role", "pid")}
        return {"path": None, "name": node.get_name() or "", "role": node.get_role_name(),
                "pid": node.get_process_id()}

    result = {"chain": [], "links": [], "frame_reached": False,
              "parent_ended_before_frame": False, "cycle": False,
              "truncated": False, "errors": []}
    seen = set()
    current = subject
    try:
        for _ in range(maximum):
            if current in seen:
                result["cycle"] = True
                break
            seen.add(current)
            child_identity = identity(current)
            result["chain"].append(child_identity)
            if current in frames:
                result["frame_reached"] = True
                break
            parent = current.get_parent()
            if parent is None:
                result["parent_ended_before_frame"] = True
                break
            parent_identity = identity(parent)
            index = current.get_index_in_parent()
            count = parent.get_child_count()
            if count < 0:
                raise RuntimeError(f"Native parent returned invalid child count: {count}")
            valid_index = 0 <= index < count
            index_matches = parent.get_child_at_index(index) == current if valid_index else None
            found_index = index if index_matches else None
            if found_index is None:
                # AtkSocket may leave its optional index vfunc unsupported.
                # Preserve that reported value and prove the inverse using the
                # parent's real getters rather than inventing an index.
                for candidate in range(min(count, 512)):
                    if valid_index and candidate == index:
                        continue
                    if parent.get_child_at_index(candidate) == current:
                        found_index = candidate
                        break
            path, parent_path = child_identity["path"], parent_identity["path"]
            result["links"].append({
                "child": child_identity, "parent": parent_identity,
                "index_reported_by_child": index, "parent_child_count": count,
                "reported_index_child_matches": index_matches,
                "index_observed_in_parent": found_index,
                "parent_child_getter_matches": found_index is not None,
                "parent_child_scan_truncated": found_index is None and count > 512,
                "bfs_parent_matches": path[:-1] == parent_path if path and parent_path is not None else None,
            })
            current = parent
        else:
            result["truncated"] = True
    except Exception as error:
        result["errors"].append(f"{type(error).__name__}: {error}")
    return result


def inspect_catalog(pid: int) -> None:
    """Read only. No AT-SPI focus, action, selection or text mutation APIs."""
    import gi
    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi

    desktop = Atspi.get_desktop(0)
    applications = []
    selected = []
    errors = []
    desktop_count = desktop.get_child_count()
    if desktop_count > 64:
        errors.append(f"Application limit: {desktop_count}")
    for index in range(min(desktop_count, 64)):
        app = desktop.get_child_at_index(index)
        app_pid = app.get_process_id()
        applications.append({"name": app.get_name(), "pid": app_pid})
        if app_pid == pid:
            selected.append((app, (index,)))
    pending = selected[:]
    nodes = []
    known_nodes = {}
    while pending and len(nodes) < 4096:
        node, path = pending.pop(0)
        try:
            state = node.get_state_set()
            record = {"path": list(path), "name": node.get_name() or "",
                      "role": node.get_role_name(), "pid": node.get_process_id()}
            for label, flag in (
                ("focused", Atspi.StateType.FOCUSED), ("selected", Atspi.StateType.SELECTED),
                ("expanded", Atspi.StateType.EXPANDED), ("expandable", Atspi.StateType.EXPANDABLE),
                ("showing", Atspi.StateType.SHOWING), ("enabled", Atspi.StateType.ENABLED),
                ("editable", Atspi.StateType.EDITABLE),
            ):
                record[label] = state.contains(flag)
            if record["editable"] or record["focused"]:
                try:
                    text = node.get_text_iface()
                    if text is not None:
                        record["text"] = read_interface_text(Atspi, text)
                except Exception as error:
                    record["text_read_error"] = str(error)
            nodes.append(record)
            known_nodes[node] = record
            count = node.get_child_count()
            if count > 512:
                errors.append(f"Child limit at {path}: {count}")
            pending.extend((node.get_child_at_index(i), path + (i,)) for i in range(min(count, 512)))
        except Exception as error:
            errors.append(f"{path}: {type(error).__name__}: {error}")
    frames = {node for node, record in known_nodes.items()
              if record["pid"] == pid and record["role"] in ("frame", "window", "dialog")}
    subjects = [node for node, record in known_nodes.items()
                if record["focused"] or record["name"].startswith("Theme:")
                or record["name"] in ("Hide steps thinking details", "Show steps thinking details",
                                      "Search flavors", RESULT)]
    parents = [parent_chain_evidence(node, known_nodes, frames) for node in subjects[:12]]
    print(json.dumps({"target_pid": pid, "applications": applications, "nodes": nodes,
                      "truncated": bool(pending) or any("limit" in error.lower() for error in errors),
                      "errors": errors[:32], "parent_chain_evidence": parents,
                      "parent_chain_subjects_omitted": max(0, len(subjects) - 12),
                      "parent_chain_scope": "Supplemental read-only diagnostics; original task acceptance predicates are unchanged"}))


def audio_statistics(raw: bytes) -> dict:
    samples = array.array("h")
    samples.frombytes(raw[:len(raw) // 2 * 2])
    if sys.byteorder != "little":
        samples.byteswap()
    return {"frames": len(samples), "rms": math.sqrt(sum(x * x for x in samples) / len(samples)) if samples else 0,
            "sample_rate": 16000, "channels": 1, "sample_format": "s16le"}


class CatalogProbe(Probe):
    def __init__(self, output: Path, seconds: int, provenance: Path):
        self.root = output.resolve()
        self.root.mkdir(parents=True, exist_ok=False)
        super().__init__(self.root / "capability-preflight", seconds)
        self.named_children = {}
        self.orca_capture = None
        self.current_task = None
        self.provenance = provenance.resolve()
        self.app = {
            "schema_version": 1, "scope": "three_representative_flutter_catalog_tasks",
            "status": "not_observed", "application_acceptance": "not_accepted",
            "human_review": {"status": "not_accepted", "reason": "No human listened to or accepted these tasks"},
            "all_components_accepted": False, "all_platform_release_accepted": False,
            "tasks": [{**task, "status": "not_observed", "layers": {x: "not_observed" for x in LAYERS},
                       "commands": [], "reader_checkpoints": [], "errors": []} for task in TASKS],
            "errors": [], "input_method": "OS X11 keyboard via xdotool, not Flutter test events or AT-SPI actions",
            "observation_method": "PID-scoped read-only AT-SPI, real Orca handler/debug output, isolated real speech PCM",
        }

    def spawn(self, argv, name, *, stdout=None):
        if name == "orca":
            debug_files = [arg.split("=", 1)[1] for arg in argv if arg.startswith("--debug-file=")]
            if len(debug_files) != 1 or stdout is not None:
                raise RuntimeError("The pilot requires exactly one owned Orca debug destination")
            debug_path = Path(debug_files[0])
            command = ["--debug-file=/dev/stdout" if arg.startswith("--debug-file=") else arg for arg in argv]
            error_log = (self.output / "orca.log").open("wb")
            self.handles.append(error_log)
            self.orca_capture = OwnedPtyCapture(command, debug_path, env=self.env, stderr=error_log)
            child = self.orca_capture.process
            self.children.append(child)
            self.app["orca_debug_transport"] = {
                "kind": "owned_raw_pty", "producer_debug_file": "/dev/stdout",
                "captured_log": str(debug_path.relative_to(self.root)),
                "content_policy": "Original diagnostic bytes; no injected utterances or handler records",
            }
        else:
            child = super().spawn(argv, name, stdout=stdout)
        self.named_children[name] = child
        return child

    def stop(self, child):
        if self.orca_capture is not None and child is self.orca_capture.process:
            self.orca_capture.close(grace=1, kill_timeout=1)
        else:
            super().stop(child)

    def checkpoint(self) -> None:
        write_json(self.root / "catalog-report.json", self.app)

    def alive(self) -> None:
        if self.orca_capture is not None and self.orca_capture.error is not None:
            raise RuntimeError(f"Real Orca diagnostic capture failed: {self.orca_capture.error}")
        dead = {name: self.named_children[name].poll() for name in
                ("pulseaudio", "speech-dispatcher", "orca", "catalog")
                if name in self.named_children and self.named_children[name].poll() is not None}
        if dead:
            raise RuntimeError(f"Required real process exited: {dead}")

    def snapshot(self, label: str | None = None) -> dict:
        self.alive()
        result = self.run([sys.executable, str(Path(__file__).resolve()), "--inspect-pid", str(self.catalog.pid)], timeout=8)
        data = json.loads(result.stdout)
        write_json(self.root / "last-native-tree.json", data)
        if label:
            write_json(self.root / f"{label}-native-tree.json", data)
        if data["errors"] or data["truncated"]:
            raise RuntimeError(f"Incomplete AT-SPI snapshot: truncated={data['truncated']}, errors={data['errors']}")
        return data

    def wait_snapshot(self, predicate, label: str, seconds: int = 8) -> dict:
        latest = None
        def check():
            nonlocal latest
            latest = self.snapshot()
            return predicate(latest)
        self.wait_for(check, seconds)
        write_json(self.root / f"{label}-native-tree.json", latest)
        return latest

    @staticmethod
    def target(tree: dict, name: str, *, focused: bool = False):
        for node in tree["nodes"]:
            if node["name"] != name:
                continue
            if not focused or node["focused"]:
                return node
            # Thinking intentionally preserves child semantics. Its single
            # control may own a genuinely focused child; never use ancestor
            # View focus or invent a focused flag on the named button.
            if name in ("Hide steps thinking details", "Show steps thinking details"):
                for child in tree["nodes"]:
                    if (child["focused"] and child["showing"]
                            and child["pid"] == node["pid"] == tree["target_pid"]
                            and len(child["path"]) > len(node["path"])
                            and child["path"][:len(node["path"])] == node["path"]):
                        return {**node, "observed_focused_descendant": child}
        return None

    def key(self, key: str) -> None:
        self.alive()
        start = time.time_ns()
        self.run(["xdotool", "key", "--clearmodifiers", key])
        entry = {"kind": "key", "key": key, "start_epoch_ns": start, "end_epoch_ns": time.time_ns()}
        if self.current_task is not None:
            self.current_task["commands"].append(entry)
        self.checkpoint()

    def focus_by_tab(self, name: str, maximum: int = 96) -> dict:
        for count in range(maximum + 1):
            tree = self.snapshot()
            node = self.target(tree, name, focused=True)
            if node:
                if not node["showing"]:
                    raise RuntimeError(f"Focused target is not exposed as showing: {name}")
                self.current_task.setdefault("keyboard_focus_matches", []).append(node)
                return tree
            if count == maximum:
                break
            self.key("Tab")
            time.sleep(self.remaining(0.12))
            self.current_task["commands"][-1]["focused_before_next_tab"] = [
                {"name": x["name"], "role": x["role"], "text": x.get("text")}
                for x in self.snapshot()["nodes"] if x["focused"]]
        raise RuntimeError(f"Target not reached using at most {maximum} Tab keys: {name}")

    def audio_quiet(self, pcm_path: Path, start_bytes: int, debug_start: int) -> dict:
        """Require measured silence and no new speech text, not a fixed sleep."""
        last_speech = None
        last_change = time.monotonic()
        observed = {}
        def quiet():
            nonlocal last_speech, last_change, observed
            self.alive()
            speech = [line for line in self.debug.read_bytes()[debug_start:].decode(errors="replace").splitlines()
                      if "SPEECH OUTPUT:" in line]
            marker = (len(speech), speech[-1] if speech else None)
            if marker != last_speech:
                last_speech, last_change = marker, time.monotonic()
            size = pcm_path.stat().st_size
            if size - start_bytes < 16000:
                return False
            with pcm_path.open("rb") as stream:
                stream.seek(max(start_bytes, size - 16000))
                tail = audio_statistics(stream.read())
            observed = {"pcm_byte_offset": size, "tail": tail,
                        "speech_text_quiet_seconds": time.monotonic() - last_change}
            return tail["frames"] >= 8000 and tail["rms"] < 20 and observed["speech_text_quiet_seconds"] >= 0.6
        self.wait_for(quiet, 12)
        return observed

    def where_am_i(self, label: str, expected_text: str, still_valid) -> None:
        pcm_path = self.root / f"{label}.pcm"
        stream = pcm_path.open("wb")
        self.handles.append(stream)
        recorder = self.spawn(["parec", "--device=at_probe.monitor", "--format=s16le",
                               "--rate=16000", "--channels=1", "--raw"], label + "-audio", stdout=stream)
        start = self.debug.stat().st_size
        command_pcm_start = 0
        quiet_before = None
        quiet_after = None
        clients = ""
        failure = None
        try:
            quiet_before = self.audio_quiet(pcm_path, 0, start)
            command_pcm_start = pcm_path.stat().st_size
            start = self.debug.stat().st_size
            self.key("KP_Enter")
            handler = "KEYBOARD EVENT: Handler is Perform the basic Where Am I operation"
            def said_it():
                text = self.debug.read_bytes()[start:].decode(errors="replace")
                after_handler = text.partition(handler)[2]
                return bool(after_handler) and any(expected_text.casefold() in line.casefold()
                                                   for line in after_handler.splitlines() if "SPEECH OUTPUT:" in line)
            self.wait_for(said_it, 8)
            def speech_client_ready():
                nonlocal clients
                clients = self.run(["pactl", "list", "sink-inputs"], check=False).stdout
                return set(re.findall(r'application.name = "([^"]+)"', clients)) == {"speech-dispatcher-espeak-ng"}
            self.wait_for(speech_client_ready, 5)
            quiet_after = self.audio_quiet(pcm_path, command_pcm_start, start)
        except Exception as error:
            failure = error
        finally:
            self.stop(recorder)
            stream.flush()
            stream.close()
        text = self.debug.read_bytes()[start:].decode(errors="replace")
        (self.root / f"{label}-orca-command.log").write_text(text, encoding="utf-8")
        after_handler = text.partition("KEYBOARD EVENT: Handler is Perform the basic Where Am I operation")[2]
        utterances = [line for line in after_handler.splitlines() if "SPEECH OUTPUT:" in line]
        (self.root / f"{label}-utterances.log").write_text("\n".join(utterances) + "\n", encoding="utf-8")
        raw = pcm_path.read_bytes()
        audio = audio_statistics(raw[command_pcm_start:])
        with wave.open(str(self.root / f"{label}.wav"), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(raw[command_pcm_start:])
        after = self.snapshot(label + "-after-reader-command")
        check = {"label": label, "expected_text": expected_text, "utterances": utterances,
                 "orca_handler_observed": "KEYBOARD EVENT: Handler is Perform the basic Where Am I operation" in text,
                 "expected_utterance_observed": any(expected_text.casefold() in line.casefold() for line in utterances),
                 "audio": audio, "audio_clients": clients,
                 "audio_quiet_before": quiet_before, "audio_quiet_after": quiet_after,
                 "command_pcm_start_byte": command_pcm_start,
                 "audio_association": "Post-key PCM after a measured quiet baseline and ordered Orca handler/utterance; words still require human listening",
                 "audio_client_names": re.findall(r'application.name = "([^"]+)"', clients),
                 "application_state_unchanged_by_reader_command": bool(still_valid(after)),
                 "reader_pid": self.named_children["orca"].pid,
                 "speechd_pid": self.named_children["speech-dispatcher"].pid,
                 "catalog_pid": self.catalog.pid}
        self.current_task["reader_checkpoints"].append(check)
        self.checkpoint()
        self.alive()
        if failure:
            raise failure
        if not (check["orca_handler_observed"] and check["expected_utterance_observed"]
                and check["application_state_unchanged_by_reader_command"]
                and quiet_before is not None and quiet_after is not None
                and set(check["audio_client_names"]) == {"speech-dispatcher-espeak-ng"}
                and audio["frames"] >= 1600 and audio["rms"] >= 20):
            raise RuntimeError(f"Incomplete real reader/utterance/audio/app-state evidence: {label}")

    def theme(self) -> None:
        before = self.focus_by_tab("Theme: system")
        write_json(self.root / "theme-before-native-tree.json", before)
        self.key("space")
        expected = lambda tree: self.target(tree, "Theme: light", focused=True) is not None
        self.wait_snapshot(expected, "theme-after")
        self.where_am_i("theme-light", "Theme: light", expected)

    def disclosure(self) -> None:
        before = self.focus_by_tab("Hide steps thinking details")
        write_json(self.root / "disclosure-before-native-tree.json", before)
        node = self.target(before, "Hide steps thinking details", focused=True)
        if not node["expanded"]:
            raise RuntimeError("Initial steps disclosure did not expose expanded=true")
        def traces(tree):
            return sum("Reading flavor briefs" in x["name"] for x in tree["nodes"])
        count = traces(before)
        if count < 1 or before["truncated"]:
            raise RuntimeError("Cannot observe the original steps trace in an untruncated native tree")
        self.current_task["initial_repeated_trace_label_count"] = count
        self.key("space")
        def collapsed(tree):
            current = self.target(tree, "Show steps thinking details", focused=True)
            return current is not None and not current["expanded"] and traces(tree) == count - 1 and not tree["truncated"]
        self.wait_snapshot(collapsed, "disclosure-collapsed")
        self.where_am_i("disclosure-collapsed", "Show steps thinking details", collapsed)
        self.key("space")
        def expanded(tree):
            current = self.target(tree, "Hide steps thinking details", focused=True)
            return current is not None and current["expanded"] and traces(tree) == count and not tree["truncated"]
        self.wait_snapshot(expanded, "disclosure-restored")
        self.where_am_i("disclosure-restored", "Hide steps thinking details", expanded)

    def search(self) -> None:
        before = self.focus_by_tab("Search flavors")
        write_json(self.root / "search-before-native-tree.json", before)
        self.key("ctrl+a")
        started = time.time_ns()
        self.run(["xdotool", "type", "--clearmodifiers", "--delay", "80", "cone"])
        self.current_task["commands"].append({"kind": "typed_text", "text": "cone",
                                              "start_epoch_ns": started, "end_epoch_ns": time.time_ns()})
        def filtered(tree):
            field = self.target(tree, "Search flavors", focused=True)
            results = [x["name"] for x in tree["nodes"] if x["name"] in SEARCH_RESULTS]
            return field is not None and field.get("text") == "cone" and results == [RESULT]
        self.wait_snapshot(filtered, "search-filtered")
        self.focus_by_tab(RESULT, maximum=8)
        self.where_am_i("search-result", RESULT,
                        lambda tree: self.target(tree, RESULT, focused=True) is not None)
        self.key("Return")
        def committed(tree):
            field = self.target(tree, "Search flavors", focused=True)
            return field is not None and field.get("text") == RESULT
        self.wait_snapshot(committed, "search-committed")
        self.where_am_i("search-committed", RESULT, committed)
        self.current_task["result_boundary"] = "Search committed its selected title; Catalog's demo onSelected callback performs no navigation"

    def execute_catalog(self) -> None:
        require_ci()
        provenance = json.loads(self.provenance.read_text())
        if provenance.get("status") != "compiled_snapshot_bound":
            raise RuntimeError("A successful --build-only provenance record is required")
        executable = Path(provenance["executable"])
        if not executable.is_file() or not os.access(executable, os.X_OK):
            raise RuntimeError("Compiled Catalog executable is absent or not executable")
        if provenance["source_sha256_after"] != source_inventory():
            raise RuntimeError("Source/configuration changed after the recorded build")
        if provenance["bundle_sha256"] != bundle_inventory(executable.parent):
            raise RuntimeError("Compiled bundle changed after the recorded build")
        self.app["build_provenance_sha256"] = sha(self.provenance)
        shutil.copyfile(self.provenance, self.root / "build-provenance.json")
        try:
            super().execute()  # Existing real GTK capability preflight and private services.
        finally:
            # Preserve partial capability evidence even if startup or its task fails.
            write_json(self.output / "preflight-report.json", self.report)
        if self.report["status"] != "capability_observed":
            raise RuntimeError("Existing real-Orca capability preflight did not succeed")
        self.stop(self.named_children["fixture"])
        self.debug = self.output / "orca-debug.log"
        self.app["runtime"] = self.report["runtime"]
        self.app["gtk_preflight"] = "observed separately; not evidence that Catalog tasks passed"
        self.output = self.root
        self.catalog = self.spawn([str(executable)], "catalog")
        self.app["processes"] = {name: {"pid": process.pid, "argv": process.args}
                                 for name, process in self.named_children.items()
                                 if name in ("catalog", "orca", "speech-dispatcher", "pulseaudio")}
        window = None
        def find_window():
            nonlocal window
            result = self.run(["xdotool", "search", "--onlyvisible", "--pid", str(self.catalog.pid),
                               "--name", "^beautiful_ai_ui_catalog$"], check=False, timeout=2)
            values = result.stdout.splitlines()
            window = values[0] if values else None
            return window is not None
        self.wait_for(find_window, 25)
        self.run(["xdotool", "windowsize", "--sync", window, "1280", "1000"])
        self.run(["xdotool", "windowfocus", "--sync", window])
        self.app["window_id"] = window
        self.app["native_window_geometry"] = self.run(["xdotool", "getwindowgeometry", "--shell", window]).stdout
        self.wait_snapshot(lambda tree: self.target(tree, "Theme: system") is not None,
                           "catalog-initial", seconds=20)
        for task, action in zip(self.app["tasks"], (self.theme, self.disclosure, self.search)):
            self.current_task = task
            task["start_epoch_ns"] = time.time_ns()
            try:
                action()
                task["layers"] = {name: "observed" for name in LAYERS}
                task["status"] = "machine_evidence_observed"
            except Exception as error:
                task["errors"].append(f"{type(error).__name__}: {error}")
                try:
                    self.snapshot(task["id"] + "-failure")
                except Exception as snapshot_error:
                    task["errors"].append(f"Failure snapshot: {snapshot_error}")
            task["end_epoch_ns"] = time.time_ns()
            self.checkpoint()
        self.current_task = None
        self.app["source_unchanged_since_build"] = provenance["source_sha256_after"] == source_inventory()
        self.app["bundle_unchanged_during_tasks"] = provenance["bundle_sha256"] == bundle_inventory(executable.parent)
        if (all(task["status"] == "machine_evidence_observed" for task in self.app["tasks"])
                and self.app["source_unchanged_since_build"] and self.app["bundle_unchanged_during_tasks"]):
            self.app["status"] = "three_task_machine_evidence_observed"

    def finish_catalog(self) -> int:
        for child in reversed(self.children):
            try:
                self.stop(child)
            except Exception as error:
                self.app["errors"].append(f"Owned process cleanup: {error}")
        for handle in self.handles:
            try:
                if not handle.closed:
                    handle.close()
            except Exception as error:
                self.app["errors"].append(f"Evidence handle cleanup: {error}")
        try:
            self.runtime.cleanup()
        except Exception as error:
            self.app["errors"].append(f"Private runtime cleanup: {error}")
        if self.app["errors"]:
            self.app["status"] = "not_observed"
        if self.orca_capture is not None:
            self.app["orca_debug_transport"].update({
                "bytes_captured": self.orca_capture.bytes_written,
                "eof_verified": self.orca_capture.eof,
                "reader_stopped": not self.orca_capture.reader_alive,
                "capture_error": str(self.orca_capture.error) if self.orca_capture.error else None,
            })
        self.app["elapsed_seconds"] = round(time.monotonic() - self.started, 3)
        self.app["cleanup"] = "verified" if not any("cleanup:" in error for error in self.app["errors"]) else "failed"
        self.checkpoint()
        files = {str(p.relative_to(self.root)): {"sha256": sha(p), "bytes": p.stat().st_size}
                 for p in sorted(self.root.rglob("*")) if p.is_file() and p.name != "artifact-manifest.json"}
        write_json(self.root / "artifact-manifest.json", {"schema_version": 1, "files": files})
        print(json.dumps({"status": self.app["status"], "application_acceptance": "not_accepted",
                          "human_review": "not_accepted", "report": str(self.root / "catalog-report.json")}))
        return 0 if self.app["status"] == "three_task_machine_evidence_observed" else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--describe", action="store_true", help="Print the bounded plan without launching processes")
    parser.add_argument("--build-only", action="store_true", help="Build the ordinary release entry and record matching source/bundle hashes")
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--build-provenance", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seconds", type=int, default=240, choices=range(90, 301), metavar="90..300")
    parser.add_argument("--inspect-pid", type=int, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.describe:
        print(json.dumps({"status": "prepared_not_executed", "tasks": TASKS, "human_review": "not_accepted",
                          "application_acceptance": "not_accepted", "live_execution": "Linux GitHub Actions only"}, indent=2))
        return 0
    require_ci()
    if args.inspect_pid is not None:
        inspect_catalog(args.inspect_pid)
        return 0
    if args.output is None:
        parser.error("--output must name a fresh directory")
    if args.build_only:
        return build_catalog(args.output.resolve(), args.flutter)
    if args.build_provenance is None:
        parser.error("--build-provenance from --build-only is required")
    probe = CatalogProbe(args.output, args.seconds, args.build_provenance)
    try:
        probe.execute_catalog()
    except Exception as error:
        probe.app["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        result = probe.finish_catalog()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
