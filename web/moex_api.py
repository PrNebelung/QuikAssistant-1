"""Клиент API MOEX ISS для данных инструментов - загружает только инструменты из CSV-файлов."""
import os
import json
import time
import requests
import sys

sys.path.insert(0, os.path.dirname(__file__))
from csv_handler import read_orders, get_csv_files, get_all_brokers

BASE_URL = "https://iss.moex.com/iss"
CACHE_DIR = os.path.dirname(__file__)
CACHE_FILE = os.path.join(CACHE_DIR, 'instruments_cache.json')
CACHE_TTL = 3600  # 1 hour

def _load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def _save_cache(cache):
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

def _parse_iss_response(data):
    """Разобрать ответ MOEX ISS в список словарей."""
    columns = data.get('columns', [])
    rows = data.get('data', [])
    result = []
    for row in rows:
        if len(row) == len(columns):
            result.append(dict(zip(columns, row)))
    return result

def get_all_isins_from_csv():
    """Собрать все ISIN/тикеры из CSV-файлов всех брокеров."""
    isins = set()
    for broker in get_all_brokers():
        files = get_csv_files(broker)
        for filepath in files.values():
            if os.path.exists(filepath):
                for order in read_orders(filepath):
                    isins.add(order['isin'])
    return isins

def fetch_instrument_data(secid):
    """Получить данные по одному инструменту из MOEX."""
    url = f"{BASE_URL}/securities/{secid}.json"
    try:
        resp = requests.get(url, params={'iss.meta': 'off'}, timeout=10)
        d = resp.json()
    except Exception as e:
        print(f"  Ошибка получения {secid}: {e}")
        return None
    
    # Get description data
    desc_raw = d.get('description', {})
    desc_rows = _parse_iss_response(desc_raw)
    
    info = {}
    for row in desc_rows:
        key = row.get('name', '')
        val = row.get('value', '')
        if key == 'SHORTNAME':
            info['name'] = val
        elif key == 'ISIN':
            info['isin'] = val
        elif key == 'FACEVALUE':
            info['facevalue'] = float(val) if val else 0
        elif key == 'MATDATE':
            info['maturity'] = val
        elif key == 'COUPONVALUE':
            info['coupon'] = float(val) if val else 0
    
    # Get board data to find where it trades
    boards_raw = d.get('boards', {})
    boards_rows = _parse_iss_response(boards_raw)
    
    board_ids = []
    for row in boards_rows:
        if row.get('is_traded') == 1:
            board_ids.append(row.get('boardid', ''))
    
    # Try to get price from boards
    price = 0
    lot = 1
    for board in board_ids[:3]:  # Try first 3 boards
        try:
            if board.startswith('TQ') or board.startswith('EQ') or board.startswith('FQ'):
                # Stock or bond board
                is_bond_board = any(x in board for x in ['OB', 'CB', 'RD', 'IB', 'IEB'])
                market = 'bonds' if is_bond_board else 'shares'
                url2 = f"{BASE_URL}/engines/stock/markets/{market}/boards/{board}/securities.json"
                resp2 = requests.get(url2, params={'iss.meta': 'off', 'limit': 5000}, timeout=10)
                d2 = resp2.json()
                
                md_rows = _parse_iss_response(d2.get('marketdata', {}))
                sec_rows = _parse_iss_response(d2.get('securities', {}))
                
                for sec in sec_rows:
                    if sec.get('SECID') == secid:
                        lot = sec.get('LOTSIZE', 1) or 1
                        break
                
                for md in md_rows:
                    if md.get('SECID') == secid:
                        price = md.get('LAST') or md.get('PREVPRICE') or md.get('LCURRENTPRICE') or 0
                        if price:
                            break

                if price:
                    break
        except:
            continue
    
    if not price and info.get('maturity'):
        # Try to get price from marketdata boards
        for board in ['TQCB', 'TQOB', 'TQRD', 'TQIB', 'TQIEB']:
            try:
                market = 'bonds'
                url2 = f"{BASE_URL}/engines/stock/markets/{market}/boards/{board}/securities.json"
                resp2 = requests.get(url2, params={'iss.meta': 'off', 'limit': 5000}, timeout=10)
                d2 = resp2.json()
                
                md_rows = _parse_iss_response(d2.get('marketdata', {}))
                for md in md_rows:
                    if md.get('SECID') == secid:
                        price = md.get('LAST') or md.get('PREVPRICE') or md.get('LCURRENTPRICE') or 0
                        if price:
                            break
                
                if price:
                    break
            except:
                continue
    
    info['price'] = float(price) if price else 0
    info['lot'] = int(lot) if lot else 1
    
    return info if info.get('name') else None

def _batch_fetch_prices():
    """Получить текущие цены для всех инструментов пакетно с бирж MOEX."""
    prices = {}

    # Shares from TQBR
    try:
        url = f"{BASE_URL}/engines/stock/markets/shares/boards/TQBR/securities.json"
        resp = requests.get(url, params={'iss.meta': 'off', 'limit': 10000}, timeout=30)
        resp.raise_for_status()
        d = resp.json()
        md = _parse_iss_response(d.get('marketdata', {}))
        for row in md:
            secid = row.get('SECID')
            price = row.get('LAST') or row.get('PREVPRICE') or row.get('LCURRENTPRICE') or 0
            if secid and price:
                prices[secid] = float(price)
        print(f"  Получено {len(prices)} цен акций с TQBR")
    except Exception as e:
        print(f"  Ошибка получения TQBR: {e}")

    # Bonds from TQCB, TQOB, TQRD, TQIB, TQIEB
    bond_boards = ['TQCB', 'TQOB', 'TQRD', 'TQIB', 'TQIEB']
    for board in bond_boards:
        try:
            url = f"{BASE_URL}/engines/stock/markets/bonds/boards/{board}/securities.json"
            resp = requests.get(url, params={'iss.meta': 'off', 'limit': 10000}, timeout=30)
            resp.raise_for_status()
            d = resp.json()
            md = _parse_iss_response(d.get('marketdata', {}))
            for row in md:
                secid = row.get('SECID')
                price = row.get('LAST') or row.get('PREVPRICE') or row.get('LCURRENTPRICE') or 0
                if secid and price and secid not in prices:
                    prices[secid] = float(price)
        except Exception:
            continue

    print(f"  Всего пакетных цен: {len(prices)}")
    return prices


def refresh_instruments():
    """Обновить кэш инструментов - пакетная загрузка цен, индивидуальная загрузка метаданных."""
    cache = _load_cache()
    cache['updated'] = time.time()

    isins = get_all_isins_from_csv()
    print(f"Найдено {len(isins)} инструментов в CSV-файлах")

    # Bulk fetch all current prices
    bulk_prices = _batch_fetch_prices()

    for i, isin in enumerate(isins):
        # Get price from bulk data
        bulk_price = bulk_prices.get(isin, 0)

        # Check if we already have metadata (name, maturity, etc.)
        existing = cache.get(isin, {})
        has_metadata = existing.get('name') and existing.get('isin')

        if has_metadata and bulk_price:
            # Just update price from bulk data
            cache[isin]['price'] = bulk_price
            continue

        # Need to fetch full instrument data (first time or missing metadata)
        print(f"  [{i+1}/{len(isins)}] Получение {isin}...", end=' ')
        data = fetch_instrument_data(isin)
        if data:
            if bulk_price:
                data['price'] = bulk_price
            cache[isin] = data
            print(f"OK - {data.get('name', '')} цена={data.get('price', 0)}")
        else:
            # Even if metadata fails, save the bulk price
            if bulk_price:
                cache[isin] = {'name': isin, 'isin': isin, 'price': bulk_price, 'lot': 1}
                print(f"только цена: {bulk_price}")
            else:
                print("не найден")

        time.sleep(0.1)  # Rate limit

    _save_cache(cache)
    return cache

def get_instrument(isin_or_ticker):
    """Получить данные инструмента из кэша. Автообновление при устаревании."""
    cache = _load_cache()

    if time.time() - cache.get('updated', 0) > CACHE_TTL:
        cache = refresh_instruments()

    return cache.get(isin_or_ticker)

def get_all_instruments():
    """Получить все кэшированные инструменты. Автообновление при устаревании кэша."""
    cache = _load_cache()
    if time.time() - cache.get('updated', 0) > CACHE_TTL:
        print("Кэш устарел, обновление инструментов...")
        cache = refresh_instruments()
    return {k: v for k, v in cache.items() if k != 'updated'}
