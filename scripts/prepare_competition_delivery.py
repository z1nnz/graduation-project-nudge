"""Standard-library-only package 13 assembly, integrity and record checks.

No upload, message sending, issue closure, or hardware certification is performed.
"""
import argparse
import hashlib
import json
import re
import stat
import subprocess
import zipfile
from datetime import date
from pathlib import Path, PurePosixPath

ROOT = 'Nudge-Competition-Demo'
PREFIX = 'docs/competition-demo/package13/'
STAGES = ['boot', 'home', 'ready', 'focus', 'encouragement', 'complete', 'growth', 'summary']
ASSETS = ['source-lock.json', 'demo-data.json', 'templates/package-readme.md', 'templates/pr-template.md',
    'templates/device-handoff-template.md', 'templates/team-message-draft.txt', 'templates/evidence-instructions.md']


def digest(body):
    return hashlib.sha256(body).hexdigest()


def blob_hash(body):
    return hashlib.sha1(b'blob ' + str(len(body)).encode() + b'\0' + body).hexdigest()


def git(repo, *args):
    return subprocess.check_output(['git', *args], cwd=repo)


def read_at(repo, ref, filename):
    return git(repo, 'show', ref + ':' + filename)


def safe_name(name):
    if not isinstance(name,str):
        return False
    p = PurePosixPath(name)
    forbidden = {'.git', '.env', '.pio', '.dart_tool', 'node_modules', '__pycache__', 'firebase-service-account.json'}
    return bool(name) and name not in ['.', '/'] and str(p) == name and not name.startswith('/') and \
        '\\' not in name and '\0' not in name and '..' not in p.parts and not p.parts[0].endswith(':') and not forbidden.intersection(p.parts)


def validate_demo_data(data, core):
    if data.get('scope') != 'fictional-fixed-demo-data' or any(data.get(k) is not False for k in ['real_accounts', 'formal_rewards_issued', 'live_cloud_sync']):
        raise ValueError('Demo truth flags must remain false')
    for key, value in data['data'].items():
        if isinstance(value, str):
            found = re.search(r'\b' + key + r'\s*=\s*"([^"]*)"', core)
            if not found or found[1] != value:
                raise ValueError('Shared demo string differs from firmware: ' + key)
        elif isinstance(value, int):
            found = re.search(r'\b' + key + r'\s*=\s*(\d+)\s*;', core)
            if not found or int(found[1]) != value:
                raise ValueError('Shared demo number differs from firmware: ' + key)
        elif key == 'taskLabels' and isinstance(value, list):
            found = re.search(r'taskLabels\[3\]\s*=\s*\{([^}]+)\}', core)
            if not found or re.findall(r'"([^"]*)"', found[1]) != value:
                raise ValueError('Shared task labels differ from firmware')
        else:
            raise ValueError('Unsupported demo field')


def pending_device(name, entry, source):
    return {'device': name, 'owner': 'johnsnow (default; not acknowledged)' if name == 'orbit' else 'roy (default; physical deferred)',
        'hardware': {'board': 'XIAO ESP32-S3 (confirm physical identity)', 'board_id': None,
            'display': 'Seeed Round Display (confirm)' if name == 'orbit' else 'Waveshare 17344 ST7789V/VW 240x320; wiring unconfirmed',
            'display_configured': False, 'wiring_photo': None},
        'source_commit': source, 'environment': entry['environment'], 'build_id': entry['build_id'],
        'profile_sha256': entry['profile_sha256'], 'binary': {'file': 'binaries/' + name + '_demo/' + entry['binary'],
            'sha256': entry['binary_sha256'], 'configuration': entry['configuration']},
        'demo_data_reference': 'evidence/demo-data.json', 'claims': {'p0b': False, 'p1': False},
        'verification': {'compile_source_reference': True, 'physical_upload': False, 'cold_boot_successes': 0,
            'complete_demo_flow': False, 'offline_fallback': False, 'restart_successes': 0, 'optional_removed': None},
        'physical_verified': False, 'operator': None, 'recorded_at': None, 'media': [],
        'known_limitations': ['No physical acceptance or video.', 'Default candidate profile; not accepted hardware wiring.']}


def handoff_card(d):
    name = d['device']
    command = '尚未執行；Station 獨立主控／GPIO 未確認，不執行 upload。' if name == 'station' else \
        '尚未執行；確認該台 port／接法後才可依來源用 PlatformIO upload，不使用 raw 0x0。'
    return ('# Device handoff - ' + name + '（待實機驗收）\n\n'
        '裝置：' + name + '\n負責人：' + d['owner'] + '\n硬體型號：' + d['hardware']['board'] + ' / ' + d['hardware']['display'] + '\n'
        'PlatformIO environment：' + d['environment'] + '\nSource commit：' + d['source_commit'] + '\nBinary 路徑：' + d['binary']['file'] + '\n'
        'Binary SHA-256：' + d['binary']['sha256'] + '\nProfile SHA-256：' + d['profile_sha256'] + '\n燒錄命令：' + command + '\n'
        '正常開機畫面：source 預期 Boot／Home，實際未驗。\nNext 操作：未驗；不把 source 的 Serial N 當已驗按鍵。\n'
        'Restart 操作：未驗；USB 斷電 5 秒再接是操作計畫，長按尚未驗。\nAuto Demo：source 有自動三幕／八幕，實物未驗。\n'
        'P1 周邊：OFF，未採。\n離線狀態：source 無需 App／Cloud，實物未驗。\n已知限制：候選 application image，不是已驗收發布，Station 接線未配置。\n'
        '最後實機驗收日期：未驗。\n驗收影片：未拍。\nDemo data：共用 evidence/demo-data.json，虛構小樹／小芽／82 分等固定資料。\n')


def write_zip(files, out):
    if out.exists():
        raise ValueError('Output exists; use a fresh path')
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, body in sorted(files.items()):
            info = zipfile.ZipInfo(ROOT + '/' + name, (1980, 1, 1, 0, 0, 0))
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, body, compresslevel=9)


def build(repo, source_commit, out, delivery_pr=None):
    if not re.fullmatch(r'[a-f0-9]{40}', source_commit):
        raise ValueError('Use full packaging source commit')
    if delivery_pr and not re.fullmatch(r'https://github.com/z1nnz/graduation-project-nudge/pull/[1-9]\d*', delivery_pr):
        raise ValueError('Wrong delivery PR URL')
    assets = {name: read_at(repo, source_commit, PREFIX + name) for name in ASSETS}
    lock = json.loads(assets['source-lock.json'])
    if git(repo, 'rev-parse', lock['firmware_commit'] + ':firmware/nudge_competition_demo').decode().strip() != lock['firmware_tree']:
        raise ValueError('Firmware tree differs from source lock')
    files, origins = {}, {}
    def import_tree(ref, prefix, dest):
        rows = git(repo, 'ls-tree', '-r', '-z', ref, '--', prefix)
        for row in rows.split(b'\0'):
            if not row:
                continue
            meta, original = row.split(b'\t', 1)
            mode, kind, blob = meta.decode().split()
            original = original.decode()
            if kind != 'blob' or mode not in ['100644', '100755'] or not original.startswith(prefix + '/'):
                raise ValueError('Unexpected source tree entry')
            target = dest + original[len(prefix) + 1:]
            files[target] = git(repo, 'cat-file', 'blob', blob)
            origins[target] = {'commit': ref, 'path': original, 'git_blob': blob}
    import_tree(lock['requirements_commit'], 'docs/work-packages', 'work-packages/')
    import_tree(lock['firmware_commit'], 'firmware/nudge_competition_demo', 'firmware-source/nudge_competition_demo/')
    import_tree(lock['gate_a_commit'], 'docs/competition-demo/package09-10/build-evidence/gate-a', 'evidence/build/')
    # Binaries have a single, clearly separated location. Build logs retain original filenames in their provenance.
    a = json.loads(files['evidence/build/gate-a.json'])
    if not a['passed'] or a['source_commit'] != lock['firmware_commit'] or a['physical_verified'] or len(a['environments']) != 4:
        raise ValueError('Unexpected candidate provenance')
    for e in a['environments']:
        old = 'evidence/build/' + e['binary']
        target = 'binaries/' + e['device'] + '_demo/' + e['binary']
        if digest(files[old]) != e['binary_sha256'] or e['build_id'].encode() not in files[old]:
            raise ValueError('Candidate binary mismatch')
        files[target] = files.pop(old)
        origins[target] = origins.pop(old)
    fixed = [
        (lock['firmware_commit'], 'shared/demo_contract.json', 'firmware-source/shared/demo_contract.json'),
        (lock['firmware_commit'], 'docs/competition-demo/package05-06/dependencies.md', 'firmware-source/UPSTREAM-DEPENDENCIES.md'),
        (lock['firmware_commit'], 'docs/competition-demo/package05-06/dependencies.md', 'firmware-source/UPSTREAM-DEPENDENCIES.md'),
        (lock['operations_commit'], 'docs/competition-demo/package11-12/presenter-script.md', 'scripts/competition-script.md'),
        (lock['operations_commit'], 'docs/competition-demo/package11-12/runbook.md', 'scripts/runbook.md'),
        (lock['operations_commit'], 'output/pdf/nudge-demo-operations.pdf', 'scripts/field-card.pdf'),
        (lock['operations_commit'], 'docs/competition-demo/package11-12/font-license/OFL.txt', 'scripts/font-license/OFL.txt'),
        (lock['operations_commit'], 'docs/competition-demo/package11-12/font-license/source.json', 'scripts/font-license/source.json'),
        (source_commit, 'scripts/prepare_competition_delivery.py', 'scripts/prepare_competition_delivery.py')]
    for ref, original, target in fixed:
        files[target] = read_at(repo, ref, original)
        origins[target] = {'commit': ref, 'path': original, 'git_blob': blob_hash(files[target])}
    core = files['firmware-source/nudge_competition_demo/include/demo/core.h'].decode()
    data = json.loads(assets['demo-data.json'])
    validate_demo_data(data, core)
    files['evidence/demo-data.json'] = assets['demo-data.json']
    labels = {'userName':'使用者（虛構 Demo）','primaryTask':'主要任務','roomName':'自律房（Demo）',
        'encouragement':'家庭訊息（Demo）','characterName':'角色','characterLevel':'角色等級（Demo）',
        'demoXp':'Demo XP','todayFocusMinutes':'今日專注分鐘（Demo）','disciplineScore':'今日分數（Demo）',
        'activeMembers':'房間已加入人數（Demo）','totalMembers':'房間人數（Demo）','focusMinutes':'專注分鐘（壓縮示意）',
        'todayFocusCount':'今日次數（Demo）','taskLabels':'韌體 task labels'}
    files['evidence/demo-data.md'] = ('# 兩台共用的固定 Demo 資料\n\n' +
        '\n\n'.join(labels[k] + '：' + str(v) for k, v in data['data'].items()) +
        '\n\n其他任務：閱讀 25 分鐘、散步 3000 步。房間進度 3/5。全部為固定原型，不是真實帳號／即時健康資料，不核發正式 XP。\n').encode()
    for name in ['pr-template.md', 'device-handoff-template.md', 'team-message-draft.txt', 'evidence-instructions.md']:
        files['evidence/templates/' + name] = assets['templates/' + name]
    devices = {}
    for name in ['orbit', 'station']:
        entry = next(e for e in a['environments'] if e['environment'] == name + '_p0a')
        devices[name] = pending_device(name, entry, lock['firmware_commit'])
        files['evidence/' + name + '/HANDOFF.md'] = handoff_card(devices[name]).encode()
        files['evidence/' + name + '/STATUS.md'] = assets['templates/evidence-instructions.md']
    record = {'schema_version':1, 'scope':'package13-physical-record', 'devices':devices, 'full_demo':None,
        'physical_videos_available':False, 'hardware_certified':False}
    files['evidence/delivery-record.pending.json'] = (json.dumps(record, ensure_ascii=False, indent=2) + '\n').encode()
    files['evidence/full-demo/STATUS.md'] = '尚未拍攝雙機完整實物影片，未做離線播放驗證。不是放一個 README 就算有影片。\n'.encode()
    created = git(repo, 'show', '-s', '--format=%cI', source_commit).decode().strip()
    pr_text = delivery_pr or '尚未建立；發布後補進最終包與 PR 索引'
    readme = assets['templates/package-readme.md'].decode().replace('{{PACKAGE_COMMIT}}', source_commit).replace('{{CREATED_AT}}', created).replace('{{PACKAGE_PR}}', pr_text)
    files['README.md'] = readme.encode()
    files['VERSION.txt'] = ('Package: Nudge-Competition-Demo preparation v1\nCreated at: ' + created +
        '\nSource repository: https://github.com/' + lock['repository'] + '\nSource commit: ' + lock['firmware_commit'] +
        '\nPackaging source commit: ' + source_commit + '\nDelivery PR: ' + pr_text +
        '\nOrbit environment: orbit_p0a (primary), orbit_demo (candidate)\nStation environment: station_p0a (primary), station_demo (candidate, unconfigured)\n'
        'Orbit device verified: false\nStation device verified: false\nBLE included: false (runtime; gated source adapter is present)\n'
        'Known limitations: no upload, physical video, confirmed Station pinmap, offline video playback or another-computer flash acceptance; no toolchain cache.\n').encode()
    files['SOURCE_LOCK.json'] = assets['source-lock.json']
    for name, body in files.items():
        if not safe_name(name) or str(Path.home()).encode() in body or re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}', body):
            raise ValueError('Unsafe/private package member: ' + name)
    files['SHA256SUMS.txt'] = ''.join(digest(b) + '  ' + n + '\n' for n, b in sorted(files.items())).encode()
    m = {'schema_version':1, 'phase':'preparation-only', 'packaging_source_commit':source_commit,
        'delivery_pr':delivery_pr, 'created_at_source_commit_time':created, 'hardware_certified':False,
        'physical_verified':False, 'video_playback_verified':False, 'ble_runtime_included':False,
        'station_pinmap_configured':False, 'toolchain_cache_included':False,
        'files':[{'file':n, 'bytes':len(b), 'sha256':digest(b), **({'origin':origins[n]} if n in origins else {})} for n,b in sorted(files.items())]}
    files['MANIFEST.json'] = (json.dumps(m, ensure_ascii=False, indent=2) + '\n').encode()
    write_zip(files, out)
    result = verify(out)
    out.with_suffix(out.suffix + '.sha256').write_text(digest(out.read_bytes()) + '  ' + out.name + '\n')
    return result


def verify(archive):
    with zipfile.ZipFile(archive) as z:
        info = z.infolist()
        full = [i.filename for i in info]
        if len(info) > 1000 or len(set(full)) != len(full) or sum(i.file_size for i in info) > 64*1024*1024:
            raise ValueError('Archive duplicate/count/size limit')
        if any(not safe_name(i.filename) or not i.filename.startswith(ROOT + '/') or i.file_size > 32*1024*1024 or stat.S_IFMT(i.external_attr >> 16) == stat.S_IFLNK for i in info):
            raise ValueError('Unsafe/root/symlink archive entry')
        names = [n[len(ROOT)+1:] for n in full]
        root_files={'README.md','VERSION.txt','MANIFEST.json','SOURCE_LOCK.json','SHA256SUMS.txt'}
        if any((n.split('/')[0] not in {'work-packages','firmware-source','binaries','evidence','scripts'} and n not in root_files) or
            n.lower().endswith(('.zip','.tar','.gz','.tgz','.7z')) for n in names):
            raise ValueError('Unapproved/legacy/nested archive member')
        read = lambda n: z.read(ROOT + '/' + n)
        m = json.loads(read('MANIFEST.json'))
        if m.get('schema_version') != 1 or m.get('phase') != 'preparation-only' or any(m.get(k) is not False for k in
            ['hardware_certified','physical_verified','video_playback_verified','ble_runtime_included','station_pinmap_configured','toolchain_cache_included']):
            raise ValueError('Preparation flags must not claim physical certification')
        declared = [f['file'] for f in m['files']]
        if len(set(declared)) != len(declared) or set(declared) != set(names)-{'MANIFEST.json'}:
            raise ValueError('Undeclared/missing member')
        for f in m['files']:
            b = read(f['file'])
            if len(b) != f['bytes'] or digest(b) != f['sha256']:
                raise ValueError('Package file hash mismatch: ' + f['file'])
            if 'origin' in f and blob_hash(b) != f['origin']['git_blob']:
                raise ValueError('Imported Git blob mismatch')
        required = ['README.md','VERSION.txt','SHA256SUMS.txt','SOURCE_LOCK.json','evidence/templates/pr-template.md',
            'evidence/templates/device-handoff-template.md','evidence/templates/team-message-draft.txt','evidence/demo-data.json',
            'evidence/orbit/HANDOFF.md','evidence/station/HANDOFF.md','evidence/full-demo/STATUS.md',
            'scripts/competition-script.md','scripts/runbook.md','scripts/prepare_competition_delivery.py']
        if not set(required).issubset(names):
            raise ValueError('Missing package13 structure/template')
        work = [n for n in names if n.startswith('work-packages/')]
        numbered = [n for n in work if re.fullmatch(r'work-packages/\d{2}-[^/]+\.md',n)]
        if len(work)!=15 or len(numbered)!=14 or {n.split('/')[1][:2] for n in numbered}!={str(i).zfill(2) for i in range(14)} or 'work-packages/README.md' not in work:
            raise ValueError('Old/missing work packages: only Competition v1 00-13 allowed')
        if not read('README.md').decode().startswith('# Nudge 競賽 Demo') or b'PREPARATION ONLY' not in read('README.md'):
            raise ValueError('README must identify unaccepted competition demo')
        version = read('VERSION.txt').decode()
        for key in ['Package:','Created at:','Source repository:','Source commit:','Orbit environment:',
            'Station environment:','Orbit device verified: false','Station device verified: false','BLE included: false','Known limitations:']:
            if key not in version:
                raise ValueError('Missing VERSION field or false hardware flag')
        if m.get('delivery_pr') and (not re.fullmatch(r'https://github.com/z1nnz/graduation-project-nudge/pull/[1-9]\d*',m['delivery_pr']) or
            'Delivery PR: '+m['delivery_pr'] not in version or m['delivery_pr'].encode() not in read('README.md')):
            raise ValueError('Delivery PR trace does not agree')
        lock = json.loads(read('SOURCE_LOCK.json'))
        a = json.loads(read('evidence/build/gate-a.json'))
        if a['source_commit'] != lock['firmware_commit'] or a['source_tree' if 'source_tree' in a else 'firmware_tree'] != lock['firmware_tree'] or a['physical_verified']:
            raise ValueError('Candidate source identity mismatch')
        envs = {e['environment'] for e in a['environments']}
        if envs != {'orbit_p0a','station_p0a','orbit_demo','station_demo'}:
            raise ValueError('Wrong candidate environments')
        for e in a['environments']:
            b = read('binaries/' + e['device'] + '_demo/' + e['binary'])
            if digest(b) != e['binary_sha256'] or e['build_id'].encode() not in b or not e['binary'].startswith(e['device']+'_'):
                raise ValueError('Wrong-device candidate or embedded identity')
        expected_binary_paths={'binaries/'+e['device']+'_demo/'+e['binary'] for e in a['environments']}
        if {n for n in names if n.startswith('binaries/')}!=expected_binary_paths:
            raise ValueError('Unexpected or mixed-device binary layout')
        validate_demo_data(json.loads(read('evidence/demo-data.json')), read('firmware-source/nudge_competition_demo/include/demo/core.h').decode())
        pending=json.loads(read('evidence/delivery-record.pending.json'))
        if pending.get('hardware_certified') is not False or pending.get('physical_videos_available') is not False or any(
            d.get('physical_verified') is not False or d.get('demo_data_reference')!='evidence/demo-data.json' or
            d.get('source_commit')!=lock['firmware_commit'] for d in pending['devices'].values()):
            raise ValueError('Pending cards must not claim physical acceptance or split demo data')
        if any(n.lower().endswith(('.mp4','.mov','.m4v')) for n in names):
            raise ValueError('Unverified media must not be silently added to a preparation archive')
        return {'verified':True,'phase':m['phase'],'files':len(info),'work_packages':14,'candidate_images':4,
            'physical_verified':False,'video_playback_verified':False,'packaging_source_commit':m['packaging_source_commit'],'delivery_pr':m['delivery_pr']}


def extract(archive, out):
    result = verify(archive)
    if out.exists():
        raise ValueError('Extraction output exists')
    out.mkdir(parents=True)
    base = out.resolve()
    with zipfile.ZipFile(archive) as z:
        for i in z.infolist():
            target = out / i.filename
            if not target.resolve().is_relative_to(base):
                raise ValueError('Extraction path escape')
            target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('xb') as f:
                f.write(z.read(i.filename))
    return result


def media_ok(media, root):
    if not isinstance(media,dict) or media.get('kind')!='physical_video' or not media.get('continuous') is True:
        return False
    file = media.get('file','')
    if not safe_name(file) or not file.lower().endswith(('.mp4','.mov','.m4v')) or not isinstance(media.get('sha256'),str) or not re.fullmatch(r'[a-f0-9]{64}',media['sha256']):
        return False
    if not isinstance(media.get('duration_ms'),(int,float)) or media['duration_ms']<=0:
        return False
    try:
        base=root.resolve(); p=(base/file).resolve()
        if not p.is_relative_to(base) or not p.is_file() or not p.stat().st_size:
            return False
        h=hashlib.sha256()
        with p.open('rb') as f:
            for chunk in iter(lambda:f.read(1024*1024),b''):
                h.update(chunk)
        return h.hexdigest()==media['sha256']
    except OSError:
        return False


def evidence(record, root):
    if record.get('schema_version')!=1 or record.get('scope')!='package13-physical-record':
        raise ValueError('Wrong physical record schema')
    result={'scope':'record-completeness-only','hardware_certified':False,'human_review_required':True,'devices':{}}
    def valid_date(v):
        try:return isinstance(v,str) and date.fromisoformat(v).isoformat()==v
        except ValueError:return False
    for name in ['orbit','station']:
        d=record['devices'][name]; v=d['verification']; claims=d['claims']; media=d['media']
        identity=bool(d.get('physical_verified') is True and d['hardware'].get('display_configured') is True and
            d['hardware'].get('board_id') and isinstance(d.get('source_commit'),str) and re.fullmatch(r'[a-f0-9]{40}',d['source_commit']) and
            isinstance(d.get('environment'),str) and d['environment'].startswith(name+'_') and
            isinstance(d.get('operator'),str) and d['operator'].strip() and valid_date(d.get('recorded_at')))
        binary=d.get('binary') or {}; binary_good=False
        if identity and safe_name(binary.get('file')) and isinstance(d.get('build_id'),str):
            file=(root/binary['file']).resolve()
            if file.is_relative_to(root.resolve()) and file.is_file():
                body=file.read_bytes()
                binary_good=bool(binary.get('configuration')=='accepted-profile' and digest(body)==binary.get('sha256') and
                    d['build_id'].startswith(d['source_commit'][:12]) and d['build_id'].encode() in body and
                    file.name.startswith(name+'_'))
                gate_path=root/'evidence/build/gate-a.json'
                if name=='station' and gate_path.is_file():
                    unconfigured={e['binary_sha256'] for e in json.loads(gate_path.read_text())['environments'] if e['device']=='station' and e['configuration']=='unconfigured'}
                    if digest(body) in unconfigured:binary_good=False
        expected=STAGES if claims.get('p0b') else ['boot','home','focus','complete']
        full=[]; close=[]
        for m in media:
            good=media_ok(m,root) and m.get('physical_xiao_visible') is True and m.get('physical_screen_visible') is True
            if good and 'closeup' in m.get('roles',[]):close.append(m)
            sequence=iter(m.get('scenes',[]))
            ordered=all(any(s==want for s in sequence) for want in expected)
            if good and 'full' in m.get('roles',[]) and m.get('boot_visible') is True and m.get('complete_visible') is True and ordered and \
                (not (claims.get('p0b') or claims.get('p1')) or m.get('restart_visible') is True) and \
                (not claims.get('p1') or m.get('operator_actions_visible') is True):full.append(m)
        tests=v.get('physical_upload') is True and v.get('cold_boot_successes')==3 and v.get('complete_demo_flow') is True and v.get('offline_fallback') is True and \
            (not (claims.get('p0b') or claims.get('p1')) or v.get('restart_successes',0)>=10) and \
            (not claims.get('p1') or v.get('optional_removed') is True)
        result['devices'][name]={'records_complete':bool(identity and binary_good and tests and full and close),'valid_media_records':len(full)}
    ids=[record['devices'][n]['hardware'].get('board_id') for n in ['orbit','station']]
    if ids[0] and ids[0]==ids[1]:
        for d in result['devices'].values():d['records_complete']=False
    result['minimum_device_records_complete']=all(d['records_complete'] for d in result['devices'].values())
    full=record.get('full_demo') or {}
    result['full_demo_record_complete']=bool(media_ok(full,root) and full.get('both_devices_visible') is True and
        full.get('duration_ms',0)>=165000 and full.get('build_ids')=={n:record['devices'][n]['build_id'] for n in ['orbit','station']})
    result['full_delivery_records_complete']=result['minimum_device_records_complete'] and result['full_demo_record_complete']
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest='command',required=True)
    b=sub.add_parser('build'); b.add_argument('--git-source',type=Path,required=True); b.add_argument('--source-commit',required=True); b.add_argument('--out',type=Path,required=True); b.add_argument('--delivery-pr')
    v=sub.add_parser('verify');v.add_argument('archive',type=Path)
    x=sub.add_parser('extract');x.add_argument('archive',type=Path);x.add_argument('--out',type=Path,required=True)
    e=sub.add_parser('evidence');e.add_argument('record',type=Path);e.add_argument('--root',type=Path,required=True)
    a=p.parse_args()
    try:
        if a.command=='build':r=build(a.git_source,a.source_commit,a.out,a.delivery_pr)
        elif a.command=='verify':r=verify(a.archive)
        elif a.command=='extract':r=extract(a.archive,a.out)
        else:r=evidence(json.loads(a.record.read_text()),a.root)
        print(json.dumps(r,ensure_ascii=False))
        if a.command=='evidence' and not r['full_delivery_records_complete']:p.exit(2)
    except (ValueError,KeyError,OSError,zipfile.BadZipFile) as ex:p.exit(1,str(ex)+'\n')
