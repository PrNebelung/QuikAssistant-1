--- Адаптер для взаимодействия с QUIK API.
--- Инкапсулирует все вызовы функций QUIK: getSecurityInfo, getParamEx,
--- SearchItems, getItem, sendTransaction, isConnected и др.
--- Единая точка доступа к брокерскому API с кешированием.

local BrokerAdapter = {}

-- ==========================================
-- Информация об инструментах
-- ==========================================

local CLASS_CODES = "TQCB,TQBR,SPBXM,EQOB,TQIR,TQRD,TQOB,FQBR,TQTF,TQPI,MTQR,"
local securityInfoCache = {}

--- Очищает кеш информации об инструментах.
function BrokerAdapter.ClearSecurityInfoCache()
  securityInfoCache = {}
end

--- Получает информацию об инструменте. Ищет по списку классов. Кеширует результат.
function BrokerAdapter.GetSecurityInfo(securityCode)
  if securityInfoCache[securityCode] then
    return securityInfoCache[securityCode]
  end
  for classCode in string.gmatch(CLASS_CODES, "(%P*),") do
    local info = getSecurityInfo(classCode, securityCode)
    if info ~= nil then
      securityInfoCache[securityCode] = info
      return info
    end
  end
  log.error("Security not found: " .. securityCode)
  return nil
end

-- ==========================================
-- Рыночные данные
-- ==========================================

--- Получает параметр инструмента (LAST, PRICEMIN, PRICEMAX и др.). Возвращает значение или nil.
function BrokerAdapter.GetParamEx(classCode, secCode, param)
  local value = getParamEx(classCode, secCode, param)
  if value == nil or value.result == "0" then
    return nil
  end
  return value.param_value
end

--- Получает параметр инструмента из объекта Order. Логирует ошибку если не найден. Возвращает "0" по умолчанию.
function BrokerAdapter.GetParamInfo(order, param)
  local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
  if value == nil or value.result == "0" then
    log.error("Parameter not found.", param, order:Print())
    return "0"
  end
  return value.param_value
end

-- ==========================================
-- Ордера
-- ==========================================

--- Возвращает количество ордеров в QUIK.
function BrokerAdapter.GetNumberOfOrders()
  return getNumberOf("orders")
end

--- Ищет ордера по фильтру. Возвращает массив индексов.
function BrokerAdapter.SearchOrders(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfOrders()
  if count <= 0 then
    return {}
  end
  local ok, orders = pcall(function()
    return SearchItems("orders", 0, count - 1, filterFunc, params)
  end)
  if ok and orders ~= nil then
    return orders
  end
  return {}
end

--- Получает ордер по индексу из QUIK.
function BrokerAdapter.GetOrder(index)
  local ok, order = pcall(function()
    return getItem("orders", index)
  end)
  if ok then
    return order
  end
  return nil
end

-- ==========================================
-- Позиции (депо-лимиты)
-- ==========================================

--- Возвращает количество депо-лимитов в QUIK.
function BrokerAdapter.GetNumberOfPositions()
  return getNumberOf("depo_limits")
end

--- Ищет позиции по фильтру. Возвращает массив индексов.
function BrokerAdapter.SearchPositions(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfPositions()
  if count <= 0 then
    return {}
  end
  local ok, positions = pcall(function()
    return SearchItems("depo_limits", 0, count - 1, filterFunc, params)
  end)
  if ok and positions ~= nil then
    return positions
  end
  return {}
end

--- Получает позицию по индексу из QUIK.
function BrokerAdapter.GetPosition(index)
  local ok, position = pcall(function()
    return getItem("depo_limits", index)
  end)
  if ok then
    return position
  end
  return nil
end

-- ==========================================
-- Транзакции
-- ==========================================

--- Отправляет транзакцию в QUIK. Возвращает пустую строку при успехе или текст ошибки.
function BrokerAdapter.SendTransaction(transaction)
  local ok, result = pcall(function()
    return sendTransaction(transaction)
  end)
  if not ok then
    return "sendTransaction error: " .. tostring(result)
  end
  return result or ""
end

-- ==========================================
-- Подключение и информация
-- ==========================================

--- Возвращает true если QUIK подключён к серверу.
function BrokerAdapter.IsConnected()
  return isConnected() == 1
end

--- Получает информационный параметр QUIK (USERID, SERVERTIME и др.).
function BrokerAdapter.GetInfoParam(param)
  return getInfoParam(param)
end

--- Получает информацию о портфеле (активы, прибыль/убыток).
function BrokerAdapter.GetPortfolioInfo(firmId, clientCode)
  return getPortfolioInfoEx(firmId, clientCode, 0)
end

-- ==========================================
-- Файловая система
-- ==========================================

--- Возвращает путь к скрипту QUIK.
function BrokerAdapter.GetScriptPath()
  return getScriptPath()
end

return BrokerAdapter
