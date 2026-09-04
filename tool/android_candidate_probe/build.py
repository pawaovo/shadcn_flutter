#!/usr/bin/env python3
"""Build the native candidate probe with an existing Android SDK and JDK.

No Gradle, AndroidX, network downloads, or global configuration changes are used.
The output directory must be new. Failed builds retain their log and intermediate
files there; the APK is published atomically only after signing and verification.
The temporary signing key is deleted after either success or failure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
import zipfile

REPO_ROOT = Path(__file__).resolve().parents[2]
PROCESS_SCRIPTS = REPO_ROOT / ".github" / "scripts"
sys.path.insert(0, str(PROCESS_SCRIPTS))
from run_catalog_input_acceptance import start_owned_process, stop_owned_process


PACKAGE = "dev.beautifulai.androidcandidateprobe"
COMPONENT = PACKAGE + "/.ProbeInstrumentation"
ANDROID_API = "35"
MIN_API = "34"
BUILD_TOOLS = ("aapt2", "d8", "zipalign", "apksigner")


class BuildError(Exception):
    """An actionable build failure, already covered by the diagnostic log."""


def source_sha(value: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{40}", value):
        raise argparse.ArgumentTypeError("must be a full 40-character hexadecimal Git SHA")
    return value.lower()


def build_tools_version(value: str) -> str:
    if not re.fullmatch(r"[0-9][A-Za-z0-9._+-]*", value):
        raise argparse.ArgumentTypeError("must be an SDK build-tools version, not a path")
    return value


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", required=True, type=Path,
                        help="Existing Android SDK containing platforms/android-35/android.jar")
    parser.add_argument("--source-sha", required=True, type=source_sha,
                        help="Full Git commit SHA embedded into the probe")
    parser.add_argument("--output-dir", required=True, type=Path,
                        help="New directory for the signed APK and retained build diagnostics")
    parser.add_argument("--build-tools-version", type=build_tools_version,
                        help="Installed SDK build-tools version (default: newest complete installation)")
    parser.add_argument("--java-home", type=Path,
                        help="Existing JDK root (otherwise JAVA_HOME or the current PATH)")
    return parser.parse_args(argv)


class Diagnostics:
    def __init__(self, path: Path):
        self.path = path
        self.stream = path.open("x", encoding="utf-8", buffering=1)

    def write(self, message: str) -> None:
        print(message, file=sys.stderr, flush=True)
        self.stream.write(message + "\n")

    def run(self, command: list[str], *, env: dict[str, str], cwd: Path,
            timeout: float = 120) -> str:
        self.write("$ " + shlex.join(command))
        process = None
        output = ""
        original_error = None
        original_exit = None
        cleanup_error = None

        def decoded(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""

        try:
            process = start_owned_process(command, cwd=cwd, env=env,
                                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                          text=True, encoding="utf-8", errors="replace")
            output, _ = process.communicate(timeout=timeout)
            original_exit = process.returncode
            if original_exit != 0:
                original_error = BuildError(f"Command exited with status {original_exit}: {shlex.join(command)}")
        except BaseException as error:
            original_error = error
            if isinstance(error, subprocess.TimeoutExpired):
                output = decoded(error.output)
            if process is not None:
                original_exit = process.poll()
        finally:
            if process is not None:
                try:
                    # The shared owner verifies descendants even if the leader exited.
                    stop_owned_process(process, grace=5, kill_timeout=5)
                except BaseException as error:
                    cleanup_error = error
                try:
                    drained, _ = process.communicate(timeout=5)
                    output = decoded(drained) or output
                except BaseException as error:
                    if isinstance(error, subprocess.TimeoutExpired):
                        output = decoded(error.output) or output
                    if cleanup_error is None:
                        cleanup_error = error
                finally:
                    if process.stdout is not None:
                        process.stdout.close()
            if output:
                self.write(output.rstrip("\n"))
            self.write("command-result: " + json.dumps({
                "command": command, "timeout_seconds": timeout,
                "original_exit_code": original_exit,
                "error": None if original_error is None else f"{type(original_error).__name__}: {original_error}",
                "cleanup_status": "verified" if process is not None and cleanup_error is None else "not_started" if process is None else "unverified",
                "cleanup_error": None if cleanup_error is None else f"{type(cleanup_error).__name__}: {cleanup_error}",
            }, sort_keys=True))
        if isinstance(original_error, (KeyboardInterrupt, SystemExit)):
            raise original_error
        if original_error is not None or cleanup_error is not None:
            messages = []
            if original_error is not None:
                messages.append(f"{type(original_error).__name__}: {original_error}")
            if cleanup_error is not None:
                messages.append(f"Owned process cleanup failed: {type(cleanup_error).__name__}: {cleanup_error}")
            raise BuildError("; ".join(messages)) from original_error
        return output.strip()

    def close(self) -> None:
        self.stream.close()


def require_file(path: Path, description: str, *, executable: bool = False) -> Path:
    if not path.is_file():
        raise BuildError(f"Missing {description}: {path}")
    if executable and not os.access(path, os.X_OK):
        raise BuildError(f"{description} is not executable: {path}")
    return path


def version_key(path: Path) -> tuple:
    # SDK release directories use major.minor.patch[-preview]. Stable releases
    # sort after previews of the same version; numeric components sort naturally.
    match = re.fullmatch(r"(\d+(?:\.\d+)*)(.*)", path.name)
    if match is None:
        return ((), False, (), path.name)
    version = tuple(int(part) for part in match.group(1).split("."))
    suffix = match.group(2)
    preview = tuple(int(part) for part in re.findall(r"\d+", suffix))
    return (version, not suffix, preview, suffix)


def locate_build_tools(sdk_root: Path, requested: str | None) -> dict[str, Path]:
    root = sdk_root / "build-tools"
    if requested:
        candidates = [root / requested]
    else:
        if not root.is_dir():
            raise BuildError(f"Android SDK build-tools directory is missing: {root}")
        candidates = sorted((path for path in root.iterdir() if path.is_dir()
                             and re.match(r"^\d", path.name)), key=version_key, reverse=True)
    for candidate in candidates:
        if all((candidate / tool).is_file() and os.access(candidate / tool, os.X_OK)
               for tool in BUILD_TOOLS):
            return {tool: candidate / tool for tool in BUILD_TOOLS}
    requested_label = f" version {requested}" if requested else ""
    raise BuildError(f"No complete executable Android SDK build-tools{requested_label} under {root}; "
                     f"required tools: {', '.join(BUILD_TOOLS)}. No tools were installed.")


def locate_java(java_home: Path | None) -> tuple[dict[str, Path], dict[str, str]]:
    env = os.environ.copy()
    home = java_home
    if home is None and env.get("JAVA_HOME"):
        home = Path(env["JAVA_HOME"])
    if home is not None:
        home = home.expanduser().resolve()
        env["JAVA_HOME"] = str(home)
        env["PATH"] = str(home / "bin") + os.pathsep + env.get("PATH", "")
        java = {tool: require_file(home / "bin" / tool, f"JDK {tool}", executable=True)
                for tool in ("java", "javac", "keytool")}
    else:
        java = {}
        for tool in ("java", "javac", "keytool"):
            location = shutil.which(tool)
            if location is None:
                raise BuildError(f"JDK {tool} is unavailable; provide --java-home for an existing JDK")
            java[tool] = Path(location).absolute()
    return java, env


def publish_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def build(args: argparse.Namespace, output: Path, log: Diagnostics) -> dict:
    base = Path(__file__).resolve().parent
    sdk_root = args.sdk_root.expanduser().resolve()
    android_jar = require_file(sdk_root / "platforms" / f"android-{ANDROID_API}" / "android.jar",
                               f"Android {ANDROID_API} platform jar")
    tools = locate_build_tools(sdk_root, args.build_tools_version)
    java, env = locate_java(args.java_home)
    source_dir = base / "src" / Path(*PACKAGE.split("."))
    sources = [require_file(source_dir / name, "probe Java source")
               for name in ("ProbeInstrumentation.java", "Protocol.java")]
    protocol_test = require_file(base / "tests" / "ProtocolTest.java", "protocol test source")
    manifest = require_file(base / "AndroidManifest.xml", "probe manifest")
    input_files = [*sources, protocol_test, manifest, Path(__file__).resolve(),
                   require_file(base / "tests" / "test_build.py", "process ownership test source")]
    source_paths = {str(path.relative_to(base)): path for path in input_files}
    for name in ("run_catalog_input_acceptance.py", "run_ios_catalog_journey.py",
                 "windows_owned_process.py"):
        path = require_file(PROCESS_SCRIPTS / name, "shared process ownership source")
        source_paths["repo/" + str(path.relative_to(REPO_ROOT))] = path
    source_hashes = {label: file_sha256(path) for label, path in source_paths.items()}
    work = output / "intermediates"
    work.mkdir()
    classes = work / "classes"
    classes.mkdir()
    test_classes = work / "protocol-test-classes"
    test_classes.mkdir()
    dex = work / "dex"
    dex.mkdir()
    generated = work / "generated" / Path(*PACKAGE.split("."))
    generated.mkdir(parents=True)
    identity = generated / "BuildIdentity.java"
    identity.write_text(f'package {PACKAGE};\n'
                        'public final class BuildIdentity {\n'
                        f'    public static final String SOURCE_SHA = "{args.source_sha}";\n'
                        '    private BuildIdentity() {}\n'
                        '}\n', encoding="utf-8")
    def run(command: list, *, timeout: float = 120) -> str:
        return log.run([str(part) for part in command], env=env, cwd=base, timeout=timeout)

    log.write(f"Build started: {datetime.now(timezone.utc).isoformat()}")
    log.write(f"Source SHA: {args.source_sha}")
    log.write(f"Android platform: {android_jar}")
    log.write(f"Build tools: {tools['aapt2'].parent}")
    tool_versions = {
        "java": run([java["java"], "-version"], timeout=30),
        "javac": run([java["javac"], "-version"], timeout=30),
        "keytool": run([java["keytool"], "-J-version"], timeout=30),
        "aapt2": run([tools["aapt2"], "version"], timeout=30),
        "d8": run([tools["d8"], "--version"], timeout=30),
        "apksigner": run([tools["apksigner"], "version"], timeout=30),
        # zipalign has no version subcommand; its owning SDK package is recorded.
        "zipalign": "Android SDK Build-Tools " + tools["zipalign"].parent.name,
    }
    run([java["javac"], "-encoding", "UTF-8", "-source", "8", "-target", "8",
         "-d", test_classes, source_dir / "Protocol.java", protocol_test])
    run([java["java"], "-cp", test_classes, PACKAGE + ".ProtocolTest"])
    run([java["javac"], "-encoding", "UTF-8", "-source", "8", "-target", "8",
         "-bootclasspath", android_jar, "-classpath", android_jar,
         "-d", classes, *sources, identity])
    class_files = sorted(classes.rglob("*.class"))
    if not class_files:
        raise BuildError("javac succeeded without producing class files")
    run([tools["d8"], "--min-api", MIN_API, "--lib", android_jar,
         "--output", dex, *class_files])
    dex_files = sorted(dex.glob("classes*.dex"))
    if not dex_files or not (dex / "classes.dex").is_file():
        raise BuildError("d8 succeeded without producing classes.dex")
    resource_apk = work / "resources.apk"
    run([tools["aapt2"], "link", "-I", android_jar, "--manifest", manifest,
         "--min-sdk-version", MIN_API, "--target-sdk-version", ANDROID_API,
         "-o", resource_apk])
    unsigned_apk = work / "unsigned.apk"
    shutil.copyfile(resource_apk, unsigned_apk)
    with zipfile.ZipFile(unsigned_apk, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        for dex_file in dex_files:
            archive.write(dex_file, dex_file.name)
    aligned_apk = work / "aligned.apk"
    run([tools["zipalign"], "-f", "4", unsigned_apk, aligned_apk])
    signed_apk = work / "signed.apk"
    with tempfile.TemporaryDirectory(prefix="android-candidate-probe-signing-") as key_dir:
        keystore = Path(key_dir) / "debug.keystore"
        run([java["keytool"], "-genkeypair", "-noprompt", "-keystore", keystore,
             "-storetype", "JKS", "-storepass", "android", "-keypass", "android",
             "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "2048",
             "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US"])
        run([tools["apksigner"], "sign", "--ks", keystore,
             "--ks-key-alias", "androiddebugkey", "--ks-pass", "pass:android",
             "--key-pass", "pass:android", "--min-sdk-version", MIN_API,
             "--v4-signing-enabled", "false", "--out", signed_apk, aligned_apk])
    run([tools["apksigner"], "verify", "--verbose", "--print-certs", signed_apk])
    run([tools["zipalign"], "-c", "4", signed_apk])
    require_file(signed_apk, "signed APK")
    apk_sha256 = file_sha256(signed_apk)
    for label, path in source_paths.items():
        if file_sha256(path) != source_hashes[label]:
            raise BuildError(f"Source file changed during build: {path}; rebuild from a stable checkout")
    source_hashes["generated/" + str(identity.relative_to(work / "generated"))] = file_sha256(identity)
    final_apk = output / "android-candidate-probe.apk"
    result = {"apk": str(final_apk), "source_sha": args.source_sha,
              "package": PACKAGE, "component": COMPONENT, "apk_sha256": apk_sha256,
              "tool_paths": {name: str(path) for name, path in {**java, **tools}.items()},
              "tool_versions": tool_versions,
              "build_tools_version": tools["aapt2"].parent.name,
              "android_jar": str(android_jar), "android_jar_sha256": file_sha256(android_jar),
              "min_sdk": int(MIN_API), "target_sdk": int(ANDROID_API),
              "source_file_sha256": source_hashes}
    # The output directory was exclusively created for this invocation. Publishing
    # via a same-filesystem rename prevents consumers from observing a partial APK.
    os.replace(signed_apk, final_apk)
    publish_json(output / "build-report.json", result)
    log.write(f"Build succeeded: {final_apk}")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    output = args.output_dir.expanduser().absolute()
    # mkdir without exist_ok also rejects existing files, empty directories, and
    # dangling symlinks. Never delete or reuse a prior build's signing material.
    try:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.mkdir()
    except OSError as error:
        print(f"error: --output-dir must be a new writable directory: {output}: {error}",
              file=sys.stderr)
        return 1
    log = None
    try:
        log = Diagnostics(output / "build.log")
        result = build(args, output, log)
    except (BuildError, OSError, zipfile.BadZipFile) as error:
        message = f"error: {error}\nBuild diagnostics retained in {output}"
        if log is not None:
            log.write(message)
        else:
            print(message, file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        message = f"Build interrupted; diagnostics retained in {output}"
        if log is not None:
            log.write(message)
        else:
            print(message, file=sys.stderr)
        return 130
    finally:
        if log is not None:
            log.close()
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
