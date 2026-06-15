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
