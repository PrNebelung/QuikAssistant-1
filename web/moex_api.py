"""MOEX ISS API client for instrument data."""
import os
import json
import time
import requests

BASE_URL = "https://iss.moex.com/iss"
CACHE_DIR = os.path.join(os.path.dirname(__file__), '..', 'Data')
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
    """Parse MOEX ISS response into list of dicts."""
    columns = data.get('columns', [])
    rows = data.get('data', [])
    result = []
    for row in rows:
        if len(row) == len(columns):
            result.append(dict(zip(columns, row)))
    return result

def fetch_stock_data(board='TQBR'):
    """Fetch lot size and last price for all stocks on a board."""
    url = f"{BASE_URL}/engines/stock/markets/shares/boards/{board}/securities.json"
    params = {'iss.meta': 'off', 'limit': 100}
    
    result = {}
    start = 0
    
    while True:
        try:
            resp = requests.get(url, params={**params, 'start': start}, timeout=10)
            data = resp.json()
        except Exception as e:
            print(f"MOEX API error: {e}")
            break
        
        md_raw = data.get('marketdata', {})
        sec_raw = data.get('securities', {})
        
        marketdata = _parse_iss_response(md_raw)
        securities = _parse_iss_response(sec_raw)
        
        if not marketdata:
            break
        
        for sec in securities:
            ticker = sec.get('SECID', '')
            if not ticker:
                continue
            
            md = next((m for m in marketdata if m.get('SECID') == ticker), {})
            
            lot_size = sec.get('LOTSIZE') or md.get('LOTSIZE') or 1
            last_price = md.get('LAST') or md.get('LASTPRICE') or sec.get('PREVPRICE') or 0
            
            result[ticker] = {
                'lot': int(lot_size) if lot_size else 1,
                'price': float(last_price) if last_price else 0,
                'board': board,
                'name': sec.get('SHORTNAME', ''),
                'isin': sec.get('ISIN', ''),
                'facevalue': sec.get('FACEVALUE', 0),
            }
        
        if len(marketdata) < params['limit']:
            break
        start += params['limit']
        time.sleep(0.1)
    
    return result

def fetch_bond_data(board='TQOB'):
    """Fetch bond data including maturity and coupon info."""
    url = f"{BASE_URL}/engines/stock/markets/bonds/boards/{board}/securities.json"
    params = {'iss.meta': 'off', 'limit': 100}
    
    result = {}
    start = 0
    
    while True:
        try:
            resp = requests.get(url, params={**params, 'start': start}, timeout=10)
            data = resp.json()
        except Exception as e:
            print(f"MOEX API error: {e}")
            break
        
        md_raw = data.get('marketdata', {})
        sec_raw = data.get('securities', {})
        
        marketdata = _parse_iss_response(md_raw)
        securities = _parse_iss_response(sec_raw)
        
        if not marketdata:
            break
        
        for sec in securities:
            ticker = sec.get('SECID', '')
            if not ticker:
                continue
            
            md = next((m for m in marketdata if m.get('SECID') == ticker), {})
            
            last_price = md.get('LAST') or md.get('LASTPRICE') or sec.get('PREVPRICE') or 0
            coupon = sec.get('COUPONVALUE') or md.get('COUPONVALUE') or 0
            maturity = sec.get('MATDATE') or ''
            yield_pct = sec.get('YIELDCLOSE') or md.get('YIELDCLOSE') or 0
            
            result[ticker] = {
                'lot': int(sec.get('LOTSIZE', 1) or 1),
                'price': float(last_price) if last_price else 0,
                'board': board,
                'name': sec.get('SHORTNAME', ''),
                'isin': sec.get('ISIN', ''),
                'facevalue': sec.get('FACEVALUE', 0),
                'coupon': float(coupon) if coupon else 0,
                'maturity': maturity,
                'yield': float(yield_pct) if yield_pct else 0,
                'accrued': md.get('ACCRUEDINT', 0),
            }
        
        if len(marketdata) < params['limit']:
            break
        start += params['limit']
        time.sleep(0.1)
    
    return result

def refresh_instruments(boards=None):
    """Refresh instrument cache from MOEX."""
    if boards is None:
        boards = ['TQBR', 'TQOB']
    
    cache = _load_cache()
    cache['updated'] = time.time()
    
    for board in boards:
        if board in ('TQBR', 'TQNE', 'TQPI'):
            data = fetch_stock_data(board)
        else:
            data = fetch_bond_data(board)
        cache.update(data)
    
    _save_cache(cache)
    return cache

def get_instrument(isin_or_ticker):
    """Get instrument data from cache."""
    cache = _load_cache()
    
    # Check if cache is expired
    if time.time() - cache.get('updated', 0) > CACHE_TTL:
        return None
    
    return cache.get(isin_or_ticker)

def get_all_instruments():
    """Get all cached instruments."""
    cache = _load_cache()
    return {k: v for k, v in cache.items() if k != 'updated'}
