import os
import json

dir_path = r"c:\Users\user\Downloads\web_dashboard-main\web_dashboard"

# 1. Update styles.css
styles_path = os.path.join(dir_path, "assets", "styles.css")
with open(styles_path, 'r', encoding='utf-8') as f:
    styles_content = f.read()

additional_styles = """
/* Added advanced styling */
.admin-form-group select {
  appearance: none;
  background-color: #0f172a !important;
  color: #f8fafc !important;
}
.admin-form-group select option {
  background-color: #1e293b !important;
  color: #f8fafc !important;
}
.continent {
  box-shadow: inset -5px -5px 15px rgba(0,0,0,0.5), inset 5px 5px 15px rgba(255,255,255,0.3) !important;
  border-radius: 40% 60% 50% 40% !important;
  transition: all 0.5s ease;
}
.planet-target, .mission-satellite {
  cursor: pointer;
  transition: box-shadow 0.3s ease;
}
.planet-target.active, .mission-satellite.active {
  box-shadow: 0 0 0 4px #00f0ff, 0 0 20px #00f0ff !important;
}
"""
if "/* Added advanced styling */" not in styles_content:
    with open(styles_path, 'a', encoding='utf-8') as f:
        f.write(additional_styles)

# 2. Update admin_dashboard.html
admin_path = os.path.join(dir_path, "admin_dashboard.html")
with open(admin_path, 'r', encoding='utf-8') as f:
    admin_content = f.read()

# Add Flatpickr CDNs
if "flatpickr.min.css" not in admin_content:
    head_end = admin_content.find("</head>")
    flatpickr_tags = """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
    <link rel="stylesheet" type="text/css" href="https://npmcdn.com/flatpickr/dist/themes/dark.css">
    <script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
    """
    admin_content = admin_content[:head_end] + flatpickr_tags + admin_content[head_end:]

# Update Planet HTML to be clickable
admin_content = admin_content.replace('<div class="planet" id="adminPlanet">', '<div class="planet planet-target active" id="adminPlanet" onclick="selectTarget(this, \'planet\')">')
admin_content = admin_content.replace('<div class="mission-satellite s1"></div>', '<div class="mission-satellite s1" onclick="selectTarget(this, \'sat1\')"></div>')
admin_content = admin_content.replace('<div class="mission-satellite s2"></div>', '<div class="mission-satellite s2" onclick="selectTarget(this, \'sat2\')"></div>')
admin_content = admin_content.replace('<div class="mission-satellite s3"></div>', '<div class="mission-satellite s3" onclick="selectTarget(this, \'sat3\')"></div>')

# Update planet color picker HTML
old_color_input = '<input type="color" id="planetColor" value="#22c55e" style="height: 40px; padding: 2px;" onchange="changePlanetColor(this.value)" />'
new_color_input = '<input type="color" id="planetColor" value="#22c55e" style="height: 40px; padding: 2px;" onchange="applyColorToTarget(this.value)" />'
admin_content = admin_content.replace(old_color_input, new_color_input)

# Update Discount Panel HTML
old_discount_form = """<div class="admin-form-group">
                  <label>折扣特價 (自律幣)</label>
                  <input type="number" id="discountPrice" placeholder="例如：99" required />
                </div>"""
new_discount_form = """<div class="admin-form-group">
                  <label>折扣折數 (例如輸入8代表8折)</label>
                  <div style="display: flex; gap: 10px;">
                    <input type="number" id="discountPercent" placeholder="8" oninput="calculateDiscount()" required style="width: 50%;" />
                    <input type="text" id="discountResult" placeholder="折後自律幣" disabled style="width: 50%; background: rgba(255,255,255,0.05);" />
                  </div>
                </div>"""
admin_content = admin_content.replace(old_discount_form, new_discount_form)
admin_content = admin_content.replace('type="datetime-local" id="discountStart"', 'type="text" id="discountStart" placeholder="選擇開始時間..."')
admin_content = admin_content.replace('type="datetime-local" id="discountEnd"', 'type="text" id="discountEnd" placeholder="選擇結束時間..."')

# Update JS in admin_dashboard.html
js_additions = """
      // Targeted Color Selection Logic
      let currentTarget = document.getElementById('adminPlanet');
      let currentTargetId = 'planet';

      function selectTarget(element, targetId) {
        document.querySelectorAll('.planet-target, .mission-satellite').forEach(el => el.classList.remove('active'));
        element.classList.add('active');
        currentTarget = element;
        currentTargetId = targetId;
        
        const colors = JSON.parse(localStorage.getItem('nudgeColors') || '{}');
        if (colors[targetId]) {
          document.getElementById('planetColor').value = colors[targetId];
        }
      }

      function applyColorToTarget(colorCode) {
        const colors = JSON.parse(localStorage.getItem('nudgeColors') || '{}');
        colors[currentTargetId] = colorCode;
        localStorage.setItem('nudgeColors', JSON.stringify(colors));

        if (currentTargetId === 'planet') {
          const continents = currentTarget.querySelectorAll('.continent');
          continents.forEach(cont => cont.style.background = colorCode);
        } else {
          currentTarget.style.background = colorCode;
          currentTarget.style.boxShadow = `0 0 15px ${colorCode}`;
        }
      }

      // Initialize targeted colors on load
      document.addEventListener('DOMContentLoaded', () => {
        const colors = JSON.parse(localStorage.getItem('nudgeColors') || '{}');
        if (colors['planet']) {
          document.getElementById('planetColor').value = colors['planet'];
          const continents = document.querySelectorAll('#adminPlanet .continent');
          continents.forEach(cont => cont.style.background = colors['planet']);
        }
        ['sat1', 'sat2', 'sat3'].forEach(satId => {
          if (colors[satId]) {
            const sat = document.querySelector(`.mission-satellite.${satId.replace('sat', 's')}`);
            if (sat) {
              sat.style.background = colors[satId];
              sat.style.boxShadow = `0 0 15px ${colors[satId]}`;
            }
          }
        });
        
        // Initialize Flatpickr
        flatpickr("#discountStart", { enableTime: true, dateFormat: "Y-m-d H:i", time_24hr: true });
        flatpickr("#discountEnd", { enableTime: true, dateFormat: "Y-m-d H:i", time_24hr: true });
      });

      function calculateDiscount() {
        const itemSelect = document.getElementById('discountItem');
        const percentInput = document.getElementById('discountPercent').value;
        const resultInput = document.getElementById('discountResult');
        
        if (!itemSelect.value || !percentInput) {
          resultInput.value = '';
          return;
        }
        
        let originalPrice = 120;
        if (itemSelect.value === '星際探險家') originalPrice = 150;
        
        let percent = parseFloat(percentInput);
        if (percent > 10 && percent < 100) percent = percent / 100;
        else if (percent > 0 && percent <= 10) percent = percent / 10;
        
        const finalPrice = Math.round(originalPrice * percent);
        resultInput.value = finalPrice + ' 幣';
      }
"""
if "let currentTarget" not in admin_content:
    # Insert JS additions just before `// Planet CRUD Logic`
    admin_content = admin_content.replace('// Planet CRUD Logic', js_additions + '\n      // Planet CRUD Logic')
    
    # Also fix handleDiscount to use the calculated price
    admin_content = admin_content.replace("const price = document.getElementById('discountPrice').value;", "const price = document.getElementById('discountResult').value.replace(' 幣', '');")

with open(admin_path, 'w', encoding='utf-8') as f:
    f.write(admin_content)

print("Fixes applied successfully to admin_dashboard.html and styles.css.")
