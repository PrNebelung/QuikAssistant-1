import os, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8')

LUA_FILES = []
for root, dirs, files in os.walk('.'):
    if '.git' in root or '__pycache__' in root:
        continue
    for f in files:
        if f.endswith('.lua'):
            LUA_FILES.append(os.path.join(root, f))

print(f'Found {len(LUA_FILES)} Lua files')

# Step 1: Convert cp1251 -> UTF-8
for path in LUA_FILES:
    with open(path, 'rb') as f:
        raw = f.read()
    try:
        text = raw.decode('cp1251')
    except:
        print(f'  SKIP (not cp1251): {path}')
        continue
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)

print('Step 1: Converted to UTF-8')

# Step 2: Run stylua
result = subprocess.run(['stylua', '.'], capture_output=True, text=True)
if result.returncode != 0:
    print(f'stylua errors:\n{result.stderr}')
else:
    print('Step 2: stylua formatted')

# Step 3: Convert UTF-8 -> cp1251
for path in LUA_FILES:
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    with open(path, 'wb') as f:
        f.write(text.encode('cp1251'))

print('Step 3: Converted back to cp1251')
print('Done')
