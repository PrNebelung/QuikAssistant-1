"""
StyLua wrapper for cp1251 encoded Lua files.

Converts cp1251 -> UTF-8, runs StyLua, converts back -> cp1251.

Usage:
    python stylua_cp1251.py check           # Check formatting
    python stylua_cp1251.py format          # Format all files
    python stylua_cp1251.py format file.lua # Format specific file
"""

import sys
import os
import subprocess
import tempfile
import shutil

def convert_to_utf8(src, tmp_dir):
    """Convert cp1251 file to UTF-8 in temp directory."""
    with open(src, 'rb') as f:
        content = f.read()

    try:
        text = content.decode('cp1251')
    except UnicodeDecodeError:
        text = content.decode('cp1251', errors='replace')

    tmp_path = os.path.join(tmp_dir, os.path.basename(src))
    with open(tmp_path, 'w', encoding='utf-8') as f:
        f.write(text)

    return tmp_path

def convert_to_cp1251(utf8_path, dest):
    """Convert UTF-8 file back to cp1251."""
    with open(utf8_path, 'r', encoding='utf-8') as f:
        text = f.read()

    with open(dest, 'wb') as f:
        f.write(text.encode('cp1251', errors='replace'))

def find_lua_files(path):
    """Find all .lua files."""
    files = []
    if os.path.isfile(path):
        return [path]

    for root, dirs, filenames in os.walk(path):
        # Skip hidden dirs and venv
        dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'venv']
        for f in filenames:
            if f.endswith('.lua'):
                files.append(os.path.join(root, f))
    return files

def run_stylua(tmp_dir, check_only=False):
    """Run StyLua on temp directory."""
    cmd = ['stylua', '--config-path', 'stylua.toml']
    if check_only:
        cmd.append('--check')
    cmd.append('.')

    result = subprocess.run(
        cmd,
        cwd=tmp_dir,
        capture_output=True
    )
    return result

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    action = sys.argv[1]
    target = sys.argv[2] if len(sys.argv) > 2 else '.'

    check_only = (action == 'check')
    if action not in ('check', 'format'):
        print(f"Unknown action: {action}")
        print("Use 'check' or 'format'")
        sys.exit(1)

    # Create temp directory
    tmp_dir = tempfile.mkdtemp(prefix='stylua_')

    try:
        # Find all Lua files
        lua_files = find_lua_files(target)
        if not lua_files:
            print("No .lua files found")
            return

        print(f"Found {len(lua_files)} Lua files")

        # Convert all files to UTF-8 in temp
        file_map = {}  # tmp_path -> original_path
        for src in lua_files:
            rel_path = os.path.relpath(src, '.')
            tmp_path = os.path.join(tmp_dir, rel_path)
            os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
            convert_to_utf8(src, tmp_dir)
            file_map[tmp_path] = src

        # Copy stylua.toml to temp
        if os.path.exists('stylua.toml'):
            shutil.copy('stylua.toml', tmp_dir)

        # Run StyLua
        print(f"Running StyLua ({'check' if check_only else 'format'})...")
        result = run_stylua(tmp_dir, check_only)

        if result.stdout:
            print(result.stdout.decode('utf-8', errors='replace'))
        if result.stderr:
            print(result.stderr.decode('utf-8', errors='replace'))

        if result.returncode != 0:
            print(f"\nStyLua found issues (exit code: {result.returncode})")
            if not check_only:
                sys.exit(result.returncode)

        # If formatting, convert back to cp1251
        if not check_only and result.returncode == 0:
            converted = 0
            for tmp_path, orig_path in file_map.items():
                if os.path.exists(tmp_path):
                    convert_to_cp1251(tmp_path, orig_path)
                    converted += 1
            print(f"\nFormatted and converted {converted} files back to cp1251")

        if check_only and result.returncode == 0:
            print("\nAll files are properly formatted!")

    finally:
        # Cleanup
        shutil.rmtree(tmp_dir, ignore_errors=True)

if __name__ == '__main__':
    main()
