from flask import Blueprint, jsonify, request
from csv_handler import get_csv_files, read_orders, write_orders, get_all_brokers
import os
import glob

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

def parse_trade(line):
    """Parse a trade line: DATETIME;TICKER;QTY;PRICE;BROKER"""
    parts = line.strip().split(';')
    if len(parts) >= 5:
        return {
            'datetime': parts[0],
            'ticker': parts[1],
            'qty': float(parts[2]),
            'price': float(parts[3]),
            'broker': parts[4],
            'value': abs(float(parts[2])) * float(parts[3])
        }
    return None

@api.route('/api/trades')
def trades():
    """Get trade statistics."""
    source = request.args.get('source', 'all')  # all, mytrades, or broker name
    
    trades_data = []
    
    if source == 'all' or source == 'mytrades':
        mytrades_file = os.path.join(DATA_DIR, 'MyTrades.csv')
        if os.path.exists(mytrades_file):
            with open(mytrades_file, 'r', encoding='utf-8') as f:
                for line in f:
                    trade = parse_trade(line)
                    if trade:
                        trades_data.append(trade)
    
    if source != 'all' and source != 'mytrades':
        trade_file = os.path.join(DATA_DIR, f'trades{source}.csv')
        if os.path.exists(trade_file):
            with open(trade_file, 'r', encoding='utf-8') as f:
                for line in f:
                    trade = parse_trade(line)
                    if trade:
                        trades_data.append(trade)
    
    if source == 'all':
        for broker in get_all_brokers():
            trade_file = os.path.join(DATA_DIR, f'trades{broker}.csv')
            if os.path.exists(trade_file):
                with open(trade_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        trade = parse_trade(line)
                        if trade:
                            trades_data.append(trade)
    
    # Calculate statistics
    total_trades = len(trades_data)
    total_value = sum(t['value'] for t in trades_data)
    buys = [t for t in trades_data if t['qty'] > 0]
    sells = [t for t in trades_data if t['qty'] < 0]
    
    # Unique tickers
    tickers = set(t['ticker'] for t in trades_data)
    
    # By broker
    by_broker = {}
    for t in trades_data:
        b = t['broker']
        if b not in by_broker:
            by_broker[b] = {'count': 0, 'value': 0, 'tickers': set()}
        by_broker[b]['count'] += 1
        by_broker[b]['value'] += t['value']
        by_broker[b]['tickers'].add(t['ticker'])
    
    for b in by_broker:
        by_broker[b]['tickers'] = len(by_broker[b]['tickers'])
    
    # Date range
    dates = [t['datetime'][:10] for t in trades_data if t['datetime']]
    
    return jsonify({
        'total_trades': total_trades,
        'total_value': round(total_value, 2),
        'buys_count': len(buys),
        'sells_count': len(sells),
        'unique_tickers': len(tickers),
        'date_range': {'first': min(dates) if dates else '', 'last': max(dates) if dates else ''},
        'by_broker': by_broker,
        'recent': trades_data[-20:]  # Last 20 trades
    })
