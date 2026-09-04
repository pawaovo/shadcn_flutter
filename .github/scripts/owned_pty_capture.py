"""Capture an owned POSIX process's live diagnostics without producer buffering.

The child receives a raw PTY for stdout. Opening /dev/stdout as a Python text
file therefore selects line buffering, unlike a regular redirected log file.
The reader copies bytes unchanged and flushes each chunk to the evidence file.
"""

import errno
import os
from pathlib import Path
import select
import subprocess
import threading
import time

from run_catalog_input_acceptance import start_owned_process, stop_owned_process


class OwnedPtyCapture:
    def __init__(self, argv, destination: Path, **kwargs):
        if os.name == "nt":
            raise RuntimeError("Owned PTY diagnostics require POSIX")
        import pty
        import tty

        if "stdout" in kwargs:
            raise ValueError("The diagnostic capture owns stdout")
        kwargs.setdefault("stdin", subprocess.DEVNULL)
        kwargs.setdefault("stderr", subprocess.DEVNULL)
        self.process = None
        self.eof = False
        self.error = None
        self.bytes_written = 0
        self._finish = threading.Event()
        self._drain_deadline = None
        self._master, slave = pty.openpty()
        self.output = None
        try:
            # Preserve original bytes, including newlines; only the producer's
            # isatty/line-buffering decision changes, not its logging content.
            tty.setraw(slave)
            os.set_blocking(self._master, False)
            self.output = destination.open("wb")
            self.process = start_owned_process(argv, stdout=slave, **kwargs)
            self._reader = threading.Thread(target=self._read, name="owned-pty-log", daemon=True)
            self._reader.start()
        except BaseException as startup_error:
            try:
                if self.process is not None:
                    stop_owned_process(self.process, grace=1, kill_timeout=1)
            except BaseException as cleanup_error:
                raise RuntimeError(f"PTY startup failed ({startup_error}); cleanup failed ({cleanup_error})") from startup_error
            finally:
                os.close(self._master)
                if self.output is not None:
                    self.output.close()
            raise
        finally:
            os.close(slave)

    def _write(self, data):
        self.output.write(data)
        self.output.flush()
        self.bytes_written += len(data)

    def _read(self):
        try:
            while True:
                if self._finish.is_set() and time.monotonic() >= self._drain_deadline:
                    raise TimeoutError("PTY diagnostic stream did not reach EOF after owned cleanup")
                readable, _, _ = select.select([self._master], [], [], 0.1)
                if not readable:
                    continue
                try:
                    data = os.read(self._master, 65536)
                except BlockingIOError:
                    continue
                except OSError as error:
                    # Linux reports EIO when the last PTY slave closes; other
                    # POSIX systems can report an ordinary zero-byte read.
                    if error.errno == errno.EIO:
                        data = b""
                    else:
                        raise
                if not data:
                    self.eof = True
                    break
                self._write(data)
        except BaseException as error:
            self.error = error
        finally:
            try:
                os.close(self._master)
            except OSError as error:
                self.error = self.error or error
            try:
                self.output.close()
            except OSError as error:
                self.error = self.error or error

    @property
    def reader_alive(self):
        return self._reader.is_alive()

    def close(self, grace=1, kill_timeout=1):
        process_error = None
        try:
            stop_owned_process(self.process, grace=grace, kill_timeout=kill_timeout)
        except Exception as error:
            process_error = error
        self._drain_deadline = time.monotonic() + 2
        self._finish.set()
        self._reader.join(timeout=3)
        errors = []
        if process_error:
            errors.append(f"Owned process cleanup: {process_error}")
        if self.reader_alive:
            errors.append("PTY diagnostic reader did not stop")
        if self.error:
            errors.append(f"PTY diagnostic capture: {self.error}")
        if not self.eof:
            errors.append("PTY diagnostic EOF was not verified")
        if errors:
            raise RuntimeError("; ".join(errors)) from process_error
