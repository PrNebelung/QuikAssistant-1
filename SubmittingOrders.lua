--- Оркестрация отправки ордеров в QUIK.
--- Координирует загрузку ордеров из CSV, валидацию и отправку в QUIK.
--- Управляет планированием сессий через SessionScheduler.

require("Setting")
require("FileFunction")
require("Order")
require("MarketData")
require("PositionService")
require("OrderValidator")
require("TransactionHandler")
require("TableOrders")
SessionScheduler = require("SessionScheduler")
OrderLoader = require("OrderLoader")
local Config = require("Config")

-- Состояние отправки
IsSendingOrders = false

-- Отправленные ордры (для дедупликации)
sendOrders = {}
sendOrdersSet = {}

-- Статистика
local cumStats = { loaded = 0, sent = 0, rejected = 0, duplicate = 0 }
local cycleCount = 0

-- Неизвестные ценные бумаги
unknownSecurities = {}

--- Инициализация ( делегируется SessionScheduler)
function Initialization()
  SetClientSetting()
  SessionScheduler.Initialization()
end

--- Проверка времени сессий и запуск отправки
function SubmittingOrders()
  if SessionScheduler.CheckSession() then
    SubmittingOrdersRun()
  end
end

--- Ожидание рыночных данных
local marketDataWaited = false
function WaitForMarketData()
  if marketDataWaited then
    return
  end
  marketDataWaited = true

  local sampleSecurities = {
    { classCode = "TQBR", secCode = "GAZP" },
    { classCode = "TQBR", secCode = "SBER" },
    { classCode = "TQOB", secCode = "SU26245RMFS9" },
  }
  local maxRetries = 30
  local retryInterval = 2

  for retry = 1, maxRetries do
    for _, sample in ipairs(sampleSecurities) do
      local value = getParamEx(sample.classCode, sample.secCode, "LAST")
      if value ~= nil and value.result == "1" and tonumber(value.param_value) > 0 then
        log.info(
          string.format("Рыночные данные получены (%s, попытка %d)", sample.secCode, retry)
        )
        return true
      end
    end
    if retry % 5 == 0 then
      log.info(
        string.format("Ожидание рыночных данных... (попытка %d/%d)", retry, maxRetries)
      )
    end
    sleep(retryInterval * 1000)
  end
  log.warn("Рыночные данные не получены, продолжаем")
  return false
end

--- Главный цикл отправки ордеров
function SubmittingOrdersRun()
  if IsSendingOrders then
    return
  end
  if not Config.BrokerEnabled then
    log.warn("Брокер отключен, пропуск отправки ордеров")
    return
  end

  local isSubmittingOrdersRun = true

  IsSendingOrders = true
  cycleCount = cycleCount + 1

  -- Ожидание рыночных данных в первом цикле
  if cycleCount == 1 then
    WaitForMarketData()
  end

  local function ensureSendingReset()
    IsSendingOrders = false
  end

  local ok, err = pcall(function()
    local stats = { loaded = 0, sent = 0, rejected = 0, duplicate = 0 }
    unknownSecurities = {}

    log.info(string.format("=== Цикл %d запущен ===", cycleCount))

    if isSubmittingOrdersRun then
      log.debug(
        string.format("2.1 Загрузка ордеров на покупку из файла %s", Config.FileBuyOrder)
      )
      local orders = OrderLoader.LoadOrdersFromFile(Config.FileBuyOrder)
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
          "2.2 Загрузка ордеров на покупку облигаций edge %s",
          Config.FileBuyOrderBondsEdge
        )
      )
      local orders = OrderLoader.LoadOrdersFromFile(Config.FileBuyOrderBondsEdge)
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(3000)
    end

    if isSubmittingOrdersRun then
      local orders = OrderLoader.LoadOrdersFromFile(Config.FileBuyOrderEdge)
      log.debug(
        string.format(
          "2.3 Загрузка ордеров на покупку по цене edge %s",
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
      string.format("2.7 Загрузка ордеров на продажу из файла %s", Config.FileSellOrder)
    )
    local orders = OrderLoader.LoadOrdersFromFile(Config.FileSellOrder)
    stats.loaded = stats.loaded + #orders
    local s = SubmitOrders(orders)
    stats.sent = stats.sent + s.sent
    stats.rejected = stats.rejected + s.rejected
    stats.duplicate = stats.duplicate + s.duplicate

    if isSubmittingOrdersRun then
      log.debug(
        string.format(
          "2.8 Загрузка ордеров на продажу по цене edge %s",
          Config.FileSellOrderEdge
        )
      )
      local orders = OrderLoader.LoadOrdersFromFile(Config.FileSellOrderEdge)
      stats.loaded = stats.loaded + #orders
      local s = SubmitOrders(orders)
      stats.sent = stats.sent + s.sent
      stats.rejected = stats.rejected + s.rejected
      stats.duplicate = stats.duplicate + s.duplicate
      sleep(1000)
    end

    -- Обновление кумулятивной статистики
    cumStats.loaded = cumStats.loaded + stats.loaded
    cumStats.sent = cumStats.sent + stats.sent
    cumStats.rejected = cumStats.rejected + stats.rejected
    cumStats.duplicate = cumStats.duplicate + stats.duplicate

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
          "=== Обнаружено %d бумаг, не найденных в QUIK (пропущены):",
          unknownCount
        )
      )
      for code, name in pairs(unknownSecurities) do
        log.warn(string.format("  %s (%s)", code, name))
      end
      log.warn("=== Конец списка пропущенных =====")
    end
  end)

  ensureSendingReset()

  if not ok then
    log.error("Ошибка в цикле отправки: " .. tostring(err))
  end

  -- Итоговая статистика
  log.info(
    string.format(
      "=== Total after %d cycles: loaded=%d, sent=%d, rejected=%d, duplicate=%d ===",
      cycleCount,
      cumStats.loaded,
      cumStats.sent,
      cumStats.rejected,
      cumStats.duplicate
    )
  )

  SessionScheduler.MarkSent()

  for k in pairs(sendOrders) do
    sendOrders[k] = nil
  end
  sendOrdersSet = {}
end

--- Проверка, был ли ордер уже отправлен
function IsSendOrder(order)
  return sendOrdersSet[order:GetDedupKey()] == true
end

--- Отправка ордеров в QUIK
function SubmitOrders(orders, resubmit)
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
        local clientAccountCode = Config.AccountCode

        local trans_id, error = N_SetLimitOrder(
          clientAccountCode,
          Config.ClientCode,
          order.SecurityInfo.class_code,
          order.SecurityInfo.code,
          order.Operation,
          order:FormatPrice(),
          order:FormatQuantity(),
          resubmit
        )
        if error ~= "" then
          stats.rejected = stats.rejected + 1
          log.error("Не удалось отправить ордер в QUIK: ", error, order:Print())
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
    log.debug(
      string.format(
        "  [SKIP] %d ордеров: уже в QUIK или отправлены в этом цикле",
        stats.duplicate
      )
    )
  end
  for reason, count in pairs(skipReasons) do
    local tickers = skipTickers[reason] or {}
    local tickerList = table.concat(tickers, ", ")
    log.warn(string.format("  [SKIP] %d ордеров: %s [%s]", count, reason, tickerList))
  end

  return stats
end

--- Закрытие позиции по сделке (обратная заявка)
function TradeClosePosition(trade)
  local isBuy = (trade.buy_sell == "B") or (trade.buy_sell == nil and (trade.flags & FLAG_SELL) == 0)
  if not isBuy then
    return
  end
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
      "Не удалось определить цену. Вх. Цен. Макс. для закрытия позиции. (PRICEMAX). "
        .. order:Print()
    )
    return
  end

  log.info("Создание ордера на продажу для закрытия позиции ", order:Print())

  order:SetOperation(operation, price, quantity)
  order.UseFileParams = true

  local clientAccountCode = Config.AccountCode

  local trans_id, err = N_SetLimitOrder(
    clientAccountCode,
    Config.ClientCode,
    order.SecurityInfo.class_code,
    order.SecurityInfo.code,
    order.Operation,
    order:FormatPrice(),
    order:FormatQuantity()
  )
  if err ~= "" then
    log.error("Ошибка отправки ордера: ", err, order:Print())
  else
    log.info(
      string.format(
        "  [SEND-REVERSE] %s %s %s qty=%s price=%s",
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
