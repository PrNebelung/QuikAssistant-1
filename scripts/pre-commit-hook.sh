#!/bin/bash
# Pre-commit hook: проверка кодировки cp1251 для .lua файлов
# Если найдены .lua файлы с UTF-8 кириллицей или U+FFFD — коммит блокируется.

echo "=== cp1251-guard: проверка кодировки .lua файлов ==="

# Получаем список staged .lua файлов
STAGED_LUA=$(git diff --cached --name-only --diff-filter=ACM | grep '\.lua$')

if [ -z "$STAGED_LUA" ]; then
  echo "Нет .lua файлов для проверки."
  exit 0
fi

ERRORS=0

for FILE in $STAGED_LUA; do
  if [ ! -f "$FILE" ]; then
    continue
  fi

  # Проверяем наличие UTF-8 кириллицы (байты D0/D1 + 80-BF)
  HAS_UTF8=$(python -c "
import sys
with open('$FILE', 'rb') as f:
    raw = f.read()
for i in range(len(raw)-1):
    if raw[i] in (0xD0, 0xD1) and 0x80 <= raw[i+1] <= 0xBF:
        print('YES')
        sys.exit(0)
print('NO')
" 2>/dev/null)

  # Проверяем наличие U+FFFD (replacement characters)
  HAS_FFFD=$(python -c "
import sys
with open('$FILE', 'rb') as f:
    raw = f.read()
count = raw.count(b'\xef\xbf\xbd')
print('YES' if count > 0 else 'NO')
" 2>/dev/null)

  if [ "$HAS_UTF8" = "YES" ]; then
    echo "ОШИБКА: $FILE содержит UTF-8 кириллицу вместо cp1251!"
    echo "  Исправьте: cp1251_wrapper.py check_all"
    ERRORS=$((ERRORS + 1))
  fi

  if [ "$HAS_FFFD" = "YES" ]; then
    echo "ОШИБКА: $FILE содержит U+FFFD replacement characters!"
    echo "  Русский текст повреждён. Восстановите из git."
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "=== ОБНАРУЖЕНЫ ПРОБЛЕМЫ С КОДИРОВКОЙ ==="
  echo "Коммит заблокирован. Исправьте ошибки выше."
  echo ""
  echo "Помощь:"
  echo "  python cp1251_wrapper.py check_all    # проверить все файлы"
  echo "  python cp1251_wrapper.py replace ...  # заменить текст"
  exit 1
fi

echo "cp1251-guard: все .lua файлы в порядке."
exit 0
