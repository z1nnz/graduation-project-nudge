import os

file_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard\assets\app.js"
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '["operations",' in line:
        lines[i] = '  ["operations", "商城頁", "operations.html"],\n'
        break

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Renamed navigation item in app.js")
