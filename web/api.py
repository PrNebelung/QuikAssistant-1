from flask import Blueprint, jsonify, request
from csv_handler import get_csv_files, read_orders, write_orders, delete_order, get_all_brokers
import os
import glob
import json

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

@api.route('/api/orders/<broker>/<isin>', methods=['DELETE'])
def delete_order_endpoint(broker, isin):
    """Delete an order by ISIN."""
    file_type = request.args.get('type', 'buy')
    files = get_csv_files(broker)
    
    filepath = files.get(file_type)
    if not filepath:
        return jsonify({'error': 'Unknown file type'}), 400
    
    if delete_order(filepath, isin):
        return jsonify({'success': True})
    return jsonify({'error': 'Delete failed'}), 500

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
        stripped = line.strip()
        if isin in stripped:
            # Remove existing -- prefix first
            clean = stripped.lstrip('-').lstrip()
            if stripped.startswith('--'):
                # Was disabled, enable it
                line = clean + '\n'
            else:
                # Was enabled, disable it
                line = '--' + clean + '\n'
        new_lines.append(line)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    return jsonify({'success': True})

ACTION_LOG_FILE = os.path.join(os.path.dirname(__file__), 'action_log.json')

@api.route('/api/actionlog', methods=['GET'])
def get_action_log():
    """Get action log entries."""
    if os.path.exists(ACTION_LOG_FILE):
        with open(ACTION_LOG_FILE, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))
    return jsonify([])

@api.route('/api/actionlog', methods=['POST'])
def add_action_log():
    """Add entry to action log."""
    entry = request.json
    entries = []
    if os.path.exists(ACTION_LOG_FILE):
        with open(ACTION_LOG_FILE, 'r', encoding='utf-8') as f:
            entries = json.load(f)
    
    entries.append(entry)
    
    # Keep last 500 entries
    if len(entries) > 500:
        entries = entries[-500:]
    
    with open(ACTION_LOG_FILE, 'w', encoding='utf-8') as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
    
    return jsonify({'success': True})

@api.route('/api/actionlog', methods=['DELETE'])
def clear_action_log():
    """Clear action log."""
    with open(ACTION_LOG_FILE, 'w', encoding='utf-8') as f:
        json.dump([], f)
    return jsonify({'success': True})

@api.route('/api/actionlog/undo', methods=['POST'])
def undo_action():
    """Undo the last action by restoring previous state."""
    data = request.json
    undo = data.get('undo')
    if not undo:
        return jsonify({'error': 'No undo data'}), 400

    action = undo.get('action')
    broker = undo.get('broker')
    file_type = undo.get('file_type')
    isin = undo.get('isin')

    files = get_csv_files(broker)
    filepath = files.get(file_type)
    if not filepath or not os.path.exists(filepath):
        return jsonify({'error': 'File not found'}), 404

    if action == 'save':
        orders = read_orders(filepath)
        for order in orders:
            if order['isin'] == isin:
                order['qty'] = undo['old_qty']
                order['price'] = undo['old_price']
                break
        if write_orders(filepath, orders):
            return jsonify({'success': True})
        return jsonify({'error': 'Write failed'}), 500

    elif action == 'toggle':
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        new_lines = []
        for line in lines:
            stripped = line.strip()
            if isin in stripped:
                clean = stripped.lstrip('-').lstrip()
                if undo['old_enabled']:
                    line = clean + '\n'
                else:
                    line = '--' + clean + '\n'
            new_lines.append(line)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return jsonify({'success': True})

    elif action == 'delete':
        old_line = undo.get('old_line', '')
        if old_line:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            if not content.endswith('\n'):
                content += '\n'
            content += old_line + '\n'
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return jsonify({'success': True})
        return jsonify({'error': 'No old line data'}), 400

    return jsonify({'error': 'Unknown action'}), 400

LOG_DIR = os.path.join(os.path.dirname(__file__), '..', 'Log')

import re
from datetime import datetime

LOG_PATTERN = re.compile(r'^(INFO|WARN|ERROR|DEBUG|TRACE)\s+(\d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+(\S+):(\d+):\s*(.*)$')

def parse_log_entry(line):
    """Parse a log line into structured data."""
    m = LOG_PATTERN.match(line)
    if m:
        return {
            'level': m.group(1),
            'time': m.group(2),
            'broker': m.group(3),
            'file': m.group(4),
            'line': int(m.group(5)),
            'message': m.group(6).strip(),
            'raw': line
        }
    return {'level': 'INFO', 'time': '', 'broker': '', 'file': '', 'line': 0, 'message': line, 'raw': line}

@api.route('/api/logs/dates')
def log_dates():
    """Get available log dates for a broker."""
    broker = request.args.get('broker', 'VTB')
    log_dir = os.path.join(LOG_DIR, broker)
    
    if not os.path.exists(log_dir):
        return jsonify([])
    
    dates = []
    for f in glob.glob(os.path.join(log_dir, '*.log')):
        basename = os.path.basename(f).replace('.log', '')
        dates.append(basename)
    
    return jsonify(sorted(dates, reverse=True))

@api.route('/api/logs')
def logs():
    """Get parsed log entries with filters."""
    broker = request.args.get('broker', 'VTB')
    date = request.args.get('date', '')
    level = request.args.get('level', '')
    search = request.args.get('search', '').lower()
    
    log_dir = os.path.join(LOG_DIR, broker)
    
    if not os.path.exists(log_dir):
        return jsonify([])
    
    if date:
        log_file = os.path.join(log_dir, f'{date}.log')
    else:
        log_files = sorted(glob.glob(os.path.join(log_dir, '*.log')), reverse=True)
        if not log_files:
            return jsonify([])
        log_file = log_files[0]
    
    entries = []
    with open(log_file, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = parse_log_entry(line)
            
            if level and entry['level'] != level:
                continue
            if search and search not in entry['message'].lower() and search not in entry['raw'].lower():
                continue
            
            entries.append(entry)
    
    return jsonify(entries)

@api.route('/api/logs/list')
def log_list():
    brokers = []
    if os.path.exists(LOG_DIR):
        for broker_dir in os.listdir(LOG_DIR):
            if os.path.isdir(os.path.join(LOG_DIR, broker_dir)):
                brokers.append(broker_dir)
    return jsonify(sorted(brokers))

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'Data')

from moex_api import get_instrument, get_all_instruments, refresh_instruments

@api.route('/api/instruments')
def instruments_list():
    """Get all cached instruments."""
    instruments = get_all_instruments()
    return jsonify(instruments)

@api.route('/api/instruments/<code>')
def instrument_detail(code):
    """Get instrument data by ticker or ISIN."""
    data = get_instrument(code)
    if data:
        return jsonify(data)
    return jsonify({'error': 'Not found'}), 404

@api.route('/api/instruments/refresh', methods=['POST'])
def instruments_refresh():
    """Refresh instrument data from MOEX."""
    data = refresh_instruments()
    return jsonify({'success': True, 'count': len(data) - 1})

@api.route('/api/instruments/refresh-prices', methods=['POST'])
def instruments_refresh_prices():
    """Fast refresh: update only prices from MOEX boards (no metadata fetch)."""
    from moex_api import _batch_fetch_prices, _load_cache, _save_cache
    import time
    cache = _load_cache()
    prices = _batch_fetch_prices()
    updated = 0
    for isin, price in prices.items():
        if isin in cache:
            cache[isin]['price'] = price
            updated += 1
    cache['updated'] = time.time()
    _save_cache(cache)
    return jsonify({'success': True, 'updated': updated, 'total': len(prices)})

SETTINGS_FILE = os.path.join(os.path.dirname(__file__), '..', 'settings.json')

@api.route('/api/settings', methods=['GET'])
def get_settings():
    """Get all broker settings from settings.json."""
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))
    return jsonify({})

@api.route('/api/settings/<broker>', methods=['GET'])
def get_broker_settings(broker):
    """Get settings for a specific broker."""
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, 'r', encoding='utf-8') as f:
            all_settings = json.load(f)
        return jsonify(all_settings.get(broker, {}))
    return jsonify({})

@api.route('/api/settings/<broker>', methods=['POST'])
def save_broker_settings(broker):
    """Save settings for a specific broker."""
    data = request.json
    all_settings = {}
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, 'r', encoding='utf-8') as f:
            all_settings = json.load(f)
    all_settings[broker] = data
    with open(SETTINGS_FILE, 'w', encoding='utf-8') as f:
        json.dump(all_settings, f, ensure_ascii=False, indent=2)
    return jsonify({'success': True})

@api.route('/api/settings', methods=['POST'])
def save_all_settings():
    """Save all settings (full replace)."""
    data = request.json
    with open(SETTINGS_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return jsonify({'success': True})

def is_bond(isin):
    """Check if ISIN is a bond (starts with RU000A or SU)."""
    return isin.startswith('RU000A') or isin.startswith('SU')

@api.route('/api/stats')
def stats():
    """Get detailed order statistics per broker."""
    broker = request.args.get('broker', 'VTB')
    files = get_csv_files(broker)
    
    result = {
        'total': 0, 'active': 0, 'disabled': 0,
        'stocks': 0, 'bonds': 0,
        'stocks_value': 0, 'bonds_value': 0
    }
    
    for filepath in files.values():
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('----'):
                        result['total'] += 1
                        if line.startswith('--'):
                            result['disabled'] += 1
                        else:
                            result['active'] += 1
                        
                        parts = line.split(';')
                        if len(parts) >= 5:
                            isin = parts[2]
                            try:
                                qty = float(parts[3])
                                price = float(parts[4])
                                value = qty * price
                            except:
                                value = 0
                            
                            if is_bond(isin):
                                result['bonds'] += 1
                                result['bonds_value'] += value
                            else:
                                result['stocks'] += 1
                                result['stocks_value'] += value
    
    return jsonify(result)

@api.route('/api/stats/all')
def stats_all():
    """Get statistics for all brokers combined."""
    brokers = get_all_brokers()
    all_stats = {}
    totals = {'total': 0, 'active': 0, 'disabled': 0, 'stocks': 0, 'bonds': 0, 'stocks_value': 0, 'bonds_value': 0}
    
    for broker in brokers:
        files = get_csv_files(broker)
        broker_stats = {'total': 0, 'active': 0, 'disabled': 0, 'stocks': 0, 'bonds': 0, 'stocks_value': 0, 'bonds_value': 0}
        
        for filepath in files.values():
            if os.path.exists(filepath):
                with open(filepath, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('----'):
                            broker_stats['total'] += 1
                            if line.startswith('--'):
                                broker_stats['disabled'] += 1
                            else:
                                broker_stats['active'] += 1
                            
                            parts = line.split(';')
                            if len(parts) >= 5:
                                isin = parts[2]
                                try:
                                    qty = float(parts[3])
                                    price = float(parts[4])
                                    value = qty * price
                                except:
                                    value = 0
                                
                                if is_bond(isin):
                                    broker_stats['bonds'] += 1
                                    broker_stats['bonds_value'] += value
                                else:
                                    broker_stats['stocks'] += 1
                                    broker_stats['stocks_value'] += value
        
        all_stats[broker] = broker_stats
        for key in totals:
            totals[key] += broker_stats[key]
    
    return jsonify({'brokers': all_stats, 'totals': totals})

def parse_trade(line, instruments=None):
    """Parse a trade line: DATETIME;TICKER;QTY;PRICE;BROKER"""
    parts = line.strip().split(';')
    if len(parts) >= 5:
        ticker = parts[1]
        lot = 1
        if instruments and ticker in instruments:
            lot = instruments[ticker].get('lot', 1) or 1
        qty = abs(float(parts[2]))
        price = float(parts[3])
        return {
            'datetime': parts[0],
            'ticker': ticker,
            'qty': float(parts[2]),
            'price': price,
            'lot': int(lot),
            'broker': parts[4],
            'value': qty * price * int(lot)
        }
    return None

@api.route('/api/trades')
def trades():
    """Get trades with filters and sorting."""
    source = request.args.get('source', 'all')
    date_from = request.args.get('date_from', '')
    date_to = request.args.get('date_to', '')
    ticker_filter = request.args.get('ticker', '').upper()
    side_filter = request.args.get('side', '')
    sort_by = request.args.get('sort', 'datetime')
    sort_dir = request.args.get('dir', 'desc')
    
    trades_data = []
    seen = set()  # Deduplicate
    
    files_to_read = []
    if source == 'all' or source == 'mytrades':
        mytrades_file = os.path.join(DATA_DIR, 'MyTrades.csv')
        if os.path.exists(mytrades_file):
            files_to_read.append(mytrades_file)
    
    if source != 'all' and source != 'mytrades':
        trade_file = os.path.join(DATA_DIR, f'trades{source}.csv')
        if os.path.exists(trade_file):
            files_to_read.append(trade_file)
    
    if source == 'all':
        for broker in get_all_brokers():
            trade_file = os.path.join(DATA_DIR, f'trades{broker}.csv')
            if os.path.exists(trade_file):
                files_to_read.append(trade_file)
    
    instruments = get_all_instruments()
    
    for filepath in files_to_read:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                trade = parse_trade(line, instruments)
                if trade:
                    key = (trade['datetime'], trade['ticker'], trade['qty'], trade['price'])
                    if key not in seen:
                        seen.add(key)
                        trade['side'] = 'buy' if trade['qty'] > 0 else 'sell'
                        trades_data.append(trade)
    
    # Apply filters
    if date_from:
        trades_data = [t for t in trades_data if t['datetime'][:10] >= date_from]
    if date_to:
        trades_data = [t for t in trades_data if t['datetime'][:10] <= date_to]
    if ticker_filter:
        trades_data = [t for t in trades_data if ticker_filter in t['ticker'].upper()]
    if side_filter:
        trades_data = [t for t in trades_data if t['side'] == side_filter]
    
    # Sort
    reverse = sort_dir == 'desc'
    if sort_by == 'value':
        trades_data.sort(key=lambda t: t['value'], reverse=reverse)
    elif sort_by == 'qty':
        trades_data.sort(key=lambda t: abs(t['qty']), reverse=reverse)
    elif sort_by == 'price':
        trades_data.sort(key=lambda t: t['price'], reverse=reverse)
    elif sort_by in ('datetime', 'ticker', 'side', 'broker'):
        trades_data.sort(key=lambda t: t.get(sort_by, ''), reverse=reverse)
    
    # Stats
    total_trades = len(trades_data)
    total_value = sum(t['value'] for t in trades_data)
    buys = [t for t in trades_data if t['side'] == 'buy']
    sells = [t for t in trades_data if t['side'] == 'sell']
    tickers = set(t['ticker'] for t in trades_data)
    dates = [t['datetime'][:10] for t in trades_data if t['datetime']]
    
    # Grouping
    group_by = request.args.get('group', '')
    grouped = {}
    
    if group_by == 'date':
        for t in trades_data:
            key = t['datetime'][:10]
            if key not in grouped:
                grouped[key] = {'count': 0, 'value': 0, 'buys': 0, 'sells': 0, 'tickers': set()}
            grouped[key]['count'] += 1
            grouped[key]['value'] += t['value']
            if t['side'] == 'buy':
                grouped[key]['buys'] += 1
            else:
                grouped[key]['sells'] += 1
            grouped[key]['tickers'].add(t['ticker'])
        
        for k in grouped:
            grouped[k]['tickers'] = len(grouped[k]['tickers'])
            grouped[k]['value'] = round(grouped[k]['value'], 2)
        grouped = dict(sorted(grouped.items(), reverse=True))
    
    elif group_by == 'ticker':
        for t in trades_data:
            key = t['ticker']
            if key not in grouped:
                grouped[key] = {'count': 0, 'value': 0, 'buys': 0, 'sells': 0, 'qty': 0, 'dates': set()}
            grouped[key]['count'] += 1
            grouped[key]['value'] += t['value']
            grouped[key]['qty'] += t['qty']
            if t['side'] == 'buy':
                grouped[key]['buys'] += 1
            else:
                grouped[key]['sells'] += 1
            grouped[key]['dates'].add(t['datetime'][:10])
        
        for k in grouped:
            grouped[k]['value'] = round(grouped[k]['value'], 2)
            grouped[k]['first_date'] = min(grouped[k]['dates'])
            grouped[k]['last_date'] = max(grouped[k]['dates'])
            del grouped[k]['dates']
        grouped = dict(sorted(grouped.items(), key=lambda x: x[1]['value'], reverse=True))
    
    return jsonify({
        'total_trades': total_trades,
        'total_value': round(total_value, 2),
        'buys_count': len(buys),
        'sells_count': len(sells),
        'unique_tickers': len(tickers),
        'date_range': {'first': min(dates) if dates else '', 'last': max(dates) if dates else ''},
        'trades': trades_data,
        'grouped': grouped,
        'group_by': group_by
    })
