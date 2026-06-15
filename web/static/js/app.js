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

    // Dashboard
    const brokerStatsDiv = document.getElementById('broker-stats');
    const tradeStatsDiv = document.getElementById('trade-stats');
    const tradesTable = document.querySelector('#trades-table tbody');
    const tradeSource = document.getElementById('trade-source');
    const refreshTrades = document.getElementById('refresh-trades');
    
    function fmt(n) {
        return n >= 1000000 ? (n/1000000).toFixed(1) + 'M' : n >= 1000 ? (n/1000).toFixed(1) + 'K' : Math.round(n);
    }
    
    async function loadDashboard() {
        try {
            const response = await fetch('/api/stats/all');
            const data = await response.json();
            
            brokerStatsDiv.innerHTML = Object.entries(data.brokers).map(([broker, s]) => `
                <div class="broker-card">
                    <h3>${broker}</h3>
                    <div class="broker-grid">
                        <div class="broker-stat"><div class="label">Всего</div><div class="value">${s.total}</div></div>
                        <div class="broker-stat"><div class="label">Активных</div><div class="value">${s.active}</div></div>
                        <div class="broker-stat"><div class="label">Отключено</div><div class="value">${s.disabled}</div></div>
                        <div class="broker-stat"><div class="label">Акции</div><div class="value">${s.stocks}</div></div>
                        <div class="broker-stat"><div class="label">Облигации</div><div class="value">${s.bonds}</div></div>
                        <div class="broker-stat"><div class="label">Сумма акций</div><div class="value money">${fmt(s.stocks_value)}</div></div>
                        <div class="broker-stat"><div class="label">Сумма облигаций</div><div class="value money">${fmt(s.bonds_value)}</div></div>
                    </div>
                </div>
            `).join('');
            
            const t = data.totals;
            brokerStatsDiv.innerHTML += `
                <div class="broker-card" style="border-left: 3px solid #e94560;">
                    <h3>ИТОГО</h3>
                    <div class="broker-grid">
                        <div class="broker-stat"><div class="label">Всего</div><div class="value">${t.total}</div></div>
                        <div class="broker-stat"><div class="label">Активных</div><div class="value">${t.active}</div></div>
                        <div class="broker-stat"><div class="label">Акции</div><div class="value">${t.stocks}</div></div>
                        <div class="broker-stat"><div class="label">Облигации</div><div class="value">${t.bonds}</div></div>
                        <div class="broker-stat"><div class="label">Сумма акций</div><div class="value money">${fmt(t.stocks_value)}</div></div>
                        <div class="broker-stat"><div class="label">Сумма облигаций</div><div class="value money">${fmt(t.bonds_value)}</div></div>
                    </div>
                </div>
            `;
        } catch (error) {
            console.error('Error loading dashboard:', error);
        }
    }
    
    async function loadTrades() {
        const source = tradeSource.value;
        try {
            const response = await fetch(`/api/trades?source=${source}`);
            const data = await response.json();
            
            tradeStatsDiv.innerHTML = `
                <div class="trade-summary">
                    <div class="trade-card"><div class="label">Всего сделок</div><div class="value">${data.total_trades}</div></div>
                    <div class="trade-card"><div class="label">Оборот</div><div class="value money">${fmt(data.total_value)}</div></div>
                    <div class="trade-card"><div class="label">Покупки</div><div class="value positive">${data.buys_count}</div></div>
                    <div class="trade-card"><div class="label">Продажи</div><div class="value negative">${data.sells_count}</div></div>
                    <div class="trade-card"><div class="label">Тикеров</div><div class="value">${data.unique_tickers}</div></div>
                    <div class="trade-card"><div class="label">Период</div><div class="value" style="font-size:0.85rem">${data.date_range.first} — ${data.date_range.last}</div></div>
                </div>
            `;
            
            tradesTable.innerHTML = data.recent.map(t => `
                <tr>
                    <td>${t.datetime}</td>
                    <td>${t.ticker}</td>
                    <td>${t.qty > 0 ? 'Покупка' : 'Продажа'}</td>
                    <td>${Math.abs(t.qty)}</td>
                    <td>${t.price}</td>
                    <td>${fmt(t.value)}</td>
                    <td>${t.broker}</td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading trades:', error);
        }
    }
    
    document.querySelector('[data-tab="dashboard"]').addEventListener('click', () => {
        loadDashboard();
        loadTrades();
    });
    tradeSource.addEventListener('change', loadTrades);
    refreshTrades.addEventListener('click', loadTrades);

    // Logs tab
    const logsTable = document.querySelector('#logs-table tbody');
    const logBroker = document.getElementById('log-broker');
    const logDate = document.getElementById('log-date');
    const logLevel = document.getElementById('log-level');
    const logSearch = document.getElementById('log-search');
    const refreshLogs = document.getElementById('refresh-logs');
    
    async function loadLogDates() {
        const broker = logBroker.value;
        try {
            const response = await fetch(`/api/logs/dates?broker=${broker}`);
            const dates = await response.json();
            logDate.innerHTML = dates.length
                ? dates.map(d => `<option value="${d}">${d}</option>`).join('')
                : '<option value="">Нет файлов</option>';
        } catch (e) {
            console.error('Error loading dates:', e);
        }
    }
    
    async function loadLogs() {
        const broker = logBroker.value;
        const date = logDate.value;
        const level = logLevel.value;
        const search = logSearch.value;
        
        try {
            const params = new URLSearchParams({ broker });
            if (date) params.set('date', date);
            if (level) params.set('level', level);
            if (search) params.set('search', search);
            
            const response = await fetch(`/api/logs?${params}`);
            const logs = await response.json();
            
            logsTable.innerHTML = logs.map(entry => `
                <tr>
                    <td><span class="level-badge level-${entry.level}">${entry.level}</span></td>
                    <td>${entry.time}</td>
                    <td>${entry.file}:${entry.line}</td>
                    <td title="${entry.raw}">${entry.message}</td>
                </tr>
            `).join('');
        } catch (error) {
            console.error('Error loading logs:', error);
        }
    }
    
    logBroker.addEventListener('change', () => {
        loadLogDates();
        loadLogs();
    });
    logDate.addEventListener('change', loadLogs);
    logLevel.addEventListener('change', loadLogs);
    logSearch.addEventListener('input', loadLogs);
    refreshLogs.addEventListener('click', () => {
        loadLogDates();
        loadLogs();
    });
    
    loadLogDates();
    loadLogs();
});
