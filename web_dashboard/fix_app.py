import os

app_js_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard\assets\app.js"

with open(app_js_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix injectModuleMenu
old_func = """function injectModuleMenu() {
  const sidebar = $(".sidebar");"""
new_func = """function injectModuleMenu() {
  if (window.location.pathname.includes('admin_dashboard.html')) return;
  const sidebar = $(".sidebar");"""

if "if (window.location.pathname.includes('admin_dashboard.html')) return;" not in content:
    content = content.replace(old_func, new_func)

# Fix button CSS
old_css = """    .global-admin-switch-btn {
      position: absolute;
      top: 1.5rem;
      right: 2rem;"""
new_css = """    .global-admin-switch-btn {
      position: fixed;
      top: 1.5rem;
      right: 1.5rem;"""

content = content.replace(old_css, new_css)

with open(app_js_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app.js")
