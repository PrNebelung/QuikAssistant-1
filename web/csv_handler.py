import os
from typing import List, Dict

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'Data')

def get_csv_files(broker: str) -> Dict[str, str]:
    """Вернуть доступные CSV-файлы для брокера."""
    return {
        'buy': os.path.join(DATA_DIR, f'{broker}_BuyOrders.csv'),
        'buy_edge': os.path.join(DATA_DIR, f'{broker}_BuyOrders_Edge.csv'),
        'buy_bonds': os.path.join(DATA_DIR, f'{broker}_BuyOrdersBonds_Edge.csv'),
        'sell': os.path.join(DATA_DIR, f'{broker}_SellOrders.csv'),
        'sell_edge': os.path.join(DATA_DIR, f'{broker}_SellOrders_Edge.csv'),
    }

def read_orders(filepath: str) -> List[Dict]:
    """Прочитать заявки из CSV-файла, включая закомментированные строки."""
    orders = []
    if not os.path.exists(filepath):
        return orders

    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.rstrip('\n\r')
            stripped = line.strip()
            if not stripped:
                continue

            # Check if line is a separator
            if stripped.startswith('----'):
                continue

            # Check if order is disabled (commented)
            enabled = True
            if stripped.startswith('--'):
                enabled = False
                stripped = stripped[2:].strip()

            parts = stripped.split(';')
            if len(parts) >= 5:
                orders.append({
                    'line': line_num,
                    'name': parts[0],
                    'side': parts[1],
                    'isin': parts[2],
                    'qty': parts[3],
                    'price': parts[4],
                    'enabled': enabled,
                    'raw': stripped
                })
    return orders

def write_orders(filepath: str, orders: List[Dict]) -> bool:
    """Записать заявки обратно в CSV-файл."""
    try:
        lines = []
        for order in orders:
            lines.append(f"{order['name']};{order['side']};{order['isin']};{order['qty']};{order['price']}")

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        return True
    except Exception as e:
        print(f"Ошибка записи CSV: {e}")
        return False

def delete_order(filepath: str, isin: str) -> bool:
    """Удалить заявку по ISIN из CSV-файла."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        new_lines = [line for line in lines if isin not in line]

        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    except Exception as e:
        print(f"Ошибка удаления заявки: {e}")
        return False

def get_all_brokers() -> List[str]:
    """Получить список доступных брокеров."""
    brokers = set()
    for filename in os.listdir(DATA_DIR):
        if filename.endswith('_BuyOrders.csv'):
            broker = filename.replace('_BuyOrders.csv', '')
            if not broker.startswith('_'):
                brokers.add(broker)
    return sorted(brokers)
