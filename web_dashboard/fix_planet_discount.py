import os
import re

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"
admin_path = os.path.join(dir_path, "admin_dashboard.html")
planet_path = os.path.join(dir_path, "planet.html")

# Fix admin_dashboard.html
with open(admin_path, 'r', encoding='utf-8') as f:
    admin_content = f.read()

# 1. Remove continents HTML
admin_content = re.sub(r'<span class="continent.*?</span>\s*', '', admin_content)

# 2. Remove continent management CRUD
crud_regex = r'<div class="crud-action-group".*?<strong.*?>板塊管理</strong>.*?</div>'
admin_content = re.sub(crud_regex, '', admin_content, flags=re.DOTALL)

# Also remove related JS functions
admin_content = re.sub(r'let contCount = 3;\s*', '', admin_content)
admin_content = re.sub(r'function addContinent\(\).*?\}\s*', '', admin_content, flags=re.DOTALL)
admin_content = re.sub(r'function removeContinent\(\).*?\}\s*', '', admin_content, flags=re.DOTALL)

# 3. Update applyColorToTarget to change planet gradient
old_apply_color = """        if (currentTargetId === 'planet') {
          const continents = currentTarget.querySelectorAll('.continent');
          continents.forEach(cont => cont.style.background = colorCode);
        } else {"""
new_apply_color = """        if (currentTargetId === 'planet') {
          currentTarget.style.background = `radial-gradient(circle at 38% 28%, ${colorCode}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colorCode})`;
          currentTarget.style.boxShadow = `inset 0 0 40px ${colorCode}66, 0 0 20px ${colorCode}33`;
        } else {"""
admin_content = admin_content.replace(old_apply_color, new_apply_color)

# 4. Update initial load color for planet
old_init_color = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const continents = document.querySelectorAll('#adminPlanet .continent');
          continents.forEach(cont => cont.style.background = colors['planet']);
        }"""
new_init_color = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const p = document.getElementById('adminPlanet');
          p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
          p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
        }"""
admin_content = admin_content.replace(old_init_color, new_init_color)

# 5. Fix discount item onchange
admin_content = admin_content.replace('<select id="discountItem" required>', '<select id="discountItem" required onchange="calculateDiscount()">')
admin_content = admin_content.replace('id="discountResult" placeholder="折後自律幣" disabled', 'id="discountResult" placeholder="折後自律幣" readonly')

with open(admin_path, 'w', encoding='utf-8') as f:
    f.write(admin_content)

# Fix planet.html
with open(planet_path, 'r', encoding='utf-8') as f:
    planet_content = f.read()

# 1. Remove continents
planet_content = re.sub(r'<span class="continent.*?</span>\s*', '', planet_content)

# 2. Update init color
old_planet_init = """        if (colors['planet']) {
          const continents = document.querySelectorAll('.continent');
          continents.forEach(cont => {
            cont.style.background = colors['planet'];
          });
        }"""
new_planet_init = """        if (colors['planet']) {
          const p = document.querySelector('.planet');
          if (p) {
            p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
            p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
          }
        }"""
planet_content = planet_content.replace(old_planet_init, new_planet_init)

with open(planet_path, 'w', encoding='utf-8') as f:
    f.write(planet_content)

print("Planet and Discount fixes applied!")
