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
    
    document.querySelector('[data-tab="dashboard"]').addEventListener('click', loadStats);

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
});
