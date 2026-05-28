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


# ==========================================
# User Data & Mobile Sync APIs
# ==========================================
import random

USER_DATA_FILE = os.path.join(UPLOAD_FOLDER, 'users_data.json')

def load_all_users():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r', encoding='utf-8') as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return {}
    return {}

def save_all_users(data):
    with open(USER_DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_user(user_id):
    users = load_all_users()
    if user_id not in users:
        users[user_id] = {
            "user_id": user_id,
            "name": user_id,
            "avatar": "🧑‍🚀",
            "planet": {
                "name": "新手星球",
                "level": 1,
                "color": "#9ca3af",
                "unlocked": ["新手星球"]
            },
            "stats": {
                "focus_minutes": 0,
                "steps": 0,
                "sleep_hours": 0.0,
                "exercise_minutes": 0
            },
            "status": "努力自律中",
            "current_goal": "無"
        }
    return users[user_id]

def update_user(user_id, updates):
    users = load_all_users()
    user = get_user(user_id)
    
    # Recursively update dictionary
    def recursive_update(d, u):
        for k, v in u.items():
            if isinstance(v, dict):
                d[k] = recursive_update(d.get(k, {}), v)
            else:
                d[k] = v
        return d
        
    updated_user = recursive_update(user, updates)
    users[user_id] = updated_user
    save_all_users(users)
    return updated_user

@app.route('/api/sync/user', methods=['POST'])
def sync_user():
    data = request.json
    if not data or 'user_id' not in data:
        return jsonify({"error": "Missing user_id"}), 400
    
    # Example payload: {"user_id": "an_nudge", "name": "小安", "avatar": "🧑‍🚀", "status": "被專題快搞瘋了"}
    user_id = data.pop('user_id')
    user = update_user(user_id, data)
    return jsonify({"success": True, "user": user})

@app.route('/api/sync/health', methods=['POST'])
def sync_health():
    data = request.json
    if not data or 'user_id' not in data:
        return jsonify({"error": "Missing user_id"}), 400
    
    user_id = data.pop('user_id')
    
    # Map health data to stats
    stats_update = {"stats": {}}
    if 'sleep_hours' in data: stats_update["stats"]["sleep_hours"] = data['sleep_hours']
    if 'steps' in data: stats_update["stats"]["steps"] = data['steps']
    if 'exercise_minutes' in data: stats_update["stats"]["exercise_minutes"] = data['exercise_minutes']
    
    user = update_user(user_id, stats_update)
    return jsonify({"success": True, "message": "Health synced", "user": user})

@app.route('/api/sync/focus', methods=['POST'])
def sync_focus():
    data = request.json
    if not data or 'user_id' not in data:
        return jsonify({"error": "Missing user_id"}), 400
    
    user_id = data.pop('user_id')
    user = get_user(user_id)
    
    # Gamification Logic: Weekly Task Completion -> Planet Unlock
    newly_unlocked = None
    tasks_completed = data.get('tasks_completed', 0)
    tasks_total = data.get('tasks_total', 1)
    
    if tasks_total > 0:
        completion_rate = tasks_completed / tasks_total
        if completion_rate >= 0.6:
            planets_pool = ["綠洲星球", "熔岩星球", "冰雪星球", "沙漠星球", "水晶星球", "暗物質星球"]
            current_unlocked = set(user.get("planet", {}).get("unlocked", []))
            
            # Find planets not yet unlocked
            available_planets = [p for p in planets_pool if p not in current_unlocked]
            
            if available_planets:
                # Randomly unlock a new one
                newly_unlocked = random.choice(available_planets)
                user["planet"].setdefault("unlocked", []).append(newly_unlocked)
                # Automatically equip the new planet (optional, but gives a cool effect)
                user["planet"]["name"] = newly_unlocked
                
                # Level up the base planet system
                user["planet"]["level"] = user["planet"].get("level", 1) + 1
                
                # Assign a color based on planet type
                colors = {
                    "綠洲星球": "#34d399", "熔岩星球": "#ef4444", 
                    "冰雪星球": "#60a5fa", "沙漠星球": "#fbbf24", 
                    "水晶星球": "#a78bfa", "暗物質星球": "#8b5cf6"
                }
                user["planet"]["color"] = colors.get(newly_unlocked, "#ffffff")

    # Update focus stats
    if 'focus_minutes' in data:
        user.setdefault("stats", {})["focus_minutes"] = data['focus_minutes']
    if 'current_goal' in data:
        user["current_goal"] = data['current_goal']
        
    users = load_all_users()
    users[user_id] = user
    save_all_users(users)
    
    return jsonify({
        "success": True, 
        "message": "Focus synced",
        "new_planet_unlocked": newly_unlocked,
        "user": user
    })

@app.route('/api/user/<user_id>', methods=['GET'])
def get_user_api(user_id):
    user = get_user(user_id)
    return jsonify({"success": True, "user": user})
    

if __name__ == '__main__':
    print(f"Server is running on http://127.0.0.1:5001")
    print(f"Uploading images to: {UPLOAD_FOLDER}")
    app.run(debug=True, port=5001)
