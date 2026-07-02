#!/usr/bin/env python3
import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('Constants.lua', 'rb') as f:
    text = f.read().decode('cp1251')

# Add new constants section before _initConstants
new_section = """
-- ==========================================
-- Пороги цвета для таблицы ордеров
-- ==========================================
Constants.ACTUATION_COLOR_RED = 2
Constants.ACTUATION_COLOR_YELLOW = 5

-- ==========================================
-- Лимит цены облигации (проценты)
-- ==========================================
Constants.BOND_MAX_PRICE_PERCENT = 100.0

-- ==========================================
-- Интервалы повторных попыток
-- ==========================================
Constants.RETRY_LOG_INTERVAL = 5
Constants.TRADE_CLOSE_SLEEP_MS = 500
"""

old_marker = 'function _initConstants()'
new_marker = new_section + 'function _initConstants()'

if old_marker in text and new_section.strip() not in text:
    text = text.replace(old_marker, new_marker, 1)
    print('Added new constants section')

# Add global promotions
old_promo = '\tMAX_RECURSION_DEPTH = Constants.MAX_RECURSION_DEPTH'
new_promo = '''\tMAX_RECURSION_DEPTH = Constants.MAX_RECURSION_DEPTH
\tACTUATION_COLOR_RED = Constants.ACTUATION_COLOR_RED
\tACTUATION_COLOR_YELLOW = Constants.ACTUATION_COLOR_YELLOW
\tBOND_MAX_PRICE_PERCENT = Constants.BOND_MAX_PRICE_PERCENT
\tRETRY_LOG_INTERVAL = Constants.RETRY_LOG_INTERVAL
\tTRADE_CLOSE_SLEEP_MS = Constants.TRADE_CLOSE_SLEEP_MS'''

if old_promo in text:
    text = text.replace(old_promo, new_promo, 1)
    print('Added global promotions')

# Remove SLEEP_SHORT_MS
text = text.replace('\tSLEEP_SHORT_MS = Constants.SLEEP_SHORT_MS\n', '')
text = text.replace('Constants.SLEEP_SHORT_MS = 1000\n', '')
print('Removed SLEEP_SHORT_MS')

with open('Constants.lua', 'wb') as f:
    f.write(text.encode('cp1251'))
print('Done')
