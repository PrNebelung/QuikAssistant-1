#!/bin/bash
# Установка git hooks для QuikAssistant
# Запуск: bash scripts/install-hooks.sh

echo "Установка git hooks..."

# Копируем pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✅ pre-commit hook установлен"
echo ""
echo "Проверка кодировки перед коммитом:"
echo "  - Если .lua файл содержит UTF-8 кириллицу → коммит блокируется"
echo "  - Если .lua файл содержит U+FFFD → коммит блокируется"
echo ""
echo "Для ручной проверки:"
echo "  python cp1251_wrapper.py check_all"
