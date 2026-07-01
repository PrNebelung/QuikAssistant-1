--- Обёртка для взаимодействия с QUIK API.
--- Инкапсулирует все вызовы функций QUIK: getSecurityInfo, getParamEx,
--- SearchItems, getItem, sendTransaction, isConnected и др.
--- Все вызовы обёрнуты в pcall для обработки ошибок.

local BrokerAdapter = {}

-- ==========================================
-- Инициализация и кэширование
-- ==========================================

local CLASS_CODES = "TQCB,TQBR,SPBXM,EQOB,TQIR,TQRD,TQOB,FQBR,TQTF,TQPI,MTQR,"
local securityInfoCache = {}

--- Очистка кэша информации о бумагах.
function BrokerAdapter.ClearSecurityInfoCache()
  securityInfoCache = {}
end

--- Получение информации о бумаге. Если нет в кэще — ищет по классам. Возвращает nil.
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
  log.error(string.format("Не удалось найти бумагу: %s", securityCode))
  return nil
end

-- ==========================================
-- Рыночные данные
-- ==========================================

--- Получение значения параметра (LAST, PRICEMIN, PRICEMAX и др.). Возвращает строку или nil.
function BrokerAdapter.GetParamEx(classCode, secCode, param)
  local value = getParamEx(classCode, secCode, param)
  if value == nil or value.result == "0" then
    return nil
  end
  return value.param_value
end

--- Получение данных параметра по объекту Order. Логирует ошибку если не найдено. Возвращает "0" по умолчанию.
function BrokerAdapter.GetParamInfo(order, param)
  local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
  if value == nil or value.result == "0" then
    log.error(string.format("Параметр не найден: %s %s", param, order:Print()))
    return "0"
  end
  return value.param_value
end

-- ==========================================
-- Ордера
-- ==========================================

--- Получение количества ордеров в QUIK.
function BrokerAdapter.GetNumberOfOrders()
  return getNumberOf("orders")
end

--- Поиск ордеров по фильтру. Возвращает массив индексов.
function BrokerAdapter.SearchOrders(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfOrders()
  if count <= 0 then
    log.debug("SearchOrders: нет ордеров в QUIK (count=0)")
    return {}
  end
  local ok, orders = pcall(function()
    return SearchItems("orders", 0, count - 1, filterFunc, params)
  end)
  if not ok then
    log.error(string.format("SearchOrders: ошибка SearchItems: %s (count=%d)", tostring(orders), count))
    return {}
  end
  if orders ~= nil then
    log.debug(string.format("SearchOrders: найдено %d ордеров (всего в QUIK=%d)", #orders, count))
    return orders
  end
  log.warn(string.format("SearchOrders: SearchItems вернул nil (count=%d)", count))
  return {}
end

--- Получение данных ордера по индексу в QUIK.
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

--- Получение количества депо-лимитов в QUIK.
function BrokerAdapter.GetNumberOfPositions()
  return getNumberOf("depo_limits")
end

--- Поиск позиций по фильтру. Возвращает массив индексов.
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

--- Получение данных позиции по индексу в QUIK.
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

--- Отправка транзакции в QUIK. Возвращает строку ошибки или пустую строку.
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
-- Соединение и сервис
-- ==========================================

--- Возвращает true если QUIK подключён к серверу.
function BrokerAdapter.IsConnected()
  return isConnected() == 1
end

--- Получение служебного параметра QUIK (USERID, SERVERTIME и др.).
function BrokerAdapter.GetInfoParam(param)
  return getInfoParam(param)
end

--- Получение портфеля и позиций (клиент, фирма/счёт).
function BrokerAdapter.GetPortfolioInfo(firmId, clientCode)
  return getPortfolioInfoEx(firmId, clientCode, 0)
end

-- ==========================================
-- Путь к скрипту
-- ==========================================

--- Получение пути к скрипту QUIK.
function BrokerAdapter.GetScriptPath()
  return getScriptPath()
end

return BrokerAdapter
