# AGENTS.md - QuikAssistant Project Rules

## CRITICAL: File Encoding

All `.lua` files in this project use **Windows-1251 (cp1251)** encoding.

### DO NOT use the Edit tool directly on `.lua` files with Russian text.

The Edit tool writes UTF-8, which breaks cp1251 files. Instead:

### Safe editing workflow:

```bash
# Check encoding of all files
python cp1251_wrapper.py check_all

# Replace text in a file (preserves cp1251)
python cp1251_wrapper.py replace "filename.lua" "old text" "new text"

# Insert after a specific line
python cp1251_wrapper.py insert_after "filename.lua" 10 "    new_line_here"

# Insert before a specific line
python cp1251_wrapper.py insert_before "filename.lua" 10 "    new_line_here"

# Delete a line
python cp1251_wrapper.py delete_line "filename.lua" 10
```

### Python helper scripts (existing):
- `cp1251_edit.py` - read/replace/check cp1251 files
- `cp1251_wrapper.py` - extended wrapper with insert/delete operations

### If you must use Edit tool:
Only use it for lines that contain NO Russian/Cyrillic characters.
For any text with Russian, use the Python scripts.

## Encoding Recovery Playbook

When Russian text in `.lua` files becomes garbled (shows as `nISnIS`, `пїЅпїЅпїЅ`, `??????`, or `\xef\xbf\xbd` bytes), follow this procedure:

### Step 1: Diagnose

```bash
# Quick check all files
python cp1251_wrapper.py check_all
```

Possible statuses:
- `OK` — file is correct cp1251
- `UTF-8 CYRILLIC DETECTED` — file has UTF-8 Cyrillic bytes (D0/D1 + 80-BF), needs re-encoding
- `pre-existing replacement chars` — file has `\xef\xbf\xbd` (U+FFFD) bytes, Russian text is **lost**

### Step 2: Understand the corruption

```python
import sys
sys.stdout.reconfigure(encoding='utf-8')
with open('file.lua', 'rb') as f:
    raw = f.read()
count = raw.count(b'\xef\xbf\xbd')
has_utf8 = any(raw[i] in (0xD0, 0xD1) and 0x80 <= raw[i+1] <= 0xBF for i in range(len(raw)-1))
print(f'U+FFFD: {count}, UTF-8 Cyrillic: {has_utf8}')
```

- **U+FFFD = 0**: File is clean. May need simple re-encoding from UTF-8 to cp1251.
- **U+FFFD > 0**: Original Russian text was destroyed by a lossy encoding conversion. Must be manually reconstructed.

### Step 3: Fix (two scenarios)

#### Scenario A: UTF-8 Cyrillic, no U+FFFD (simple re-encode)

```python
with open('file.lua', 'rb') as f:
    text = f.read().decode('utf-8')
with open('file.lua', 'wb') as f:
    f.write(text.encode('cp1251'))
```

#### Scenario B: U+FFFD replacement characters (manual reconstruction)

The `\xef\xbf\xbd` bytes are the UTF-8 encoding of U+FFFD (REPLACEMENT CHARACTER). The original Russian text is **irrecoverable** from the file. You must reconstruct it from code context.

**Reconstruction script template:**

```python
import sys
sys.stdout.reconfigure(encoding='utf-8')

REPL = '\ufffd'

def read_binary(path):
    with open(path, 'rb') as f:
        return f.read()

def write_cp1251(path, text):
    with open(path, 'wb') as f:
        f.write(text.encode('cp1251', errors='replace'))

def replace_lines(path, line_map):
    raw = read_binary(path)
    text = raw.decode('utf-8', errors='replace')
    lines = text.split('\n')
    count = 0
    for line_num, new_text in line_map.items():
        idx = line_num - 1
        if 0 <= idx < len(lines):
            if REPL in lines[idx]:
                lines[idx] = new_text
                count += 1
    write_cp1251(path, '\n'.join(lines))
    print(f'{path}: {count} lines replaced')

# Build line_map: { line_number: "correct cp1251-safe text" }
# Read file as UTF-8 to see garbled lines with context, then write correct text
line_map = {
    5: '      "Параметр не найден.",',
    14: '--- Получение последней цены',
    # ... more lines
}
replace_lines('QuikFunction.lua', line_map)
```

**How to build `line_map`:**
1. Read file as UTF-8 to see garbled lines: `raw.decode('utf-8', errors='replace')`
2. List all lines containing `\ufffd`
3. For each garbled line, use surrounding context (variable names, function names, code logic) to reconstruct the Russian text
4. Verify: run `python cp1251_wrapper.py check_all` after fixing

### Step 4: Verify

```bash
python cp1251_wrapper.py check_all
# All files should show: OK

# Spot-check Russian text readability:
python -c "
import sys; sys.stdout.reconfigure(encoding='utf-8')
with open('file.lua', 'rb') as f: raw = f.read()
text = raw.decode('cp1251')
for i, line in enumerate(text.split(chr(10))[:20], 1):
    print(f'{i}: {line.rstrip()}')
"
```

### Common corruption patterns

| Pattern | Cause | Fix |
|---------|-------|-----|
| `пїЅпїЅпїЅ` in cp1251 decode | U+FFFD bytes in file | Manual reconstruction |
| `nISnISnIS` in VS Code | U+FFFD displayed in wrong encoding | Same — manual reconstruction |
| Valid UTF-8 Cyrillic (Д0/Д1 bytes) | File saved as UTF-8 instead of cp1251 | Re-encode: `decode('utf-8').encode('cp1251')` |
| `??????` or `▯▯▯` | Replacement chars from terminal/editor | Check raw bytes, apply appropriate fix |

### Prevention

- **Never** open cp1251 `.lua` files in a UTF-8 editor and save them
- **Never** use the Edit tool on lines with Russian text
- Always use `cp1251_wrapper.py` for modifications
- Run `python cp1251_wrapper.py check_all` after any encoding-related changes
