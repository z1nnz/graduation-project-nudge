"""Check the source-bound 00-13 review ledger; never certify physical devices."""
import argparse
import hashlib
import json
import re
from pathlib import Path

REQUIREMENTS = '9ace911bf892dfb3a451acce7e2ecbeb41904f7d'
STATES = {'source_prepared', 'physical_deferred', 'team_pending', 'owner_pending', 'optional_off'}
SECTIONS = {
    '00': ['完成定義', 'P0-A 唯一必做', 'P0-B 完整展示', '範圍變更門檻'],
    '01': ['開發前的零件卡', '現有零件的分級', '不可猜測', 'P0-A 失敗時的降級'],
    '02': ['目標', '展示前狀態', '畫面狀態表', '控制方式優先順序', '展示資料', 'P0-A 驗收證據', 'P0-B 驗收證據'],
    '03': ['必要狀態', '必要資料模型', '兩台裝置的編譯設定', '自動與手動模式', '不阻擋畫面的錯誤策略', 'Host', '實機', '交付'],
    '04': ['P0-A 驗收', 'P0-B 驗收', '圓形版面規則'],
    '05': ['P0-A 前置：確認螢幕身分', 'P0-A 驗收', 'P0-B 驗收', '方形版面規則'],
    '06': ['原則', '按鍵／觸控', '旋鈕', 'LED', '環境光', '蜂鳴器', '測試矩陣', '交付'],
    '07': ['優先級', '最小有價值的連動', 'App 最小畫面', '驗收', '停止條件'],
    '08': ['核心概念', '角色資源', '動畫限制', 'Demo 標記', '驗收'],
    '09': ['預設分工', '共用部分誰先做', '每次開發循環', 'PR 必須包含', 'Review 清單', '衝突處理', '每日回報'],
    '10': ['Gate A｜程式碼', 'Gate B｜最小顯示', 'Gate C｜P0-A 三幕短展示', 'Gate D｜P0-B 完整故事',
        'Gate E｜降級', 'Gate F｜重播次數', 'Gate G｜觀看品質', '排練 1｜工程排練', '排練 2｜完整口頭排練',
        '排練 3｜故障排練', '凍結規則', '驗收表', '不可當作通過'],
    '11': ['使用方法', 'Wave 0｜範圍與零件', 'Wave 1｜P0-B 共用場景', 'Wave 2A｜Orbit', 'Wave 2B｜Station',
        'Wave 3｜一致性與驗收', 'Wave 4｜選配', 'Issue 模板', '關閉規則'],
    '12': ['前一晚', '攜帶物', '到場後 15 分鐘檢查', '開始', '互動', '結尾', '一台沒有畫面', '畫面停住',
        'LED／感測器失敗', 'App／BLE 失敗', '兩台都失敗', '現場禁止', '重設口令', '現場驗收紀錄'],
    '13': ['PR 模板', '實機證據最低要求', '單機交接卡', 'Demo 資料表', '發布包結構', 'VERSION.txt', '壓縮檔驗收', '寄給組員時的訊息'],
}


# Include device scene specifications and development slices, not only final checkboxes.
SECTIONS['02'] += ['0:00–0:25｜一句話與雙裝置','0:25–1:10｜開始專注','1:10–1:40｜自主與同儕支持','1:40–2:20｜完成與角色成長','2:20–2:45｜兩台的差異','2:45–3:00｜結尾','失敗備援']
SECTIONS['03'] += ['P0-A 三幕時間軸','P0-B 八幕時間軸','螢幕 Adapter 的最低介面','圖形資源規則','Logging']
SECTIONS['04'] += ['O0｜Boot','O1｜Watch Home','O2｜Ready','O3｜Focus','O4｜Encouragement','O5｜Complete','O6｜Growth','O7｜Summary','ORB-01｜恢復最小顯示基線','ORB-02｜字型與安全區','ORB-03｜P0-A 靜態三幕','ORB-04｜P0-B 靜態 8 幕','ORB-05｜P0-B 場景引擎','ORB-06｜動畫','ORB-07｜既有輸入']
SECTIONS['05'] += ['S0｜Boot','S1｜Desk Home','S2｜Task Select','S3｜Focus','S4｜Support','S5｜Complete','S6｜Character Result','S7｜Today Summary','STA-01｜原廠最小範例','STA-02｜字型與版面格線','STA-03｜P0-A 靜態三幕','STA-04｜P0-B 靜態 8 幕','STA-05｜P0-B 場景引擎','STA-06｜現有互動','STA-07｜現有周邊']
SECTIONS['07'] += ['Demo 協定','一次只連一台','沒完成時的說法']
SECTIONS['08'] += ['共用色彩 token','共用文案']
SECTIONS['09'] += ['開始工作','分支命名','Push','合併順序']


def sha(body):
    return hashlib.sha256(body).hexdigest()


def criteria(text, package):
    """Selected paragraphs, list items, table records and template blocks.

    All canonical checkbox rows are mandatory even outside selected sections.
    Original inclusive line spans expose the grouping for human review.
    """
    lines = text.splitlines()
    section = ''
    rows = []
    selected = set(SECTIONS[package])
    start = None
    block = []
    fenced = 0

    def flush():
        nonlocal start, block
        if block:
            rows.append({'line': start, 'end_line': start + len(block) - 1,
                         'section': section, 'text': '\n'.join(block)})
        start = None
        block = []

    for i, line in enumerate(lines, 1):
        if line.startswith('#') and not fenced:
            flush()
            section = line.lstrip('#').strip()
            continue
        active = section in selected or line.startswith('- [ ]')
        if not active:
            continue
        if line.startswith(chr(96)*3):
            if not fenced:
                flush()
                start = i
            block.append(line)
            if line[3:].strip():
                fenced += 1
            else:
                fenced = max(0, fenced - 1)
            if not fenced:
                flush()
            continue
        if fenced:
            block.append(line)
            continue
        if not line.strip():
            flush()
            continue
        if line.startswith('|') and i < len(lines) and re.match(r'^\|[\s:|\-]+\|$', lines[i]):
            flush()
            continue
        if re.match(r'^\|[\s:|\-]+\|$', line):
            flush()
            continue
        if re.match(r'^(?:- |\d+\. |\|)', line):
            flush()
            start = i
            block.append(line)
            flush()
        else:
            if start is None:
                start = i
            block.append(line)
    flush()
    return rows


def assess(root):
    ledger = json.loads((root / 'acceptance-matrix.json').read_text())
    if ledger['requirements_commit'] != REQUIREMENTS or ledger.get('hardware_certified') is not False or \
            ledger.get('all_package_criteria_completed') is not False:
        raise ValueError('Wrong source or false hardware-completion claim')
    packages = ledger['packages']
    if [p['id'] for p in packages] != [f'{i:02}' for i in range(14)]:
        raise ValueError('Expected exactly 00-13')
    counts = {s: 0 for s in sorted(STATES)}
    total = 0
    for p in packages:
        filename = p['requirements_file']
        if Path(filename).name != filename:
            raise ValueError('Requirements path must be a local snapshot')
        body = (root / 'requirements' / filename).read_bytes()
        if sha(body) != p['requirements_sha256']:
            raise ValueError('Requirements snapshot hash mismatch')
        expected = criteria(body.decode(), p['id'])
        actual = [{k: row[k] for k in ['line','end_line','section','text']} for row in p['criteria']]
        if actual != expected:
            raise ValueError('Missing/reordered/changed criterion: ' + p['id'])
        if not expected or any(r['state'] not in STATES or not r.get('evidence_ids') or not r.get('finding') for r in p['criteria']):
            raise ValueError('Unreviewed criterion: ' + p['id'])
        evidence = {e['id']: e for e in p['evidence']}
        if len(evidence) != len(p['evidence']):
            raise ValueError('Duplicate evidence id')
        for e in evidence.values():
            if not re.fullmatch('[a-f0-9]{40}', e['commit']) or not re.fullmatch('[a-f0-9]{40}', e['git_blob']):
                raise ValueError('Evidence must reference a fixed Git blob')
        for row in p['criteria']:
            if not set(row['evidence_ids']).issubset(evidence):
                raise ValueError('Unknown evidence reference')
            if row.get('physical_verified') is not False:
                raise ValueError('Deferred physical work cannot be certified')
            counts[row['state']] += 1
        scores = p['preparation_scores']
        limits = {'content':25,'criteria':35,'verification':25,'handoff':15}
        if set(scores) != set(limits) or any(type(scores[k]) is not int or not 0 <= scores[k] <= limits[k] for k in limits):
            raise ValueError('Invalid scoring rubric')
        if sum(scores.values()) < 85 or not p.get('deductions') or p.get('complete') is not False:
            raise ValueError('Preparation threshold or truthful completion state failed')
        total += len(expected)
    remote = json.loads((root / 'remote-snapshot.json').read_text())
    if remote['main_commit'] != ledger['main_at_review'] or len(remote['hardware_issues']) != 34:
        raise ValueError('Remote audit is incomplete')
    required_checks = {'Flutter analyze and tests','Android Kotlin compile','iOS dependency lock',
        'Web and shared contract tests','Cloud Functions tests','Firestore rules and transaction tests'}
    if {p['number'] for p in remote['delivery_prs']} != {19,20,21,22,23,24,25,26,61,62} or len(remote['delivery_prs']) != 10:
        raise ValueError('Missing/duplicate delivery PR in initial snapshot')
    if {x['number'] for x in remote['hardware_issues']} != set(range(27,61)):
        raise ValueError('Missing/duplicate hardware issue in initial snapshot')
    for p in remote['delivery_prs']:
        if p['base'] != 'main' or p['merged'] or p['state'] != 'open' or 'z1nnz' not in p['reviewers']:
            raise ValueError('Unexpected PR ownership/base/state')
        if {c['name'] for c in p['checks']} != required_checks or any(
                c['head'] != p['head'] or c['status'] != 'completed' or c['conclusion'] != 'success' for c in p['checks']):
            raise ValueError('Prior CI snapshot is not green for its exact head')
    if any(not re.search(r'\[P[012](?:-[AB])?\]', x['title']) or x['state'] != 'open' for x in remote['hardware_issues']):
        raise ValueError('Unmarked or unexpectedly closed hardware issue')
    return {'scope':'preparation-review-only','packages':14,'criteria_reviewed':total,'states':counts,
        'minimum_preparation_score':min(sum(p['preparation_scores'].values()) for p in packages),
        'hardware_certified':False,'all_package_criteria_completed':False,
        'ci_snapshot_only':True,'current_head_ci_must_be_checked_separately':True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1] / 'docs/competition-demo/audit00-13')
    args = parser.parse_args()
    try:
        print(json.dumps(assess(args.root), ensure_ascii=False))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, str(error) + '\n')
