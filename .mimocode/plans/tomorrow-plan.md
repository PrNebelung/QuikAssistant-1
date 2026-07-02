# План на завтра — QuikAssistant

## Текущее состояние
- HEAD: `78c5205`
- Тесты: 170 unit + 66 integration OK

## Задачи

### 1. Удалить мёртвый `isSubmittingOrdersRun` (ПРИОРИТЕТ)
Проблема: переменная не определена (=nil=false), блокирует загрузку Buy ордеров.
Решение: удалить `if isSubmittingOrdersRun then ... end` блоки.
**ВАЖНО:** трогать только конкретный код, не русский текст!

### 2. Исправить `Config.Config.Config.Broker` → `Config.Broker`
Файл: `log.lua:136`

### 3. Исправить опечатку `securiyCode` → `securityCode`
Файл: `Assistant.lua`

### 4. Добавить параметр `resubmit` в `N_SetLimitOrder`
Файл: `Assistant.lua`
Убрать recursion guard (`limitOrderRecursionDepth`, `LIMIT_ORDER_MAX_RECURSION`)

### 5. Удалить мёртвый код
- `OrderLoader.lua:118` — self-assignment `OrderLoader = OrderLoader`
- `OrderValidator.lua` — `volumeWarnedTickers` не используется
- `Tests/run_tests.lua:660` — assertion на `#sendOrders`

## Правила безопасности
- Python script для всех изменений в .lua файлах
- НЕ трогать русский текст
- `python cp1251_wrapper.py check_all` после каждого изменения
