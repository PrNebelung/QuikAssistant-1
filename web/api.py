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
