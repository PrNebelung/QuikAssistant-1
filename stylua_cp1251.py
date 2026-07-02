#!/usr/bin/env python3
"""Обёртка для stylua: форматирует Lua-файлы в cp1251 через UTF-8."""
import sys
import os
import subprocess
import tempfile
import shutil

sys.stdout.reconfigure(encoding='utf-8')

def format_cp1251_file(filepath):
    """Форматирует один cp1251 Lua-файл через stylua."""
    with open(filepath, 'rb') as f:
        cp1251_bytes = f.read()

    # Декодируем cp1251
    try:
        text = cp1251_bytes.decode('cp1251')
    except UnicodeDecodeError as e:
        print(f'  Ошибка декодирования {filepath}: {e}')
        return False

    # Записываем во временный UTF-8 файл
    with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as tmp:
        tmp.write(text)
        tmp_path = tmp.name

    try:
        # Запускаем stylua
        result = subprocess.run(
            ['stylua', tmp_path],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            print(f'  stylua ошибка для {filepath}: {result.stderr.strip()}')
            return False

        # Читаем отформатированный UTF-8
        with open(tmp_path, 'r', encoding='utf-8') as f:
            formatted = f.read()

        # Конвертируем обратно в cp1251
        cp1251_out = formatted.encode('cp1251', errors='replace')

        # Проверяем, что не потеряли русский текст
        original_russian = sum(1 for b in cp1251_bytes if 0xC0 <= b <= 0xFF)
        formatted_russian = sum(1 for b in cp1251_out if 0xC0 <= b <= 0xFF)

        if original_russian > 0 and formatted_russian < original_russian * 0.9:
            print(f'  Предупреждение: возможна потеря русского текста в {filepath}')
            print(f'    Оригинал: {original_russian} русских байт, результат: {formatted_russian}')
            return False

        # Записываем обратно
        with open(filepath, 'wb') as f:
            f.write(cp1251_out)

        print(f'  OK: {filepath}')
        return True

    finally:
        os.unlink(tmp_path)


def main():
    if len(sys.argv) < 2:
        # Форматируем все .lua файлы
        files = []
        for root, dirs, filenames in os.walk('.'):
            # Пропускаем служебные директории
            dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', '.mimocode', 'docs']]
            for f in filenames:
                if f.endswith('.lua'):
                    files.append(os.path.join(root, f))
    else:
        files = sys.argv[1:]

    success = 0
    failed = 0

    for filepath in files:
        if format_cp1251_file(filepath):
            success += 1
        else:
            failed += 1

    print(f'\nИтого: {success} успешно, {failed} ошибок')


if __name__ == '__main__':
    main()
