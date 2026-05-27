import os
import re

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"

# 1. Revert planet.html
planet_path = os.path.join(dir_path, "planet.html")
with open(planet_path, 'r', encoding='utf-8') as f:
    p_content = f.read()

# Restore continents
p_content = p_content.replace('<div class="planet">', '<div class="planet">\n              <span class="continent c1" style="background: #22c55e;"></span>\n              <span class="continent c2" style="background: #16a34a;"></span>\n              <span class="continent c3" style="background: #15803d;"></span>')

# Restore init JS
old_p_init = """        if (colors['planet']) {
          const p = document.querySelector('.planet');
          if (p) {
            p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
            p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
          }
        }"""
new_p_init = """        if (colors['planet']) {
          const continents = document.querySelectorAll('.continent');
          continents.forEach(cont => {
            cont.style.background = colors['planet'];
          });
        }"""
p_content = p_content.replace(old_p_init, new_p_init)

# Restore orbit-five
orbit_four = """            <div class="orbit-line orbit-four">
              <div class="mission-satellite s10"></div>
              <div class="mission-satellite s11"></div>
              <div class="mission-satellite s12"></div>
            </div>"""
orbit_five = """
            <div class="orbit-line orbit-five">
              <div class="asteroid a1"></div>
              <div class="asteroid a2"></div>
              <div class="asteroid a3"></div>
            </div>"""
p_content = p_content.replace(orbit_four, orbit_four + orbit_five)

with open(planet_path, 'w', encoding='utf-8') as f:
    f.write(p_content)

# 2. Revert admin_dashboard.html
admin_path = os.path.join(dir_path, "admin_dashboard.html")
with open(admin_path, 'r', encoding='utf-8') as f:
    a_content = f.read()

# Restore continents in HTML
a_content = a_content.replace('<div class="planet planet-target active" id="adminPlanet" onclick="selectTarget(this, \'planet\')">\n                  </div>', '<div class="planet planet-target active" id="adminPlanet" onclick="selectTarget(this, \'planet\')">\n                  <span class="continent c1" style="background: #22c55e;"></span>\n                  <span class="continent c2" style="background: #16a34a;"></span>\n                  <span class="continent c3" style="background: #15803d;"></span>\n                </div>')

# Restore Continent CRUD UI
crud_sat = """              <div class="crud-action-group">
                <strong style="width: 80px;">衛星管理</strong>
                <button class="admin-btn" onclick="addSatellite()">＋ 新增衛星</button>
                <button class="admin-btn danger" onclick="removeSatellite()">－ 刪除衛星</button>
              </div>"""
crud_cont = """

              <div class="crud-action-group" style="margin-top: 1.5rem;">
                <strong style="width: 80px;">板塊管理</strong>
                <button class="admin-btn" onclick="addContinent()">＋ 新增板塊</button>
                <button class="admin-btn danger" onclick="removeContinent()">－ 刪除板塊</button>
              </div>"""
a_content = a_content.replace(crud_sat, crud_sat + crud_cont)
a_content = a_content.replace('目標主要顏色', '地表主要顏色')
a_content = a_content.replace('選擇顏色後會立刻變更您所選定星球或衛星的色調', '選擇顏色後會立刻變更星球上的所有大陸板塊色調')

# Restore init JS
old_a_init = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const p = document.getElementById('adminPlanet');
          p.style.background = `radial-gradient(circle at 38% 28%, ${colors['planet']}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colors['planet']})`;
          p.style.boxShadow = `inset 0 0 40px ${colors['planet']}66, 0 0 20px ${colors['planet']}33`;
        }"""
new_a_init = """        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const continents = document.querySelectorAll('#adminPlanet .continent');
          continents.forEach(cont => cont.style.background = colors['planet']);
        }"""
a_content = a_content.replace(old_a_init, new_a_init)

# Restore applyColorToTarget logic
old_apply = """        if (currentTargetId === 'planet') {
          currentTarget.style.background = `radial-gradient(circle at 38% 28%, ${colorCode}44, transparent 30%), linear-gradient(145deg, #0a0f25, ${colorCode})`;
          currentTarget.style.boxShadow = `inset 0 0 40px ${colorCode}66, 0 0 20px ${colorCode}33`;
        } else {"""
new_apply = """        if (currentTargetId === 'planet') {
          const continents = currentTarget.querySelectorAll('.continent');
          continents.forEach(cont => cont.style.background = colorCode);
          currentTarget.style.background = '';
          currentTarget.style.boxShadow = '';
        } else {"""
a_content = a_content.replace(old_apply, new_apply)

# Restore continent CRUD JS
cont_js = """
      let contCount = 3;
      function addContinent() {
        const p = document.getElementById('adminPlanet');
        const cont = document.createElement('span');
        contCount++;
        cont.className = 'continent c' + (contCount > 5 ? Math.floor(Math.random()*5+1) : contCount);
        const currentColor = document.getElementById('planetColor').value;
        cont.style.background = currentColor;
        p.appendChild(cont);
      }

      function removeContinent() {
        if (contCount > 0) {
          const p = document.getElementById('adminPlanet');
          if (p.lastElementChild && p.lastElementChild.classList.contains('continent')) {
            p.removeChild(p.lastElementChild);
            contCount--;
          }
        }
      }
"""
a_content = a_content.replace('      // Planet CRUD Logic', '      // Planet CRUD Logic' + cont_js)

with open(admin_path, 'w', encoding='utf-8') as f:
    f.write(a_content)

print("Reverted to previous state.")
