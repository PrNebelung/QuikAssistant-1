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
| `{BROKER}_SellOrders.csv` | Заявки на продажу (фиксированная цена) |
| `{BROKER}_BuyOrders_Edge.csv` | Покупка по минимальной цене (PRICEMIN) |
| `{BROKER}_SellOrders_Edge.csv` | Продажа по максимальной цене (PRICEMAX) |
| `{BROKER}_BuyOrdersBonds_Edge.csv` | Покупка облигаций по минимальной цене |

### Формат CSV

```
Название;Операция;Тикер;Количество;Цена
```

- `Операция`: `B` (покупка) или `S` (продажа)
- Строки, начинающиеся с `--`, считаются комментариями

### Типы файлов

- **Обычные файлы** (`_BuyOrders.csv`, `_SellOrders.csv`): заявки с фиксированной ценой из колонки 5
- **Buy Edge** (`_BuyOrders_Edge.csv`): цена берётся из `PRICEMIN`, количество рассчитывается по объёму
- **Sell Edge** (`_SellOrders_Edge.csv`): цена берётся из `PRICEMAX`, количество по объёму, ограничение позицией
- **Облигации Edge** (`_BuyOrdersBonds_Edge.csv`): аналогично buy edge, но для облигаций

### Валидация операций

При загрузке заявок проверяется соответствие операции имени файла:
- Файл содержит `BUY` → операция должна быть `B`
- Файл содержит `SELL` → операция должна быть `S`
- Файл не содержит ни BUY, ни SELL → заявка пропускается с предупреждением

Несовпадение игнорируется с ошибкой в логах: `[SKIP] Несовпадение операции в файле BUY/SELL`.

### Обработка пробелов

Пробелы в начале и конце операции (` B `) и тикера (` GAZP `) автоматически удаляются перед обработкой.

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
2. Загрузка заявок из CSV-файлов (по порядку):
   - 2.1 `_BuyOrders.csv` — покупка по фиксированной цене
   - 2.2 `_BuyOrdersBondsEdge.csv` — покупка облигаций edge
   - 2.3 `_BuyOrders_Edge.csv` — покупка акций edge
   - 2.7 `_SellOrders.csv` — продажа по фиксированной цене
   - 2.8 `_SellOrders_Edge.csv` — продажа по максимальной цене
3. Для каждой заявки:
   - Валидация операции по имени файла (BUY→B, SELL→S)
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

### Расчёт количества для edge-заявок

**Buy Edge**: количество = `floor(VolumeMax / PriceMin / LotSize)`

**Sell Edge**: количество = `floor(VolumeMax / PriceMax / LotSize)`, ограничено позицией в портфеле

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

170 тестов: Order, CheckOrder, QuikFunction, TradeSave, TableConstructor, Sell Edge, валидация операций, тримминг пробелов.

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
[SEND] S GAZP TQBR кол=50 цена=300.00
[SKIP] B GAZP - Заявка уже существует в QUIK (isFind=true)
[SKIP] B TGKA - Объём превышает лимит 200000 SUR (объём: 250100)
[SKIP] Несовпадение операции в файле BUY: ожидалась S, нужно B [GAZP]
[SKIP] Файл MyFile.csv не содержит BUY/SELL в имени, пропуск [GAZP]
=== Цикл 1: загружено=8, отправлено=5, отклонено=2, дублей=1 ===
```

## Все настройки

### Идентификация брокера

| Параметр | Описание | Пример |
|----------|----------|--------|
| `Broker` | Имя брокера (используется в именах файлов) | `"VTB"`, `"FINAM"` |
| `ClientCode` | Код клиента | `"386507"` |
| `AccountCode` | Код торгового счёта | `"L01-00000F00"` |
| `FirmId` | Код фирмы | `"MC0003300000"` |

### Лимиты объёма

| Параметр | Описание | FINAM | VTB | PSB | RSHB |
|----------|----------|-------|-----|-----|------|
| `VolumeOrderMin` | Минимальный объём сделки | 11000 | 11000 | 10000 | 11000 |
| `VolumeOrderMax` | Макс. объём покупки акций (RUB) | 70000 | 20000 | 50000 | 20000 |
| `BondVolumeOrderMax` | Макс. объём покупки облигаций (RUB) | 100000 | 20000 | 100000 | 20000 |
| `OFZVolumeOrderMax` | Макс. объём покупки ОФЗ (RUB) | 10000 | 15000 | 10000 | 15000 |
| `VolumeOrderLimit` | Глобальный лимит объёма (RUB) | 120000 | 200000 | 120000 | 200000 |

### Пороги срабатывания (отклонение от рынка)

| Параметр | Описание | FINAM | VTB | PSB | RSHB |
|----------|----------|-------|-----|-----|------|
| `LimitActuationOrderEdge` | Мин. % отклонения для акций | 0% | 0% | 0% | 0% |
| `LimitActuationOrderBondEdge` | Мин. % отклонения для облигаций | 50% | 30% | 0% | 60% |

### Корректировка цены

| Параметр | Описание | Значение |
|----------|----------|----------|
| `PRICE_DEVIATION_MULTIPLIER` | Множитель отклонения цены от LAST | 10 |

Как работает: если цена покупки выше `LAST`, она снижается до `LAST - 10 × шаг`. Если цена продажи ниже `LAST`, она повышается до `LAST + 10 × шаг`.

### Файлы заявок

Автоматически формируются из имени брокера:

| Переменная | Формируется как | Назначение |
|------------|-----------------|------------|
| `FileBuyOrder` | `{Broker}_BuyOrders.csv` | Покупка по фикс. цене |
| `FileSellOrder` | `{Broker}_SellOrders.csv` | Продажа по фикс. цене |
| `FileBuyOrderEdge` | `{Broker}_BuyOrders_Edge.csv` | Покупка по PRICEMIN |
| `FileSellOrderEdge` | `{Broker}_SellOrders_Edge.csv` | Продажа по PRICEMAX |
| `FileBuyOrderBondsEdge` | `{Broker}_BuyOrdersBonds_Edge.csv` | Покупка облигаций edge |

### Флаги и коды ошибок

| Параметр | Описание | Значение |
|----------|----------|----------|
| `FLAG_ACTIVE` | Флаг активной заявки | `0x1` |
| `FLAG_EXECUTED` | Флаг исполненной заявки | `0x2` |
| `FLAG_SELL` | Флаг заявки на продажу | `0x4` |
| `ERR_PRICE_TOO_LOW` | Ошибка: цена слишком низкая | `579` |
| `ERR_PRICE_TOO_HIGH` | Ошибка: цена слишком высокая | `580` |
| `ERR_EXECUTION_REJECTED` | Ошибка: исполнение отклонено | `133` |

## Пример конфигурации

### Настройка брокера (`Setting.lua`)

```lua
function SetSettingMyBroker()
  Broker = "MYBROKER"
  ClientCode = "12345"              -- Код клиента
  AccountCode = "NL0011100043"      -- Код торгового счёта
  FirmId = "MC0000000000"           -- Код фирмы

  -- Лимиты объёма
  VolumeOrderMax = 30000            -- Макс. объём покупки акций (RUB)
  BondVolumeOrderMax = 50000        -- Макс. объём покупки облигаций (RUB)
  OFZVolumeOrderMax = 20000         -- Макс. объём покупки ОФЗ (RUB)
  VolumeOrderLimit = 200000         -- Глобальный лимит объёма (RUB)

  -- Пороги срабатывания (отклонение от рынка)
  LimitActuationOrderEdge = 5       -- Мин. % отклонения для акций
  LimitActuationOrderBondEdge = 60  -- Мин. % отклонения для облигаций
end
```

### Подключение в `SetClientSetting()`

```lua
function SetClientSetting()
  local userId = getInfoParam("USERID")

  if userId == "171783" then
    SetSettingFinam()
  elseif userId == "49653" then
    SetSettingVTB()
  elseif userId == "12345" then       -- <-- ваш USERID
    SetSettingMyBroker()
  else
    Broker = ""
    ClientCode = ""
    AccountCode = ""
    VolumeOrderMax = 0
  end

  -- Файлы заявок формируются автоматически
  FileBuyOrder = Broker .. "_BuyOrders.csv"
  FileSellOrder = Broker .. "_SellOrders.csv"
  FileBuyOrderEdge = Broker .. "_BuyOrders_Edge.csv"
  FileSellOrderEdge = Broker .. "_SellOrders_Edge.csv"
  FileBuyOrderBondsEdge = Broker .. "_BuyOrdersBonds_Edge.csv"
end
```

### Пример CSV-файла (`Data/MYBROKER_BuyOrders.csv`)

```csv
-- Акции
ГАЗПРОМ;B;GAZP;100;180.00
Сбербанк;B;SBER;50;250.00
Лукойл;B;LKOH;10;7000.00
-- Облигации (закомментированы)
--ОФЗ 26236;B;SU26236RMFS8;5;100.00
```

### Пример CSV-файла (`Data/MYBROKER_SellOrders_Edge.csv`)

```csv
-- Продажа по максимуму, количество из позиции
ГАЗПРОМ;S;GAZP;1;0.01
Сбербанк;S;SBER;1;0.01
```

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

### ~~Комментарий N_CloseAllOrder в вечерней сессии~~ (исправлено)

Вызов `N_CloseAllOrder()` в вечерней сессии был закомментирован. Теперь отмена заявок работает во всех сессиях.

### ~~Проверка дублей по коду бумаги и операции~~ (исправлено)

`IsSendOrder` проверял только `SecurityCode` и `Operation`. Теперь добавлена проверка количества и цены:
```lua
local key = order.SecurityCode .. " " .. order.Operation .. " " .. order:FormatQuantity() .. " " .. order:FormatPrice()
```
Это позволяет корректно различать заявки на одну бумагу с разными параметрами.
