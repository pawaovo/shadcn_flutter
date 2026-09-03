#!/usr/bin/env python3
"""Verify pinned transitive images and complete Web media/notice coverage.

Uses Python 3's standard library only. Never changes a dependency cache or asset.
The default audit verifies the lock, resolved cache, licenses, and every registered
country_flags source file. --bundle WEB_OUTPUT also checks exact bundled bytes,
registered original web icons, all standalone image/audio/video files, and both
required complete MIT notices. --verify-upstream verifies the fixed official pub
archive and license source. --archive can reuse an already downloaded archive.

Examples:
  python3 tool/audit_transitive_media.py
  python3 tool/audit_transitive_media.py --bundle packages/beautiful_ai_ui_catalog/build/web
  python3 tool/audit_transitive_media.py --verify-upstream --archive /tmp/country_flags-4.1.2.tar.gz
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tarfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / 'legal/transitive_media_assets.json'
SEPARATOR = '\n' + '-' * 80 + '\n'
IMAGE_SUFFIXES = {'.si', '.svg', '.svgz', '.vec', '.png', '.apng', '.jpg', '.jpeg',
                  '.jfif', '.gif', '.webp', '.ico', '.bmp', '.tif', '.tiff',
                  '.avif', '.heic', '.heif', '.jxl', '.tga', '.ktx', '.ktx2', '.dds'}
AUDIO_SUFFIXES = {'.mp3', '.wav', '.ogg', '.oga', '.aac', '.m4a', '.opus',
                  '.flac', '.aif', '.aiff', '.weba', '.mid', '.midi'}
VIDEO_SUFFIXES = {'.mp4', '.m4v', '.mov', '.webm', '.mkv', '.avi', '.mpeg',
                  '.mpg', '.m2v', '.3gp', '.3g2', '.wmv', '.ogv'}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(text: str) -> str:
    return ' '.join(text.split())


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify_bytes(data: bytes, record: dict, label: str) -> None:
    require(len(data) == record['bytes'], f'{label}: byte length differs')
    require(sha(data) == record['sha256'], f'{label}: SHA-256 differs')


def package_root(config: Path, name: str) -> Path:
    entries = json.loads(config.read_text())['packages']
    entry = next((item for item in entries if item['name'] == name), None)
    require(entry is not None, f'{name}: missing from {config}')
    uri = urllib.parse.urljoin(config.resolve().as_uri(), entry['rootUri'])
    parsed = urllib.parse.urlparse(uri)
    require(parsed.scheme == 'file', f'{name}: expected a resolved local package')
    return Path(urllib.parse.unquote(parsed.path))


def verify_source(inventory: dict, config: Path) -> tuple[Path, dict]:
    package = inventory['package']
    lock = (ROOT / package['pubspec_lock']).read_text()
    match = re.search(r'^  ' + re.escape(package['name']) +
                      r':\n(.*?)(?=^  \S|\Z)', lock, re.M | re.S)
    require(match is not None, 'Pinned country_flags lock entry is absent')
    block = match.group(1)
    for pattern, expected in (
        (r'^    version: "([^"]+)"$', package['version']),
        (r'^      sha256: ([0-9a-f]{64})$', package['archive_sha256']),
        (r'^      url: "([^"]+)"$', package['registry']),
        (r'^    source: (\S+)$', package['source']),
    ):
        value = re.search(pattern, block, re.M)
        require(value is not None and value.group(1) == expected,
                f'country_flags lock mismatch: expected {expected}')
    resolved = package_root(config, package['name'])
    for record in package['source_documents']:
        verify_bytes((resolved / record['path']).read_bytes(), record,
                     f'country_flags/{record["path"]}')
    expected = {record['source_path'] for record in inventory['assets']}
    actual = {p.relative_to(resolved).as_posix()
              for p in (resolved / package['declared_asset_directory']).rglob('*')
              if p.is_file()}
    require(actual == expected,
            f'Source media inventory mismatch; extra={sorted(actual-expected)}, '
            f'missing={sorted(expected-actual)}')
    for record in inventory['assets']:
        data = (resolved / record['source_path']).read_bytes()
        verify_bytes(data, record, f'country_flags/{record["source_path"]}')
        require(data[:4].hex() == inventory['format']['observed_header_hex'],
                f'{record["source_path"]}: unexpected scalable-image header')
    for record in inventory['licenses']:
        verify_bytes((ROOT / record['file']).read_bytes(), record, record['file'])
    require(len(expected) == inventory['counts']['transitive_media_files'],
            'Registered media count is inconsistent')
    require(sum(r['bytes'] for r in inventory['assets']) ==
            inventory['counts']['transitive_media_bytes'],
            'Registered media byte total is inconsistent')
    return resolved, {'source_media_files': len(expected),
                      'source_media_bytes': inventory['counts']['transitive_media_bytes']}


def read_media_kind(path: Path) -> str | None:
    suffix = path.suffix.lower()
    if suffix in IMAGE_SUFFIXES:
        return 'image'
    if suffix in AUDIO_SUFFIXES:
        return 'audio'
    if suffix in VIDEO_SUFFIXES:
        return 'video'
    with path.open('rb') as stream:
        head = stream.read(512)
    if (head.startswith((b'\x89PNG\r\n\x1a\n', b'\xff\xd8\xff', b'GIF87a',
                         b'GIF89a', b'\0\0\1\0', b'II*\0', b'MM\0*',
                         bytes.fromhex('b0b01e07'))) or
            re.search(br'<svg(?:\s|>)', head, re.I)):
        return 'image'
    if head[:4] == b'RIFF':
        return {b'WEBP': 'image', b'WAVE': 'audio', b'AVI ': 'video'}.get(head[8:12])
    if head.startswith((b'ID3', b'fLaC', b'OggS', b'MThd')):
        return 'audio'
    if len(head) > 12 and head[4:8] == b'ftyp':
        return 'image' if head[8:12] in (b'avif', b'avis', b'heic', b'heix') else 'video'
    if head.startswith(b'\x1aE\xdf\xa3'):
        return 'video'
    return None


def notice_blocks(text: str) -> dict[str, list[str]]:
    blocks = {}
    for block in text.split(SEPARATOR):
        labels, split, body = block.strip().partition('\n\n')
        require(bool(split), 'Malformed Flutter notice block')
        for label in labels.splitlines():
            blocks.setdefault(label, []).append(body)
    return blocks


def verify_notices(assets: Path, licenses: list[dict]) -> list[str]:
    notice_files = [p for p in (assets / 'NOTICES', assets / 'NOTICES.Z') if p.exists()]
    require(bool(notice_files), f'No generated Flutter NOTICES in {assets}')
    verified = []
    for path in notice_files:
        data = path.read_bytes()
        if data.startswith(b'\x1f\x8b'):
            data = gzip.decompress(data)
        blocks = notice_blocks(data.decode('utf-8'))
        for license in licenses:
            expected = normalized((ROOT / license['file']).read_text())
            candidates = [body for label in license['notice_labels']
                          for body in blocks.get(label, [])]
            require(any(expected in normalized(body) for body in candidates),
                    f'{path}: missing complete {license["id"]} notice under '
                    f'{license["notice_labels"]}')
            verified.append(f'{path.name}:{license["id"]}')
    return verified


def verify_bundle(bundle: Path, inventory: dict, source: Path) -> dict:
    require((bundle / 'assets/packages').is_dir(),
            '--bundle must name a built Web output directory containing assets/packages')
    expected = {record['bundle_path']: record for record in inventory['assets']}
    for relative, record in expected.items():
        path = bundle / relative
        require(path.is_file(), f'Bundled media is missing: {relative}')
        data = path.read_bytes()
        verify_bytes(data, record, relative)
        require(data == (source / record['source_path']).read_bytes(),
                f'{relative}: bundled and resolved package bytes differ')
    original = json.loads((ROOT / inventory['original_media_inventory']).read_text())
    prefix = 'packages/beautiful_ai_ui_catalog/web/'
    original_records = {r['path'].removeprefix(prefix): r for r in original['records']
                        if r['path'].startswith(prefix) and r['kind'] == 'png'}
    require(set(original_records) == set(inventory['original_web_media_paths']),
            'Original Web media inventory changed; review media coverage')
    for relative, record in original_records.items():
        data = (bundle / relative).read_bytes()
        require(sha(data) == record['sha256'],
                f'{relative}: bundle differs from registered original artwork')
        require(data == (ROOT / record['path']).read_bytes(),
                f'{relative}: bundle and source artwork differ')
    found = {}
    for path in bundle.rglob('*'):
        if path.is_file():
            kind = read_media_kind(path)
            if kind:
                found[path.relative_to(bundle).as_posix()] = kind
    registered = set(expected) | set(original_records)
    require(set(found) == registered,
            f'Unregistered/missing runtime media; extra={sorted(set(found)-registered)}, '
            f'missing={sorted(registered-set(found))}')
    for kind, count_key in (('audio', 'audio_files'), ('video', 'video_files')):
        require(sum(value == kind for value in found.values()) ==
                inventory['counts'][count_key], f'Unexpected {kind} resources')
    require(len(found) == inventory['counts']['total_web_media_files'],
            'Runtime media count differs')
    notices = verify_notices(bundle / 'assets', inventory['licenses'])
    return {'bundle_media_files': len(found), 'transitive_images': len(expected),
            'original_images': len(original_records), 'audio': 0, 'video': 0,
            'complete_notices': notices}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={'User-Agent': 'Beautiful-AI-UI-asset-audit'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def verify_upstream(inventory: dict, source: Path, archive: Path | None) -> dict:
    package = inventory['package']
    data = archive.read_bytes() if archive else fetch(package['archive_url'])
    require(len(data) == package['archive_bytes'] and
            sha(data) == package['archive_sha256'], 'Official pub archive hash/size mismatch')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as package_tar:
        members = {m.name: m for m in package_tar.getmembers() if m.isfile()}
        flags = {name for name in members if name.startswith(package['declared_asset_directory'])}
        require(flags == {r['source_path'] for r in inventory['assets']},
                'Official archive media list differs')
        names = flags | {r['path'] for r in package['source_documents']}
        for name in names:
            entry = package_tar.extractfile(members[name])
            require(entry is not None, f'Official archive member is unavailable: {name}')
            require(entry.read() == (source / name).read_bytes(),
                    f'Official archive and cache bytes differ: {name}')
    license = next(r for r in inventory['licenses'] if r['id'] == 'flag_icons_mit')
    verify_bytes(fetch(license['official_source']), license, 'Official flag-icons MIT')
    return {'archive_sha256': package['archive_sha256'],
            'archive_members_matched': len(names), 'official_flag_icons_license': True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, help='Built Catalog Web output directory')
    parser.add_argument('--package-config', type=Path, default=ROOT / '.dart_tool/package_config.json')
    parser.add_argument('--verify-upstream', action='store_true')
    parser.add_argument('--archive', type=Path, help='Existing immutable pub archive to verify')
    args = parser.parse_args()
    try:
        require(args.archive is None or args.verify_upstream,
                '--archive requires --verify-upstream')
        inventory = json.loads(INVENTORY.read_text())
        source, result = verify_source(inventory, args.package_config)
        if args.verify_upstream:
            result['upstream'] = verify_upstream(inventory, source, args.archive)
        if args.bundle:
            result['bundle'] = verify_bundle(args.bundle.resolve(), inventory, source)
        print(json.dumps({'status': 'passed', **result}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        print(f'Transitive media audit failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
