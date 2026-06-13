# QuikAssistant

Автоматический торговый ассистент для платформы QUIK (Московская биржа). Загружает заявки из CSV-файлов, проверяет ограничения и отправляет лимитные заявки на биржу.

## Зависимости

- **Lua 5.3+** — запуск скриптов
- **QUIK** — терминал Московской биоржи (скрипт загружается через `StartEngine.lua`)

## Быстрый старт

1. Поместите папку `QuikAssistant` в папку скриптов QUIK
2. В терминале QUIK откройте `StartEngine.lua`
3. Скрипт автоматически определит брокера по USERID и начнёт работу

## Структура проекта

```
QuikAssistant/
├── StartEngine.lua           # Точка входа, главный цикл
├── Assistant.lua             # Обработка событий QUIK, отправка заявок
├── SubmittingOrders.lua      # Загрузка и отправка заявок по сессиям
├── QuikFunction.lua          # Проверка заявок, работа с позициями
├── Order.lua                 # Модель заявки, расчёт цен и объёмов
├── Setting.lua               # Конфигурация брокеров
├── FileFunction.lua          # Загрузка CSV-файлов
├── TradeSave.lua             # Сохранение сделок в лог
├── TableConstructor.lua      # Абстракция таблиц QUIK (QTable)
├── TableOrders.lua           # Таблица заявок в интерфейсе
├── TableSetting.lua          # Таблица настроек в интерфейсе
├── log.lua                   # Библиотека логирования (rxi/log.lua)
├── csv.lua                   # Парсер CSV
├── json.lua                  # JSON-кодировщик
├── enum.lua                  # Библиотека enum
├── Data/                     # CSV-файлы с заявками
│   ├── {BROKER}_BuyOrders.csv
│   ├── {BROKER}_SellOrders.csv
│   ├── {BROKER}_BuyOrders_Edge.csv
│   └── {BROKER}_BuyOrdersBonds_Edge.csv
├── Log/                      # Лог-файлы по брокерам
│   └── {BROKER}/{YYYY-MM-DD}.log
├── Tests/                    # Unit-тесты
└── IntegrationTests/         # Интеграционные тесты
```

## Поддерживаемые брокеры

| Брокер | USERID | Код клиента | Фирма |
|--------|--------|-------------|-------|
| **FINAM** | 171783 | 0734A/0734A | MC0061900000 |
| **VTB** | 49653 | 386507 | MC0003300000 |
| **PSB** | 34146 | 40200 | MC0038600000 |
| **RSHB** | 48640 | 496082 | MC0134700000 |
| **TEST** | 119330 | 10567 | — |

Брокер определяется автоматически по `USERID` терминала QUIK.

## Сессии

Скрипт работает в трёх торговых сессиях:

| Сессия | Время (UTC) | Действие |
|--------|-------------|----------|
| **Утренняя** | 07:00:30 | Загрузка заявок не выполняется |
| **Основная** | 10:00:30 | Загрузка и отправка заявок |
| **Вечерняя** | 19:02:10 | Загрузка заявок не выполняется |

При переходе между сессиями активные заявки отменяются (`N_CloseAllOrder`).

## Файлы заявок

Для каждого брокера в папке `Data/` хранятся CSV-файлы:

| Файл | Назначение |
|------|-----------|
| `{BROKER}_BuyOrders.csv` | Заявки на покупку (фиксированная цена) |
| `{BROKER}_SellOrders.csv` | Заявки на продажу |
| `{BROKER}_BuyOrders_Edge.csv` | Покупка по минимальной цене (edge) |
| `{BROKER}_BuyOrdersBonds_Edge.csv` | Покупка облигаций по минимальной цене |

### Формат CSV

```
Название;Операция;Тикер;Количество;Цена
```

- `Операция`: `B` (покупка) или `S` (продажа)
- Строки, начинающиеся с `--`, считаются комментариями

### Типы файлов

- **Обычные файлы** (`_BuyOrders.csv`): заявки с фиксированной ценой из колонки 5
- **Edge-файлы** (`_Edge.csv`): цена берётся из `PRICEMIN`, количество рассчитывается по объёму
- **Облигации Edge** (`_BuyOrdersBonds_Edge.csv`): аналогично, но для облигаций

## Логика работы

### Главный цикл (`StartEngine.lua`)

```
while isRun:
  1. N_OnMainLoop()         → обработка заявок
  2. Проверка транзакций    → обработка ошибок/успеха
  3. Проверка заявок        → отслеживание исполнения
  4. Проверка сделок        → закрытие позиций
  5. sleep(1000)
```

### Отправка заявок (`SubmittingOrders.lua`)

1. Проверка текущей сессии
2. Загрузка заявок из CSV-файлов
3. Для каждой заявки:
   - Проверка на дубли в QUIK (`IsOrderExists`)
   - Проверка ограничений (`CheckOrder`)
   - Проверка на дублирование в текущем цикле (`IsSendOrder`)
   - Отправка через `sendTransaction`

### Проверка заявок (`QuikFunction.lua`)

`CheckOrder` выполняет последовательную проверку:

1. **Корректность параметров** — цена, количество, операция > 0
2. **Корректировка цены** — цена покупки не выше `LAST - 10 * шаг`, продажи не ниже `LAST + 10 * шаг`
3. **Достаточность позиции** (продажа) — `currentbal >= quantity`
4. **Лимит объёма** (покупка) — `GetVolume() <= VolumeOrderLimit`
5. **Отклонение от рынка** (покупка) — `actuation >= LimitActuationOrderEdge`
6. **Лимит цены облигации** — цена <= 100%
7. **Средняя цена позиции** — не покупать дороже текущей средней

### Расчёт объёма (`Order.lua`)

```lua
GetVolume() = Quantity × PriceInCurrency × LotSize

-- Для акций:
PriceInCurrency = Price

-- Для облигаций:
PriceInCurrency = Price × Nominal / 100
```

## Тесты

### Unit-тесты

```bash
lua Tests/run_tests.lua
```

176 тестов: Order, CheckOrder, QuikFunction, TradeSave, TableConstructor.

### Интеграционные тесты

```bash
# Основной pipeline
lua IntegrationTests/run_integration_tests.lua --broker=TEST --session=main

# Edge cases
lua IntegrationTests/run_edge_cases.lua
```

| Тест | Что проверяет |
|------|--------------|
| `run_integration_tests.lua` | Загрузка CSV, отправка, дубли, логирование |
| `run_edge_cases.lua` | Nil-безопасность, лимиты, позиции,边界值 |

### Запуск с параметрами

```bash
lua IntegrationTests/run_integration_tests.lua --broker=VTB --session=morning
lua IntegrationTests/run_integration_tests.lua --broker=FINAM --session=evening
```

## Логирование

Логи пишутся в `Log/{BROKER}/{YYYY-MM-DD}.log`.

Уровни: `trace` < `debug` < `info` < `warn` < `error` < `fatal`.

### Формат лога

```
УРОВЕНЬ  ДАТА_ВРЕМЯ  БРОКЕР  ФАЙЛ:СТРОКА  СООБЩЕНИЕ
```

### Примеры записей

```
[SEND] B GAZP TQBR кол=100 цена=250.00
[SKIP] B GAZP - Заявка уже существует в QUIK (isFind=true)
[SKIP] B TGKA - Объём превышает лимит 200000 SUR (объём: 250100)
=== Цикл 1: загружено=6, отправлено=4, отклонено=2, дублей=0 ===
```

## Конфигурация лимитов

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `VolumeOrderMax` | Макс. объём покупки акций | 11000 |
| `BondVolumeOrderMax` | Макс. объём покупки облигаций | 7000 |
| `VolumeOrderLimit` | Глобальный лимит объёма | 200000 |
| `VolumeOrderLimitUSD` | Лимит для USD/SPB | 100 |
| `LimitActuationOrderEdge` | Мин. отклонение от рынка (акции) | 5% |
| `LimitActuationOrderBondEdge` | Мин. отклонение от рынка (облигации) | 60% |
| `PRICE_DEVIATION_MULTIPLIER` | Множитель корректировки цены | 10 |

## Добавление нового брокера

1. Добавить USERID в `Setting.lua` → `SetClientSetting()`
2. Создать функцию `SetSettingXxx()` с параметрами
3. Создать CSV-файлы `Data/{BROKER}_*.csv`

## Архитектурные решения

- **Кэш позиций** (`Order.lua`): `positionCache` хранит найденные позиции для избежания повторных запросов
- **Кэш инструментов** (`Order.lua`): `securityInfoCache` кэширует `GetSecurityInfo`/`GetUsdSecurityInfo`
- **Защита от рекурсии** (`Assistant.lua`): `N_SetLimitOrder` имеет счётчик глубины (макс. 3)
- **SetOperations** (`SubmittingOrders.lua`): `sendOrdersSet` для O(1) проверки дублей в текущем цикле
- **pcall** (`SubmittingOrders.lua`): основной блок обёрнут в `pcall` для гарантии сброса `IsSendingOrders`

## Известные проблемы

### ~~Дублирование sell-заявок при корректировке цены~~ (исправлено)

Проблема была в `SubmitOrders`: `IsOrderExists` вызывался **до** `CheckOrder`, который корректирует цену продажи. Sell-заявка с CSV-ценой 3.0 проверялась через `IsOrderExists` (сравнивала 3.0 ≠ 1001.0 из mock-таблицы), а затем `CheckOrder` менял цену на 1001.0.

**Исправление**: в `SubmitOrders` порядок вызовов изменён на `CheckOrder` → `IsOrderExists`. Теперь цена корректируется до проверки на дубли, и sell-заявки корректно определяются как дубли.

### Комментарий N_CloseAllOrder в вечерней сессии

В `SubmittingOrders.lua:90-95` вызов `N_CloseAllOrder()` закомментирован:
```lua
if (os.time(TimeEveningStart) < timeCurrent) and not IsEveningTime then
    -- if IsSentOrders then
      -- N_CloseAllOrder()
    -- end
```
При наступлении вечерней сессии `IsSentOrders` сбрасывается, но активные заявки **не отменяются**. Если это не intentional — нужно раскомментировать.

### ~~Проверка дублей по коду бумаги и операции~~ (исправлено)

`IsSendOrder` проверял только `SecurityCode` и `Operation`. Теперь добавлена проверка количества и цены:
```lua
local key = order.SecurityCode .. " " .. order.Operation .. " " .. order:FormatQuantity() .. " " .. order:FormatPrice()
```
Это позволяет корректно различать заявки на одну бумагу с разными параметрами.

### Молчаливый пропуск ненайденного инструмента в GetUsdSecurityInfo

`GetUsdSecurityInfo` (`Order.lua:52-64`) возвращает `nil` без логирования, если инструмент не найден ни в одном классе. Вызывающий код (`Order:new`) обрабатывает `nil`, но причина отказа невидима в логах.

### Результат unit-тестов: 3 FAIL

В `Tests/run_tests.lua` 3 теста не проходят (176/179):
- Название инструмента / Краткое имя — расхождение ожидаемых значений в тесте облигации
- Объём `0.01 * 100 * 10` — расчёт `GetVolume` для GAZP (lot_size=10) даёт 0.1 вместо 10

Эти тесты были до рефакторинга и не связаны с внесенными изменениями.
