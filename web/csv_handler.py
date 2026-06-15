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
