import os
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__, static_folder='.', static_url_path='')

# 取得目前 web_dashboard 目錄的路徑
BASE_DIR = os.path.dirname(os.path.abspath(__name__))
# 設定 assets/shop/ 路徑 (在 Flutter 專案根目錄下的 assets/shop/)
UPLOAD_FOLDER = os.path.abspath(os.path.join(BASE_DIR, '..', 'assets', 'shop'))

# 如果目錄不存在，則建立
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 限制最大 16MB

import json
import time
import uuid
import datetime

# 儲存商品資訊的 JSON 檔案路徑
DATA_FILE = os.path.join(UPLOAD_FOLDER, 'shop_items.json')

def load_shop_items():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return []
    return []

def save_shop_items(items):
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(items, f, ensure_ascii=False, indent=2)

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/upload-shop-item', methods=['POST'])
def upload_file():
    if 'image' not in request.files:
        return jsonify({'error': 'No image part in the request'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    if file:
        filename = secure_filename(file.filename)
        # 為了避免檔名衝突，可以加上 UUID
        unique_filename = f"{uuid.uuid4().hex[:8]}_{filename}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
        file.save(filepath)
        
        relative_path = f"assets/shop/{unique_filename}"
        
        # 處理商品元資料
        item_type = request.form.get('type', 'limited')
        name = request.form.get('name', '未命名套裝')
        rarity = request.form.get('rarity', '一般')
        price = request.form.get('price', 0, type=int)
        
        current_time = time.time()
        
        start_time_ts = None
        end_time_ts = None
        
        if item_type == 'permanent':
            expires_at = None
        else:
            start_time_str = request.form.get('start_time')
            end_time_str = request.form.get('end_time')
            if start_time_str and end_time_str:
                start_dt = datetime.datetime.strptime(start_time_str, "%Y-%m-%d %H:%M")
                end_dt = datetime.datetime.strptime(end_time_str, "%Y-%m-%d %H:%M")
                start_time_ts = start_dt.timestamp()
                end_time_ts = end_dt.timestamp()
                expires_at = end_time_ts
            else:
                expires_at = None
        
        new_item = {
            'id': str(uuid.uuid4()),
            'type': item_type,
            'name': name,
            'price': price,
            'image_path': relative_path,
            'created_at': current_time,
            'start_time': start_time_ts,
            'end_time': end_time_ts,
            'expires_at': expires_at
        }
        
        items = load_shop_items()
        items.append(new_item)
        save_shop_items(items)

        return jsonify({'success': True, 'path': relative_path, 'message': 'Upload successful', 'item': new_item})

@app.route('/active-shop-items', methods=['GET'])
def get_active_items():
    items = load_shop_items()
    current_time = time.time()
    
    active_items = []
    for item in items:
        if item.get('type') == 'permanent' or item.get('expires_at') is None:
            active_items.append(item)
        else:
            start_ts = item.get('start_time', 0)
            end_ts = item.get('end_time', item.get('expires_at', 0))
            # 只有在目前時間大於開始時間，且小於結束時間，才顯示
            if start_ts <= current_time <= end_ts:
                active_items.append(item)
    
    # 按照建立時間排序，最新的在前面
    active_items.sort(key=lambda x: x.get('created_at', 0), reverse=True)
    return jsonify({'success': True, 'items': active_items})

# 讓 dashboard 可以讀取到剛上傳的圖片 (用於預覽)
@app.route('/assets/shop/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    print(f"Server is running on http://127.0.0.1:5001")
    print(f"Uploading images to: {UPLOAD_FOLDER}")
    app.run(debug=True, port=5001)
