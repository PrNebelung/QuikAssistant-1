local BrokerAdapter = {}

-- ==========================================
-- Security Info
-- ==========================================

local CLASS_CODES = "TQCB,TQBR,SPBXM,EQOB,TQIR,TQRD,TQOB,FQBR,TQTF,TQPI,MTQR,"
local securityInfoCache = {}

function BrokerAdapter.ClearSecurityInfoCache()
  securityInfoCache = {}
end

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
-- Market Data
-- ==========================================

function BrokerAdapter.GetParamEx(classCode, secCode, param)
  local value = getParamEx(classCode, secCode, param)
  if value == nil or value.result == "0" then
    return nil
  end
  return value.param_value
end

function BrokerAdapter.GetParamInfo(order, param)
  local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
  if value == nil or value.result == "0" then
    log.error("Parameter not found.", param, order:Print())
    return "0"
  end
  return value.param_value
end

-- ==========================================
-- Orders
-- ==========================================

function BrokerAdapter.GetNumberOfOrders()
  return getNumberOf("orders")
end

function BrokerAdapter.SearchOrders(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfOrders()
  if count <= 0 then return {} end
  local ok, orders = pcall(function()
    return SearchItems("orders", 0, count - 1, filterFunc, params)
  end)
  if ok and orders ~= nil then
    return orders
  end
  return {}
end

function BrokerAdapter.GetOrder(index)
  local ok, order = pcall(function()
    return getItem("orders", index)
  end)
  if ok then return order end
  return nil
end

-- ==========================================
-- Positions (depo_limits)
-- ==========================================

function BrokerAdapter.GetNumberOfPositions()
  return getNumberOf("depo_limits")
end

function BrokerAdapter.SearchPositions(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfPositions()
  if count <= 0 then return {} end
  local ok, positions = pcall(function()
    return SearchItems("depo_limits", 0, count - 1, filterFunc, params)
  end)
  if ok and positions ~= nil then
    return positions
  end
  return {}
end

function BrokerAdapter.GetPosition(index)
  local ok, position = pcall(function()
    return getItem("depo_limits", index)
  end)
  if ok then return position end
  return nil
end

-- ==========================================
-- Transactions
-- ==========================================

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
-- Connection & Info
-- ==========================================

function BrokerAdapter.IsConnected()
  return isConnected() == 1
end

function BrokerAdapter.GetInfoParam(param)
  return getInfoParam(param)
end

function BrokerAdapter.GetPortfolioInfo(firmId, clientCode)
  return getPortfolioInfoEx(firmId, clientCode, 0)
end

-- ==========================================
-- File System
-- ==========================================

function BrokerAdapter.GetScriptPath()
  return getScriptPath()
end

return BrokerAdapter
