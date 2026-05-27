import os

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"
app_js_path = os.path.join(dir_path, "assets", "app.js")

with open(app_js_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the old injectAdminSwitch function completely
start_idx = content.find("function injectAdminSwitch()")
if start_idx != -1:
    content = content[:start_idx]

# The new injectAdminSwitch function
new_inject_code = """
function injectAdminSwitch() {
  const existingBtn1 = document.querySelector('.admin-switch-btn');
  if (existingBtn1) existingBtn1.remove();
  const existingBtn2 = document.querySelector('.exit-admin-btn');
  if (existingBtn2) existingBtn2.remove();

  const isAdminPage = window.location.pathname.includes('admin_dashboard.html');

  const style = document.createElement('style');
  style.innerHTML = `
    .global-admin-switch-btn {
      position: absolute;
      top: 1.5rem;
      right: 2rem;
      background: transparent;
      border: none;
      color: #F3F4F6;
      font-weight: 700;
      font-size: 1.1rem;
      cursor: pointer;
      z-index: 1000;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      text-shadow: 0 1px 4px rgba(0,0,0,0.6);
      transition: opacity 0.2s;
    }
    .global-admin-switch-btn:hover {
      opacity: 0.8;
    }
    .global-login-modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.3s ease;
    }
    .global-login-modal-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }
    .global-login-modal {
      background: var(--c-panel-bg);
      padding: 2.5rem;
      border-radius: 20px;
      width: 100%;
      max-width: 400px;
      box-shadow: 0 24px 48px var(--shadow-color);
      transform: translateY(20px);
      transition: transform 0.3s ease;
      border: 1px solid var(--c-border);
      color: var(--c-text);
    }
    .global-login-modal-overlay.active .global-login-modal {
      transform: translateY(0);
    }
    .global-login-modal h2 { margin-top: 0; margin-bottom: 1.5rem; font-size: 1.5rem; }
    .global-form-group { margin-bottom: 1.25rem; text-align: left; }
    .global-form-group label { display: block; font-size: 0.875rem; margin-bottom: 0.5rem; color: var(--c-text-muted); }
    .global-form-group input { width: 100%; padding: 0.75rem 1rem; border-radius: 8px; border: 1px solid var(--c-border); background: var(--c-bg); color: var(--c-text); box-sizing: border-box; }
    .global-login-actions { display: flex; justify-content: flex-end; gap: 1rem; margin-top: 2rem; }
    .global-btn-cancel { background: transparent; border: 1px solid var(--c-border); color: var(--c-text); padding: 0.6rem 1.2rem; border-radius: 8px; cursor: pointer; }
    .global-btn-submit { background: var(--c-primary); border: none; color: white; padding: 0.6rem 1.2rem; border-radius: 8px; cursor: pointer; font-weight: 600; }
    .global-error-msg { color: #ef4444; font-size: 0.875rem; margin-top: 0.5rem; display: none; text-align: left; }
  `;
  document.head.appendChild(style);

  const main = document.querySelector('.main');
  if (main) main.style.position = 'relative';
  const btnContainer = main || document.body;
  
  const btn = document.createElement('button');
  btn.className = 'global-admin-switch-btn';
  
  if (isAdminPage) {
    btn.innerHTML = '⚙ 切回前台';
    btn.onclick = () => window.location.href = 'index.html';
  } else {
    btn.innerHTML = '⚙ 切換成後台';
    btn.onclick = () => document.getElementById('globalLoginModal').classList.add('active');
  }
  
  btnContainer.appendChild(btn);

  if (!isAdminPage) {
    const modalHtml = `
      <div class="global-login-modal-overlay" id="globalLoginModal">
        <div class="global-login-modal">
          <h2>後台登入</h2>
          <div class="global-form-group">
            <label>帳號</label>
            <input type="text" id="gAdminUsername" placeholder="請輸入 admin" />
          </div>
          <div class="global-form-group">
            <label>密碼</label>
            <input type="password" id="gAdminPassword" placeholder="請輸入 admin" />
          </div>
          <div class="global-error-msg" id="gLoginError">帳號或密碼錯誤！預設請使用 admin / admin。</div>
          <div class="global-login-actions">
            <button class="global-btn-cancel" onclick="document.getElementById('globalLoginModal').classList.remove('active')">取消</button>
            <button class="global-btn-submit" onclick="gAttemptLogin()">登入</button>
          </div>
        </div>
      </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHtml);

    window.gAttemptLogin = function() {
      const user = document.getElementById('gAdminUsername').value;
      const pass = document.getElementById('gAdminPassword').value;
      if (user === 'admin' && pass === 'admin') {
        window.location.href = 'admin_dashboard.html';
      } else {
        document.getElementById('gLoginError').style.display = 'block';
      }
    }
  }
}

document.addEventListener("DOMContentLoaded", () => {
    setTimeout(injectAdminSwitch, 100);
});
"""

with open(app_js_path, 'w', encoding='utf-8') as f:
    f.write(content + "\n" + new_inject_code)

print("Updated app.js")
