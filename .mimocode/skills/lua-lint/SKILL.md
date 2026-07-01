---
name: lua-lint
description: Use when checking Lua code quality, running linters, or fixing code issues
---

# Lua Code Quality Check

## Available Tools

### luacheck (Lua linter)

```bash
# Run on all files (requires local path, not UNC)
luacheck . --no-color --quiet

# Run on specific file
luacheck filename.lua --no-color

# Run with custom config
luacheck . --config .luacheckrc
```

**Note:** luacheck doesn't work with UNC paths. If running from network drive:
1. Copy files to temp: `Copy-Item *.lua $env:TEMP\lint_check`
2. Run luacheck there
3. Copy results back

### stylua (Lua formatter) with cp1251 support

Use `stylua_cp1251.py` wrapper that handles encoding conversion automatically:

```bash
# Check formatting (shows diffs, doesn't change files)
python stylua_cp1251.py check

# Format all files
python stylua_cp1251.py format

# Format specific file
python stylua_cp1251.py format path/to/file.lua
```

The wrapper:
1. Converts cp1251 files to UTF-8 in temp directory
2. Runs StyLua
3. Converts formatted files back to cp1251

Config: `stylua.toml` in project root (2-space indent, Windows line endings).

### Tests

```bash
# Unit tests (170 tests)
lua Tests/run_tests.lua

# Integration tests (uses mock QUIK API)
lua IntegrationTests/run_tests.lua
```

**Note:** Tests don't work with UNC paths. Copy to temp directory first if needed.

## Common Issues and Fixes

### "accessing undefined variable"

This usually means a global is used but not in `.luacheckrc`. Add it to `read_globals` section.

### "setting non-standard global variable"

This is intentional for QUIK callback compatibility. Add to `globals` section.

### "line is too long"

Style preference. Ignore with `--ignore 512` or add to config.

### "shadowing definition"

Common in loops. Ignore with `--ignore 431` or add to config.

## Config Location

`.luacheckrc` in project root contains all global definitions for QUIK API and project architecture.
