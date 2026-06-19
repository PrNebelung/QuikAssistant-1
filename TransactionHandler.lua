--- Обработчик транзакций и ордеров QUIK.
--- Определяет операцию по флагам, проверяет существование ордера,
--- получает список активных ордеров, обрабатывает ошибки транзакций
--- (579, 580, 133) с автоматическим восстановлением.


local BrokerAdapter = require("BrokerAdapter")

local TransactionHandler = {}

function TransactionHandler.GetOperation(flags)
  if (flags & FLAG_SELL) > 0 then
    return "S"
  else
    return "B"
  end
end

function TransactionHandler.IsOrderExecuted(flags)
  return (flags & FLAG_ACTIVE) == 0 and (flags & FLAG_EXECUTED) == 0
end

function TransactionHandler.FindOrder(flags, sec_code, class_code)
  if (flags & FLAG_ACTIVE) > 0 or TransactionHandler.IsOrderExecuted(flags) then
    return true
  else
    return false
  end
end

function TransactionHandler.GetQuikOrders()
  local orderIndices = BrokerAdapter.SearchOrders(TransactionHandler.FindOrder, "flags, sec_code, class_code")
  log.debug(string.format("Active orders: %d items.", #orderIndices))
  for i = 1, #orderIndices do
    local order = BrokerAdapter.GetOrder(orderIndices[i])
    if order then
      OnOrder(order)
    end
  end
end

function TransactionHandler.IsOrderExists(newOrder)
  local orderIndices = BrokerAdapter.SearchOrders(TransactionHandler.FindOrder, "flags, sec_code, class_code")
  for i = 1, #orderIndices do
    local order = BrokerAdapter.GetOrder(orderIndices[i])
    if order then
      local operation
      if (order.flags & FLAG_SELL) > 0 then
        operation = "S"
      else
        operation = "B"
      end

      if
        order.sec_code == newOrder.SecurityCode
        and operation == newOrder.Operation
        and string.format("%." .. newOrder.SecurityInfo.scale .. "f", tonumber(order.price)) == string.format(
          "%." .. newOrder.SecurityInfo.scale .. "f",
          tonumber(newOrder.Price)
        )
        and ((order.flags & FLAG_ACTIVE) > 0 or TransactionHandler.IsOrderExecuted(order.flags))
      then
        return true
      end
    end
  end

  return false
end

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
    local maxPrice = string.match(trans.result_msg, "do %d+%.?%d*")
    if maxPrice == nil then
      maxPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "S"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error(
        "Cannot create order for auto-recover",
        trans.sec_code
      )
      return
    end
    order:SetOperation(operation, maxPrice, trans.quantity)
    log.info(
      "Auto-recover sell order at max price: "
        .. order:Print()
    )
    local orders = {}
    table.insert(orders, order)
    SubmitOrders(orders)
    return
  end

  local errorTest = string.find(
    trans.result_msg,
    "not compliant with min price for this security",
    1,
    true
  )
  if errorTest ~= nil then
    local minPrice = string.match(trans.result_msg, "ot %d+%.?%d*")
    if minPrice == nil then
      minPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "B"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error(
        "Cannot create order for auto-recover",
        trans.sec_code
      )
      return
    end
    order:SetOperation(operation, minPrice, 0)
    log.info("Auto-recover buy order at min price: " .. order:Print())
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

  log.error(string.format("Unknown transaction error. %s", trans.result_msg))
  log.error(json.encode(trans))
end

-- Global wrappers for backward compatibility
function GetOperation(flags)
  return TransactionHandler.GetOperation(flags)
end

function IsOrderExecuted(flags)
  return TransactionHandler.IsOrderExecuted(flags)
end

function FindOrder(flags, sec_code, class_code)
  return TransactionHandler.FindOrder(flags, sec_code, class_code)
end

function GetQuikOrders()
  TransactionHandler.GetQuikOrders()
end

function IsOrderExists(newOrder)
  return TransactionHandler.IsOrderExists(newOrder)
end

function SetLimitOrdersWithError(trans)
  TransactionHandler.SetLimitOrdersWithError(trans)
end

return TransactionHandler
