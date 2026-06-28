document.addEventListener('DOMContentLoaded', () => {
    // Tab switching
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            document.getElementById(tab.dataset.tab).classList.add('active');
            localStorage.setItem('activeTab', tab.dataset.tab);
        });
    });

    // Restore last active tab
    const savedTab = localStorage.getItem('activeTab');
    if (savedTab) {
        const tab = document.querySelector(`.tab[data-tab="${savedTab}"]`);
        if (tab) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            document.getElementById(savedTab).classList.add('active');
            setTimeout(() => tab.click(), 0);
        }
    }

    // Orders tab
    const ordersTable = document.querySelector('#orders-table tbody');
    const brokerSelect = document.getElementById('broker-select');
    const fileTypeSelect = document.getElementById('file-type');
    const refreshBtn = document.getElementById('refresh-btn');
    let instrumentsCache = {};

    function fmtNum(n) {
        const s = String(n);
        const parts = s.split('.');
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
        return parts.join('.');
    }

    function parseNum(s) {
        return parseFloat(s.replace(/\s/g, '')) || 0;
    }

    function initNumInputs() {
        document.querySelectorAll('.num-input').forEach(input => {
            if (input.value) {
                const v = parseFloat(input.value);
                if (!isNaN(v)) input.value = fmtNum(input.value);
            }
            input.addEventListener('focus', () => {
                input.value = input.value.replace(/\s/g, '');
            });
            input.addEventListener('blur', () => {
                const raw = input.value.replace(/\s/g, '');
                const num = parseFloat(raw);
                if (!isNaN(num)) input.value = fmtNum(raw);
            });
        });
    }
    
    async function loadInstruments() {
        try {
            const response = await fetch('/api/instruments');
            instrumentsCache = await response.json();
        } catch (e) {
            console.error('Error loading instruments:', e);
        }
    }
    
    let ordersSortBy = null;
    let ordersSortDir = 'asc';

    async function loadOrders() {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;

        try {
            const response = await fetch(`/api/orders/${broker}?type=${type}`);
            let orders = await response.json();

            // Enrich with instrument data for sorting
            orders = orders.map(order => {
                const inst = instrumentsCache[order.isin] || instrumentsCache[order.name] || {};
                const lot = inst.lot || 1;
                const price = parseFloat(order.price) || 0;
                const qty = parseInt(order.qty) || 0;
                const facevalue = inst.facevalue || 0;
                const isBond = order.isin.startsWith('SU') || order.isin.startsWith('RU000A');
                const actualPrice = isBond && facevalue ? facevalue * (price / 100) : price;
                const sum = actualPrice * qty * lot;
                const currentPrice = inst.price || 0;
                const maturity = inst.maturity || '';
                return { ...order, lot, sum, currentPrice, maturity, side: order.side === 'B' ? 'Покупка' : 'Продажа' };
            });

            // Sort
            if (ordersSortBy) {
                const reverse = ordersSortDir === 'desc';
                orders.sort((a, b) => {
                    let va, vb;
                    switch (ordersSortBy) {
                        case 'name': va = a.name; vb = b.name; break;
                        case 'maturity': va = a.maturity; vb = b.maturity; break;
                        case 'isin': va = a.isin; vb = b.isin; break;
                        case 'side': va = a.side; vb = b.side; break;
                        case 'lot': va = a.lot; vb = b.lot; break;
                        case 'qty': va = parseInt(a.qty)||0; vb = parseInt(b.qty)||0; break;
                        case 'price': va = parseFloat(a.price)||0; vb = parseFloat(b.price)||0; break;
                        case 'currentPrice': va = a.currentPrice; vb = b.currentPrice; break;
                        case 'sum': va = a.sum; vb = b.sum; break;
                    }
                    if (typeof va === 'string') return reverse ? vb.localeCompare(va) : va.localeCompare(vb);
                    return reverse ? vb - va : va - vb;
                });
            }

            ordersTable.innerHTML = orders.map(order => {
                const inst = instrumentsCache[order.isin] || instrumentsCache[order.name] || {};
                const price = parseFloat(order.price) || 0;
                const currentPrice = order.currentPrice;
                const diff = price && currentPrice ? ((currentPrice - price) / price * 100).toFixed(1) : 0;
                const diffClass = diff >= 0 ? 'positive' : 'negative';

                return `
                <tr class="${order.enabled ? '' : 'disabled'}" data-raw-line="${order.raw.replace(/"/g, '&quot;')}">
                    <td>${order.name}</td>
                    <td class="maturity-cell">${order.maturity || ''}</td>
                    <td>${order.isin}</td>
                    <td>${order.side}</td>
                    <td class="lot-cell">${order.lot}</td>
                    <td><input class="edit-input num-input" type="text" inputmode="numeric" value="${order.qty}" data-field="qty" data-isin="${order.isin}" ${order.enabled ? '' : 'disabled'}></td>
                    <td><input class="edit-input num-input" type="text" inputmode="numeric" step="0.01" value="${order.price}" data-field="price" data-isin="${order.isin}" ${order.enabled ? '' : 'disabled'}></td>
                    <td class="current-price">${currentPrice > 0 ? currentPrice : '-'} ${currentPrice > 0 ? `<span class="${diffClass}">(${diff}%)</span>` : ''}</td>
                    <td class="sum-cell" data-isin="${order.isin}">${order.sum > 0 ? fmt(order.sum) : '-'}</td>
                    <td class="actions-cell">
                        <button class="btn-icon btn-toggle ${order.enabled ? 'btn-enabled' : 'btn-disabled'}" data-isin="${order.isin}" title="${order.enabled ? 'Отключить' : 'Включить'}">${order.enabled ? '&#x2716;' : '&#x2714;'}</button>
                        <button class="btn-icon btn-save" data-isin="${order.isin}" disabled title="Сохранить">&#x1F4BE;</button>
                        <button class="btn-icon btn-cancel" data-isin="${order.isin}" disabled title="Отмена">&#x21BA;</button>
                        <button class="btn-icon btn-delete" data-isin="${order.isin}" title="Удалить">&#x1F5D1;</button>
                    </td>
                </tr>`;
            }).join('');

            initNumInputs();

            // Store original values for cancel
            document.querySelectorAll('#orders-table tr').forEach(row => {
                const qtyInput = row.querySelector('[data-field="qty"]');
                const priceInput = row.querySelector('[data-field="price"]');
                if (qtyInput) row.dataset.origQty = qtyInput.value;
                if (priceInput) row.dataset.origPrice = priceInput.value;
            });
            
            // Add event listeners
            document.querySelectorAll('.btn-toggle').forEach(btn => {
                btn.addEventListener('click', () => toggleOrder(btn.dataset.isin));
            });
            
            document.querySelectorAll('.btn-save').forEach(btn => {
                btn.addEventListener('click', () => saveOrder(btn.dataset.isin));
            });
            
            document.querySelectorAll('.btn-cancel').forEach(btn => {
                btn.addEventListener('click', () => cancelEdit(btn.dataset.isin));
            });
            
            document.querySelectorAll('.btn-delete').forEach(btn => {
                btn.addEventListener('click', () => deleteOrder(btn.dataset.isin));
            });
            
            // Dynamic recalculation on input change
            document.querySelectorAll('#orders-table .edit-input').forEach(input => {
                input.addEventListener('input', (e) => {
                    const isin = e.target.dataset.isin;
                    const row = e.target.closest('tr');
                    const qtyInput = row.querySelector('[data-field="qty"]');
                    const priceInput = row.querySelector('[data-field="price"]');
                    const sumCell = row.querySelector('.sum-cell');
                    const saveBtn = row.querySelector('.btn-save');
                    const cancelBtn = row.querySelector('.btn-cancel');
                    
                    const qty = parseInt(qtyInput.value.replace(/\s/g, '')) || 0;
                    const price = parseFloat(priceInput.value.replace(/\s/g, '')) || 0;
                    
                    const inst = instrumentsCache[isin] || {};
                    const lot = inst.lot || 1;
                    const facevalue = inst.facevalue || 0;
                    const isBond = isin.startsWith('SU') || isin.startsWith('RU000A');
                    const actualPrice = isBond && facevalue ? facevalue * (price / 100) : price;
                    const sum = actualPrice * qty * lot;
                    
                    sumCell.textContent = sum > 0 ? fmt(sum) : '-';
                    
                    // Mark as edited
                    row.classList.add('edited');
                    saveBtn.classList.add('btn-edited');
                    saveBtn.disabled = false;
                    cancelBtn.disabled = false;
                });
            });
        } catch (error) {
            console.error('Error loading orders:', error);
        }
    }
    
    // Web log
    const webLogEntries = document.getElementById('web-log-entries');
    const clearLogBtn = document.getElementById('clear-log');
    const exportLogBtn = document.getElementById('export-log');
    let logEntries = [];
    
    function webLog(msg, level = 'info', undo = null) {
        const time = new Date().toLocaleTimeString('ru-RU');
        const date = new Date().toLocaleDateString('ru-RU');
        const entry = { time, date, msg, level, undo };
        logEntries.push(entry);

        const el = document.createElement('div');
        el.className = `log-entry log-${level}`;
        el.innerHTML = `<span class="log-time">${date} ${time}</span><span class="log-msg">${msg}</span>${undo ? '<button class="btn-undo" onclick="undoAction(this)" data-index="' + (logEntries.length - 1) + '" title="Отменить">&#x21A9;</button>' : ''}`;
        webLogEntries.appendChild(el);
        webLogEntries.scrollTop = webLogEntries.scrollHeight;

        // Save to server
        fetch('/api/actionlog', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(entry)
        }).catch(() => {});
    }
    
    async function loadActionLog() {
        try {
            const response = await fetch('/api/actionlog');
            const entries = await response.json();
            logEntries = entries;
            webLogEntries.innerHTML = entries.map((e, i) => `
                <div class="log-entry log-${e.level}">
                    <span class="log-time">${e.date} ${e.time}</span>
                    <span class="log-msg">${e.msg}</span>
                    ${e.undo ? `<button class="btn-undo" onclick="undoAction(this)" data-index="${i}" title="Отменить">&#x21A9;</button>` : ''}
                </div>
            `).join('');
            webLogEntries.scrollTop = webLogEntries.scrollHeight;
        } catch (e) {
            console.error('Error loading log:', e);
        }
    }
    
    clearLogBtn.addEventListener('click', async () => {
        await fetch('/api/actionlog', { method: 'DELETE' });
        logEntries = [];
        webLogEntries.innerHTML = '';
    });
    
    exportLogBtn.addEventListener('click', () => {
        const text = logEntries.map(e => `${e.date} ${e.time} [${e.level}] ${e.msg}`).join('\n');
        const blob = new Blob([text], { type: 'text/plain' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = `action_log_${new Date().toISOString().slice(0,10)}.txt`;
        a.click();
    });
    
    document.querySelector('[data-tab="actionlog"]').addEventListener('click', loadActionLog);
    
    async function toggleOrder(isin) {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        const row = document.querySelector(`[data-isin="${isin}"]`)?.closest('tr');
        const wasEnabled = row ? row.classList.contains('disabled') === false : true;

        await fetch(`/api/orders/${broker}/${isin}/toggle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type })
        });

        webLog(`Переключено: ${isin}`, 'info', { action: 'toggle', broker, file_type: type, isin, old_enabled: wasEnabled });
        loadOrders();
    }

    async function saveOrder(isin) {
        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        const row = document.querySelector(`[data-isin="${isin}"]`).closest('tr');
        const qty = row.querySelector('[data-field="qty"]').value.replace(/\s/g, '');
        const price = row.querySelector('[data-field="price"]').value.replace(/\s/g, '');
        const oldQty = row.dataset.origQty;
        const oldPrice = row.dataset.origPrice;

        await fetch(`/api/orders/${broker}/${isin}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, qty, price })
        });

        webLog(`Сохранено: ${isin} — qty=${qty}, price=${price}`, 'success', { action: 'save', broker, file_type: type, isin, old_qty: oldQty, old_price: oldPrice });
        loadOrders();
    }
    
    function cancelEdit(isin) {
        const row = document.querySelector(`[data-isin="${isin}"]`).closest('tr');
        const qtyInput = row.querySelector('[data-field="qty"]');
        const priceInput = row.querySelector('[data-field="price"]');
        const sumCell = row.querySelector('.sum-cell');
        const saveBtn = row.querySelector('.btn-save');
        const cancelBtn = row.querySelector('.btn-cancel');

        qtyInput.value = fmtNum(row.dataset.origQty);
        priceInput.value = fmtNum(row.dataset.origPrice);
        row.classList.remove('edited');
        saveBtn.disabled = true;
        saveBtn.classList.remove('btn-edited');
        cancelBtn.disabled = true;

        const inst = instrumentsCache[isin] || {};
        const lot = inst.lot || 1;
        const facevalue = inst.facevalue || 0;
        const isBond = isin.startsWith('SU') || isin.startsWith('RU000A');
        const price = parseNum(priceInput.value);
        const qty = parseInt(qtyInput.value.replace(/\s/g, '')) || 0;
        const actualPrice = isBond && facevalue ? facevalue * (price / 100) : price;
        const sum = actualPrice * qty * lot;
        sumCell.textContent = sum > 0 ? fmt(sum) : '-';

        webLog(`Отменено: ${isin}`, 'info');
    }
    
    async function deleteOrder(isin) {
        if (!confirm(`Удалить заявку ${isin}?`)) return;

        const broker = brokerSelect.value;
        const type = fileTypeSelect.value;
        const row = document.querySelector(`[data-isin="${isin}"]`)?.closest('tr');
        const oldLine = row ? row.dataset.rawLine : '';

        await fetch(`/api/orders/${broker}/${isin}?type=${type}`, {
            method: 'DELETE'
        });

        webLog(`Удалено: ${isin}`, 'warn', { action: 'delete', broker, file_type: type, isin, old_line: oldLine });
        loadOrders();
    }
    
    refreshBtn.addEventListener('click', loadOrders);
    brokerSelect.addEventListener('change', loadOrders);
    fileTypeSelect.addEventListener('change', loadOrders);

    // Orders table sorting
    document.querySelectorAll('#orders-table .sortable').forEach(th => {
        th.addEventListener('click', () => {
            const sort = th.dataset.sort;
            if (ordersSortBy === sort) {
                ordersSortDir = ordersSortDir === 'asc' ? 'desc' : 'asc';
            } else {
                ordersSortBy = sort;
                ordersSortDir = 'asc';
            }
            document.querySelectorAll('#orders-table .sortable').forEach(h => h.textContent = h.textContent.replace(/[▲▼]/g, ''));
            th.textContent += ordersSortDir === 'asc' ? ' ▲' : ' ▼';
            loadOrders();
        });
    });

    loadInstruments().then(loadOrders);

    // Dashboard
    const brokerStatsDiv = document.getElementById('broker-stats');
    
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
    
    document.querySelector('[data-tab="dashboard"]').addEventListener('click', loadDashboard);

    // Trades tab
    const tradeStatsDiv = document.getElementById('trade-stats');
    const tradeCountDiv = document.getElementById('trade-count');
    const tradeGroupedDiv = document.getElementById('trade-grouped');
    const tradesTable = document.querySelector('#trades-table');
    const tradesTbody = document.querySelector('#trades-table tbody');
    const tradeSource = document.getElementById('trade-source');
    const tradeDateFrom = document.getElementById('trade-date-from');
    const tradeDateTo = document.getElementById('trade-date-to');
    const tradeTicker = document.getElementById('trade-ticker');
    const tradeSide = document.getElementById('trade-side');
    const tradeGroup = document.getElementById('trade-group');
    const refreshTrades = document.getElementById('refresh-trades');
    let currentSort = 'datetime';
    let currentDir = 'desc';

    // Default date range: last 2 months
    const today = new Date();
    const twoMonthsAgo = new Date(today);
    twoMonthsAgo.setMonth(today.getMonth() - 2);
    tradeDateTo.value = today.toISOString().slice(0, 10);
    tradeDateFrom.value = twoMonthsAgo.toISOString().slice(0, 10);

    async function loadTrades() {
        const params = new URLSearchParams({
            source: tradeSource.value,
            sort: currentSort,
            dir: currentDir
        });
        if (tradeDateFrom.value) params.set('date_from', tradeDateFrom.value);
        if (tradeDateTo.value) params.set('date_to', tradeDateTo.value);
        if (tradeTicker.value) params.set('ticker', tradeTicker.value);
        if (tradeSide.value) params.set('side', tradeSide.value);
        if (tradeGroup.value) params.set('group', tradeGroup.value);
        
        try {
            const response = await fetch(`/api/trades?${params}`);
            const data = await response.json();
            
            tradeStatsDiv.innerHTML = `
                <div class="trade-summary">
                    <div class="trade-card"><div class="label">Найдено сделок</div><div class="value">${data.total_trades}</div></div>
                    <div class="trade-card"><div class="label">Оборот</div><div class="value money">${fmt(data.total_value)}</div></div>
                    <div class="trade-card"><div class="label">Покупки</div><div class="value positive">${data.buys_count}</div></div>
                    <div class="trade-card"><div class="label">Продажи</div><div class="value negative">${data.sells_count}</div></div>
                    <div class="trade-card"><div class="label">Тикеров</div><div class="value">${data.unique_tickers}</div></div>
                    <div class="trade-card"><div class="label">Период</div><div class="value" style="font-size:0.85rem">${data.date_range.first} — ${data.date_range.last}</div></div>
                </div>
            `;
            
            tradeCountDiv.textContent = `Показано: ${data.trades.length} из ${data.total_trades}`;
            
            if (data.group_by && Object.keys(data.grouped).length > 0) {
                tradesTable.style.display = 'none';
                tradeGroupedDiv.style.display = 'block';
                
                const renderDetailTrades = (trades) => `
                    <table class="detail-table">
                        <thead><tr><th>Дата</th><th>Тикер</th><th>Операция</th><th>Лот</th><th>Кол-во</th><th>Цена</th><th>Сумма</th><th>Брокер</th></tr></thead>
                        <tbody>${trades.map(t => `
                            <tr>
                                <td>${t.datetime}</td>
                                <td>${t.ticker}</td>
                                <td><span class="level-badge ${t.side === 'buy' ? 'level-INFO' : 'level-ERROR'}">${t.side === 'buy' ? 'Покупка' : 'Продажа'}</span></td>
                                <td class="num-cell">${t.lot || 1}</td>
                                <td class="num-cell">${fmtNum(Math.abs(t.qty))}</td>
                                <td class="num-cell">${fmtNum(t.price)}</td>
                                <td class="money num-cell">${fmt(t.value)}</td>
                                <td>${t.broker}</td>
                            </tr>
                        `).join('')}</tbody>
                    </table>`;
                
                if (data.group_by === 'date') {
                    tradeGroupedDiv.innerHTML = `<table class="grouped-table">
                        <thead><tr><th></th><th>Дата</th><th>Сделок</th><th>Покупки</th><th>Продажи</th><th>Тикеров</th><th>Сумма</th></tr></thead>
                        <tbody>${Object.entries(data.grouped).map(([date, g]) => `
                            <tr class="group-row" data-key="${date}">
                                <td class="expand-icon">▸</td>
                                <td><strong>${date}</strong></td>
                                <td>${g.count}</td>
                                <td class="positive">${g.buys}</td>
                                <td class="negative">${g.sells}</td>
                                <td>${g.tickers}</td>
                                <td class="money">${fmt(g.value)}</td>
                            </tr>
                            <tr class="detail-row" style="display:none" data-for="${date}">
                                <td colspan="7">${renderDetailTrades(data.trades.filter(t => t.datetime.startsWith(date)))}</td>
                            </tr>
                        `).join('')}</tbody></table>`;
                } else if (data.group_by === 'ticker') {
                    tradeGroupedDiv.innerHTML = `<table class="grouped-table">
                        <thead><tr><th></th><th>Тикер</th><th>Сделок</th><th>Покупки</th><th>Продажи</th><th>Кол-во (нетто)</th><th>Сумма</th><th>Перв. дата</th><th>Посл. дата</th></tr></thead>
                        <tbody>${Object.entries(data.grouped).map(([ticker, g]) => `
                            <tr class="group-row" data-key="${ticker}">
                                <td class="expand-icon">▸</td>
                                <td><strong>${ticker}</strong></td>
                                <td>${g.count}</td>
                                <td class="positive">${g.buys}</td>
                                <td class="negative">${g.sells}</td>
                                <td class="${g.qty >= 0 ? 'positive' : 'negative'}">${g.qty > 0 ? '+' : ''}${g.qty}</td>
                                <td class="money">${fmt(g.value)}</td>
                                <td>${g.first_date}</td>
                                <td>${g.last_date}</td>
                            </tr>
                            <tr class="detail-row" style="display:none" data-for="${ticker}">
                                <td colspan="8">${renderDetailTrades(data.trades.filter(t => t.ticker === ticker))}</td>
                            </tr>
                        `).join('')}</tbody></table>`;
                }
                
                document.querySelectorAll('.group-row').forEach(row => {
                    row.addEventListener('click', () => {
                        const key = row.dataset.key;
                        const detail = document.querySelector(`.detail-row[data-for="${key}"]`);
                        const icon = row.querySelector('.expand-icon');
                        if (detail.style.display === 'none') {
                            detail.style.display = 'table-row';
                            icon.textContent = '▾';
                        } else {
                            detail.style.display = 'none';
                            icon.textContent = '▸';
                        }
                    });
                });
            } else {
                tradeGroupedDiv.style.display = 'none';
                tradesTable.style.display = 'table';
                
                tradesTbody.innerHTML = data.trades.map(t => `
                    <tr>
                        <td>${t.datetime}</td>
                        <td>${t.ticker}</td>
                        <td><span class="level-badge ${t.side === 'buy' ? 'level-INFO' : 'level-ERROR'}">${t.side === 'buy' ? 'Покупка' : 'Продажа'}</span></td>
                        <td class="num-cell">${t.lot || 1}</td>
                        <td class="num-cell">${fmtNum(Math.abs(t.qty))}</td>
                        <td class="num-cell">${fmtNum(t.price)}</td>
                        <td class="num-cell sum-cell">${fmt(t.value)}</td>
                        <td>${t.broker}</td>
                    </tr>
                `).join('');
            }
        } catch (error) {
            console.error('Error loading trades:', error);
        }
    }
    
    // Sort by column
    document.querySelectorAll('#trades-table .sortable').forEach(th => {
        th.addEventListener('click', () => {
            const sort = th.dataset.sort;
            if (currentSort === sort) {
                currentDir = currentDir === 'asc' ? 'desc' : 'asc';
            } else {
                currentSort = sort;
                currentDir = 'desc';
            }
            document.querySelectorAll('#trades-table .sortable').forEach(h => h.textContent = h.textContent.replace(/[▲▾]/g, '▾'));
            th.textContent = th.textContent.replace(/[▲▾]/g, currentDir === 'asc' ? '▲' : '▾');
            loadTrades();
        });
    });
    
    tradeSource.addEventListener('change', loadTrades);
    tradeDateFrom.addEventListener('change', loadTrades);
    tradeDateTo.addEventListener('change', loadTrades);
    tradeTicker.addEventListener('input', loadTrades);
    tradeSide.addEventListener('change', loadTrades);
    tradeGroup.addEventListener('change', loadTrades);
    refreshTrades.addEventListener('click', loadTrades);
    
    document.querySelector('[data-tab="trades"]').addEventListener('click', loadTrades);

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

    // Control tab - Settings
    const settingsForm = document.getElementById('settings-form');
    const brokerTabs = document.getElementById('broker-tabs');
    const saveSettingsBtn = document.getElementById('save-settings-btn');
    const addBrokerBtn = document.getElementById('add-broker-btn');
    const deleteBrokerBtn = document.getElementById('delete-broker-btn');
    const settingsStatus = document.getElementById('settings-status');

    let allSettings = {};
    let activeBroker = '';
    const brokerOrder = ['FINAM', 'VTB', 'PSB', 'RSHB'];

    const settingsFields = [
        { group: 'Брокер', fields: [
            { key: 'clientCode', label: 'Код клиента', type: 'text' },
            { key: 'accountCode', label: 'Код счета', type: 'text' },
            { key: 'firmId', label: 'FirmId', type: 'text' },
            { key: 'brokerEnabled', label: 'Брокер включен', type: 'checkbox' },
        ]},
        { group: 'Лимиты', fields: [
            { key: 'volumeOrderMax', label: 'Макс. объем акций', type: 'number' },
            { key: 'bondVolumeOrderMax', label: 'Макс. объем облигаций', type: 'number' },
            { key: 'volumeOrderLimit', label: 'Лимит объема', type: 'number' },
            { key: 'limitActuationOrderEdge', label: 'Лимит edge акций %', type: 'number' },
            { key: 'limitActuationOrderBondEdge', label: 'Лимит edge облигаций %', type: 'number' },
        ]},
        { group: 'Сессии', fields: [
            { key: 'sessionMorningEnabled', label: 'Утренняя сессия', type: 'checkbox' },
            { key: 'sessionMainEnabled', label: 'Основная сессия', type: 'checkbox' },
            { key: 'sessionEveningEnabled', label: 'Вечерняя сессия', type: 'checkbox' },
        ]},
        { group: 'Время сессий (UTC)', fields: [
            { key: 'sessionMorning', label: 'Утренняя', type: 'time' },
            { key: 'sessionMain', label: 'Основная', type: 'time' },
            { key: 'sessionEvening', label: 'Вечерняя', type: 'time' },
        ]},
    ];

    const brokerDefaults = {
        clientCode: '', accountCode: '', firmId: '',
        volumeOrderMax: 0, bondVolumeOrderMax: 0,
        volumeOrderLimit: 200000,
        limitActuationOrderEdge: 5, limitActuationOrderBondEdge: 60,
        sessionMorningEnabled: false, sessionMainEnabled: false, sessionEveningEnabled: false,
        brokerEnabled: false,
        sessionMorningHour: 7, sessionMorningMin: 0, sessionMorningSec: 30,
        sessionMainHour: 10, sessionMainMin: 0, sessionMainSec: 30,
        sessionEveningHour: 19, sessionEveningMin: 2, sessionEveningSec: 10,
    };

    function renderBrokerTabs() {
        const brokers = Object.keys(allSettings).sort((a, b) => {
            const ia = brokerOrder.indexOf(a);
            const ib = brokerOrder.indexOf(b);
            return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib);
        });
        brokerTabs.innerHTML = brokers.map(b =>
            `<button class="broker-tab ${b === activeBroker ? 'active' : ''}" data-broker="${b}">${b}</button>`
        ).join('');
        brokerTabs.querySelectorAll('.broker-tab').forEach(btn => {
            btn.addEventListener('click', () => {
                activeBroker = btn.dataset.broker;
                renderBrokerTabs();
                renderSettingsForm();
            });
        });
    }

    function timeToHMS(h, m, s) {
        const pad = n => String(n || 0).padStart(2, '0');
        return `${pad(h)}:${pad(m)}:${pad(s)}`;
    }

    function hmsToParts(val) {
        const parts = (val || '10:00:30').split(':');
        return {
            hour: parseInt(parts[0]) || 10,
            min: parseInt(parts[1]) || 0,
            sec: parseInt(parts[2]) || 30,
        };
    }

    function renderSettingsForm() {
        const data = allSettings[activeBroker] || {};
        settingsForm.innerHTML = settingsFields.map(group => `
            <div class="settings-group">
                <h4>${group.group}</h4>
                ${group.fields.map(f => {
                    const val = data[f.key] !== undefined ? data[f.key] : (brokerDefaults[f.key] ?? '');
                    if (f.type === 'checkbox') {
                        return `<div class="settings-row">
                            <label>${f.label}</label>
                            <input type="checkbox" data-key="${f.key}" ${val ? 'checked' : ''}>
                        </div>`;
                    }
                    if (f.type === 'time') {
                        const h = data[f.key + 'Hour'] ?? brokerDefaults[f.key + 'Hour'] ?? 10;
                        const m = data[f.key + 'Min'] ?? brokerDefaults[f.key + 'Min'] ?? 0;
                        const s = data[f.key + 'Sec'] ?? brokerDefaults[f.key + 'Sec'] ?? 30;
                        return `<div class="settings-row">
                            <label>${f.label}</label>
                            <input type="time" step="1" data-key="${f.key}" value="${timeToHMS(h, m, s)}">
                        </div>`;
                    }
                    if (f.type === 'number') {
                        return `<div class="settings-row">
                            <label>${f.label}</label>
                            <input type="text" inputmode="numeric" data-key="${f.key}" value="${val}">
                        </div>`;
                    }
                    return `<div class="settings-row">
                        <label>${f.label}</label>
                        <input type="text" data-key="${f.key}" value="${val}">
                    </div>`;
                }).join('')}
            </div>
        `).join('');

        settingsForm.querySelectorAll('input[inputmode="numeric"]').forEach(input => {
            const rawVal = input.value;
            if (rawVal) {
                input.value = rawVal.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
            }
            input.addEventListener('focus', () => {
                input.value = input.value.replace(/\s/g, '');
            });
            input.addEventListener('blur', () => {
                const raw = input.value.replace(/\s/g, '');
                const num = parseFloat(raw);
                if (!isNaN(num)) {
                    input.value = raw.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
                }
            });
        });
    }

    async function loadSettings() {
        try {
            const res = await fetch('/api/settings');
            allSettings = await res.json();
            const brokers = Object.keys(allSettings);
            if (brokers.length > 0 && !activeBroker) {
                activeBroker = brokers[0];
            }
            renderBrokerTabs();
            renderSettingsForm();
        } catch (e) {
            console.error('Error loading settings:', e);
        }
    }

    async function saveSettings() {
        if (!activeBroker) return;
        const data = {};
        settingsForm.querySelectorAll('input').forEach(input => {
            const key = input.dataset.key;
            if (input.type === 'checkbox') {
                data[key] = input.checked;
            } else if (input.type === 'time') {
                const parts = hmsToParts(input.value);
                data[key + 'Hour'] = parts.hour;
                data[key + 'Min'] = parts.min;
                data[key + 'Sec'] = parts.sec;
            } else if (input.type === 'number' || input.inputMode === 'numeric') {
                data[key] = parseFloat(input.value.replace(/\s/g, '')) || 0;
            } else {
                data[key] = input.value;
            }
        });
        allSettings[activeBroker] = data;
        try {
            settingsStatus.textContent = 'Сохранение...';
            settingsStatus.style.color = '#ff9800';
            await fetch('/api/settings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(allSettings)
            });
            settingsStatus.textContent = 'Настройки сохранены';
            settingsStatus.style.color = '#4caf50';
        } catch (e) {
            settingsStatus.textContent = 'Ошибка сохранения';
            settingsStatus.style.color = '#e94560';
        }
    }

    addBrokerBtn.addEventListener('click', async () => {
        const name = prompt('Имя нового брокера (латиница, например VTB):');
        if (!name || name.trim() === '') return;
        const broker = name.trim().toUpperCase();
        if (allSettings[broker]) {
            settingsStatus.textContent = 'Брокер уже существует';
            settingsStatus.style.color = '#e94560';
            return;
        }
        allSettings[broker] = { ...brokerDefaults };
        activeBroker = broker;
        await saveSettings();
        renderBrokerTabs();
        renderSettingsForm();
    });

    deleteBrokerBtn.addEventListener('click', async () => {
        if (!activeBroker) return;
        if (!confirm(`Удалить брокера ${activeBroker}?`)) return;
        delete allSettings[activeBroker];
        const brokers = Object.keys(allSettings);
        activeBroker = brokers[0] || '';
        await fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(allSettings)
        });
        renderBrokerTabs();
        renderSettingsForm();
        settingsStatus.textContent = 'Брокер удален';
        settingsStatus.style.color = '#4caf50';
    });

    saveSettingsBtn.addEventListener('click', saveSettings);
    document.querySelector('[data-tab="control"]').addEventListener('click', loadSettings);

    // Control tab - Price refresh
    const refreshPricesBtn = document.getElementById('refresh-prices-btn');
    const refreshPricesStatus = document.getElementById('refresh-prices-status');
    const refreshAllBtn = document.getElementById('refresh-all-btn');
    const refreshAllStatus = document.getElementById('refresh-all-status');

    refreshPricesBtn.addEventListener('click', async () => {
        refreshPricesBtn.disabled = true;
        refreshPricesStatus.textContent = 'Обновление...';
        refreshPricesStatus.style.color = '#ff9800';
        try {
            const res = await fetch('/api/instruments/refresh-prices', { method: 'POST' });
            const data = await res.json();
            refreshPricesStatus.textContent = `Готово: обновлено ${data.updated} из ${data.total} инструментов`;
            refreshPricesStatus.style.color = '#4caf50';
            loadInstruments();
        } catch (e) {
            refreshPricesStatus.textContent = 'Ошибка обновления';
            refreshPricesStatus.style.color = '#e94560';
        }
        refreshPricesBtn.disabled = false;
    });

    refreshAllBtn.addEventListener('click', async () => {
        refreshAllBtn.disabled = true;
        refreshAllStatus.textContent = 'Полное обновление (~1-2 мин)...';
        refreshAllStatus.style.color = '#ff9800';
        try {
            const res = await fetch('/api/instruments/refresh', { method: 'POST' });
            const data = await res.json();
            refreshAllStatus.textContent = `Готово: ${data.count} инструментов`;
            refreshAllStatus.style.color = '#4caf50';
            loadInstruments();
        } catch (e) {
            refreshAllStatus.textContent = 'Ошибка обновления';
            refreshAllStatus.style.color = '#e94560';
        }
        refreshAllBtn.disabled = false;
    });

    window.undoAction = async function(btn) {
        const index = parseInt(btn.dataset.index);
        const response = await fetch('/api/actionlog');
        const entries = await response.json();
        const entry = entries[index];
        if (!entry || !entry.undo) return;

        if (!confirm('Отменить это действие?')) return;

        const res = await fetch('/api/actionlog/undo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ undo: entry.undo })
        });

        if (res.ok) {
            const u = entry.undo;
            const desc = u.action === 'save' ? `Сохранение ${u.isin} (qty=${u.old_qty}, price=${u.old_price})`
                : u.action === 'toggle' ? `Переключение ${u.isin}`
                : `Удаление ${u.isin}`;
            webLog(`Откат: ${desc}`, 'info');
        } else {
            btn.textContent = 'Ошибка';
        }
    };
});
