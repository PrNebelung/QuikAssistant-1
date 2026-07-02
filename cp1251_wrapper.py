"""
cp1251_wrapper.py - Wrapper for safe editing of cp1251 Lua files.

Usage:
    python cp1251_wrapper.py replace <file> <old> <new>
    python cp1251_wrapper.py insert_after <file> <after_line> <text>
    python cp1251_wrapper.py insert_before <file> <before_line> <text>
    python cp1251_wrapper.py delete_line <file> <line_num>
    python cp1251_wrapper.py check_all
"""

import sys
import os
import glob


def read_cp1251(filepath):
    with open(filepath, "rb") as f:
        raw = f.read()
    return raw.decode("cp1251", errors="replace")


def write_cp1251(filepath, content):
    with open(filepath, "wb") as f:
        f.write(content.encode("cp1251", errors="replace"))


def replace_in_file(filepath, old_text, new_text):
    content = read_cp1251(filepath)
    if old_text not in content:
        print(f"ERROR: old_text not found in {filepath}")
        return False
    content = content.replace(old_text, new_text, 1)
    write_cp1251(filepath, content)
    print(f"OK: {filepath}")
    return True


def insert_after_line(filepath, line_num, text):
    content = read_cp1251(filepath)
    lines = content.split("\n")
    if line_num < 1 or line_num > len(lines):
        print(f"ERROR: line {line_num} out of range (1-{len(lines)})")
        return False
    lines.insert(line_num, text)
    write_cp1251(filepath, "\n".join(lines))
    print(f"OK: {filepath} (inserted after line {line_num})")
    return True


def insert_before_line(filepath, line_num, text):
    content = read_cp1251(filepath)
    lines = content.split("\n")
    if line_num < 1 or line_num > len(lines):
        print(f"ERROR: line {line_num} out of range (1-{len(lines)})")
        return False
    lines.insert(line_num - 1, text)
    write_cp1251(filepath, "\n".join(lines))
    print(f"OK: {filepath} (inserted before line {line_num})")
    return True


def delete_line(filepath, line_num):
    content = read_cp1251(filepath)
    lines = content.split("\n")
    if line_num < 1 or line_num > len(lines):
        print(f"ERROR: line {line_num} out of range (1-{len(lines)})")
        return False
    del lines[line_num - 1]
    write_cp1251(filepath, "\n".join(lines))
    print(f"OK: {filepath} (deleted line {line_num})")
    return True


def check_all():
    lua_files = sorted(
        glob.glob("*.lua")
        + glob.glob("Tests/*.lua")
        + glob.glob("Tests/*.lua")
    )
    for f in lua_files:
        with open(f, "rb") as fh:
            raw = fh.read()
        has_utf8_cyrillic = any(
            raw[i] in (0xD0, 0xD1) and 0x80 <= raw[i + 1] <= 0xBF
            for i in range(len(raw) - 1)
        )
        has_replacement = b"\xef\xbf\xbd" in raw
        if has_utf8_cyrillic:
            print(f"  {f}: UTF-8 CYRILLIC DETECTED")
        elif has_replacement:
            print(f"  {f}: pre-existing replacement chars")
        else:
            print(f"  {f}: OK")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "replace" and len(sys.argv) == 5:
        replace_in_file(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "insert_after" and len(sys.argv) == 5:
        insert_after_line(sys.argv[2], int(sys.argv[3]), sys.argv[4])
    elif cmd == "insert_before" and len(sys.argv) == 5:
        insert_before_line(sys.argv[2], int(sys.argv[3]), sys.argv[4])
    elif cmd == "delete_line" and len(sys.argv) == 4:
        delete_line(sys.argv[2], int(sys.argv[3]))
    elif cmd == "check_all":
        check_all()
    else:
        print(__doc__)
        sys.exit(1)
