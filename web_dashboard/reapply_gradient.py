import os
import re

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"

# 1. Update planet.html
planet_path = os.path.join(dir_path, "planet.html")
with open(planet_path, 'r', encoding='utf-8') as f:
    p_content = f.read()

# Remove continents from HTML
p_content = re.sub(r'<div class="planet">.*?</div>', '<div class="planet">\n              </div>', p_content, flags=re.DOTALL)

# Update init JS
old_p_init = """        if (colors['planet']) {
          const continents = document.querySelectorAll('.continent');
          continents.forEach(cont => {
            cont.style.background = colors['planet'];
          });
        }"""
new_p_init = """        if (colors['planet']) {
          const p = document.querySelector('.planet');
          if (p) {
            p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
            p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
          }
        }"""
p_content = p_content.replace(old_p_init, new_p_init)

with open(planet_path, 'w', encoding='utf-8') as f:
    f.write(p_content)


# 2. Update admin_dashboard.html
admin_path = os.path.join(dir_path, "admin_dashboard.html")
with open(admin_path, 'r', encoding='utf-8') as f:
    a_content = f.read()

# Remove continents from HTML
a_content = re.sub(r'<div class="planet planet-target active" id="adminPlanet" onclick="selectTarget\(this, \'planet\'\)">.*?</div>', '<div class="planet planet-target active" id="adminPlanet" onclick="selectTarget(this, \'planet\')">\n                  </div>', a_content, flags=re.DOTALL)

# Remove Continent CRUD UI
a_content = re.sub(r'<div class="crud-action-group" style="margin-top: 1.5rem;">\s*<strong style="width: 80px;">板塊管理</strong>\s*<button class="admin-btn" onclick="addContinent\(\)">＋ 新增板塊</button>\s*<button class="admin-btn danger" onclick="removeContinent\(\)">－ 刪除板塊</button>\s*</div>', '', a_content)
a_content = a_content.replace('地表主要顏色', '目標主要顏色')
a_content = a_content.replace('選擇顏色後會立刻變更星球上的所有大陸板塊色調', '選擇顏色後會立刻變更您所選定星球或衛星的色調')

# Update init JS
old_a_init = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const continents = document.querySelectorAll('#adminPlanet .continent');
          continents.forEach(cont => cont.style.background = colors['planet']);
        }"""
new_a_init = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const p = document.getElementById('adminPlanet');
          p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
          p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
        }"""
a_content = a_content.replace(old_a_init, new_a_init)

# Update applyColorToTarget logic
old_apply = """        if (currentTargetId === 'planet') {
          const continents = currentTarget.querySelectorAll('.continent');
          continents.forEach(cont => cont.style.background = colorCode);
          currentTarget.style.background = '';
          currentTarget.style.boxShadow = '';
        } else {"""
new_apply = """        if (currentTargetId === 'planet') {
          currentTarget.style.background = `radial-gradient(circle at 38% 28%, ${colorCode}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colorCode})`;
          currentTarget.style.boxShadow = `inset 0 0 40px ${colorCode}66, 0 0 20px ${colorCode}33`;
        } else {"""
a_content = a_content.replace(old_apply, new_apply)

# Remove continent CRUD JS
# We find contCount and remove continent functions
a_content = re.sub(r'let contCount = 3;\s*function addContinent\(\).*?function removeContinent\(\).*?\}\s*\}\s*\}', '', a_content, flags=re.DOTALL)

with open(admin_path, 'w', encoding='utf-8') as f:
    f.write(a_content)

print("Re-applied gradient logic.")
