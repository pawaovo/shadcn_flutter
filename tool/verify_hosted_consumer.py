#!/usr/bin/env python3
"""Verify an isolated beautiful_ai_ui consumer against public shadcn_flutter.

This copies the runtime publication surface into a temporary package, removes
only the copy's workspace-resolution directive, and creates a separate consumer
with no workspace or dependency overrides. The copy normalization does not
claim that pub.dev removes this field from uploaded archives (it need not).

The unmodified public dependency is resolved into a disposable PUB_CACHE. The
script verifies the public archive, lock source/hash, package_config location,
and installed runtime-file bytes, then checks public integration, atomic theme
changes with retained editor state, generated NOTICES, and real LicenseRegistry.
It never edits repository package sources, the existing pub cache, or SDK files.
Only normal Flutter CLI operations and Python's standard library are used.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request

DEFAULT_VERSION = '0.0.54'
DEFAULT_ARCHIVE_SHA256 = '403a9e790447dc4b6bae73a810d7ffa52baece4d7b29b32de56d0dd769be080e'
SEPARATOR = '\n' + '-' * 80 + '\n'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(text: str) -> str:
    return ' '.join(text.split())


def notices(text: str) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for block in text.split(SEPARATOR):
        names, separator, body = block.strip().partition('\n\n')
        if not separator:
            raise ValueError('Malformed notice block')
        for label in names.splitlines():
            result.setdefault(label, []).append(normalized(body))
    return result


def expected_notices(root: Path) -> dict[str, str]:
    inventory = json.loads((root / 'legal/dependency_assets.json').read_text())
    result = {}
    for item in inventory['licenses']:
        body = (root / item['file']).read_text()
        for label in item['notice_labels']:
            result[label] = body
    for item in inventory['required_additional_notices']:
        body = (root / item['license_file']).read_text()
        if 'source_label' in item:
            blocks = notices(body)
            values = blocks.get(item['source_label'], [])
            if len(values) != 1:
                raise ValueError('Expected one source notice for ' + item['label'])
            body = values[0]
        result[item['label']] = body
    return result


def read_url(url: str, limit: int = 64 * 1024 * 1024) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != 'https' or parsed.netloc != 'pub.dev':
        raise ValueError('Only public pub.dev endpoints are accepted: ' + url)
    with urllib.request.urlopen(url, timeout=30) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Public artifact exceeds bounded download size')
    return data


def public_archive(version: str, expected_sha256: str | None) -> tuple[dict, dict[str, str]]:
    metadata_url = f'https://pub.dev/api/packages/shadcn_flutter/versions/{version}'
    metadata = json.loads(read_url(metadata_url, 1024 * 1024))
    if metadata['version'] != version or metadata['pubspec']['name'] != 'shadcn_flutter':
        raise ValueError('Unexpected hosted package metadata')
    data = read_url(metadata['archive_url'])
    archive_hash = digest(data)
    if archive_hash != metadata['archive_sha256']:
        raise ValueError('Downloaded archive does not match official metadata hash')
    if expected_sha256 and archive_hash != expected_sha256:
        raise ValueError('Public archive differs from the approved hash')
    runtime = {}
    root_notices = []
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        for entry in archive.getmembers():
            path = PurePosixPath(entry.name)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Archive contains a non-relative path')
            name = str(path)
            if entry.isfile() and (name.startswith('lib/') or name in ('pubspec.yaml', 'LICENSE', 'NOTICES')):
                runtime[name] = digest(archive.extractfile(entry).read())
            if name in ('LICENSE', 'NOTICES'):
                root_notices.append(name)
    return {
        'package': 'shadcn_flutter', 'version': version,
        'metadata_url': metadata_url, 'published': metadata['published'],
        'archive_url': metadata['archive_url'], 'archive_sha256': archive_hash,
        'root_notice_files': sorted(root_notices),
        'runtime_files_in_archive': len(runtime),
    }, runtime


def publication_copy(source: Path, target: Path) -> dict:
    target.mkdir(parents=True)
    for name in ('lib', 'pubspec.yaml', 'README.md', 'CHANGELOG.md', 'LICENSE', 'NOTICES'):
        entry = source / name
        if entry.is_dir():
            shutil.copytree(entry, target / name)
        elif entry.is_file():
            shutil.copy2(entry, target / name)
    original = (target / 'pubspec.yaml').read_text()
    if re.search(r'^dependency_overrides\s*:', original, flags=re.MULTILINE):
        raise ValueError('The publication source must not carry dependency_overrides')
    clean, removed = re.subn(r'^resolution:\s*workspace\s*\n', '', original, flags=re.MULTILINE)
    if removed > 1:
        raise ValueError('Ambiguous workspace resolution directive')
    (target / 'pubspec.yaml').write_text(clean)
    # Own runtime assets must be added to this reviewed copy surface explicitly.
    if re.search(r'^flutter\s*:', clean, flags=re.MULTILINE):
        raise ValueError('Package declares own Flutter assets; extend the publication copy surface before verification')
    files = {str(path.relative_to(target)): digest(path.read_bytes())
             for path in sorted(target.rglob('*')) if path.is_file()}
    encoded = json.dumps(files, sort_keys=True, separators=(',', ':')).encode()
    return {
        'source': str(source),
        'copy_scope': 'lib, pubspec.yaml, README.md, CHANGELOG.md, LICENSE, NOTICES when present',
        'normalization': 'Remove resolution: workspace from the temporary development-source copy only; hosted archives may retain this field.',
        'removed_workspace_directives': removed,
        'source_file_hashes': files,
        'publication_surface_sha256': digest(encoded),
        'notice_sha256': files.get('NOTICES'),
    }


def lock_entry(text: str, package: str) -> dict[str, str]:
    match = re.search(r'^  ' + re.escape(package) + r':\n(.*?)(?=^  [^ ]|^sdks:|\Z)', text, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError('Resolved lockfile lacks ' + package)
    block = match.group(1)
    result = {}
    for field in ('source', 'version', 'sha256', 'url'):
        found = re.search(r'^\s+' + field + r':\s*["\']?([^"\'\n]+)', block, re.MULTILINE)
        if found:
            result[field] = found.group(1).strip()
    return result


def package_roots(config_path: Path) -> dict[str, Path]:
    config = json.loads(config_path.read_text())
    result = {}
    for item in config['packages']:
        url = urllib.parse.urljoin(config_path.as_uri(), item['rootUri'])
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != 'file':
            raise ValueError('Expected file package_config URI')
        result[item['name']] = Path(urllib.request.url2pathname(parsed.path)).resolve()
    return result


def run_command(command: list[str], cwd: Path, env: dict[str, str], timeout: int,
                name: str, logs: dict[str, str]) -> dict:
    print(f'[hosted consumer] {name}', file=sys.stderr, flush=True)
    start = time.monotonic()
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True,
                               encoding='utf-8', errors='replace',
                               start_new_session=os.name == 'posix')
    try:
        output, _ = process.communicate(timeout=timeout)
        code = process.returncode
    except subprocess.TimeoutExpired as error:
        if os.name == 'posix':
            # Stop Flutter's own compiler/test subprocesses as well, so a child
            # holding the output pipe cannot extend the command indefinitely.
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
        raw = error.stdout or ''
        output = raw.decode(errors='replace') if isinstance(raw, bytes) else raw
        try:
            final_output, _ = process.communicate(timeout=10)
            output = final_output
        except subprocess.TimeoutExpired:
            if process.stdout is not None:
                process.stdout.close()
        output += f'\nCommand exceeded {timeout}s limit.\n'
        code = 124
    logs[name] = output
    return {'name': name, 'command': command, 'exit_code': code,
            'elapsed_seconds': round(time.monotonic() - start, 3), 'passed': code == 0}


def verify(args: argparse.Namespace, root: Path, temporary: Path, report: dict, logs: dict[str, str]) -> None:
    flutter = Path(args.flutter or shutil.which('flutter') or '').expanduser().resolve()
    if not flutter.is_file():
        raise ValueError('Pass --flutter with an absolute Flutter executable path')
    report['flutter_executable'] = str(flutter)
    version_file = flutter.parent.parent / 'bin/cache/flutter.version.json'
    if version_file.is_file():
        report['toolchain'] = json.loads(version_file.read_text())
    hosted, runtime = public_archive(args.shadcn_version, args.archive_sha256)
    report['hosted_dependency'] = hosted
    package = temporary / 'package'
    source = Path(args.library_source).resolve() if args.library_source else root / 'packages/beautiful_ai_ui'
    report['publication_copy'] = publication_copy(source, package)
    consumer = temporary / 'consumer'
    (consumer / 'lib').mkdir(parents=True)
    (consumer / 'test').mkdir()
    consumer_pubspec = f'''name: beautiful_ai_ui_hosted_consumer
publish_to: none
environment:
  sdk: ">=3.13.0 <4.0.0"
  flutter: ">=3.47.0"
dependencies:
  flutter:
    sdk: flutter
  beautiful_ai_ui:
    path: ../package
  shadcn_flutter: {args.shadcn_version}
dev_dependencies:
  flutter_test:
    sdk: flutter
'''
    (consumer / 'pubspec.yaml').write_text(consumer_pubspec)
    fixtures = root / 'tool/hosted_consumer'
    report['fixture_sha256'] = {
        name: digest((fixtures / name).read_bytes())
        for name in ('main.dart', 'consumer_theme_test.dart', 'license_registry_test.dart')
    }
    shutil.copy2(fixtures / 'main.dart', consumer / 'lib/main.dart')
    for name in ('consumer_theme_test.dart', 'license_registry_test.dart'):
        shutil.copy2(fixtures / name, consumer / 'test' / name)
    expectations = expected_notices(root)
    (consumer / 'expected_notices.json').write_text(json.dumps(expectations, indent=2, ensure_ascii=False) + '\n')
    report['expected_notice_labels'] = sorted(expectations)
    report['isolation'] = {'consumer_inside_repository': consumer.is_relative_to(root),
                           'consumer_dependency_overrides': False, 'consumer_workspace': False,
                           'beautiful_ai_ui_source': 'temporary publication-surface path dependency (not yet a hosted publication)',
                           'pub_cache': 'fresh disposable directory; existing cache is untouched',
                           'pubspec': consumer_pubspec}
    if consumer.is_relative_to(root):
        raise ValueError('Consumer directory must be outside the repository workspace')
    cache = temporary / 'pub-cache'
    env = os.environ.copy()
    env['PUB_CACHE'] = str(cache)
    env['PUB_HOSTED_URL'] = 'https://pub.dev'
    env['CI'] = 'true'
    stages = report.setdefault('stages', [])
    stages.append(run_command([str(flutter), 'pub', 'get'], consumer, env,
                              args.timeout, 'resolve-public-dependencies', logs))
    if not stages[-1]['passed']:
        raise RuntimeError('Isolated dependency resolution failed')
    config = consumer / '.dart_tool/package_config.json'
    roots = package_roots(config)
    lock = lock_entry((consumer / 'pubspec.lock').read_text(), 'shadcn_flutter')
    if lock.get('source') != 'hosted' or lock.get('version') != args.shadcn_version:
        raise ValueError('shadcn_flutter did not resolve to the exact hosted version')
    if lock.get('url') != 'https://pub.dev' or lock.get('sha256') != hosted['archive_sha256']:
        raise ValueError('Lock source or archive hash differs from public pub.dev artifact')
    installed = roots['shadcn_flutter']
    expected_root = (cache / 'hosted/pub.dev' / f'shadcn_flutter-{args.shadcn_version}').resolve()
    if installed != expected_root or installed.is_relative_to(root):
        raise ValueError('shadcn_flutter package_config points outside the isolated hosted cache')
    if roots['beautiful_ai_ui'] != package.resolve():
        raise ValueError('beautiful_ai_ui did not resolve to the isolated publication copy')
    mismatches = [name for name, expected_hash in runtime.items()
                  if not (installed / name).is_file() or digest((installed / name).read_bytes()) != expected_hash]
    unexpected_notice = (installed / 'NOTICES').exists() and 'NOTICES' not in runtime
    if mismatches or unexpected_notice:
        raise ValueError('Installed hosted runtime differs from public archive: ' + str(mismatches))
    report['resolution'] = {'shadcn_flutter_lock': lock,
                            'shadcn_flutter_package_root': str(installed),
                            'beautiful_ai_ui_package_root': str(roots['beautiful_ai_ui']),
                            'runtime_files_matching_public_archive': len(runtime),
                            'hosted_dependency_unmodified': True}
    logs['pubspec.lock'] = (consumer / 'pubspec.lock').read_text()
    logs['package_config.json'] = config.read_text()
    stages.append(run_command([str(flutter), 'analyze', '--no-pub', '--fatal-infos', '--fatal-warnings'],
                              consumer, env, args.timeout, 'consumer-analysis', logs))
    for file, name in [('consumer_theme_test.dart', 'public-integration-and-atomic-theme'),
                       ('license_registry_test.dart', 'production-license-registry')]:
        stages.append(run_command([str(flutter), 'test', '--no-pub', '--reporter', 'expanded', 'test/' + file],
                                  consumer, env, args.timeout, name, logs))
    for name in ('theme_probe_result', 'license_probe_result'):
        path = consumer / (name + '.json')
        if path.is_file():
            report[name] = json.loads(path.read_text())
    generated = consumer / 'build/unit_test_assets/NOTICES.Z'
    if not generated.is_file():
        generated = consumer / 'build/unit_test_assets/NOTICES'
    if not generated.is_file():
        raise RuntimeError('Flutter did not produce a real generated NOTICES artifact')
    data = generated.read_bytes()
    body = gzip.decompress(data) if data.startswith(b'\x1f\x8b') else data
    blocks = notices(body.decode())
    missing = [label for label, text in expectations.items() if normalized(text) not in blocks.get(label, [])]
    report['generated_notices'] = {'artifact': str(generated.relative_to(consumer)),
                                    'sha256': digest(data), 'complete_expected_labels': len(expectations) - len(missing),
                                    'missing_complete_labels': sorted(missing), 'passed': not missing}
    report['passed'] = (all(stage['passed'] for stage in stages) and not missing and
                        report.get('theme_probe_result', {}).get('passed') is True and
                        report.get('license_probe_result', {}).get('passed') is True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', help='Flutter executable; resolved to an absolute path before entering the temporary consumer')
    parser.add_argument('--library-source', help='Optional pre-change package snapshot for an honest failing baseline')
    parser.add_argument('--shadcn-version', default=DEFAULT_VERSION)
    parser.add_argument('--archive-sha256', default=DEFAULT_ARCHIVE_SHA256,
                        help='Approved official archive digest; change explicitly when changing the dependency pin')
    parser.add_argument('--output', type=Path, help='JSON result; command logs and lock/config snapshots are saved alongside it')
    parser.add_argument('--timeout', type=int, default=300, help='Maximum seconds for each bounded Flutter command')
    parser.add_argument('--keep-temp', action='store_true', help='Preserve disposable source/cache for diagnosing a failure')
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][\w.]+)?', args.shadcn_version):
        parser.error('Use an explicit package version')
    if not 1 <= args.timeout <= 600:
        parser.error('--timeout must be between 1 and 600 seconds')
    root = Path(__file__).resolve().parents[1]
    temporary = Path(tempfile.mkdtemp(prefix='beautiful-ai-ui-hosted-consumer-')).resolve()
    report = {'schema_version': 1, 'captured_at_utc': datetime.now(timezone.utc).isoformat(),
              'passed': False, 'scope': 'isolated public-dependency consumer gate; not a package publication',
              'verification_script_sha256': digest(Path(__file__).read_bytes()),
              'temporary_directory_retained': args.keep_temp}
    logs: dict[str, str] = {}
    try:
        report['repository_head'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        verify(args, root, temporary, report, logs)
    except Exception as error:
        report['error'] = f'{type(error).__name__}: {error}'
    finally:
        if args.keep_temp:
            report['temporary_directory'] = str(temporary)
        else:
            shutil.rmtree(temporary)
    if args.output:
        output = args.output.resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        log_directory = output.with_suffix('')
        log_directory.mkdir(exist_ok=True)
        for name, text in logs.items():
            suffix = '' if name.endswith(('.json', '.lock')) else '.txt'
            (log_directory / (name + suffix)).write_text(text)
        report['log_directory'] = str(log_directory)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
        print(str(output))
    else:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    print('Hosted consumer: ' + ('PASS' if report['passed'] else 'FAIL'), file=sys.stderr)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
