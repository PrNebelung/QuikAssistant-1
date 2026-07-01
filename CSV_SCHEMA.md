# CSV Schema — QuikAssistant

Описание форматов CSV-файлов, используемых системой.

---

## 1. Файлы заявок (Orders)

**Имена файлов:** `{Broker}_{Type}.csv`

| Поле | Пример |
|------|--------|
| Broker | VTB, PSB, FINAM, RSHB, TEST |
| Type | BuyOrders, SellOrders, BuyOrders_Edge, SellOrders_Edge, BuyOrdersBonds_Edge |

### Формат строки

```
Название;Операция;Тикер;Количество;Цена
```

| Позиция | Поле | Тип | Описание | Пример |
|---------|------|-----|----------|--------|
| 1 | Название | string | Человекочитаемое название бумаги | `ГАЗПРОМ` |
| 2 | Операция | char | `B` = покупка, `S` = продажа | `B` |
| 3 | Тикер/ISIN | string | Код бумаги в QUIK (тикер или ISIN для облигаций) | `GAZP`, `RU000A102RN7` |
| 4 | Количество | number | Количество лотов (целое число) | `200` |
| 5 | Цена | number | Цена за единицу | `50`, `0.0001` |

### Примеры

**Акции (BuyOrders):**
```csv
ГАЗПРОМ;B;GAZP;200;50
Сбербанк;B;SBER;1110;90
```

**Облигации (BuyOrdersBondsEdge):**
```csv
Атомэнергопром-001Р-05;B;RU000A10BFG2;1;0.01
РЖД-001P-38R;B;RU000A10AZ60;1;0.01
```

### Типы файлов

| Файл | Назначение | Обработка |
|------|------------|-----------|
| `BuyOrders.csv` | Ордера на покупку по фиксированной цене | `Order:SetOperation(price, qty)` |
| `SellOrders.csv` | Ордера на продажу по фиксированной цене | `Order:SetOperation(price, qty)` |
| `BuyOrders_Edge.csv` | Ордера на покупку по рыночной цене (edge) | `Order:SetQuantity(priceMin, volumeMax)` |
| `SellOrders_Edge.csv` | Ордера на продажу по макс. цене (edge) | `Order:SetQuantitySell(priceMax, positionQty)` |
| `BuyOrdersBondsEdge.csv` | Ордера на покупку облигаций по рыночной цене | `Order:SetQuantity(priceMin, volumeMax)` |

### Комментарии и разделители

```csv
-- ═══════════════════ Нефтегаз ═══════════════════
ГАЗПРОМ;B;GAZP;200;50
-- Роснефть;B;ROSN;500;200
```

- Строки, начинающиеся с `--`, являются комментариями (пропускаются)
- Строки-разделители (`-- ═══...`) используются для визуального разделения секций
- Закомментированные заявки (`-- Название;B;...`) не обрабатываются

---

## 2. Журнал сделок (Trades)

**Имя файла:** `MyTrades.csv`

### Формат строки

```
Дата_Время;Тикер;Количество;Цена;Брокер
```

| Позиция | Поле | Тип | Описание | Пример |
|---------|------|-----|----------|--------|
| 1 | Дата/Время | datetime | `YYYY-MM-DD HH:MM:SS` | `2026-01-05 17:53:12` |
| 2 | Тикер | string | Код бумаги | `RU000A10DG52` |
| 3 | Количество | number | Количество (с `-` для продажи) | `9.0`, `-5.0` |
| 4 | Цена | number | Цена исполнения | `98.0` |
| 5 | Брокер | string | Название брокера | `PSB`, `VTB` |

### Пример

```csv
2026-01-05 17:53:12;RU000A10DG52;9.0;98.0;PSB
2026-01-05 17:55:00;GAZP;100;150.50;VTB
```

### Формирование

Файл формируется функцией `TradeSave()` в `TradeSave.lua`. Каждая сделка записывается при получении callback'а `OnTrade` от QUIK.

---

## 3. Архивные журналы сделок

**Имена файлов:** `_MyTrades_{Год}.csv`

Формат идентичен `MyTrades.csv`. Файлы создаются вручную или скриптами для архивации по годам.

Примеры: `_MyTrades_2023.csv`, `_MyTrades_2024.csv`, `_MyTrades_2025.csv`

---

## 4. Настройки (Settings)

**Имя файла:** `settings.json`

Формат: JSON с вложенными объектами по брокерам.

```json
{
  "VTB": {
    "clientCode": "49653",
    "accountCode": "49653",
    "firmId": "SPBFUT",
    "volumeOrderMax": 100,
    "bondVolumeOrderMax": 50,
    "volumeOrderLimit": 200000,
    "limitActuationOrderEdge": 5,
    "limitActuationOrderBondEdge": 60,
    "sessionMorningEnabled": true,
    "sessionMainEnabled": true,
    "sessionEveningEnabled": true,
    "sessionMorningHour": 7,
    "sessionMorningMin": 30,
    "sessionMorningSec": 0,
    "sessionMainHour": 10,
    "sessionMainMin": 30,
    "sessionMainSec": 0,
    "sessionEveningHour": 19,
    "sessionEveningMin": 2,
    "sessionEveningSec": 10,
    "brokerEnabled": true
  }
}
```

### Поля конфигурации

| Поле | Тип | Описание |
|------|-----|----------|
| `clientCode` | string | Код клиента в QUIK |
| `accountCode` | string | Код счета |
| `firmId` | string | Идентификатор фирмы |
| `volumeOrderMax` | number | Макс. объём ордера (акции) |
| `bondVolumeOrderMax` | number | Макс. объём ордера (облигации) |
| `volumeOrderLimit` | number | Лимит объёма ордера |
| `limitActuationOrderEdge` | number | Порог срабатывания для edge (%) |
| `limitActuationOrderBondEdge` | number | Порог срабатывания для облигаций (%) |
| `sessionMorningEnabled` | bool | Утренняя сессия включена |
| `sessionMainEnabled` | bool | Дневная сессия включена |
| `sessionEveningEnabled` | bool | Вечерняя сессия включена |
| `sessionMorningHour/Min/Sec` | number | Время начала утренней сессии (UTC) |
| `sessionMainHour/Min/Sec` | number | Время начала дневной сессии (UTC) |
| `sessionEveningHour/Min/Sec` | number | Время начала вечерней сессии (UTC) |
| `brokerEnabled` | bool | Брокер включён для торговли |

---

## Валидация

### Lua (LoadOrdersFromFile)

```lua
-- Проверки при загрузке:
assert(row[2] ~= nil and row[3] ~= nil, "Некорректная строка CSV")
assert(operation == "B" or operation == "S", "Неизвестная операция")
assert(tonumber(quantity) > 0, "Количество должно быть > 0")
```

### Python (web/csv_handler.py)

```python
# read_orders() проверяет:
if len(parts) >= 5:
    # Валидная строка
else:
    # Пропуск (комментарий или разделитель)
```

---

## Кодировки

| Файл | Кодировка |
|------|-----------|
| `*.csv` (заявки) | UTF-8 |
| `MyTrades.csv` | UTF-8 |
| `settings.json` | UTF-8 |
| `*.lua` | Windows-1251 (cp1251) |
