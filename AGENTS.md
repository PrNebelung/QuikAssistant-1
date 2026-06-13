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
