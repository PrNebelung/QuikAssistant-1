--- ������� ��� �������������� � QUIK API.
--- ������������� ��� ������ ������� QUIK: getSecurityInfo, getParamEx,
--- SearchItems, getItem, sendTransaction, isConnected � ��.
--- ������ ����� ������� � ����������� API � ������������.

local BrokerAdapter = {}

-- ==========================================
-- ���������� �� ������������
-- ==========================================

local CLASS_CODES = "TQCB,TQBR,SPBXM,EQOB,TQIR,TQRD,TQOB,FQBR,TQTF,TQPI,MTQR,"
local securityInfoCache = {}

--- ������� ��� ���������� �� ������������.
function BrokerAdapter.ClearSecurityInfoCache()
  securityInfoCache = {}
end

--- �������� ���������� �� �����������. ���� �� ������ �������. �������� ���������.
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
-- �������� ������
-- ==========================================

--- �������� �������� ����������� (LAST, PRICEMIN, PRICEMAX � ��.). ���������� �������� ��� nil.
function BrokerAdapter.GetParamEx(classCode, secCode, param)
  local value = getParamEx(classCode, secCode, param)
  if value == nil or value.result == "0" then
    return nil
  end
  return value.param_value
end

--- �������� �������� ����������� �� ������� Order. �������� ������ ���� �� ������. ���������� "0" �� ���������.
function BrokerAdapter.GetParamInfo(order, param)
  local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
  if value == nil or value.result == "0" then
    log.error("Parameter not found.", param, order:Print())
    return "0"
  end
  return value.param_value
end

-- ==========================================
-- ������
-- ==========================================

--- ���������� ���������� ������� � QUIK.
function BrokerAdapter.GetNumberOfOrders()
  return getNumberOf("orders")
end

--- ���� ������ �� �������. ���������� ������ ��������.
function BrokerAdapter.SearchOrders(filterFunc, params)
  local count = BrokerAdapter.GetNumberOfOrders()
  if count <= 0 then
    log.debug("SearchOrders: orders count=0, returning empty")
    return {}
  end
  local ok, orders = pcall(function()
    return SearchItems("orders", 0, count - 1, filterFunc, params)
  end)
  if not ok then
    log.error("SearchOrders: SearchItems error: " .. tostring(orders) .. " (count=" .. count .. ")")
    return {}
  end
  if orders ~= nil then
    log.debug(string.format("SearchOrders: found %d orders (QUIK total=%d)", #orders, count))
    return orders
  end
  log.warn("SearchOrders: SearchItems returned nil (count=" .. count .. ")")
  return {}
end

--- �������� ����� �� ������� �� QUIK.
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
-- ������� (����-������)
-- ==========================================

--- ���������� ���������� ����-������� � QUIK.
function BrokerAdapter.GetNumberOfPositions()
  return getNumberOf("depo_limits")
end

--- ���� ������� �� �������. ���������� ������ ��������.
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

--- �������� ������� �� ������� �� QUIK.
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
-- ����������
-- ==========================================

--- ���������� ���������� � QUIK. ���������� ������ ������ ��� ������ ��� ����� ������.
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
-- ����������� � ����������
-- ==========================================

--- ���������� true ���� QUIK ��������� � �������.
function BrokerAdapter.IsConnected()
  return isConnected() == 1
end

--- �������� �������������� �������� QUIK (USERID, SERVERTIME � ��.).
function BrokerAdapter.GetInfoParam(param)
  return getInfoParam(param)
end

--- �������� ���������� � �������� (������, �������/������).
function BrokerAdapter.GetPortfolioInfo(firmId, clientCode)
  return getPortfolioInfoEx(firmId, clientCode, 0)
end

-- ==========================================
-- �������� �������
-- ==========================================

--- ���������� ���� � ������� QUIK.
function BrokerAdapter.GetScriptPath()
  return getScriptPath()
end

return BrokerAdapter
