# QuikAssistant

Торговый ассистент для QUIK — автоматическая отправка лимитных ордеров по расписанию сессий.

---

## Модули проекта

| Модуль | Описание |
|--------|----------|
| `StartEngine.lua` | Точка входа скрипта QUIK. Загружает модули, определяет глобальные переменные состояния, реализует главный цикл обработки событий и callback-функции QUIK (OnInit, OnStop, OnOrder, OnTrade, OnTransReply). |
| `Assistant.lua` | Основная логика торгового ассистента. Определяет callback-функции обработки событий QUIK, отправку лимитных ордеров через N_SetLimitOrder, обработку ошибок транзакций и закрытие всех активных ордеров. |
| `Config.lua` | Единый конфигурационный модуль проекта. Хранит все настройки: параметры брокера, лимиты объёмов, пороговые значения, имена файлов ордеров и расписание сессий. |
| `Constants.lua` | Бизнес-константы проекта. Определяет флаги ордеров QUIK, коды ошибок, статусы транзакций и множители корректировки цен. |
| `Setting.lua` | Настройки брокеров и инициализация конфигурации. Содержит функции SetSettingVTB, SetSettingPSB, SetSettingFinam и др. для заполнения Config параметрами конкретного брокера. Реализует автодетект брокера по USERID через BrokerRegistry. |
| `Order.lua` | Модуль торгового ордера (Order). Реализует конструктор Order:new(), методы установки цены, количества, операции, проверки типа инструмента (акция/облигация/ETF), округления цен, расчёта объёма и форматирования для отправки в QUIK. |
| `BrokerAdapter.lua` | Адаптер для взаимодействия с QUIK API. Инкапсулирует все вызовы функций QUIK: getSecurityInfo, getParamEx, SearchItems, getItem, sendTransaction, isConnected и др. Единая точка доступа к брокерскому API с кешированием. |
| `MarketData.lua` | Получение рыночных данных из QUIK. Предоставляет функции GetPriceLast, GetPriceMin, GetPriceMax, GetPricePrev для получения текущей, минимальной, максимальной и предыдущей цены инструмента. |
| `PositionService.lua` | Сервис позиций депо-лимитов. Реализует кешированный поиск позиций по депо-лимитам, определение текущей позиции по коду инструмента и очистку кеша позиций. |
| `OrderValidator.lua` | Валидатор ордеров (цепочка проверок). Проверяет ордера перед отправкой: обязательные поля, цена ниже PRICEMIN, наличие позиции для продажи, лимит объёма, срабатывание, цена облигации, средняя цена позиции. Также содержит логику расчёта максимального объёма ордера. |
| `PriceAdjuster.lua` | Корректировщик цен ордеров. Автоматически корректирует цену покупки/продажи относительно последней цены (LAST) и минимального шага цены (PRICEMIN). Не изменяет цены, заданные из файла (UseFileParams). |
| `TransactionHandler.lua` | Обработчик транзакций и ордеров QUIK. Определяет операцию по флагам, проверяет существование ордера, получает список активных ордеров, обрабатывает ошибки транзакций (579, 580, 133) с автоматическим восстановлением. |
| `SubmittingOrders.lua` | Основной модуль отправки ордеров. Управляет расписанием сессий, загрузкой ордеров из CSV-файлов, проверкой на дубликаты, валидацией и отправкой в QUIK. Также обрабатывает закрытие позиций при сделках. |
| `FileFunction.lua` | Работа с CSV-файлами ордеров. Реализует чтение CSV-файлов с описаниями ордеров из папки Data проекта. |
| `TradeSave.lua` | Сохранение сделок в файл. Записывает информацию о каждой исполненной сделке (код, операция, количество, цена) в файл MyTrades.csv. |
| `TableConstructor.lua` | Универсальный конструктор таблиц QUIK (QTable). Реализует класс QTable с методами добавления колонок, строк, позиционирования окна, окраски ячеек, а также утилиты форматирования чисел. |
| `TableOrders.lua` | Таблица активных ордеров в интерфейсе QUIK. Создаёт и обновляет таблицу с текущими ордерами: название, код, операция, актуализация, цена, объём, номер ордера с цветовой индикацией. |
| `TableSetting.lua` | Таблица настроек в интерфейсе QUIK. Отображает информацию о брокере, времени сервера, файлах ордеров, портфеле (активы, прибыль/убыток) и индексе MOEX. Поддерживает открытие файлов по двойному клику. |
| `log.lua` | Модуль логирования (log). Реализует уровни TRACE/DEBUG/INFO/WARN/ERROR/FATAL. INFO и выше пишутся в файл Log/<Broker>/<дата>.log, все уровни выводятся в консоль QUIK. |

---

## Глобальные переменные

### Состояние главного цикла (`StartEngine.lua`)

| Переменная | Описание |
|-----------|----------|
| `isRun` | Флаг работы главного цикла. Устанавливается в `false` при OnStop для завершения цикла. |
| `transId` | Текущий ID транзакции. Инкрементируется при каждой новой отправке ордера. |
| `N_TransReplies` | Массив ответов транзакций от QUIK. Обрабатывается в главном цикле. |
| `N_LastTransID` | Последний обработанный ID транзакции. Используется для фильтрации новых ответов. |
| `N_Orders` | Массив текущих ордеров. Обновляется из QUIK при событиях OnOrder. |
| `N_LastOrderNum` | Последний обработанный номер ордера. Используется для фильтрации новых ордеров. |
| `N_Trades` | Массив текущих сделок. Обновляется из QUIK при событиях OnTrade. |
| `N_LastTradeNum` | Последний обработанный номер сделки. Используется для фильтрации новых сделок. |

### Расписание сессий (`SubmittingOrders.lua`)

| Переменная | Описание |
|-----------|----------|
| `TimeMorningStart` | Время начала утренней сессии (UTC). Инициализируется из Config.SessionMorning. |
| `TimeMainStart` | Время начала основной сессии (UTC). Инициализируется из Config.SessionMain. |
| `TimeEveningStart` | Время начала вечерней сессии (UTC). Инициализируется из Config.SessionEvening. |
| `IsMorningTime` | Флаг: утренняя сессия уже началась. Сбрасывается при смене сессии. |
| `IsMainTime` | Флаг: основная сессия уже началась. Сбрасывается при смене сессии. |
| `IsEveningTime` | Флаг: вечерняя сессия уже началась. Сбрасывается при смене сессии. |
| `IsSentOrders` | Флаг: ордера уже отправлены в текущей сессии. Предотвращает повторную отправку. |
| `IsSendingOrders` | Флаг: отправка ордеров в процессе. Предотвращает параллельную обработку. |
| `sendOrders` | Таблица отправленных ордеров для логирования. |
| `sendOrdersSet` | Множество дедупликации отправленных ордеров (ключ: код+операция+кол-во+цена). |
| `unknownSecurities` | Таблица инструментов, не найденных в QUIK (код -> название). |
| `cycleCount` | Номер текущего цикла отправки ордеров. |

### Настройки брокера (`Setting.lua`)

| Переменная | Описание |
|-----------|----------|
| `Broker` | Краткое имя брокера (VTB, PSB, FINAM, RSHB, TEST). Используется в логах и именах файлов. |
| `ClientCode` | Код клиента у брокера. Передаётся в транзакциях как CLIENT_CODE. |
| `AccountCode` | Код торгового счёта. Передаётся в транзакциях как ACCOUNT. |
| `FirmId` | Идентификатор фирмы. Используется для получения информации о портфеле. |
| `VolumeOrderMax` | Максимальный объём ордера для акций (руб.). Для VTB = 20000. |
| `BondVolumeOrderMax` | Максимальный объём ордера для облигаций (руб.). Для VTB = 20000. |
| `VolumeOrderLimit` | Абсолютный лимит объёма ордера (руб.). Если задан — перекрывает VolumeOrderMax. |
| `LimitActuationOrderEdge` | Порог срабатывания для акций (%). Если 0 — проверка отключена. |
| `LimitActuationOrderBondEdge` | Порог срабатывания для облигаций (%). |
| `FileBuyOrder` | Имя CSV-файла с ордерами на покупку (формат: <Broker>_BuyOrders.csv). |
| `FileSellOrder` | Имя CSV-файла с ордерами на продажу (формат: <Broker>_SellOrders.csv). |
| `FileBuyOrderEdge` | Имя CSV-файла с edge-ордерами на покупку. |
| `FileBuyOrderBondsEdge` | Имя CSV-файла с edge-ордерами на покупку облигаций. |
| `FileSellOrderEdge` | Имя CSV-файла с edge-ордерами на продажу. |
| `BrokerRegistry` | Таблица соответствия USERID -> функция настройки брокера. |

### Константы (`Constants.lua`)

| Переменная | Описание |
|-----------|----------|
| `FLAG_ACTIVE` | Флаг QUIK: активный ордер (0x1). |
| `FLAG_EXECUTED` | Флаг QUIK: исполненный ордер (0x2). |
| `FLAG_SELL` | Флаг QUIK: ордер на продажу (0x4). |
| `ERR_PRICE_TOO_LOW` | Код ошибки QUIK: цена слишком низкая (579). |
| `ERR_PRICE_TOO_HIGH` | Код ошибки QUIK: цена слишком высокая (580). |
| `ERR_EXECUTION_REJECTED` | Код ошибки QUIK: исполнение отклонено (133). |
| `TRANS_STATUS_COMPLETED` | Статус транзакции: выполнена (3). |
| `PRICE_DEVIATION_MULTIPLIER` | Множитель отклонения цены от LAST при корректировке (10 шагов цены). |

### Интерфейсные таблицы (`TableOrders.lua`, `TableSetting.lua`)

| Переменная | Описание |
|-----------|----------|
| `tableOrdersControl` | Экземпляр QTable с таблицей активных ордеров. |
| `tableSetting` | Экземпляр QTable с таблицей настроек. |
| `nameColumnSecurityName` | Заголовок колонки: наименование ценной бумаги. |
| `nameColumnSecurityCode` | Заголовок колонки: код бумаги (тикер). |
| `nameColumnOperation` | Заголовок колонки: операция (B/S). |
| `nameColumnPriceLast` | Заголовок колонки: последняя цена. |
| `nameColumnOrderPrice` | Заголовок колонки: цена ордера. |
| `nameColumnQuantity` | Заголовок колонки: количество. |
| `nameColumnVolume` | Заголовок колонки: объём в валюте инструмента. |
| `nameColumnActuation` | Заголовок колонки: актуализация (%). |
| `nameColumnLastChange` | Заголовок колонки: % изменения от предыдущей. |
| `nameColumnOrderNum` | Заголовок колонки: номер ордера в QUIK. |

### Прочие глобальные переменные

| Переменная | Описание |
|-----------|----------|
| `json` | Модуль JSON-сериализации (json.lua). Используется для логирования. |
| `Broker` | То же что Config.Broker — краткое имя брокера. Устанавливается в SetClientSetting(). |
| `AccountCode` | То же что Config.AccountCode — код счёта. Устанавливается в SetClientSetting(). |
| `ClientCode` | То же что Config.ClientCode — код клиента. Устанавливается в SetClientSetting(). |
| `FirmId` | То же что Config.FirmId — идентификатор фирмы. Устанавливается в SetClientSetting(). |
| `FLAG_ACTIVE` | То же что Constants.FLAG_ACTIVE. Устанавливается в _initConstants(). |
| `FLAG_EXECUTED` | То же что Constants.FLAG_EXECUTED. Устанавливается в _initConstants(). |
| `FLAG_SELL` | То же что Constants.FLAG_SELL. Устанавливается в _initConstants(). |
| `ERR_PRICE_TOO_LOW` | То же что Constants.ERR_PRICE_TOO_LOW. Устанавливается в _initConstants(). |
| `ERR_PRICE_TOO_HIGH` | То же что Constants.ERR_PRICE_TOO_HIGH. Устанавливается в _initConstants(). |
| `ERR_EXECUTION_REJECTED` | То же что Constants.ERR_EXECUTION_REJECTED. Устанавливается в _initConstants(). |
| `TRANS_STATUS_COMPLETED` | То же что Constants.TRANS_STATUS_COMPLETED. Устанавливается в _initConstants(). |

---

## Функции по модулям

### StartEngine.lua — Точка входа

| Функция | Описание |
|---------|----------|
| `main()` | Главный цикл скрипта. Вызывает N_OnMainLoop(), очищает кеш позиций, обрабатывает ответы транзакций, ордера и сделки. Работает пока isRun = true. |
| `OnTransReply(trans_reply)` | Callback QUIK. Вызывается при ответе на транзакцию. Обновляет N_TransReplies. |
| `OnOrder(order)` | Callback QUIK. Вызывается при создании/обновлении ордера. Обновляет N_Orders. |
| `OnTrade(trade)` | Callback QUIK. Вызывается при исполнении сделки. Обновляет N_Trades. |
| `OnInit()` | Callback QUIK. Вызывается при инициализации скрипта. Передаёт управление в N_OnInit(). |
| `OnStop()` | Callback QUIK. Вызывается при остановке скрипта. Устанавливает isRun = false, вызывает N_OnStop(). |
| `OnClose()` | Callback QUIK. Вызывается при закрытии скрипта. Передаёт управление в N_OnClose(). |

### Assistant.lua — Основная логика

| Функция | Описание |
|---------|----------|
| `N_OnInit()` | Инициализация ассистента. Проверяет подключение к брокеру, очищает кеш, инициализирует настройки и таблицы. |
| `N_OnMainLoop()` | Основной цикл. Проверяет подключение, вызывает SubmittingOrders(), обновляет таблицы настроек и ордеров. |
| `N_OnStop()` | Остановка. Удаляет таблицы интерфейса, логирует завершение. |
| `N_OnClose()` | Закрытие. Логирует закрытие ассистента. |
| `N_OnTransSendError(trans)` | Обработка ошибки отправки транзакции. Помечает ордер с ошибкой, логирует детали. |
| `N_OnTransExecutionError(trans)` | Обработка ошибки исполнения транзакции. Помечает ордер, логирует код ошибки, цену, количество. |
| `N_OnTransOK(trans)` | Обработка успешной транзакции. Логирует подтверждение. |
| `N_OnNewOrder(order)` | Обработка нового ордера. Логирует номер, транзакцию, бумагу, цену, количество. |
| `N_OnExecutionOrder(order)` | Обработка частичного исполнения ордера. Логирует количество исполненного. |
| `N_OnNewTrade(trade)` | Обработка новой сделки. Сохраняет сделку в файл, закрывает позицию, логирует цену и количество. |
| `N_SetLimitOrder(accountCode, clientCode, classCode, securityCode, operation, price, quantity)` | Отправка лимитного ордера в QUIK. Формирует транзакцию, отправляет через BrokerAdapter, обрабатывает ошибки. Возвращает (transId, error). |
| `N_CloseAllOrder()` | Закрытие всех активных ордеров. Ищет активные ордера, отправляет KILL_ORDER для каждого. Очищает таблицу ордеров. |

### Config.lua — Конфигурация

| Поле | Описание |
|------|----------|
| `Config.Broker` | Краткое имя брокера (VTB, PSB, FINAM, RSHB, TEST). |
| `Config.ClientCode` | Код клиента у брокера. |
| `Config.AccountCode` | Код торгового счёта. |
| `Config.FirmId` | Идентификатор фирмы. |
| `Config.VolumeOrderMax` | Максимальный объём ордера для акций (руб.). |
| `Config.BondVolumeOrderMax` | Максимальный объём ордера для облигаций (руб.). |
| `Config.VolumeOrderLimit` | Абсолютный лимит объёма ордера (руб.). |
| `Config.LimitActuationOrderEdge` | Порог срабатывания для акций (%). |
| `Config.LimitActuationOrderBondEdge` | Порог срабатывания для облигаций (%). |
| `Config.FileBuyOrder` | Имя CSV-файла ордеров на покупку. |
| `Config.FileSellOrder` | Имя CSV-файла ордеров на продажу. |
| `Config.FileBuyOrderEdge` | Имя CSV-файла edge-ордеров на покупку. |
| `Config.FileBuyOrderBondsEdge` | Имя CSV-файла edge-ордеров на покупку облигаций. |
| `Config.FileSellOrderEdge` | Имя CSV-файла edge-ордеров на продажу. |
| `Config.SessionMorning` | Время начала утренней сессии {hour, min, sec} UTC. |
| `Config.SessionMain` | Время начала основной сессии {hour, min, sec} UTC. |
| `Config.SessionEvening` | Время начала вечерней сессии {hour, min, sec} UTC. |

### Constants.lua — Константы

| Поле | Описание |
|------|----------|
| `Constants.FLAG_ACTIVE` | Флаг QUIK: активный ордер (0x1). |
| `Constants.FLAG_EXECUTED` | Флаг QUIK: исполненный ордер (0x2). |
| `Constants.FLAG_SELL` | Флаг QUIK: ордер на продажу (0x4). |
| `Constants.ERR_PRICE_TOO_LOW` | Код ошибки: цена слишком низкая (579). |
| `Constants.ERR_PRICE_TOO_HIGH` | Код ошибки: цена слишком высокая (580). |
| `Constants.ERR_EXECUTION_REJECTED` | Код ошибки: исполнение отклонено (133). |
| `Constants.TRANS_STATUS_COMPLETED` | Статус транзакции: выполнена (3). |
| `Constants.PRICE_DEVIATION_MULTIPLIER` | Множитель отклонения цены от LAST (10 шагов цены). |

### Setting.lua — Настройки брокеров

| Функция | Описание |
|---------|----------|
| `SetSettingFinam()` | Устанавливает параметры для брокера FINAM: код клиента, счёт, фирма, лимиты. |
| `SetSettingVTB()` | Устанавливает параметры для брокера VTB: код клиента, счёт, фирма, лимиты. |
| `SetSettingPSB()` | Устанавливает параметры для брокера PSB: код клиента, счёт, фирма, лимиты. |
| `SetSettingRSHB()` | Устанавливает параметры для брокера RSHB: код клиента, счёт, фирма, лимиты. |
| `SetSettingTest()` | Устанавливает параметры для тестового брокера: код клиента, счёт, лимиты. |
| `_initSettingGlobals()` | Копирует значения Config.* в глобальные переменные (Broker, ClientCode и др.) для обратной совместимости. |
| `_initConstants()` | Копирует значения Constants.* в глобальные переменные (FLAG_ACTIVE и др.) для обратной совместимости. |
| `SetClientSetting()` | Автоматически определяет брокера по USERID, вызывает соответствующую функцию настройки, формирует имена файлов CSV, копирует настройки в глобалы. |

### Order.lua — Торговый ордер

| Функция | Описание |
|---------|----------|
| `Order:new(securityCode)` | Конструктор ордера. Получает информацию об инструменте из QUIK, инициализирует поля (SecurityCode, Operation, Quantity, Price). Возвращает nil если инструмент не найден. |
| `Order:IsBuy()` | Возвращает true если операция = "B" (покупка). |
| `Order:IsSell()` | Возвращает true если операция = "S" (продажа). |
| `Order:IsBond()` | Возвращает true если инструмент — облигация (по коду класса). |
| `Order:IsOFZ()` | Возвращает true если инструмент — ОФЗ (класс TQOB). |
| `Order:IsEtf()` | Возвращает true если инструмент — ETF (класс TQTF). |
| `Order:IsExceptionFromLimitActuation()` | Возвращает true если тикер в списке исключений проверки срабатывания. |
| `Order:SetOperation(operation, price, quantity)` | Устанавливает операцию, цену и количество. Округляет цену. |
| `Order:SetPriceMin(operation)` | Устанавливает минимальную цену для покупки (1 лот по min_price_step) или нулевую для продажи. |
| `Order:SetQuantity(operation, price, quantityMax)` | Рассчитывает количество лотов исходя из цены и максимального объёма. Для облигаций учитывает номинал. |
| `Order:SetQuantitySell(operation, price, positionQty)` | Рассчитывает количество для продажи по текущей позиции. |
| `Order:Clear()` | Обнуляет операцию, количество и цену. |
| `Order:GetPriceRound()` | Округляет цену до шага цены: ceil для покупки, floor для продажи. |
| `Order:GetPriceInCurrency(price)` | Конвертирует цену облигации из процентов в рубли (умножает на номинал/100). |
| `Order:GetVolume()` | Рассчитывает объём ордера в валюте (количество * цена * лот). |
| `Order:FormatPrice()` | Форматирует цену в строку с нужным количеством знаков после запятой (по scale). |
| `Order:FormatQuantity(n)` | Форматирует количество в строку с n знаками после запятой (по умолчанию 0). |
| `Order:GetDedupKey()` | Возвращает ключ дедупликации: "код операция количество цена". |
| `Order:Print()` | Возвращает строковое представление ордера для логирования. |
| `ClearSecurityInfoCache()` | Очищает кеш информации об инструментах (делегирует в BrokerAdapter). |
| `GetSecurityInfo(securityCode)` | Получает информацию об инструменте по коду (делегирует в BrokerAdapter). |

### BrokerAdapter.lua — Адаптер QUIK API

| Функция | Описание |
|---------|----------|
| `BrokerAdapter.GetSecurityInfo(securityCode)` | Получает информацию об инструменте. Ищет по списку классов (TQCB, TQBR, SPBXM и др.). Кеширует результат. |
| `BrokerAdapter.ClearSecurityInfoCache()` | Очищает кеш информации об инструментах. |
| `BrokerAdapter.GetParamEx(classCode, secCode, param)` | Получает параметр инструмента (LAST, PRICEMIN, PRICEMAX и др.). Возвращает значение или nil. |
| `BrokerAdapter.GetParamInfo(order, param)` | Получает параметр инструмента из объекта Order. Логирует ошибку если параметр не найден. Возвращает "0" по умолчанию. |
| `BrokerAdapter.GetNumberOfOrders()` | Возвращает количество ордеров в QUIK. |
| `BrokerAdapter.SearchOrders(filterFunc, params)` | Ищет ордера по фильтру. Возвращает массив индексов. |
| `BrokerAdapter.GetOrder(index)` | Получает ордер по индексу из QUIK. |
| `BrokerAdapter.GetNumberOfPositions()` | Возвращает количество депо-лимитов в QUIK. |
| `BrokerAdapter.SearchPositions(filterFunc, params)` | Ищет позиции по фильтру. Возвращает массив индексов. |
| `BrokerAdapter.GetPosition(index)` | Получает позицию по индексу из QUIK. |
| `BrokerAdapter.SendTransaction(transaction)` | Отправляет транзакцию в QUIK. Возвращает пустую строку при успехе или текст ошибки. |
| `BrokerAdapter.IsConnected()` | Возвращает true если QUIK подключён к серверу. |
| `BrokerAdapter.GetInfoParam(param)` | Получает информационный параметр QUIK (USERID, SERVERTIME и др.). |
| `BrokerAdapter.GetPortfolioInfo(firmId, clientCode)` | Получает информацию о портфеле (активы, прибыль/убыток). |
| `BrokerAdapter.GetScriptPath()` | Возвращает путь к скрипту QUIK. |

### MarketData.lua — Рыночные данные

| Функция | Описание |
|---------|----------|
| `MarketData.GetParamInfo(order, param)` | Получает параметр инструмента (делегирует в BrokerAdapter.GetParamInfo). |
| `MarketData.GetPriceLast(order)` | Получает последнюю цену. Если LAST = 0, возвращает PREVPRICE. |
| `MarketData.GetPriceMin(order)` | Получает минимальную цену (PRICEMIN) — нижнюю границу стакана. |
| `MarketData.GetPriceMax(order)` | Получает максимальную цену (PRICEMAX) — верхнюю границу стакана. |
| `MarketData.GetPricePrev(order)` | Получает предыдущую закрытия (PREVPRICE). |
| `GetParamInfo(order, param)` | Глобальная обёртка для MarketData.GetParamInfo (обратная совместимость). |
| `GetPriceLast(order)` | Глобальная обёртка для MarketData.GetPriceLast. |
| `GetPriceMin(order)` | Глобальная обёртка для MarketData.GetPriceMin. |
| `GetPriceMax(order)` | Глобальная обёртка для MarketData.GetPriceMax. |
| `GetPricePrev(order)` | Глобальная обёртка для MarketData.GetPricePrev. |

### PositionService.lua — Сервис позиций

| Функция | Описание |
|---------|----------|
| `PositionService.ClearCache()` | Очищает кеш позиций. |
| `PositionService.FindPosition(limit_kind, currentbal)` | Фильтр позиций: только depo_limits с limit_kind=2 и ненулевым балансом. |
| `PositionService.GetPosition(securityCode)` | Получает позицию по коду инструмента. Ищет в кеше, затем в QUIK. |
| `FindPosition(limit_kind, currentbal)` | Глобальная обёртка для PositionService.FindPosition. |
| `ClearPositionCache()` | Глобальная обёртка для PositionService.ClearCache. |
| `GetPosition(securityCode)` | Глобальная обёртка для PositionService.GetPosition. |

### OrderValidator.lua — Валидатор ордеров

| Функция | Описание |
|---------|----------|
| `OrderValidator.GetKoeffVolumeOrderMax(order, priceMin)` | Рассчитывает коэффициент максимального объёма на основе разницы LAST и PRICEMIN. |
| `OrderValidator.GetOrderVolumeMax(order, priceMin)` | Рассчитывает максимальный объём ордера с учётом коэффициента и лимитов. |
| `OrderValidator.CheckOrder(order)` | Цепочка проверок ордера: обязательные поля, цена, позиция, объём, срабатывание, облигация, средняя цена. |
| `OrderValidator.ClearVolumeWarnedTickers()` | Очищает список тикеров с предупреждением об объёме. |
| `GetKoeffVolumeOrderMax(order, priceMin)` | Глобальная обёртка для OrderValidator.GetKoeffVolumeOrderMax. |
| `GetOrderVolumeMax(order, priceMin)` | Глобальная обёртка для OrderValidator.GetOrderVolumeMax. |
| `ClearVolumeWarnedTickers()` | Глобальная обёртка для OrderValidator.ClearVolumeWarnedTickers. |
| `CheckOrder(order)` | Глобальная обёртка для OrderValidator.CheckOrder. |

### PriceAdjuster.lua — Корректировщик цен

| Функция | Описание |
|---------|----------|
| `PriceAdjuster.AdjustPrice(order)` | Корректирует цену ордера. Для покупки: если LAST < цена, снижает на 10 шагов; если цена < PRICEMIN, ставит PRICEMIN. Для продажи: если LAST > цена, повышает на 10 шагов. Не трогает цены из файла. |
| `AdjustPrice(order)` | Глобальная обёртка для PriceAdjuster.AdjustPrice. |

### TransactionHandler.lua — Обработчик транзакций

| Функция | Описание |
|---------|----------|
| `TransactionHandler.GetOperation(flags)` | Определяет операцию по флагам: "S" если FLAG_SELL установлен, иначе "B". |
| `TransactionHandler.IsOrderExecuted(flags)` | Проверяет исполнен ли ордер: не активен и не в статусе исполнения. |
| `TransactionHandler.FindOrder(flags, sec_code, class_code)` | Фильтр для поиска ордеров: активные или исполненные. |
| `TransactionHandler.GetQuikOrders()` | Получает все активные ордера из QUIK и передаёт в N_Orders через OnOrder. |
| `TransactionHandler.IsOrderExists(newOrder)` | Проверяет существует ли уже такой ордер в QUIK (по коду, операции, цене, флагам). |
| `TransactionHandler.SetLimitOrdersWithError(trans)` | Обрабатывает ошибки транзакций: 579 (цена низкая), 580 (цена высокая) с автовосстановлением, 133 (отклонено). |
| `GetOperation(flags)` | Глобальная обёртка для TransactionHandler.GetOperation. |
| `IsOrderExecuted(flags)` | Глобальная обёртка для TransactionHandler.IsOrderExecuted. |
| `FindOrder(flags, sec_code, class_code)` | Глобальная обёртка для TransactionHandler.FindOrder. |
| `GetQuikOrders()` | Глобальная обёртка для TransactionHandler.GetQuikOrders. |
| `IsOrderExists(newOrder)` | Глобальная обёртка для TransactionHandler.IsOrderExists. |
| `SetLimitOrdersWithError(trans)` | Глобальная обёртка для TransactionHandler.SetLimitOrdersWithError. |

### SubmittingOrders.lua — Отправка ордеров

| Функция | Описание |
|---------|----------|
| `Initialization()` | Инициализация: устанавливает настройки клиента, рассчитывает времена сессий, сбрасывает флаги. |
| `SubmittingOrders()` | Основной цикл: определяет текущую сессию, закрывает ордера при смене сессии, запускает SubmittingOrdersRun. |
| `SubmittingOrdersRun()` | Загружает ордера из всех CSV-файлов, отправляет в QUIK, логирует статистику. Обрабатывает ошибки через pcall. |
| `LoadOrdersFromFile(fileName)` | Загружает ордера из CSV-файла. Для каждого инструмента создаёт Order, устанавливает цену/количество в зависимости от типа файла (обычный, edge, sell edge). |
| `SubmitOrders(orders)` | Отправляет массив ордеров в QUIK. Для каждого: корректирует цену, проверяет дубликаты, валидирует, отправляет через N_SetLimitOrder. Возвращает статистику {sent, rejected, duplicate}. |
| `IsSendOrder(order)` | Проверяет отправлялся ли ордер уже в текущей сессии (по ключу дедупликации). |
| `TradeClosePosition(trade)` | При покупке: автоматически выставляет ордер на продажу (закрытие позиции) по текущей PRICEMAX. |

### FileFunction.lua — Чтение CSV

| Функция | Описание |
|---------|----------|
| `getFromCSV(nameFileCSV)` | Читает CSV-файл из папки Data, возвращает массив строк (каждая строка — массив значений). |

### TradeSave.lua — Сохранение сделок

| Функция | Описание |
|---------|----------|
| `TradeSave(trade)` | Записывает сделку в файл MyTrades.csv: дата, время, код, операция, количество, цена, брокер. |

### TableConstructor.lua — Конструктор таблиц

| Функция | Описание |
|---------|----------|
| `QTable.new()` | Создаёт новый экземпляр таблицы QUIK. Возвращает объект QTable или nil. |
| `QTable:Show()` | Показывает окно таблицы. |
| `QTable:IsClosed()` | Возвращает true если окно таблицы закрыто. |
| `QTable:Delete()` | Уничтожает таблицу. |
| `QTable:GetCaption()` | Возвращает заголовок окна. |
| `QTable:SetCaption(s)` | Устанавливает заголовок окна. |
| `QTable:AddColumn(name, c_type, width, ff)` | Добавляет колонку: имя, тип (STRING/DOUBLE/INT64), ширина, опциональная функция форматирования. |
| `QTable:Clear()` | Очищает все строки таблицы. |
| `QTable:SetValue(row, col_name, data)` | Устанавливает значение ячейки по номеру строки и имени колонки. |
| `QTable:AddLine()` | Добавляет новую строку в конец таблицы. Возвращает номер строки. |
| `QTable:GetSize()` | Возвращает (количество_строк, количество_колонок). |
| `QTable:GetValue(row, name)` | Получает значение ячейки. Возвращает таблицу {image=значение}. |
| `QTable:SetPosition(x, y, dx, dy)` | Устанавливает позицию и размер окна таблицы. |
| `QTable:GetPosition()` | Возвращает (top, left, width, height) окна таблицы. |
| `QTable:Red(row, col)` | Окрашивает ячейку в красный. |
| `QTable:Yellow(row, col)` | Окрашивает ячейку в жёлтый. |
| `QTable:Green(row, col)` | Окрашивает ячейку в зелёный. |
| `QTable:Default(row, col)` | Сбрасывает цвет ячейки на стандартный. |
| `comma_value(amount)` | Форматирует число с разделителем тысяч (пробел). |
| `round(val, decimal)` | Округляет число до decimal знаков. Делегирует в math.round. |
| `format_num(amount, decimal, prefix, neg_prefix)` | Форматирует число: разделитель тысяч, десятичная часть, префикс, знак для отрицательных. |

### TableOrders.lua — Таблица ордеров

| Функция | Описание |
|---------|----------|
| `CreateTableOrdersControl(t)` | Создаёт колонки таблицы ордеров (название, код, операция, актуализация, цена, объём и т.д.). |
| `ShowTableOrdersControl(t)` | Показывает таблицу ордеров и устанавливает позицию на экране. |
| `RefreshTableOrdersControl()` | Обновляет таблицу: создаёт при первом вызове, восстанавливает если закрыта, заполняет данными из QUIK. |
| `FindRow(t, orderNum)` | Ищет строку в таблице по номеру ордера. |
| `UpdateTableOrdersControl(t, order)` | Обновляет/добавляет строку для ордера: название, код, операция, актуализация, цены, цветовая индикация. |
| `GetOrderOperation(order)` | Возвращает операцию ордера ("B"/"S") по флагам. |
| `ClearTableOrdersControl()` | Очищает таблицу ордеров. |
| `GetPriceCurrent(classCode, secCode)` | Получает текущую цену: LAST или PREVPRICE если LAST = 0. |

### TableSetting.lua — Таблица настроек

| Функция | Описание |
|---------|----------|
| `CreateTableSetting(t)` | Создаёт колонки таблицы настроек (parameter, value, description). |
| `ShowTableSetting(t)` | Показывает таблицу настроек и устанавливает позицию. |
| `UpdateTableSetting()` | Обновляет таблицу: создаёт при первом вызове, восстанавливает если закрыта. |
| `SetDataToTableSetting(t)` | Заполняет таблицу начальными данными: время сервера, аккаунт, файлы ордеров. |
| `RefreshDataToTableSetting(t)` | Обновляет динамические данные: время сервера, портфель. |
| `FindSetting(t, setting)` | Ищет строку в таблице по имени параметра. |
| `SetServerTime(t)` | Устанавливает время сервера QUIK в таблице. |
| `SetAccountSetting(t)` | Устанавливает настройки брокера в таблице: имя, код клиента, код счёта, лимит. |
| `SetPortfolioInfo(t)` | Устанавливает информацию о портфеле: активы, прибыль/убыток, % изменения, индекс MOEX. |
| `SetFileOrders(t)` | Устанавливает имена CSV-файлов ордеров в таблице. |
| `GetSettingValue(t, param)` | Получает значение параметра из таблицы по имени. |
| `EventCallbackTableSetting(t_id, msg, par1, par2)` | Обработчик событий таблицы: двойной клик по файлу — открывает в Notepad. |

### log.lua — Логирование

| Функция | Описание |
|---------|----------|
| `log.trace(...)` | Логирование уровня TRACE (самый подробный). Только в консоль. |
| `log.debug(...)` | Логирование уровня DEBUG. Только в консоль. |
| `log.info(...)` | Логирование уровня INFO. В консоль и в файл Log/<Broker>/<дата>.log. |
| `log.warn(...)` | Логирование уровня WARN. В консоль и в файл. |
| `log.error(...)` | Логирование уровня ERROR. В консоль и в файл. |
| `log.fatal(...)` | Логирование уровня FATAL. В консоль и в файл. |
| `log.close()` | Закрывает файл лога. |

---

## Архитектура

```
StartEngine.lua (точка входа)
  ├── Assistant.lua (callback-функции, N_SetLimitOrder)
  │   ├── SubmittingOrders.lua (расписание, CSV, отправка)
  │   │   ├── Setting.lua (настройки брокеров)
  │   │   │   ├── Constants.lua (константы QUIK)
  │   │   │   ├── BrokerAdapter.lua (QUIK API)
  │   │   │   ├── Config.lua (конфигурация)
  │   │   │   └── TableSetting.lua (таблица настроек)
  │   │   ├── FileFunction.lua (чтение CSV)
  │   │   ├── Order.lua (модуль ордера)
  │   │   │   ├── MarketData.lua (рыночные данные)
  │   │   │   ├── PositionService.lua (позиции)
  │   │   │   ├── OrderValidator.lua (валидация)
  │   │   │   │   └── PriceAdjuster.lua (корректировка цен)
  │   │   │   └── TransactionHandler.lua (транзакции)
  │   │   └── TableOrders.lua (таблица ордеров)
  │   ├── TableConstructor.lua (QTable)
  │   └── TradeSave.lua (сохранение сделок)
  └── log.lua (логирование)
```

### Поток отправки ордера

1. `N_OnMainLoop()` → `SubmittingOrders()`
2. `SubmittingOrders()` определяет текущую сессию по времени
3. `SubmittingOrdersRun()` загружает ордера из CSV через `LoadOrdersFromFile()`
4. `SubmitOrders()` для каждого ордера:
   - `AdjustPrice()` — корректировка цены (PriceAdjuster)
   - `IsOrderExists()` — проверка дубликата в QUIK (TransactionHandler)
   - `IsSendOrder()` — проверка дубликата в сессии
   - `CheckOrder()` — цепочка валидации (OrderValidator)
   - `N_SetLimitOrder()` → `BrokerAdapter.SendTransaction()` → `sendTransaction()` QUIK
5. Ответ обрабатывается через `OnTransReply()` → `N_TransReplies`
6. Исполнение через `OnOrder()` → `N_Orders` → `N_OnNewOrder()`
7. Сделка через `OnTrade()` → `N_Trades` → `N_OnNewTrade()` → `TradeSave()` + `TradeClosePosition()`
