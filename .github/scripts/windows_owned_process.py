"""Own Windows subprocess descendants with a private, non-inheritable Job Object.

The leader starts suspended, enters the job, then resumes through documented
Toolhelp/OpenThread/ResumeThread APIs. No descendant can start before assignment.
The job survives an exited leader; cleanup checks the job's ActiveProcesses.
See https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects.
"""

import ctypes
import os
import subprocess
import time
import weakref


# Fixed-width Windows ABI types also keep this module importable on POSIX.
DWORD = ctypes.c_uint32
LONG = ctypes.c_int32
HANDLE = ctypes.c_void_p
SIZE_T = ctypes.c_size_t
BOOL = ctypes.c_int32
CREATE_SUSPENDED = 0x00000004
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION = 1
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9
ERROR_NO_MORE_FILES = 18
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


class _BasicLimits(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_int64),
        ("PerJobUserTimeLimit", ctypes.c_int64),
        ("LimitFlags", DWORD),
        ("MinimumWorkingSetSize", SIZE_T),
        ("MaximumWorkingSetSize", SIZE_T),
        ("ActiveProcessLimit", DWORD),
        ("Affinity", SIZE_T),
        ("PriorityClass", DWORD),
        ("SchedulingClass", DWORD),
    ]


class _IoCounters(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint64) for name in (
        "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
        "ReadTransferCount", "WriteTransferCount", "OtherTransferCount",
    )]


class _ExtendedLimits(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", _BasicLimits),
        ("IoInfo", _IoCounters),
        ("ProcessMemoryLimit", SIZE_T),
        ("JobMemoryLimit", SIZE_T),
        ("PeakProcessMemoryUsed", SIZE_T),
        ("PeakJobMemoryUsed", SIZE_T),
    ]


class _Accounting(ctypes.Structure):
    _fields_ = [
        ("TotalUserTime", ctypes.c_int64),
        ("TotalKernelTime", ctypes.c_int64),
        ("ThisPeriodTotalUserTime", ctypes.c_int64),
        ("ThisPeriodTotalKernelTime", ctypes.c_int64),
        ("TotalPageFaultCount", DWORD),
        ("TotalProcesses", DWORD),
        ("ActiveProcesses", DWORD),
        ("TotalTerminatedProcesses", DWORD),
    ]


class _ThreadEntry(ctypes.Structure):
    _fields_ = [
        ("dwSize", DWORD), ("cntUsage", DWORD), ("th32ThreadID", DWORD),
        ("th32OwnerProcessID", DWORD), ("tpBasePri", LONG),
        ("tpDeltaPri", LONG), ("dwFlags", DWORD),
    ]


def _kernel32():
    if os.name != "nt":
        raise RuntimeError("Windows-owned processes require Windows")
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    signatures = {
        "CreateJobObjectW": ([ctypes.c_void_p, ctypes.c_wchar_p], HANDLE),
        "SetInformationJobObject": ([HANDLE, ctypes.c_int, ctypes.c_void_p, DWORD], BOOL),
        "QueryInformationJobObject": (
            [HANDLE, ctypes.c_int, ctypes.c_void_p, DWORD, ctypes.POINTER(DWORD)], BOOL),
        "AssignProcessToJobObject": ([HANDLE, HANDLE], BOOL),
        "TerminateJobObject": ([HANDLE, DWORD], BOOL),
        "OpenProcess": ([DWORD, BOOL, DWORD], HANDLE),
        "CloseHandle": ([HANDLE], BOOL),
        "CreateToolhelp32Snapshot": ([DWORD, DWORD], HANDLE),
        "Thread32First": ([HANDLE, ctypes.POINTER(_ThreadEntry)], BOOL),
        "Thread32Next": ([HANDLE, ctypes.POINTER(_ThreadEntry)], BOOL),
        "OpenThread": ([DWORD, BOOL, DWORD], HANDLE),
        "GetProcessIdOfThread": ([HANDLE], DWORD),
        "ResumeThread": ([HANDLE], DWORD),
    }
    for name, (arguments, result) in signatures.items():
        function = getattr(api, name)
        function.argtypes = arguments
        function.restype = result
    return api


def _checked(result, operation):
    if not result:
        error = ctypes.WinError(ctypes.get_last_error())
        raise OSError(f"{operation}: {error}") from error
    return result


class _Job:
    def __init__(self):
        self.api = _kernel32()
        self.handle = _checked(self.api.CreateJobObjectW(None, None), "CreateJobObjectW")
        self.confirmed_empty = False
        # No inheritable security attributes or job name: only this owner holds it.
        self._finalizer = weakref.finalize(self, self.api.CloseHandle, self.handle)
        limits = _ExtendedLimits()
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        try:
            _checked(self.api.SetInformationJobObject(
                self.handle, JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
                ctypes.byref(limits), ctypes.sizeof(limits)), "SetInformationJobObject")
        except BaseException:
            self.close()
            raise

    def active_processes(self):
        if self.handle is None:
            raise RuntimeError("Cannot query a closed Job Object")
        accounting = _Accounting()
        _checked(self.api.QueryInformationJobObject(
            self.handle, JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION,
            ctypes.byref(accounting), ctypes.sizeof(accounting), None),
            "QueryInformationJobObject")
        return accounting.ActiveProcesses

    def close(self):
        if self.handle is not None:
            _checked(self.api.CloseHandle(self.handle), "CloseHandle(job)")
            self.handle = None
            self._finalizer.detach()


def _resume_primary_thread(api, pid):
    # Popen closes CreateProcess's primary thread handle. Since CREATE_SUSPENDED
    # has kept that thread from executing, it is the process's only thread.
    snapshot = api.CreateToolhelp32Snapshot(0x00000004, 0)  # TH32CS_SNAPTHREAD
    if snapshot == INVALID_HANDLE_VALUE:
        _checked(False, "CreateToolhelp32Snapshot")
    try:
        entry = _ThreadEntry()
        entry.dwSize = ctypes.sizeof(entry)
        found = []
        available = api.Thread32First(snapshot, ctypes.byref(entry))
        while available:
            if entry.th32OwnerProcessID == pid:
                found.append(entry.th32ThreadID)
            entry.dwSize = ctypes.sizeof(entry)
            available = api.Thread32Next(snapshot, ctypes.byref(entry))
        if ctypes.get_last_error() != ERROR_NO_MORE_FILES:
            _checked(False, "Thread32First/Thread32Next")
    finally:
        _checked(api.CloseHandle(snapshot), "CloseHandle(snapshot)")
    if len(found) != 1:
        raise RuntimeError(f"Expected one suspended primary thread for PID {pid}; found {found}")
    # THREAD_SUSPEND_RESUME | THREAD_QUERY_LIMITED_INFORMATION. Recheck ownership
    # on the opened handle in case an external actor terminated the process.
    thread = _checked(api.OpenThread(0x0002 | 0x0800, False, found[0]), "OpenThread")
    try:
        owner = _checked(api.GetProcessIdOfThread(thread), "GetProcessIdOfThread")
        if owner != pid:
            raise RuntimeError(f"Primary thread no longer belongs to PID {pid}")
        previous_count = api.ResumeThread(thread)
        if previous_count == 0xFFFFFFFF:
            _checked(False, "ResumeThread")
        if previous_count != 1:
            raise RuntimeError(f"Unexpected primary thread suspend count: {previous_count}")
    finally:
        _checked(api.CloseHandle(thread), "CloseHandle(thread)")


def start_owned_process(argv, **kwargs):
    """Return a normal Popen tagged with its private Job Object ownership."""
    job = _Job()
    process = None
    assigned = False
    try:
        kwargs["creationflags"] = kwargs.get("creationflags", 0) | CREATE_SUSPENDED
        process = subprocess.Popen(argv, **kwargs)
        process._owned_job = job
        process._owned_cleanup_complete = False
        # PROCESS_SET_QUOTA | PROCESS_TERMINATE are required for job assignment.
        handle = _checked(job.api.OpenProcess(0x0100 | 0x0001, False, process.pid), "OpenProcess")
        try:
            _checked(job.api.AssignProcessToJobObject(job.handle, handle), "AssignProcessToJobObject")
            assigned = True
        finally:
            _checked(job.api.CloseHandle(handle), "CloseHandle(process)")
        _resume_primary_thread(job.api, process.pid)
        return process
    except BaseException as startup_error:
        try:
            if process is not None:
                if assigned:
                    stop_owned_process(process)
                else:
                    # It has never resumed, so no descendants can exist yet.
                    process.kill()
                    process.wait(timeout=5)
        except BaseException as cleanup_error:
            raise RuntimeError(
                f"Owned process startup failed ({startup_error}); "
                f"startup cleanup failed ({cleanup_error})") from startup_error
        finally:
            job.close()
        raise


def stop_owned_process(process, grace=5, kill_timeout=5):
    """Terminate only this process's job and prove it empty within kill_timeout.

    Windows has no generic graceful process-tree signal, so grace is retained
    only for the shared runner interface. TerminateJobObject immediately
    terminates every member, including descendants of an already-exited leader.
    A failed API call or drain deadline raises; it never reports partial cleanup
    as success. The retained job handle allows a failed cleanup to be retried.
    """
    job = getattr(process, "_owned_job", None)
    if not isinstance(job, _Job):
        raise RuntimeError("Refusing to clean up a process without owned Job Object")
    if job.handle is None:
        if job.confirmed_empty:
            return
        raise RuntimeError("Owned Job Object closed before cleanup was verified")
    deadline = time.monotonic() + max(0, kill_timeout)
    if job.active_processes():
        _checked(job.api.TerminateJobObject(job.handle, 1), "TerminateJobObject")
    while True:
        active = job.active_processes()
        if active == 0:
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(f"Owned Windows job still has {active} active processes after cleanup deadline")
        time.sleep(min(0.02, remaining))
    process.wait(timeout=max(0, deadline - time.monotonic()))
    job.confirmed_empty = True
    job.close()
    process._owned_cleanup_complete = True
