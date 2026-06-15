# QuikAssistant Web Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a web-based interface for editing orders, tracking status, viewing logs, and managing trading sessions.

**Architecture:** Python Flask backend serving a single-page application with HTML/CSS/JS frontend. Direct CSV file manipulation for order data.

**Tech Stack:** Python 3, Flask, HTML5, CSS3, JavaScript (vanilla)

---

## File Structure

```
web/
├── app.py              # Flask application entry point
├── api.py              # API endpoints for orders, logs, trading
├── csv_handler.py      # CSV file read/write operations
├── templates/
│   └── index.html      # Main SPA template
└── static/
    ├── css/
    │   └── style.css   # Styles
    └── js/
        └── app.js      # Frontend logic
```

---

### Task 1: Project Setup

**Files:**
- Create: `web/app.py`
- Create: `web/requirements.txt`

- [ ] **Step 1: Create requirements.txt**

```txt
flask>=2.3.0
```

- [ ] **Step 2: Create minimal Flask app**

```python
from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

- [ ] **Step 3: Create minimal template**

Create `web/templates/index.html`:
```html
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>QuikAssistant</title>
</head>
<body>
    <h1>QuikAssistant Web Interface</h1>
</body>
</html>
```

- [ ] **Step 4: Test run**

Run: `cd web && python app.py`
Expected: Server starts on http://localhost:5000

- [ ] **Step 5: Commit**

```bash
git add web/
git commit -m "feat: add minimal Flask web application scaffold"
```

---

### Task 2: CSV Handler

**Files:**
- Create: `web/csv_handler.py`

- [ ] **Step 1: Write CSV handler module**

```python
import os
import csv
from typing import List, Dict, Optional

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'Data')

def get_csv_files(broker: str) -> Dict[str, str]:
    """Return available CSV files for a broker."""
    return {
        'buy': os.path.join(DATA_DIR, f'{broker}_BuyOrders.csv'),
        'buy_edge': os.path.join(DATA_DIR, f'{broker}_BuyOrders_Edge.csv'),
        'buy_bonds': os.path.join(DATA_DIR, f'{broker}_BuyOrdersBonds_Edge.csv'),
        'sell': os.path.join(DATA_DIR, f'{broker}_SellOrders.csv'),
        'sell_edge': os.path.join(DATA_DIR, f'{broker}_SellOrders_Edge.csv'),
    }

def read_orders(filepath: str) -> List[Dict]:
    """Read orders from CSV file."""
    orders = []
    if not os.path.exists(filepath):
        return orders
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('--') or line.startswith('----'):
                continue
            
            parts = line.split(';')
            if len(parts) >= 5:
                orders.append({
                    'line': line_num,
                    'name': parts[0],
                    'side': parts[1],
                    'isin': parts[2],
                    'qty': parts[3],
                    'price': parts[4],
                    'raw': line
                })
    return orders

def write_orders(filepath: str, orders: List[Dict]) -> bool:
    """Write orders back to CSV file."""
    try:
        lines = []
        for order in orders:
            lines.append(f"{order['name']};{order['side']};{order['isin']};{order['qty']};{order['price']}")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        return True
    except Exception as e:
        print(f"Error writing CSV: {e}")
        return False

def get_all_brokers() -> List[str]:
    """Get list of available brokers."""
    brokers = set()
    for filename in os.listdir(DATA_DIR):
        if filename.endswith('_BuyOrders.csv'):
            broker = filename.replace('_BuyOrders.csv', '')
            if not broker.startswith('_'):
                brokers.add(broker)
    return sorted(brokers)
```

- [ ] **Step 2: Test CSV handler manually**

Run: `cd web && python -c "from csv_handler import get_all_brokers; print(get_all_brokers())"`
Expected: `['FINAM', 'PSB', 'VTB']`

- [ ] **Step 3: Commit**

```bash
git add web/csv_handler.py
git commit -m "feat: add CSV file handler for order management"
```

---

### Task 3: Orders API

**Files:**
- Create: `web/api.py`
- Modify: `web/app.py`

- [ ] **Step 1: Create API module**

```python
from flask import Blueprint, jsonify, request
from csv_handler import get_csv_files, read_orders, write_orders, get_all_brokers

api = Blueprint('api', __name__)

@api.route('/api/brokers')
def brokers():
    return jsonify(get_all_brokers())

@api.route('/api/orders/<broker>')
def orders(broker):
    file_type = request.args.get('type', 'buy')
    files = get_csv_files(broker)
    
    filepath = files.get(file_type)
    if not filepath:
        return jsonify({'error': 'Unknown file type'}), 400
    
    orders = read_orders(filepath)
    return jsonify(orders)

@api.route('/api/orders/<broker>/<isin>', methods=['PUT'])
def update_order(broker, isin):
    data = request.json
    file_type = data.get('type', 'buy')
    files = get_csv_files(broker)
    
    filepath = files.get(file_type)
    if not filepath:
        return jsonify({'error': 'Unknown file type'}), 400
    
    orders = read_orders(filepath)
    for order in orders:
        if order['isin'] == isin:
            order['qty'] = data.get('qty', order['qty'])
            order['price'] = data.get('price', order['price'])
            break
    
    if write_orders(filepath, orders):
        return jsonify({'success': True})
    return jsonify({'error': 'Write failed'}), 500

@api.route('/api/orders/<broker>/<isin>/toggle', methods=['POST'])
def toggle_order(broker, isin):
    data = request.json
    file_type = data.get('type', 'buy')
    files = get_csv_files(broker)
    
    filepath = files.get(file_type)
    if not filepath:
        return jsonify({'error': 'Unknown file type'}), 400
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    for line in lines:
        if isin in line:
            if line.startswith('--'):
                line = line[2:]
            else:
                line = '--' + line
        new_lines.append(line)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    return jsonify({'success': True})
```

- [ ] **Step 2: Register blueprint in app.py**

```python
from flask import Flask, render_template
from api import api

app = Flask(__name__)
app.register_blueprint(api)

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

- [ ] **Step 3: Test API endpoints**

Run: `cd web && python -c "from api import api; print('API registered')"`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add web/api.py web/app.py
git commit -m "feat: add REST API for order CRUD operations"
```

---

### Task 4: Log API

**Files:**
- Modify: `web/api.py`

- [ ] **Step 1: Add log endpoints**

Add to `api.py`:
```python
import os
import glob

LOG_DIR = os.path.join(os.path.dirname(__file__), '..', 'Log')

@api.route('/api/logs')
def logs():
    broker = request.args.get('broker', 'VTB')
    log_dir = os.path.join(LOG_DIR, broker)
    
    if not os.path.exists(log_dir):
        return jsonify([])
    
    log_files = sorted(glob.glob(os.path.join(log_dir, '*.log')), reverse=True)
    if not log_files:
        return jsonify([])
    
    latest_log = log_files[0]
    entries = []
    
    with open(latest_log, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(line)
    
    return jsonify(entries[-200:])  # Last 200 lines

@api.route('/api/logs/list')
def log_list():
    brokers = []
    if os.path.exists(LOG_DIR):
        for broker_dir in os.listdir(LOG_DIR):
            if os.path.isdir(os.path.join(LOG_DIR, broker_dir)):
                brokers.append(broker_dir)
    return jsonify(sorted(brokers))
```

- [ ] **Step 2: Test log endpoint**

Run: `cd web && curl http://localhost:5000/api/logs?broker=VTB`
Expected: JSON array of log entries

- [ ] **Step 3: Commit**

```bash
git add web/api.py
git commit -m "feat: add log viewing API endpoints"
```

---

### Task 5: Frontend - Main Layout

**Files:**
- Create: `web/templates/index.html`
- Create: `web/static/css/style.css`

- [ ] **Step 1: Create HTML template**

```html
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QuikAssistant</title>
    <link rel="stylesheet" href="/static/css/style.css">
</head>
<body>
    <header>
        <h1>QuikAssistant</h1>
        <nav>
            <button class="tab active" data-tab="orders">Заявки</button>
            <button class="tab" data-tab="dashboard">Дашборд</button>
            <button class="tab" data-tab="logs">Логи</button>
            <button class="tab" data-tab="control">Управление</button>
        </nav>
    </header>
    
    <main>
        <div id="orders" class="tab-content active">
            <div class="controls">
                <select id="broker-select">
                    <option value="VTB">VTB</option>
                    <option value="FINAM">FINAM</option>
                    <option value="PSB">PSB</option>
                </select>
                <select id="file-type">
                    <option value="buy">Покупка</option>
                    <option value="buy_edge">Покупка (Edge)</option>
                    <option value="buy_bonds">Облигации</option>
                    <option value="sell">Продажа</option>
                </select>
                <button id="refresh-btn">Обновить</button>
            </div>
            <table id="orders-table">
                <thead>
                    <tr>
                        <th>Название</th>
                        <th>ISIN</th>
                        <th>Сторона</th>
                        <th>Кол-во</th>
                        <th>Цена</th>
                        <th>Действия</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
        
        <div id="dashboard" class="tab-content">
            <p>Дашборд (в разработке)</p>
        </div>
        
        <div id="logs" class="tab-content">
            <div class="controls">
                <select id="log-broker">
                    <option value="VTB">VTB</option>
                    <option value="FINAM">FINAM</option>
                    <option value="PSB">PSB</option>
                </select>
                <button id="refresh-logs">Обновить</button>
            </div>
            <pre id="log-output"></pre>
        </div>
        
        <div id="control" class="tab-content">
            <p>Управление (в разработке)</p>
        </div>
    </main>
    
    <script src="/static/js/app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Create CSS styles**

```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #1a1a2e;
    color: #eee;
}

header {
    background: #16213e;
    padding: 1rem 2rem;
    border-bottom: 1px solid #0f3460;
}

header h1 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
}

nav {
    display: flex;
    gap: 0.5rem;
}

.tab {
    background: #0f3460;
    color: #eee;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    cursor: pointer;
}

.tab:hover {
    background: #1a4a8a;
}

.tab.active {
    background: #e94560;
}

main {
    padding: 2rem;
}

.tab-content {
    display: none;
}

.tab-content.active {
    display: block;
}

.controls {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
}

select, button {
    padding: 0.5rem 1rem;
    border: 1px solid #0f3460;
    border-radius: 4px;
    background: #16213e;
    color: #eee;
}

button {
    cursor: pointer;
    background: #0f3460;
}

button:hover {
    background: #1a4a8a;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th, td {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid #0f3460;
}

th {
    background: #16213e;
    font-weight: 600;
}

tr:hover {
    background: #16213e;
}

.disabled {
    opacity: 0.5;
}

pre {
    background: #16213e;
    padding: 1rem;
    border-radius: 4px;
    overflow-x: auto;
    font-size: 0.875rem;
    line-height: 1.5;
    max-height: 600px;
    overflow-y: auto;
}

.edit-input {
    width: 80px;
    padding: 0.25rem;
    background: #0f3460;
    border: 1px solid #1a4a8a;
    color: #eee;
    border-radius: 2px;
}

.btn-toggle {
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
}
```

- [ ] **Step 3: Verify template loads**

Run: `cd web && python app.py`
Expected: Open http://localhost:5000, see styled page with tabs

- [ ] **Step 4: Commit**

```bash
git add web/templates/ web/static/
git commit -m "feat: add main HTML layout and CSS styles"
```

---

### Task 6: Frontend - Orders Tab

**Files:**
- Create: `web/static/js/app.js`

- [ ] **Step 1: Create JavaScript module**

```javascript
document.addEventListener('DOMContentLoaded', () => {
    // Tab switching
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            document.getElementById(tab.dataset.tab).classList.add('active');
        });
    });
    
    // Orders tab
    const ordersTable = document.querySelector('#orders-table tbody');
    const brokerSelect = document.getElementById('broker-select');
    const fileTypeSelect = document.getElementById('file-type');
    const refreshBtn = document.getElementById('refresh-btn');
    
    async function loadOrders() {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        
        try {
            const response = await fetch(`/api/orders/${broker}?type=${type}`);
            const orders = await response.json();
            
            ordersTable.innerHTML = orders.map(order => `
                <tr class="${order.name.startsWith('--') ? 'disabled' : ''}">
                    <td>${order.name}</td>
                    <td>${order.isin}</td>
                    <td>${order.side === 'B' ? 'Покупка' : 'Продажа'}</td>
                    <td><input class="edit-input" type="number" value="${order.qty}" data-field="qty"></td>
                    <td><input class="edit-input" type="number" step="0.01" value="${order.price}" data-field="price"></td>
                    <td>
                        <button class="btn-toggle" data-isin="${order.isin}">Вкл/Выкл</button>
                        <button class="btn-save" data-isin="${order.isin}">Сохранить</button>
                    </td>
                </tr>
            `).join('');
            
            // Add event listeners
            document.querySelectorAll('.btn-toggle').forEach(btn => {
                btn.addEventListener('click', () => toggleOrder(btn.dataset.isin));
            });
            
            document.querySelectorAll('.btn-save').forEach(btn => {
                btn.addEventListener('click', () => saveOrder(btn.dataset.isin));
            });
        } catch (error) {
            console.error('Error loading orders:', error);
        }
    }
    
    async function toggleOrder(isin) {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        
        await fetch(`/api/orders/${broker}/${isin}/toggle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type })
        });
        
        loadOrders();
    }
    
    async function saveOrder(isin) {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        const row = document.querySelector(`[data-isin="${isin}"]`).closest('tr');
        const qty = row.querySelector('[data-field="qty"]').value;
        const price = row.querySelector('[data-field="price"]').value;
        
        await fetch(`/api/orders/${broker}/${isin}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, qty, price })
        });
        
        loadOrders();
    }
    
    refreshBtn.addEventListener('click', loadOrders);
    brokerSelect.addEventListener('change', loadOrders);
    fileTypeSelect.addEventListener('change', loadOrders);
    
    loadOrders();
});
```

- [ ] **Step 2: Test orders tab**

Run: `cd web && python app.py`
Expected: Open http://localhost:5000, select broker, see orders table with editable fields

- [ ] **Step 3: Commit**

```bash
git add web/static/js/app.js
git commit -m "feat: add orders tab with CRUD functionality"
```

---

### Task 7: Frontend - Logs Tab

**Files:**
- Modify: `web/static/js/app.js`

- [ ] **Step 1: Add logs functionality**

Add to `app.js`:
```javascript
// Logs tab
const logOutput = document.getElementById('log-output');
const logBroker = document.getElementById('log-broker');
const refreshLogs = document.getElementById('refresh-logs');

async function loadLogs() {
    const broker = logBroker.value;
    
    try {
        const response = await fetch(`/api/logs?broker=${broker}`);
        const logs = await response.json();
        
        logOutput.textContent = logs.join('\n');
        logOutput.scrollTop = logOutput.scrollHeight;
    } catch (error) {
        console.error('Error loading logs:', error);
    }
}

refreshLogs.addEventListener('click', loadLogs);
logBroker.addEventListener('change', loadLogs);
```

- [ ] **Step 2: Test logs tab**

Run: `cd web && python app.py`
Expected: Open http://localhost:5000, switch to Logs tab, see log entries

- [ ] **Step 3: Commit**

```bash
git add web/static/js/app.js
git commit -m "feat: add logs viewing tab"
```

---

### Task 8: Dashboard Stats

**Files:**
- Modify: `web/api.py`
- Modify: `web/static/js/app.js`
- Modify: `web/templates/index.html`

- [ ] **Step 1: Add stats API endpoint**

Add to `api.py`:
```python
@api.route('/api/stats')
def stats():
    broker = request.args.get('broker', 'VTB')
    files = get_csv_files(broker)
    
    total_orders = 0
    active_orders = 0
    disabled_orders = 0
    
    for filepath in files.values():
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('----'):
                        total_orders += 1
                        if line.startswith('--'):
                            disabled_orders += 1
                        else:
                            active_orders += 1
    
    return jsonify({
        'total': total_orders,
        'active': active_orders,
        'disabled': disabled_orders
    })
```

- [ ] **Step 2: Update dashboard HTML**

Replace dashboard content in `index.html`:
```html
<div id="dashboard" class="tab-content">
    <div class="stats-grid">
        <div class="stat-card">
            <h3>Всего заявок</h3>
            <p id="stat-total">0</p>
        </div>
        <div class="stat-card">
            <h3>Активных</h3>
            <p id="stat-active">0</p>
        </div>
        <div class="stat-card">
            <h3>Отключено</h3>
            <p id="stat-disabled">0</p>
        </div>
    </div>
</div>
```

- [ ] **Step 3: Add stats CSS**

Add to `style.css`:
```css
.stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin-top: 1rem;
}

.stat-card {
    background: #16213e;
    padding: 1.5rem;
    border-radius: 8px;
    text-align: center;
}

.stat-card h3 {
    font-size: 0.875rem;
    color: #888;
    margin-bottom: 0.5rem;
}

.stat-card p {
    font-size: 2rem;
    font-weight: bold;
    color: #e94560;
}
```

- [ ] **Step 4: Add stats loading to JS**

Add to `app.js`:
```javascript
// Dashboard
async function loadStats() {
    const broker = brokerSelect.value;
    
    try {
        const response = await fetch(`/api/stats?broker=${broker}`);
        const stats = await response.json();
        
        document.getElementById('stat-total').textContent = stats.total;
        document.getElementById('stat-active').textContent = stats.active;
        document.getElementById('stat-disabled').textContent = stats.disabled;
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Call when switching to dashboard
document.querySelector('[data-tab="dashboard"]').addEventListener('click', loadStats);
```

- [ ] **Step 5: Commit**

```bash
git add web/api.py web/static/js/app.js web/templates/index.html web/static/css/style.css
git commit -m "feat: add dashboard with order statistics"
```

---

### Task 9: Final Testing

**Files:** None (testing only)

- [ ] **Step 1: Run full application**

Run: `cd web && python app.py`
Expected: Server starts, all tabs functional

- [ ] **Step 2: Test all features**

1. Orders tab: Load orders, edit price, save, toggle enable/disable
2. Dashboard: View statistics
3. Logs: View log entries
4. All brokers: Switch between VTB, FINAM, PSB

- [ ] **Step 3: Commit final state**

```bash
git add .
git commit -m "feat: complete web interface for QuikAssistant"
```
