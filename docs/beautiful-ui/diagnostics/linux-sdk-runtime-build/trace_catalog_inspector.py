#!/usr/bin/env python3
"""Trace unchanged Catalog AT-SPI reads in a separate, manifest-bound diagnostic.

The fixed fixture and its build provenance are never edited. This diagnostic
instruments the three original read functions, records its own source binding,
and keeps the original process ownership, traversal, eight-second snapshot
deadline, tasks and predicates. It cannot grant application or human acceptance.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import inspect
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


READS = frozenset(("get_desktop", "get_child_count", "get_child_at_index",
                  "get_process_id", "get_name", "get_state_set", "get_role_name",
                  "contains", "get_text_iface", "get_character_count", "get_text",
                  "get_parent", "get_index_in_parent"))
FUNCTIONS = ("read_interface_text", "parent_chain_evidence", "inspect_catalog")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def process_start_ticks(pid):
    # /proc comm may contain spaces and parentheses. Field 22 follows the last
    # closing parenthesis and is index 19 in the remaining fields (starting at 3).
    stat = Path(f"/proc/{pid}/stat").read_text()
    return int(stat[stat.rfind(")") + 2:].split()[19])


def capture_stacks(original, probe, expected_start):
    """One bounded debugger attachment after a failure; never acceptance evidence."""
    root = probe.root / "first-timeout-stacks"
    root.mkdir(exist_ok=False)
    pid = probe.catalog.pid
    report = {"scope": "debugger_may_pause_process_not_acceptance", "pid": pid,
              "expected_start_ticks": expected_start, "errors": []}
    child = None
    try:
        if process_start_ticks(pid) != expected_start:
            raise RuntimeError("Catalog PID start time changed; refusing debugger attachment")
        report["loaded_engine"] = original.verify_loaded_engine(
            pid, probe.runtime_context["engine_library"]["sha256"])
        threads = []
        for task in sorted(Path(f"/proc/{pid}/task").iterdir()):
            record = {"tid": int(task.name)}
            for name in ("stat", "wchan", "stack"):
                try:
                    record[name] = (task / name).read_text()
                except OSError as error:
                    record[name + "_error"] = f"{type(error).__name__}: {error}"
            threads.append(record)
        original.write_json(root / "threads-before-debugger.json", threads)
        if process_start_ticks(pid) != expected_start:
            raise RuntimeError("Catalog PID changed during thread inspection")
        command = ["gdb", "--batch", "-nx", "-nh", "-ex", "set pagination off",
                   "-ex", "set confirm off", "-ex", "set debuginfod enabled off", "-ex", f"attach {pid}",
                   "-ex", "thread apply all bt", "-ex", "detach", "-ex", "quit"]
        report["command"] = command
        with (root / "gdb.log").open("wb") as log:
            child = original.start_owned_process(command, stdin=subprocess.DEVNULL,
                                                 stdout=log, stderr=subprocess.STDOUT)
            probe.children.append(child)  # The original finalizer owns a fallback cleanup attempt.
            try:
                report["gdb_exit_code"] = child.wait(timeout=12)
            finally:
                original.stop_owned_process(child, grace=2, kill_timeout=2)
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        # Normal 'detach' resumes the inferior. If a timed-out debugger exited
        # while it was stopped, restore only this verified owned process so the
        # original supervisor can finish its normal cleanup.
        try:
            if process_start_ticks(pid) != expected_start:
                raise RuntimeError("Catalog PID changed before debugger cleanup check")
            status = Path(f"/proc/{pid}/status").read_text()
            state = next(line for line in status.splitlines() if line.startswith("State:"))
            report["catalog_state_after_debugger"] = state
            if state.split()[1] in ("T", "t"):
                os.kill(pid, signal.SIGCONT)
                report["owned_catalog_resumed_for_cleanup"] = True
        except Exception as error:
            report["errors"].append(f"Debugger cleanup check: {type(error).__name__}: {error}")
        original.write_json(root / "report.json", report)
    return report


class ReadTrace:
    def __init__(self, path):
        self.stream = Path(path).open("x", encoding="utf-8", buffering=1)
        self.sequence = 0

    def emit(self, record):
        self.stream.write(json.dumps(record, ensure_ascii=False) + "\n")
        self.stream.flush()

    def call(self, method, source_line, function, context, original, *args, **kwargs):
        self.sequence += 1
        sequence = self.sequence
        started = time.monotonic_ns()
        # Only existing Python metadata is read here. Never call a GI getter
        # to identify the object whose getter might itself be stuck.
        where = {key: context[key] for key in ("path", "index", "candidate", "i")
                 if key in context and isinstance(context[key], (int, tuple, list))}
        identity = context.get("child_identity")
        if isinstance(identity, dict):
            where["child_identity"] = identity
        record = {"sequence": sequence, "method": method, "source_line": source_line,
                  "function": function, "context": where, "epoch_ns": time.time_ns()}
        self.emit({**record, "phase": "before"})
        try:
            result = original(*args, **kwargs)
        except BaseException as error:
            self.emit({**record, "phase": "error", "elapsed_ns": time.monotonic_ns() - started,
                       "error": f"{type(error).__name__}: {error}"})
            raise
        self.emit({**record, "phase": "after", "elapsed_ns": time.monotonic_ns() - started,
                   "result_type": type(result).__name__})
        return result


class InstrumentReads(ast.NodeTransformer):
    def __init__(self, function, first_line):
        self.function = function
        self.first_line = first_line
        self.count = 0

    def visit_Call(self, node):
        self.generic_visit(node)
        if not isinstance(node.func, ast.Attribute) or node.func.attr not in READS:
            return node
        self.count += 1
        replacement = ast.Call(
            func=ast.Attribute(value=ast.Name(id="_read_trace", ctx=ast.Load()),
                               attr="call", ctx=ast.Load()),
            args=[ast.Constant(node.func.attr), ast.Constant(self.first_line + node.lineno - 1),
                  ast.Constant(self.function), ast.Call(func=ast.Name(id="locals", ctx=ast.Load()),
                                                       args=[], keywords=[]),
                  node.func, *node.args], keywords=node.keywords)
        return ast.copy_location(replacement, node)


def instrument(module, trace):
    module.__dict__["_read_trace"] = trace
    counts = {}
    for name in FUNCTIONS:
        lines, first_line = inspect.getsourcelines(getattr(module, name))
        tree = ast.parse("".join(lines))
        transformer = InstrumentReads(name, first_line)
        tree = transformer.visit(tree)
        ast.fix_missing_locations(tree)
        exec(compile(tree, str(module.__file__), "exec"), module.__dict__)
        counts[name] = transformer.count
    return counts


def load_fixture(root):
    sys.path.insert(0, str(root / ".github/scripts"))
    import probe_catalog_orca_linux as original
    if original.ROOT != root:
        raise RuntimeError("Imported fixture does not match the explicit root")
    return original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-root", type=Path, default=Path("/work/catalog"))
    parser.add_argument("--sdk-runtime-manifest", type=Path, required=True)
    parser.add_argument("--build-provenance", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seconds", type=int, default=240, choices=range(90, 301))
    parser.add_argument("--inspect-pid", type=int)
    parser.add_argument("--trace-file", type=Path)
    parser.add_argument("--expected-probe-sha256")
    parser.add_argument("--capture-stacks-on-timeout", action="store_true",
                        help="After the first original timeout, inspect threads and attach gdb once; diagnostic only")
    args = parser.parse_args()
    original = load_fixture(args.catalog_root.resolve())
    original.require_execution(args.sdk_runtime_manifest, inspect_only=args.inspect_pid is not None)
    probe_sha = digest(original.__file__)
    if args.inspect_pid is not None:
        if args.trace_file is None or args.expected_probe_sha256 != probe_sha:
            parser.error("Inspector requires a fresh trace and the bound original probe hash")
        trace = ReadTrace(args.trace_file)
        try:
            counts = instrument(original, trace)
            trace.emit({"phase": "instrumented", "read_sites": counts,
                        "original_probe_sha256": probe_sha, "diagnostic_sha256": digest(__file__)})
            original.inspect_catalog(args.inspect_pid)
            trace.emit({"phase": "complete"})
        finally:
            trace.stream.close()
        return 0
    if args.output is None or args.build_provenance is None:
        parser.error("Diagnostic launch requires fresh --output and existing --build-provenance")

    class DiagnosticProbe(original.CatalogProbe):
        sequence = 0
        start_ticks = None
        stack_capture_attempted = False

        def snapshot(self, label=None):
            self.alive()
            if self.start_ticks is None:
                self.start_ticks = process_start_ticks(self.catalog.pid)
            self.sequence += 1
            trace = self.root / f"inspector-{self.sequence:04d}.jsonl"
            command = [sys.executable, str(Path(__file__).resolve()),
                       "--catalog-root", str(original.ROOT), "--inspect-pid", str(self.catalog.pid),
                       "--sdk-runtime-manifest", str(self.runtime_manifest),
                       "--trace-file", str(trace), "--expected-probe-sha256", probe_sha]
            try:
                result = self.run(command, timeout=8)
            except subprocess.TimeoutExpired:
                if args.capture_stacks_on_timeout and not self.stack_capture_attempted:
                    self.stack_capture_attempted = True
                    # Preserve the original timeout as the task's first error.
                    # Debugger failures are secondary records, never a pass.
                    try:
                        self.app["post_timeout_stack_diagnostic"] = capture_stacks(
                            original, self, self.start_ticks)
                    except Exception as error:
                        self.app["post_timeout_stack_diagnostic"] = {
                            "secondary_error": f"{type(error).__name__}: {error}"}
                raise
            data = json.loads(result.stdout)
            original.write_json(self.root / "last-native-tree.json", data)
            if label:
                original.write_json(self.root / f"{label}-native-tree.json", data)
            if data["errors"] or data["truncated"]:
                raise RuntimeError(f"Incomplete AT-SPI snapshot: truncated={data['truncated']}, errors={data['errors']}")
            return data

    probe = DiagnosticProbe(args.output, args.seconds, args.build_provenance, args.sdk_runtime_manifest)
    probe.app["scope"] = "unchanged_fixture_inspector_call_trace_diagnostic"
    probe.app["diagnostic_binding"] = {
        "diagnostic_source_sha256": digest(__file__), "original_probe_sha256": probe_sha,
        "runtime_manifest_sha256": digest(args.sdk_runtime_manifest),
        "build_provenance_sha256": digest(args.build_provenance),
        "original_snapshot_timeout_seconds": 8,
        "debugger_after_first_timeout": args.capture_stacks_on_timeout,
        "acceptance": "Diagnostic only; no ordinary application, release, or human acceptance",
    }
    (probe.root / "trace_catalog_inspector.py").write_bytes(Path(__file__).read_bytes())
    try:
        probe.execute_catalog()
    except Exception as error:
        probe.app["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        result = probe.finish_catalog()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
