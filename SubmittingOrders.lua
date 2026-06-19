--- Основной модуль отправки ордеров.
--- Управляет расписанием сессий, загрузкой ордеров из CSV-файлов,
--- проверкой на дубликаты, валидацией и отправкой в QUIK.
--- Также обрабатывает закрытие позиций при сделках.


require("Setting")
require("FileFunction")
require("Order")
require("QuikFunction")
require("TableOrders")
local Config = require("Config")

--- Время начала утреннего цикла
TimeMainStart = nil

--- Время начала основного цикла
TimeMorningStart = nil

--- Время начала вечернего цикла
TimeEveningStart = nil

--- Флаг, что уже был запуск
IsSentOrders = false

--- Флаг, что уже идет отправка заявок
IsSendingOrders = false

--- Текущее время цикла
IsMorningTime = false

--- Текущее время утреннее
IsMainTime = false

--- Текущее время основное
IsEveningTime = false

-- Множество для дедупликации ордеров (отправки в QUIK)
-- Ключ: "SECURITY_CODE OPERATION", значение: true
sendOrders = {}
sendOrdersSet = {}

-- Счетчик циклов
local cycleCount = 0

-- Неизвестные бумаги, не найденные в QUIK
unknownSecurities = {}

--- Инициализация переменных модуля
function Initialization()
  SetClientSetting()

  TimeMainStart = os.date("!*t", os.time())
  TimeMainStart.hour = Config.SessionMain.hour
  TimeMainStart.min = Config.SessionMain.min
  TimeMainStart.sec = Config.SessionMain.sec

  TimeMorningStart = os.date("!*t", os.time())
  TimeMorningStart.hour = Config.SessionMorning.hour
  TimeMorningStart.min = Config.SessionMorning.min
  TimeMorningStart.sec = Config.SessionMorning.sec

  TimeEveningStart = os.date("!*t", os.time())
  TimeEveningStart.hour = Config.SessionEvening.hour
  TimeEveningStart.min = Config.SessionEvening.min
  TimeEveningStart.sec = Config.SessionEvening.sec

  IsSentOrders = false
  IsSendingOrders = false
  IsMorningTime = false
  IsMainTime = false
  IsEveningTime = false
end

--- Основной цикл проверки и отправки заявок.
function SubmittingOrders()
  local timeCurrent = os.time()

  if (os.time(TimeMorningStart) < timeCurrent) and not IsMorningTime then
    if IsSentOrders then
      N_CloseAllOrder()
    end
    IsMorningTime = true
    IsSentOrders = false
  end

  if (os.time(TimeMainStart) < timeCurrent) and not IsMainTime then
    if IsSentOrders then
      N_CloseAllOrder()
    end
    IsMainTime = true
    IsSentOrders = false
  end

  if (os.time(TimeEveningStart) < timeCurrent) and not IsEveningTime then
    if IsSentOrders then
      N_CloseAllOrder()
    end
    IsEveningTime = true
    IsSentOrders = false
  end

  if not IsSentOrders then
    if os.time(TimeMorningStart) < timeCurrent then
    log.debug("Время для отправки заявок.")
      SubmittingOrdersRun()
    end
  end
end

--- Выполнение одного цикла отправки.
function SubmittingOrdersRun()
  if IsSendingOrders then
    return
  end

  local isSubmittingOrdersRun = true

  IsSendingOrders = true
  cycleCount = cycleCount + 1

  local function ensureSendingReset()
    IsSendingOrders = false
  end

  local ok, err = pcall(function()
    local stats = { loaded = 0, sent = 0, rejected = 0, duplicate = 0 }
    unknownSecurities = {}

    log.info(string.format("=== Цикл %d старт ===", cycleCount))

    if isSubmittingOrdersRun then
      log.debug(
        string.format("2.1 Отправка заявок на покупку по файлу %s", Config.FileBuyOrder)
      )
      local orders = LoadOrdersFromFile(Config.FileBuyOrder)
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(3000)
    end

    if isSubmittingOrdersRun then
      log.debug(
        string.format(
          "2.2 Отправка заявок на покупку облигаций edge %s",
          Config.FileBuyOrderBondsEdge
        )
      )
      local orders = LoadOrdersFromFile(Config.FileBuyOrderBondsEdge)
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(3000)
    end

    if isSubmittingOrdersRun then
      local orders = LoadOrdersFromFile(Config.FileBuyOrderEdge)
      log.debug(
        string.format(
          "2.3 Отправка заявок на покупку по файлу edge %s",
          Config.FileBuyOrderEdge
        )
      )
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(1000)
    end

    log.debug(
      string.format("2.7 Отправка заявок на продажу по файлу %s", Config.FileSellOrder)
    )
    local orders = LoadOrdersFromFile(Config.FileSellOrder)
    stats.loaded = stats.loaded + #orders
    local s = SubmitOrders(orders)
    stats.sent = stats.sent + s.sent
    stats.rejected = stats.rejected + s.rejected
    stats.duplicate = stats.duplicate + s.duplicate

    if isSubmittingOrdersRun then
      log.debug(
        string.format(
          "2.8 Отправка заявок на продажу по файлу edge %s",
          Config.FileSellOrderEdge
        )
      )
      local orders = LoadOrdersFromFile(Config.FileSellOrderEdge)
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(1000)
    end

    log.info(
      string.format(
        "=== Цикл %d завершен: загружено=%d, отправлено=%d, отклонено=%d, дубликатов=%d ===",
        cycleCount,
        stats.loaded,
        stats.sent,
        stats.rejected,
        stats.duplicate
      )
    )

    local unknownCount = 0
    for _ in pairs(unknownSecurities) do
      unknownCount = unknownCount + 1
    end
    if unknownCount > 0 then
      log.warn(
        string.format(
          "=== Обнаружено %d бумаг, не найденных в QUIK (проверьте файлы):",
          unknownCount
        )
      )
      for code, name in pairs(unknownSecurities) do
        log.warn(string.format("  %s (%s)", code, name))
      end
      log.warn("=== Конец списка бумаг =====")
    end
  end)

  ensureSendingReset()

  if not ok then
    log.error("Ошибка в основном цикле: " .. tostring(err))
  end

  IsSentOrders = true

  for k in pairs(sendOrders) do
    sendOrders[k] = nil
  end
  sendOrdersSet = {}
end

--- Загрузка заявок из файла.
function LoadOrdersFromFile(fileName)
  local orders = {}
  local rows = getFromCSV(fileName)
  local isFileSellEdge = fileName:find("_SellOrders_Edge")
  local isEdge = fileName:find("_Edge") and not isFileSellEdge

  for i, row in ipairs(rows) do
    local securityName = row[1]
    local isComment = string.find(securityName, "--", 1, true)
    if isComment == nil then
      local operation = string.match(row[2], "^%s*(.-)%s*$")
      local securityCode = string.match(row[3], "^%s*(.-)%s*$")
      local quantity = tonumber(row[4])
      local price = tonumber(row[5])

      local isBuyFile = fileName:find("[Bb][Uu][Yy]") ~= nil
      local isSellFile = fileName:find("[Ss][Ee][Ll][Ll]") ~= nil
      if isBuyFile and operation ~= "B" then
        log.error(
          string.format(
            "[SKIP] Несоответствие операции в файле BUY: операция %s, нужна B [%s]",
            operation,
            securityCode
          )
        )
      elseif isSellFile and operation ~= "S" then
        log.error(
          string.format(
            "[SKIP] Несоответствие операции в файле SELL: операция %s, нужна S [%s]",
            operation,
            securityCode
          )
        )
      elseif not isBuyFile and not isSellFile then
        log.warn(
          string.format(
            "[SKIP] Файл %s не содержит BUY/SELL в имени, пропуск [%s]",
            fileName,
            securityCode
          )
        )
      elseif securityCode == nil or operation == nil then
        log.error("Некорректная строка в CSV:", json.encode(row))
      else
        local order = Order:new(securityCode)
        if order == nil then
          log.error("Не удалось создать ордер " .. json.encode(row))
          unknownSecurities[securityCode] = securityName
        else
          if isFileSellEdge ~= nil then
            local priceMax = GetPriceMax(order)
            if tonumber(priceMax) == nil or tonumber(priceMax) == 0 then
              log.warn(
                "Не удалось получить макс. цен. Ордер пропущен. (PRICEMAX). "
                  .. order:Print()
              )
            else
              local position = GetPosition(order.SecurityCode)
              local positionQty = 0
              if position ~= nil then
                positionQty = tonumber(position.currentbal)
              end
              if positionQty > 0 then
                order:SetQuantitySell(operation, priceMax, positionQty)
                order.UseFileParams = true
              else
                log.error(
                  string.format("[SKIP] Позиция не найдена или равна нулю [%s]", order.SecurityCode)
                )
              end
            end
          elseif isEdge ~= nil then
            local priceMin = GetPriceMin(order)
            if tonumber(priceMin) == nil or tonumber(priceMin) == 0 then
              log.warn(
                "Не удалось получить мин. цен. Поз. об. не обнаружен, пропуск. "
                  .. order:Print()
              )
            else
              local progressOrderVolumeMax = GetOrderVolumeMax(order, priceMin)
              order:SetQuantity(operation, priceMin, progressOrderVolumeMax)
            end
          else
            if quantity ~= nil and price ~= nil then
              order:SetOperation(operation, price, quantity)
              order.UseFileParams = true
            else
              log.error("Некорректная строка для продажи в CSV:", json.encode(row))
            end
          end
          if order.Quantity > 0 then
            table.insert(orders, order)
          end
        end
      end
    end
  end

  return orders
end

--- Отправка заявок в QUIK
--- @return table { sent = N, rejected = N, duplicate = N }
function SubmitOrders(orders)
  local stats = { sent = 0, rejected = 0, duplicate = 0 }
  local skipReasons = {}
  local skipTickers = {}

  for i, order in pairs(orders) do
    AdjustPrice(order)
    if IsOrderExists(order) then
      stats.duplicate = stats.duplicate + 1
    elseif IsSendOrder(order) then
      stats.duplicate = stats.duplicate + 1
    else
      local isCheck, rejectReason = CheckOrder(order)
      if not isCheck then
        stats.rejected = stats.rejected + 1
        local key = rejectReason or "unknown"
        skipReasons[key] = (skipReasons[key] or 0) + 1
        if not skipTickers[key] then
          skipTickers[key] = {}
        end
        table.insert(skipTickers[key], order.SecurityCode)
      else
        local clientAccountCode = AccountCode

        local trans_id, error = N_SetLimitOrder(
          clientAccountCode,
          ClientCode,
          order.SecurityInfo.class_code,
          order.SecurityInfo.code,
          order.Operation,
          order:FormatPrice(),
          order:FormatQuantity()
        )
        if error ~= "" then
          stats.rejected = stats.rejected + 1
          log.error("Не удалось отправить заявку в QUIK: ", error, order:Print())
        else
          stats.sent = stats.sent + 1
          log.info(
            string.format(
              "  [SEND] %s %s %s qty=%s price=%s",
              order.Operation,
              order.SecurityCode,
              order.SecurityInfo.class_code,
              order:FormatQuantity(),
              order:FormatPrice()
            )
          )
          local logOrder = {}
          logOrder.SecurityCode = order.SecurityInfo.code
          logOrder.Operation = order.Operation
          logOrder.Quantity = order:FormatQuantity()
          logOrder.Price = order:FormatPrice()
          table.insert(sendOrders, logOrder)
          sendOrdersSet[order:GetDedupKey()] = true
        end
      end
    end
  end

  if stats.duplicate > 0 then
    log.debug(string.format("  [SKIP] %d orders: already in QUIK or sent this session", stats.duplicate))
  end
  for reason, count in pairs(skipReasons) do
    local tickers = skipTickers[reason] or {}
    local tickerList = table.concat(tickers, ", ")
    log.warn(string.format("  [SKIP] %d orders: %s [%s]", count, reason, tickerList))
  end

  return stats
end

--- Проверяет, что ордер уже отправлен
function IsSendOrder(order)
  return sendOrdersSet[order:GetDedupKey()] == true
end

--- Закрытие позиции по сделке для закрытия
function TradeClosePosition(trade)
  if trade.buy_sell ~= "B" then return end
  local orders = {}
  local operation = "S"
  local securityCode = trade.sec_code
  local quantity = tonumber(trade.qty)
  local order = Order:new(securityCode)

  if order == nil then
    log.error("Не удалось создать ордер " .. json.encode(trade))
    return
  end

  local price = GetPriceMax(order)
  if tonumber(price) == nil or tonumber(price) == 0 then
    sleep(500)
    price = GetPriceMax(order)
  end
  if tonumber(price) == nil or tonumber(price) == 0 then
    log.warn(
      "Не удалось получить макс. возм. цен. для прод., пропущена. (PRICEMAX). "
        .. order:Print()
    )
    return
  end

  log.info(
    "Создаем заявку на продажу для закрытия позиции ",
    order:Print()
  )

  order:SetOperation(operation, price, quantity)
  order.UseFileParams = true
  table.insert(orders, order)

  SubmitOrders(orders)
end
