"""Read-only Linux process/pressure evidence for real Edge startup diagnostics.

Default group ownership preserves the standalone three-session experiment.
Adapter ownership is restricted to one PID/start-time identity and descendants.
No browser commands, executable pre-reading, process mutation, or timeout changes.
"""

import json
import os
from pathlib import Path
import threading
import time


def owned_pids(rows, group, root_identity=None):
    # The adapter may share its shell's process group. Root identity avoids
    # observing the Flutter tool, shell, or unrelated siblings in that group.
    if root_identity is None:
        owned = {row["pid"] for row in rows if row["pgrp"] == group}
    else:
        owned = {row["pid"] for row in rows
                 if (row["pid"], row["start_ticks"]) == root_identity}
    while True:
        children = {row["pid"] for row in rows if row["ppid"] in owned}
        if children <= owned:
            return owned
        owned |= children


def proc_row(pid, details=False):
    directory = Path("/proc") / str(pid)
    stat = (directory / "stat").read_text()
    fields = stat[stat.rindex(")") + 2:].split()
    row = {"pid": pid, "state": fields[0], "ppid": int(fields[1]),
           "pgrp": int(fields[2]), "minflt": int(fields[7]), "majflt": int(fields[9]),
           "utime_ticks": int(fields[11]),
           "stime_ticks": int(fields[12]), "start_ticks": int(fields[19]),
           "rss_pages": int(fields[21])}
    if not details:
        return row
    try:
        row["exe"] = os.readlink(directory / "exe")
        row["argv"] = (directory / "cmdline").read_bytes()[:16384].decode(
            "utf-8", errors="replace").rstrip("\0").split("\0")
    except OSError as error:
        row["identity_error"] = str(error)
    for name in ("schedstat", "wchan", "cgroup"):
        try:
            row[name] = (directory / name).read_text()[:4096].strip()
        except OSError as error:
            row[name] = {"unavailable": str(error)}
    try:
        row["io"] = {name: int(value) for name, value in (
            line.split(":", 1) for line in (directory / "io").read_text().splitlines())}
    except (OSError, ValueError) as error:
        row["io"] = {"unavailable": str(error)}
    return row


class ResourceSampler:
    """Read /proc once per second; no browser commands or tracing attachment."""
    def __init__(self, group, output, *, root_pid=None):
        self.group, self.output = group, output
        self.root_identity = (root_pid, proc_row(root_pid)["start_ticks"]) if root_pid is not None else None
        self.stop_event = threading.Event()
        self.error = None
        self.executables = set()
        self.observed_processes = set()
        self.thread = threading.Thread(target=self.run, name="edge-resource-observer", daemon=True)
        self.thread.start()

    def snapshot(self):
        rows = []
        for directory in Path("/proc").iterdir():
            if directory.name.isdigit():
                try:
                    rows.append(proc_row(int(directory.name)))
                except (OSError, ValueError, IndexError):
                    pass  # Process may exit between /proc listing and reading.
        owned = owned_pids(rows, self.group, self.root_identity)
        processes = []
        for row in rows:
            if row["pid"] in owned:
                try:
                    detailed = proc_row(row["pid"], details=True)
                    if detailed["start_ticks"] == row["start_ticks"]:
                        processes.append(detailed)
                except (OSError, ValueError, IndexError):
                    pass
        self.executables.update(row["exe"] for row in processes if row.get("exe"))
        self.observed_processes.update((row["pid"], row["start_ticks"]) for row in processes)
        metrics = {}
        for path in ("/proc/loadavg", "/proc/meminfo", "/proc/pressure/cpu",
                     "/proc/pressure/memory", "/proc/pressure/io",
                     "/sys/fs/cgroup/memory.events", "/sys/fs/cgroup/memory.current",
                     "/sys/fs/cgroup/memory.max", "/sys/fs/cgroup/cpu.stat",
                     "/sys/fs/cgroup/cpu.max"):
            try:
                metrics[path] = Path(path).read_text()[:8192]
            except OSError as error:
                metrics[path] = {"unavailable": str(error)}
        try:
            shm = os.statvfs("/dev/shm")
            metrics["/dev/shm"] = {"bytes": shm.f_blocks * shm.f_frsize,
                                   "available_bytes": shm.f_bavail * shm.f_frsize}
        except OSError as error:
            metrics["/dev/shm"] = {"unavailable": str(error)}
        return {"epoch": time.time(), "monotonic": time.monotonic(),
                "processes": processes, "metrics": metrics}

    def run(self):
        previous = set()
        try:
            with self.output.open("x") as log:
                for _ in range(3000):
                    sample = self.snapshot()
                    current = {(row["pid"], row["start_ticks"]) for row in sample["processes"]}
                    sample["appeared"] = sorted(current - previous)
                    # Disappearance is observation, not an inferred exit code.
                    sample["no_longer_observed"] = sorted(previous - current)
                    previous = current
                    log.write(json.dumps(sample) + "\n")
                    log.flush()
                    if self.stop_event.wait(1):
                        return
                raise RuntimeError("Resource observation reached its 3000-sample bound")
        except Exception as error:
            self.error = f"{type(error).__name__}: {error}"

    def stop_observing(self):
        """Stop read-only collection; this makes no process-cleanup claim."""
        self.stop_event.set()
        self.thread.join(timeout=3)
        if self.thread.is_alive():
            raise RuntimeError("Resource observer did not stop")
        if self.error:
            raise RuntimeError(self.error)
    def close(self):
        self.stop_observing()
        survivors = []
        for pid, start_ticks in self.observed_processes:
            try:
                row = proc_row(pid)
                if row["start_ticks"] == start_ticks and row["state"] != "Z":
                    survivors.append(row)
            except (OSError, ValueError, IndexError):
                pass
        if survivors:
            raise RuntimeError(f"Observed owned descendants survived group cleanup: {survivors}")
