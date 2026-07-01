--- Обработка транзакций и ошибок QUIK.
--- Проверяет статус ордеров, определяет направление операции,
--- обрабатывает коды ошибок транзакций
--- (579, 580, 133) и выполняет повторную отправку.

local BrokerAdapter = require("BrokerAdapter")

local TransactionHandler = {}

--- Определение операции по флагам: "S" если FLAG_SELL установлен, иначе "B".
function TransactionHandler.GetOperation(flags)
  if (flags & FLAG_SELL) > 0 then
    return "S"
  else
    return "B"
  end
end

--- Определение статуса ордера: не активен и не в процессе исполнения.
function TransactionHandler.IsOrderExecuted(flags)
  return (flags & FLAG_ACTIVE) == 0 and (flags & FLAG_EXECUTED) == 0
end

--- Функция для поиска ордеров: активные или исполненные.
function TransactionHandler.FindOrder(flags, sec_code, class_code)
  if (flags & FLAG_ACTIVE) > 0 or TransactionHandler.IsOrderExecuted(flags) then
    return true
  else
    return false
  end
end

--- Получение текущих ордеров из QUIK и добавление их в N_Orders через OnOrder.
function TransactionHandler.GetQuikOrders()
  local orderIndices = BrokerAdapter.SearchOrders(TransactionHandler.FindOrder, "flags, sec_code, class_code")
  log.debug(string.format("Получено ордеров: %d шт.", #orderIndices))
  for i = 1, #orderIndices do
    local order = BrokerAdapter.GetOrder(orderIndices[i])
    if order then
      OnOrder(order)
    end
  end
end

--- Проверка существования ордера в QUIK (по тикеру, операции, цене).
function TransactionHandler.IsOrderExists(newOrder)
  local orderIndices = BrokerAdapter.SearchOrders(TransactionHandler.FindOrder, "flags, sec_code, class_code")
  log.debug(
    string.format(
      "IsOrderExists: проверяем %s %s, найдено существующих в QUIK: %d",
      newOrder.SecurityCode,
      newOrder.Operation,
      #orderIndices
    )
  )
  for i = 1, #orderIndices do
    local order = BrokerAdapter.GetOrder(orderIndices[i])
    if order then
      local operation
      if (order.flags & FLAG_SELL) > 0 then
        operation = "S"
      else
        operation = "B"
      end

      local priceNew = string.format("%." .. newOrder.SecurityInfo.scale .. "f", tonumber(newOrder.Price))
      local priceOld = string.format("%." .. newOrder.SecurityInfo.scale .. "f", tonumber(order.price))

      if order.sec_code == newOrder.SecurityCode and operation == newOrder.Operation and priceOld == priceNew then
        log.debug(
          string.format(
            "IsOrderExists: найден дубликат ордер #%s %s %s цена=%s",
            order.order_num,
            order.sec_code,
            operation,
            priceOld
          )
        )
        return true
      end
    end
  end
  return false
end

--- Обработка кодов ошибок транзакции: 579 (цена слишком низкая), 580 (цена слишком высокая), 133 (отклонена).
function TransactionHandler.SetLimitOrdersWithError(trans)
  local error579 = string.find(trans.result_msg, ": (" .. ERR_PRICE_TOO_LOW .. ")", 1, true)
  if error579 ~= nil then
    log.warn(
      "Error (579) for "
        .. " (qty="
        .. tostring(trans.quantity)
        .. ", price="
        .. tostring(trans.price)
        .. "): "
        .. trans.result_msg
    )
    return
  end

  local error580 = string.find(trans.result_msg, ": (" .. ERR_PRICE_TOO_HIGH .. ")", 1, true)
  if error580 ~= nil then
    local maxPrice = tonumber(string.match(trans.result_msg, "do %d+%.?%d*"))
    if maxPrice == nil then
      maxPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "S"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error(
        "Не удалось создать ордер для повторной отправки",
        trans.sec_code
      )
      return
    end
    order:SetOperation(operation, maxPrice, trans.quantity)
    log.info(string.format("Повторная отправка ордера по макс. цене: %s", order:Print()))
    local orders = {}
    table.insert(orders, order)
    SubmitOrders(orders, false)
    return
  end

  local errorTest = string.find(trans.result_msg, "not compliant with min price for this security", 1, true)
  if errorTest ~= nil then
    local minPrice = tonumber(string.match(trans.result_msg, "ot %d+%.?%d*"))
    if minPrice == nil then
      minPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "B"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error(
        "Не удалось создать ордер для повторной отправки",
        trans.sec_code
      )
      return
    end
    order:SetOperation(operation, minPrice, 0)
    log.info(string.format("Повторная отправка ордера по мин. цене: %s", order:Print()))
    return
  end

  local error133 = string.find(trans.result_msg, ": (" .. ERR_EXECUTION_REJECTED .. ")", 1, true)
  if error133 ~= nil then
    log.warn(
      "Error (133) for "
        .. " (qty="
        .. tostring(trans.quantity)
        .. ", price="
        .. tostring(trans.price)
        .. "): "
        .. trans.result_msg
    )
    return
  end

  log.error(string.format("Неизвестный код ошибки транзакции. %s", trans.result_msg))
  log.error(json.encode(trans))
end

--- Глобальная обёртка для TransactionHandler.GetOperation.
function GetOperation(flags)
  return TransactionHandler.GetOperation(flags)
end

--- Глобальная обёртка для TransactionHandler.IsOrderExecuted.
function IsOrderExecuted(flags)
  return TransactionHandler.IsOrderExecuted(flags)
end

--- Глобальная обёртка для TransactionHandler.FindOrder.
function FindOrder(flags, sec_code, class_code)
  return TransactionHandler.FindOrder(flags, sec_code, class_code)
end

--- Глобальная обёртка для TransactionHandler.GetQuikOrders.
function GetQuikOrders()
  TransactionHandler.GetQuikOrders()
end

--- Глобальная обёртка для TransactionHandler.IsOrderExists.
function IsOrderExists(newOrder)
  return TransactionHandler.IsOrderExists(newOrder)
end

--- Глобальная обёртка для TransactionHandler.SetLimitOrdersWithError.
function SetLimitOrdersWithError(trans)
  TransactionHandler.SetLimitOrdersWithError(trans)
end

return TransactionHandler
