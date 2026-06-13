import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('QuikFunction.lua', 'rb') as f:
    raw = f.read()

# Find the pattern: after ")"" before \r\n and tostring
# The bytes are: 29 22 0d 0a ... 74 6f 73 74 72 69 6e 67
# We need to insert a comma (2c) after 22 (closing quote)

# Pattern 1: after the nominal format string
# Find: ..."100%% (цена: %s%%)"\r\n          tostring
idx1 = raw.find(b'%s%%)"\r\n          tostring(order.Price)')
if idx1 != -1:
    # Insert comma after the closing quote
    pos = raw.find(b'"', idx1 + len(b'%s%%)'))  # Find the closing quote
    raw = raw[:pos+1] + b',' + raw[pos+1:]
    print(f'Fixed pattern 1 at byte {pos}')
else:
    print('Pattern 1 not found')

# Pattern 2: after the average price format string
# Find: ..."Цена последней сделки выше средней цены %s"\r\n        string.format
idx2 = raw.find(b'%s"\r\n        string.format')
if idx2 != -1:
    pos = raw.find(b'"', idx2 + len(b'%s'))  # Find the closing quote
    raw = raw[:pos+1] + b',' + raw[pos+1:]
    print(f'Fixed pattern 2 at byte {pos}')
else:
    print('Pattern 2 not found')

with open('QuikFunction.lua', 'wb') as f:
    f.write(raw)
print('Done')
