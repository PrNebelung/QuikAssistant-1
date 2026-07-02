# QuikAssistant

Торговый ассистент для QUIK — автоматическая отправка лимитных ордеров по расписанию сессий.

**Версия:** v1.3.0

---

## Модули проекта

| Модуль | Описание |
|--------|----------|
| `StartEngine.lua` | Точка входа скрипта QUIK. Загружает модули, определяет глобальные переменные состояния, реализует главный цикл обработки событий и callback-функции QUIK (OnInit, OnStop, OnOrder, OnTrade, OnTransReply). |
| `Assistant.lua` | Основная логика ассистента. Callback-функции обработки событий, отправка ордеров через N_SetLimitOrder (с флагом resubmit), обработка ошибок транзакций. |
| `Config.lua` | Единый конфигурационный модуль. Хранит все настройки: параметры брокера, лимиты, расписание сессий, имена файлов. |
| `Constants.lua` | Бизнес-константы: флаги ордеров QUIK, коды ошибок, статусы транзакций. |
| `Setting.lua` | Настройки брокеров. Определяет брокера по USERID, загружает настройки из settings.json. |
| `SessionScheduler.lua` | Планировщик торговых сессий. Управляет таймерами и флагами для утренней, дневной и вечерней сессий. |
| `OrderLoader.lua` | Загрузка ордеров из CSV-файлов. Парсит CSV, создаёт объекты Order с заполненными параметрами. |
| `Order.lua` | Модуль торгового ордера. Конструктор, методы установки цены/количества/операции, проверки типа инструмента. |
| `BrokerAdapter.lua` | Адаптер QUIK API. �?нкапсулирует все вызовы функций QUIK с кешированием. |
| `MarketData.lua` | Получение рыночных данных: LAST, PRICEMIN, PRICEMAX, PREVPRICE. |
| `PositionService.lua` | Сервис позиций депо-лимитов с кешированием. |
| `OrderValidator.lua` | Валидатор ордеров (цепочка проверок): обязательные поля, цена, позиция, объём, срабатывание. |
| `PriceAdjuster.lua` | Корректировщик цен относительно LAST и PRICEMIN. |
| `TransactionHandler.lua` | Обработчик транзакций и ошибок QUIK (579, 580, 133). |
| `SubmittingOrders.lua` | Оркестрация отправки ордеров. Координирует SessionScheduler, OrderLoader и отправку. |
| `FormatUtils.lua` | Утилиты форматирования чисел: comma_value, round, format_num. |
| `FileFunction.lua` | Чтение CSV-файлов из папки Data. |
| `TradeSave.lua` | Сохранение сделок в MyTrades.csv. |
| `TableConstructor.lua` | Универсальный конструктор таблиц QUIK (QTable). |
| `TableOrders.lua` | Таблица активных ордеров в интерфейсе QUIK. |
| `TableSetting.lua` | Таблица настроек в интерфейсе QUIK. |
| `log.lua` | Модуль логирования (TRACE..FATAL). INFO+ пишется в файл. |

---

## Архитектура

```
StartEngine.lua (точка входа)
  ├── Assistant.lua (callback-функции, N_SetLimitOrder)
  │   ├── SubmittingOrders.lua (оркестрация отправки)
  │   │   ├── SessionScheduler.lua (таймеры сессий)
  │   │   ├── OrderLoader.lua (парсинг CSV → Order)
  │   │   ├── OrderValidator.lua (валидация)
  │   │   ├── TransactionHandler.lua (ошибки QUIK)
  │   │   └── TableOrders.lua (таблица ордеров)
  │   ├── Setting.lua (настройки брокеров)
  │   │   ├── Config.lua (конфигурация)
  │   │   ├── SettingsManager.lua (JSON persistence)
  │   │   └── TableSetting.lua (таблица настроек)
  │   ├── Order.lua (модуль ордера)
  │   ├── MarketData.lua (рыночные данные)
  │   ├── PositionService.lua (позиции)
  │   ├── PriceAdjuster.lua (корректировка цен)
  │   ├── TableConstructor.lua (QTable)
  │   └── TradeSave.lua (сохранение сделок)
  ├── FormatUtils.lua (форматирование чисел)
  ├── BrokerAdapter.lua (QUIK API)
  ├── Constants.lua (константы)
  └── log.lua (логирование)
```

### Поток отправки ордера

```
1. N_OnMainLoop() → SubmittingOrders()
2. SessionScheduler.CheckSession() → определяет текущую сессию
3. SubmittingOrdersRun() → загружает ордера из CSV
4. OrderLoader.LoadOrdersFromFile() → создаёт объекты Order
5. SubmitOrders(orders) для каждого ордера:
   ├── AdjustPrice() — корректировка цены
   ├── IsOrderExists() — проверка дубликата в QUIK
   ├── IsSendOrder() — проверка дубликата в сессии
   ├── CheckOrder() — цепочка валидации
   └── N_SetLimitOrder(resubmit=true) → SendTransaction()
6. При ошибке: N_OnTransSendError → SetLimitOrdersWithError
   └── SubmitOrders(resubmit=false) → N_SetLimitOrder(resubmit=false)
       └── При ошибке: НЕ вызывает N_OnTransSendError (прерывание)
```

---

## Конфигурация

### settings.json

Файл настроек брокеров в формате JSON:

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

### Поддерживаемые брокеры

| Брокер | USERID | Статус |
|--------|--------|--------|
| VTB | 49653 | Активен |
| PSB | 34146 | Отключен |
| FINAM | 171783 | Отключен |
| RSHB | 48640 | Активен |
| TEST | любой | Тестовый |

---

## CSV-файлы

Подробное описание форматов: [CSV_SCHEMA.md](CSV_SCHEMA.md)

### Файлы заявок

| Файл | Формат |
|------|--------|
| `{Broker}_BuyOrders.csv` | Название;B;Тикер;Количество;Цена |
| `{Broker}_SellOrders.csv` | Название;S;Тикер;Количество;Цена |
| `{Broker}_BuyOrders_Edge.csv` | Название;B;Тикер;1;Цена |
| `{Broker}_SellOrders_Edge.csv` | Название;S;Тикер;1;Цена |
| `{Broker}_BuyOrdersBonds_Edge.csv` | Название;B;ISIN;1;Цена |

### Журнал сделок

| Файл | Формат |
|------|--------|
| `MyTrades.csv` | Дата_Время;Тикер;Количество;Цена;Брокер |

---

## Тесты

```bash
# Unit тесты (271)
lua Tests/run_tests.lua
```

### �?нструменты качества кода

```bash
# Luacheck (линтинг)
luacheck . --config .luacheckrc

# StyLua (форматирование cp1251)
python stylua_cp1251.py check    # проверка
python stylua_cp1251.py format   # форматирование

# Проверка кодировки
python cp1251_wrapper.py check_all
```

---

## Кодировка

Все `.lua` файлы используют **Windows-1251 (cp1251)** для русского текста.

**НЕ �?СПОЛЬЗОВАТЬ** Edit tool напрямую на `.lua` файлах с русским текстом!

Безопасное редактирование:
```bash
python cp1251_wrapper.py replace "file.lua" "старый текст" "новый текст"
python cp1251_wrapper.py insert_after "file.lua" 10 "    новая_строка"
python cp1251_wrapper.py delete_line "file.lua" 10
```

---

## Версии

| Версия | Дата | Описание |
|--------|------|----------|
| v1.3.0 | 2026-07-01 | Улучшение архитектуры: разделение модулей, resubmit flag, FormatUtils, линтинг |
| v1.2.2 | 2026-07-01 | Веб: обновление action_log.json |
| v1.2.1 | 2026-07-01 | Веб: исправление кодировки логов, сортировка |
| v1.2.0 | 2026-07-01 | Данные: группировка акций, добавление MOEX стоков |
