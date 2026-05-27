import os
import glob

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"

# Fix app.js modules array
app_js_path = os.path.join(dir_path, "assets", "app.js")
with open(app_js_path, 'r', encoding='utf-8') as f:
    content = f.read()

# We need to find the start and end of `const modules = [`
start_idx = content.find("const modules = [")
if start_idx != -1:
    end_idx = content.find("];", start_idx) + 2
    old_modules = content[start_idx:end_idx]
    new_modules = """const modules = [
  ["home", "總覽入口", "index.html"],
  ["personal", "個人進階分析", "personal.html"],
  ["guardian", "家長陪伴中心", "guardian.html"],
  ["groups", "團體 / 教育管理", "groups.html"],
  ["operations", "商城頁", "operations.html"],
  ["research", "研究 / 展示中心", "research.html"],
  ["planet", "自律城市 / 星球", "planet.html"],
  ["presentation", "專題發表流程", "presentation.html"],
];"""
    content = content.replace(old_modules, new_modules)

with open(app_js_path, 'w', encoding='utf-8') as f:
    f.write(content)

# Update HTML files cache buster
html_files = glob.glob(os.path.join(dir_path, "*.html"))
for f_path in html_files:
    with open(f_path, 'r', encoding='utf-8') as f:
        html = f.read()
    
    # Cache busting for app.js
    html = html.replace('src="assets/app.js"', 'src="assets/app.js?v=2"')
    html = html.replace('src="assets/app.js?v=1"', 'src="assets/app.js?v=2"')
    
    # Also fix admin_dashboard.html h2
    if 'admin_dashboard.html' in f_path:
        html = html.replace('商城營運工具', '商城上架')
    
    with open(f_path, 'w', encoding='utf-8') as f:
        f.write(html)

print("Fixed app.js, cache busted, and updated admin_dashboard.html")
