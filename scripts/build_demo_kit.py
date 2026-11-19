"""Build/verify a deterministic, explicitly unaccepted offline preparation kit."""
import argparse
import hashlib
import json
import re
import stat
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

BASE = Path(__file__).resolve().parents[1]
DOC = BASE / 'docs/competition-demo/package11-12'


def digest(body):
    return hashlib.sha256(body).hexdigest()


def safe_name(name):
    p = PurePosixPath(name)
    blocked = {'.env', '.git', '.pio', 'node_modules', '.dart_tool', 'firebase-service-account.json'}
    return bool(name) and name not in ['.', '/'] and '\\' not in name and '\0' not in name and not name.startswith('/') and \
        '..' not in p.parts and str(p) == name and not p.parts[0].endswith(':') and not blocked.intersection(p.parts)


def write_zip(files, out):
    if out.exists():
        raise ValueError('Output already exists; choose a fresh path')
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, body in sorted(files.items()):
            if not safe_name(name):
                raise ValueError('Unsafe archive name')
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            z.writestr(info, body, compresslevel=9)


def git(repo, *args):
    return subprocess.check_output(['git', *args], cwd=repo)


def build(repo, out):
    lock = json.loads((DOC / 'source-lock.json').read_text())
    if git(repo, 'rev-parse', lock['firmware_commit'] + ':firmware/nudge_competition_demo').decode().strip() != lock['firmware_tree']:
        raise ValueError('Firmware source tree mismatch')
    files = {}
    local = ['runbook.md', 'presenter-script.md', 'inventory-checklist.md', 'onsite-record.template.md',
        'readiness.pending.json', 'readiness.status.json', 'backlog.json', 'issue-registry.json', 'issues.md', 'issue-bodies.md',
        'source-lock.json', 'field-card.json', 'font-license/OFL.txt', 'font-license/source.json']
    for name in local:
        files['operations/' + name] = (DOC / name).read_bytes()
    files['operations/field-card.pdf'] = (BASE / 'output/pdf/nudge-demo-operations.pdf').read_bytes()
    for name in ['demo_backlog.cjs', 'demo_runbook.cjs', 'build_demo_kit.py']:
        files['tools/' + name] = (BASE / 'scripts' / name).read_bytes()
    for ref, prefixes, target in [
        (lock['firmware_commit'], ['firmware/nudge_competition_demo', 'shared/demo_contract.json',
            'docs/competition-demo/package05-06/dependencies.md'], 'source/'),
        (lock['gate_a_commit'], ['docs/competition-demo/package09-10/build-evidence/gate-a'], 'candidates/')]:
        listing = git(repo, 'ls-tree', '-r', '-z', ref, '--', *prefixes)
        for row in listing.split(b'\0'):
            if not row:
                continue
            meta, name_bytes = row.split(b'\t', 1)
            mode, kind, blob = meta.decode().split()
            name = name_bytes.decode()
            if kind != 'blob' or mode not in ['100644', '100755'] or not safe_name(name):
                raise ValueError('Unapproved source entry')
            if target == 'candidates/':
                name = 'gate-a/' + name.rsplit('/gate-a/', 1)[1]
            files[target + name] = git(repo, 'cat-file', 'blob', blob)
    a = json.loads(files['candidates/gate-a/gate-a.json'])
    if not a['passed'] or a['physical_verified'] or a['source_commit'] != lock['firmware_commit'] or len(a['environments']) != 4:
        raise ValueError('Wrong candidate Gate A report')
    for e in a['environments']:
        b = files['candidates/gate-a/' + e['binary']]
        if digest(b) != e['binary_sha256'] or e['build_id'].encode() not in b:
            raise ValueError('Candidate binary provenance mismatch')
    files['PREPARATION_ONLY.txt'] = ('PREPARATION ONLY - NOT AN ACCEPTED DEVICE RELEASE\n'
        'No physical video is supplied. Station wiring/controller remain unconfirmed. P1/BLE OFF.\n'
        'Candidate application images are NOT bootloader images; never flash them alone at address 0x0.\n'
        'Use only a configured, rehearsed laptop and verified hardware later.\n').encode()
    files['README.txt'] = ('Open operations/field-card.pdf or operations/runbook.md offline.\n'
        'Read operations/presenter-script.md and fill operations/onsite-record.template.md.\n'
        'Task index: operations/issues.md; full scopes: operations/issue-bodies.md. No issue is assigned or device-verified by this kit.\n'
        'source/ contains tracked firmware sources and pinned PlatformIO configuration only.\n'
        'PlatformIO toolchains/library caches and an offline installer are NOT included.\n'
        'Bring the already configured laptop; fresh-computer flashing is unverified.\n'
        'Historical upstream README links may require network; the operation card itself does not.\n'
        'No real backup video exists yet. Do not present a software preview as physical footage.\n'
        'Integrity: python3 tools/build_demo_kit.py verify /path/to/this.zip\n').encode()
    files['videos/NOT_YET_RECORDED.txt'] = b'No physical footage. Add accepted same-hardware recordings only after physical rehearsal.\n'
    for name, body in files.items():
        if str(Path.home()).encode() in body or re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}', body):
            raise ValueError('Private path or credential pattern in preparation kit: ' + name)
    sums = ''.join(digest(b) + '  ' + n + '\n' for n, b in sorted(files.items()))
    files['SHA256SUMS.txt'] = sums.encode()
    registry = json.loads(files['operations/issue-registry.json'])
    manifest = {'schema_version': 1, 'phase': 'preparation-only', 'physical_verified': False,
        'station_pinmap_configured': False, 'p1_armed': False, 'ble_armed': False,
        'requires_configured_laptop': True, 'toolchain_caches_included': False,
        'physical_videos_included': False, 'issue_count': len(registry['issues']),
        'sources': lock, 'files': [{'file': n, 'bytes': len(b), 'sha256': digest(b)} for n, b in sorted(files.items())]}
    files['MANIFEST.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
    write_zip(files, out)
    verify(out)
    out.with_suffix(out.suffix + '.sha256').write_text(digest(out.read_bytes()) + '  ' + out.name + '\n')
    return manifest


def verify(archive):
    with zipfile.ZipFile(archive) as z:
        entries = z.infolist()
        names = [e.filename for e in entries]
        if len(entries) > 1000 or len(set(names)) != len(names) or sum(e.file_size for e in entries) > 64 * 1024 * 1024:
            raise ValueError('Archive count/size/duplicate-entry limit')
        if any(not safe_name(e.filename) or stat.S_IFMT(e.external_attr >> 16) == stat.S_IFLNK or e.file_size > 32 * 1024 * 1024 for e in entries):
            raise ValueError('Unsafe archive entry')
        m = json.loads(z.read('MANIFEST.json'))
        if m.get('schema_version') != 1 or m.get('phase') != 'preparation-only' or any(m.get(k) is not False for k in
            ['physical_verified', 'station_pinmap_configured', 'p1_armed', 'ble_armed', 'toolchain_caches_included', 'physical_videos_included']):
            raise ValueError('Kit must remain explicitly unaccepted preparation')
        declared = [f['file'] for f in m['files']]
        if len(set(declared)) != len(declared) or set(declared) != set(names) - {'MANIFEST.json'}:
            raise ValueError('Undeclared/missing kit member')
        for f in m['files']:
            b = z.read(f['file'])
            if len(b) != f['bytes'] or digest(b) != f['sha256']:
                raise ValueError('Kit file hash mismatch: ' + f['file'])
        a = json.loads(z.read('candidates/gate-a/gate-a.json'))
        if a.get('source_commit') != m['sources']['firmware_commit'] or a.get('firmware_tree') != m['sources']['firmware_tree'] or a.get('physical_verified') is not False:
            raise ValueError('Candidate source metadata mismatch')
        for e in a['environments']:
            b = z.read('candidates/gate-a/' + e['binary'])
            if digest(b) != e['binary_sha256'] or e['build_id'].encode() not in b:
                raise ValueError('Candidate embedded identity/hash mismatch')
        if len(a['environments']) != 4 or any(name.endswith(('.mp4', '.mov', '.m4v')) for name in names):
            raise ValueError('Wrong candidate count or unverified video in preparation kit')
        return {'verified': True, 'phase': m['phase'], 'files': len(entries), 'candidate_images': 4,
            'issue_count': m['issue_count'], 'physical_verified': False}


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build')
    b.add_argument('--git-source', type=Path, required=True)
    b.add_argument('--out', type=Path, required=True)
    v = sub.add_parser('verify')
    v.add_argument('archive', type=Path)
    a = p.parse_args()
    try:
        r = build(a.git_source, a.out) if a.command == 'build' else verify(a.archive)
        print(json.dumps({'phase': r['phase'], 'physical_verified': False, 'verified': True}, ensure_ascii=False))
    except (ValueError, KeyError, zipfile.BadZipFile, OSError) as e:
        p.exit(1, str(e) + '\n')
