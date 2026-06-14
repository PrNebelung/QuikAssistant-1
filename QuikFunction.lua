function GetParamInfo(order, param)
  local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
  if value == nil or value.result == "0" then
    log.error(
      "Параметр не найден.",
      param,
      order.Print()
    )
    return "0"
  end
  return value.param_value
end

--- Получение последней цены
function GetPriceLast(order)
  local priceLast = GetParamInfo(order, "LAST")
  if tonumber(priceLast) == 0 then
    priceLast = GetPricePrev(order)
  end
  return priceLast
end

--- Получение минимальной цены
function GetPriceMin(order)
  local priceMin = GetParamInfo(order, "PRICEMIN")
  return priceMin
end

--- Получение максимальной цены
function GetPriceMax(order)
  local priceMax = GetParamInfo(order, "PRICEMAX")
  return priceMax
end

---Предыдущая цена
function GetPricePrev(order)
  local pricePrev = GetParamInfo(order, "PREVPRICE")
  return pricePrev
end

-- Коэффициент корректировки объёма ордера, если последняя не активирована или не исполнена
function GetKoeffVolumeOrderMax(order, priceMin)
  local priceLast = GetPriceLast(order)
  if tonumber(priceMin) == nil or tonumber(priceMin) == 0 or tonumber(priceLast) == nil then
    return 1
  end
  local koeff = (tonumber(priceLast) - tonumber(priceMin)) / tonumber(priceMin) * 10
  if koeff ~= nil and tonumber(koeff) > 1 then
    return koeff
  end
  return 1
end

-- Получение объёма ордера
--- Коэффициент корректировки объёма ордера зависит от цены исполнения.
--- Для инструментов BondVolumeOrderMax умножается на коэффициент.
--- Для инструментов в SPB - берём лимиты в долларах.
function GetOrderVolumeMax(order, priceMin)
  local koeff = GetKoeffVolumeOrderMax(order, priceMin)
  local limit = VolumeOrderMax

  if order:IsBond() then
    limit = BondVolumeOrderMax * tonumber(koeff)
  end

-- Ограничение по лимиту
  if limit > VolumeOrderLimit then
    limit = VolumeOrderLimit
  end

  return limit
end

function GetOperation(flags)
  if (flags & FLAG_SELL) > 0 then
    return "S"
  else
    return "B"
  end
end

--- Проверка, был ли ордер исполнен или отменён для инструмента
function IsOrderExecuted(flags)
  return (flags & FLAG_ACTIVE) == 0 and (flags & FLAG_EXECUTED) == 0
end

--Проверка активности ордера
function FindOrder(flags, sec_code, class_code)
  if (flags & FLAG_ACTIVE) > 0 or IsOrderExecuted(flags) then
    return true
  else
    return false
  end
end

--- Поиск в QUIK для получения всех активных инструментов для синхронизации позиций
function GetQuikOrders()
  local countOrders = getNumberOf("orders")

  log.debug(
    string.format(
      "?????????? ???????: %d ??.",
      countOrders
    )
  )
  local ok, orders = pcall(function()
    return SearchItems("orders", 0, countOrders - 1, FindOrder, "flags, sec_code, class_code")
  end)
  if ok and orders ~= nil then
    for i = 1, #orders do
      local ok2, order = pcall(function()
        return getItem("orders", orders[i])
      end)
      if ok2 and order then
        OnOrder(order)
      end
    end
  end
end

-- Проверяем существование ордеров в QUIK на инструменты, отправленные за этот интервал времени ордеров
function IsOrderExists(newOrder)
  local countOrders = getNumberOf("orders")

  local ok, orders = pcall(function()
    return SearchItems("orders", 0, countOrders - 1, FindOrder, "flags, sec_code, class_code")
  end)
  if ok and orders ~= nil then
    for i = 1, #orders do
      local ok2, order = pcall(function()
        return getItem("orders", orders[i])
      end)
      if ok2 and order then
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
          and ((order.flags & FLAG_ACTIVE) > 0 or IsOrderExecuted(order.flags))
        then
          return true
        end
      end
    end
  end

  return false
end

function FindPosition(limit_kind, currentbal)
  if limit_kind == 2 and tonumber(currentbal) ~= 0 then
    return true
  end
  return false
end

--- ==========================================
--- Кэш позиций: securityCode -> position
--- ==========================================
local positionCache = {}

--- Очистка кэша позиций (используется для синхронизации)
function ClearPositionCache()
  positionCache = {}
end

--- Получение позиции по тикеру из depo_limits.
function GetPosition(securityCode)
-- Проверка кэша
  if positionCache[securityCode] then
    return positionCache[securityCode]
  end

  local countPositions = getNumberOf("depo_limits")

  local ok, positions = pcall(function()
    return SearchItems("depo_limits", 0, countPositions - 1, FindPosition, "limit_kind, currentbal")
  end)
  if ok and positions ~= nil then
    for i = 1, #positions do
      local ok2, position = pcall(function()
        return getItem("depo_limits", positions[i])
      end)
      if ok2 and position and position.sec_code == securityCode then
        log.debug(
          "Найдена позиция. ",
          securityCode
        )
        log.trace(json.encode(position))
        positionCache[securityCode] = position
        return position
      end
    end
  end

  return nil
end

local volumeWarnedTickers = {}

function ClearVolumeWarnedTickers()
  volumeWarnedTickers = {}
end

--- Автоматическая корректировка цены и привязка к бирже
--- Коэффициент корректировки для цены исполнения ордера
--- Значение цены для ордера (если цена не задана автоматически)
function AdjustPrice(order)
  if order == nil or order.Price == nil or order.Operation == nil then
    return
  end

  if order.UseFileParams then
    return
  end

  local priceLast = GetPriceLast(order)

  if order:IsBuy() then
    if tonumber(priceLast) < tonumber(order.Price) and tonumber(priceLast) ~= 0 then
      order.Price = priceLast - PRICE_DEVIATION_MULTIPLIER * order.SecurityInfo.min_price_step
    end
    local priceMin = tonumber(GetPriceMin(order))
    if priceMin ~= nil and priceMin > 0 and tonumber(order.Price) < priceMin then
      order.Price = priceMin
      order:GetPriceRound()
    end
  end

  if order:IsSell() then
    if tonumber(priceLast) > tonumber(order.Price) and tonumber(priceLast) ~= 0 then
      order.Price = priceLast + PRICE_DEVIATION_MULTIPLIER * order.SecurityInfo.min_price_step
    end
  end
end

--- @return boolean, string Результат (true/false), причина ошибки ("" если ок)
function CheckOrder(order)
  -- Проверка корректности параметров
  if
    order == nil
    or order.Price == nil
    or order.Quantity == nil
    or order.Operation == nil
    or tonumber(order.Price) <= 0
    or tonumber(order.Quantity) <= 0
    or order.Operation == ""
  then
    log.error(
      "Некорректные параметры ордера.",
      order and order.Print() or "nil"
    )
    return false, "Некорректные параметры ордера"
  end

  local priceLast = GetPriceLast(order)

  -- Валидация PRICEMIN (корректировка цены — в AdjustPrice)
  if order:IsBuy() then
    local priceMin = tonumber(GetPriceMin(order))
    if priceMin ~= nil and priceMin > 0 and tonumber(order.Price) < priceMin then
      local reason = string.format(
        "price %s below PRICEMIN %s",
        tostring(order.Price),
        tostring(priceMin)
      )
      log.debug(reason .. " " .. order.Print())
      return false, reason
    end
  end

  --- Проверка достаточности позиции для продажи
  if order:IsSell() then
    local position = GetPosition(order.SecurityCode)
    if position == nil or tonumber(position.currentbal) < tonumber(order.Quantity) then
      local reason = string.format(
        "insufficient position for sell (have: %s, need: %s)",
        tostring(position and position.currentbal or 0),
        tostring(order.Quantity)
      )
      return false, reason
    end
  end

  --- Проверка на превышение максимально допустимого объёма ордера для покупки
  if order:IsBuy() then
    local limit = VolumeOrderLimit

    if order:GetVolume() > limit then
      local reason = string.format(
        "volume %s %s exceeds limit %s",
        tostring(order:GetVolume()),
        order.SecurityInfo.face_unit,
        tostring(limit)
      )
      order:Clear()
      return false, reason
    end
  end

  --- Проверка на неактивность коэффициента корректировки цены ниже цены для покупки
  if order:IsBuy() then
    if order:IsExceptionFromLimitActuation() then
      return true, ""
    end

    local actuation = (tonumber(priceLast) - tonumber(order.Price)) / tonumber(order.Price) * 100
    local limit = LimitActuationOrderEdge
    if order:IsBond() and not order:IsOFZ() then
      limit = LimitActuationOrderBondEdge

    end

    if actuation ~= nil and tonumber(actuation) < tonumber(limit) then
      local reason = string.format("actuation %.2f%% below limit %s%%", actuation, tostring(limit))
      return false, reason
    end
  end

  -- Проверка, не была ли цена выше номинала (100%)
  if order:IsBuy() then
    if order:IsBond() then
      local nominal = 100.0
      if tonumber(order.Price) > tonumber(nominal) then
        local reason = string.format(
          "Цена последней сделки выше номинала 100%% (цена: %s%%)",
          tostring(order.Price)
        )
        log.warn(reason .. " " .. order.Print())
        return false, reason
      end
    end
  end

  --- Проверка, не была ли цена выше средней для покупки
  if order:IsBuy() and not order:IsBond() then
    local position = GetPosition(order.SecurityCode)
    if position ~= nil and tonumber(position.wa_position_price) < tonumber(order.Price) then
      local reason = string.format(
        "Цена последней сделки выше средней цены %s",
        string.format("%.2f", position.wa_position_price)
      )
      log.warn(reason .. " " .. order.Print())
      return false, reason
    end
  end

  return true, ""
end

function SetLimitOrdersWithError(trans)
  -- Ошибка: (579) Цена не может быть выше максимально допустимой цены
  local error579 = string.find(trans.result_msg, ": (" .. ERR_PRICE_TOO_LOW .. ")", 1, true)
  if error579 ~= nil then
    log.warn(
      "Ошибка (579) для "
        .. " (qty=" .. tostring(trans.quantity) .. ", price=" .. tostring(trans.price) .. "): "
        .. trans.result_msg
    )
    return
  end

  -- Ошибка: (580) Цена не может быть ниже минимально допустимой цены
  local error580 = string.find(trans.result_msg, ": (" .. ERR_PRICE_TOO_HIGH .. ")", 1, true)
  if error580 ~= nil then
    local maxPrice = string.match(trans.result_msg, "не более (%d+%.?%d*)")
    if maxPrice == nil then
      maxPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "S"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error("Не удалось создать инструмент для исправления ордера", trans.sec_code)
      return
    end
    order:SetOperation(operation, maxPrice, trans.quantity)
    log.info("Корректирующий ордер на продажу создан автоматически: " .. order.Print())
    local orders = {}
    table.insert(orders, order)
    SubmitOrders(orders)
    return
  end

  -- Ошибка: Цена не находится в допустимых пределах для исполнения
  local errorTest = string.find(trans.result_msg, "не находится в допустимых пределах для не", 1, true)
  if errorTest ~= nil then
    local minPrice = string.match(trans.result_msg, "от (%d+%.?%d*)")
    if minPrice == nil then
      minPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
    end
    local operation = "B"
    local order = Order:new(trans.sec_code)
    if order == nil then
      log.error("Не удалось создать инструмент для исправления ордера", trans.sec_code)
      return
    end
    order:SetOperation(operation, minPrice, 0)
    log.info("Корректирующий ордер на покупку создан: " .. order.Print())
    return
  end

  -- Ошибка: (133) Операция не может быть исполнена по рыночной цене
  local error133 = string.find(trans.result_msg, ": (" .. ERR_EXECUTION_REJECTED .. ")", 1, true)
  if error133 ~= nil then
    log.warn("Ошибка (133) для "
      .. " (qty=" .. tostring(trans.quantity) .. ", price=" .. tostring(trans.price) .. "): "
      .. trans.result_msg)
    return
  end

  log.error(string.format("Непредвиденная ошибка транзакции. %s", trans.result_msg))
  log.error(json.encode(trans))
end