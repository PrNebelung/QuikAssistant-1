---
name: cp1251-guard
description: Use when editing .lua files in QuikAssistant project to prevent encoding corruption
---

# CP1251 Encoding Guard

## CRITICAL RULE

All `.lua` files in this project use **Windows-1251 (cp1251)** encoding for Russian text.

**NEVER** use the Edit tool directly on `.lua` files that contain Russian/Cyrillic text.

The Edit tool writes UTF-8 by default. When UTF-8 Cyrillic (2 bytes per char) is written to a cp1251 file (1 byte per char), the text becomes garbled.

## Safe Editing Workflow

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

## Creating New .lua Files

When creating new `.lua` files with Russian text:

1. Write the file in UTF-8 first
2. Convert to cp1251 using Python:

```python
with open('filename.lua', 'r', encoding='utf-8') as f:
    text = f.read()
with open('filename.lua', 'wb') as f:
    f.write(text.encode('cp1251'))
```

## If You Must Use Edit Tool

Only use it for lines that contain NO Russian/Cyrillic characters.

## Verification

After any modification to `.lua` files, run:

```bash
python cp1251_wrapper.py check_all
```

All files should show `OK`.

## Common Corruption Patterns

| Pattern | Cause | Fix |
|---------|-------|-----|
| `??????` in file | UTF-8 written to cp1251 file | Re-encode from UTF-8 to cp1251 |
| `пїЅпїЅпїЅ` | UTF-8 bytes interpreted as cp1251 | Restore from git, redo carefully |
| `nISnISnIS` | Same as above, different display | Same fix |

## Files to Always Check

After editing, verify these critical files:
- `StartEngine.lua` - entry point
- `Assistant.lua` - business logic
- `SubmittingOrders.lua` - order orchestration
- `BrokerAdapter.lua` - QUIK API wrapper
- `OrderValidator.lua` - validation logic

## Pre-commit Hook

Автоматическая проверка кодировки перед каждым коммитом.

Если .lua файл содержит UTF-8 кириллицу или U+FFFD — коммит блокируется.

```bash
# Хук уже установлен в .git/hooks/pre-commit
# Для ручной проверки:
bash .git/hooks/pre-commit
```
