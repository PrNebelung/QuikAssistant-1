--- Валидатор ордеров (цепочка проверок).
--- Проверяет ордера перед отправкой: обязательные поля,
--- цена ниже PRICEMIN, наличие позиции для продажи, лимит объёма,
--- срабатывание, цена облигации, средняя цена позиции.
--- Также содержит логику расчёта максимального объёма ордера.

local Config = require("Config")
local MarketData = require("MarketData")
local PositionService = require("PositionService")
require("PriceAdjuster")

local OrderValidator = {}

local volumeWarnedTickers = {}

--- Очищает список тикеров с предупреждением об объёме.
function OrderValidator.ClearVolumeWarnedTickers()
  volumeWarnedTickers = {}
end

--- Рассчитывает коэффициент максимального объёма на основе разницы LAST и PRICEMIN.
function OrderValidator.GetKoeffVolumeOrderMax(order, priceMin)
  local priceLast = MarketData.GetPriceLast(order)
  if tonumber(priceMin) == nil or tonumber(priceMin) == 0 or tonumber(priceLast) == nil then
    return 1
  end
  local koeff = (tonumber(priceLast) - tonumber(priceMin)) / tonumber(priceMin) * 10
  if koeff ~= nil and tonumber(koeff) > 1 then
    return koeff
  end
  return 1
end

--- Рассчитывает максимальный объём ордера с учётом коэффициента и лимитов.
function OrderValidator.GetOrderVolumeMax(order, priceMin)
  local koeff = OrderValidator.GetKoeffVolumeOrderMax(order, priceMin)
  local limit = Config.VolumeOrderMax

  if order:IsBond() then
    limit = Config.BondVolumeOrderMax * tonumber(koeff)
  end

  if limit > Config.VolumeOrderLimit then
    limit = Config.VolumeOrderLimit
  end

  return limit
end

-- ==========================================
-- Цепочка проверок
-- Каждая проверка возвращает: true, "" при успехе; false, причина при отклонении
-- ==========================================

--- Проверка: обязательные поля ордера (цена, количество, операция) не пустые и > 0.
local function checkNotNil(order)
  if
    order == nil
    or order.Price == nil
    or order.Quantity == nil
    or order.Operation == nil
    or tonumber(order.Price) <= 0
    or tonumber(order.Quantity) <= 0
    or order.Operation == ""
  then
    log.error(string.format("Некорректные параметры ордера: %s", order and order:Print() or "nil"))
    return false, "Invalid order parameters"
  end
  return true, ""
end

--- Проверка: цена покупки не ниже минимальной цены стакана (PRICEMIN).
local function checkPriceBelowPricemin(order)
  if not order:IsBuy() then
    return true, ""
  end
  local priceMin = tonumber(MarketData.GetPriceMin(order))
  if priceMin ~= nil and priceMin > 0 and tonumber(order.Price) < priceMin then
    local reason = string.format("price %s below PRICEMIN %s", tostring(order.Price), tostring(priceMin))
    log.debug(string.format("%s %s", reason, order:Print()))
    return false, reason
  end
  return true, ""
end

--- Проверка: наличие достаточной позиции для продажи.
local function checkPositionForSell(order)
  if not order:IsSell() then
    return true, ""
  end
  local position = PositionService.GetPosition(order.SecurityCode)
  if position == nil or tonumber(position.currentbal) < tonumber(order.Quantity) then
    local reason = string.format(
      "insufficient position for sell (have: %s, need: %s)",
      tostring(position and position.currentbal or 0),
      tostring(order.Quantity)
    )
    return false, reason
  end
  return true, ""
end

--- Проверка: объём ордера не превышает установленный лимит.
local function checkVolumeLimit(order)
  if not order:IsBuy() then
    return true, ""
  end
  local limit = Config.VolumeOrderLimit
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
  return true, ""
end

--- Проверка: процент срабатывания (разница LAST и цены ордера) не ниже порога.
local function checkActuation(order)
  if not order:IsBuy() then
    return true, ""
  end
  if order:IsExceptionFromLimitActuation() then
    return true, ""
  end

  local priceLast = MarketData.GetPriceLast(order)
  local actuation = (tonumber(priceLast) - tonumber(order.Price)) / tonumber(order.Price) * 100
  local limit = Config.LimitActuationOrderEdge
  if order:IsBond() and not order:IsOFZ() then
    limit = Config.LimitActuationOrderBondEdge
  end

  if actuation ~= nil and tonumber(actuation) < tonumber(limit) then
    local reason = string.format("actuation %.2f%% below limit %s%%", actuation, tostring(limit))
    return false, reason
  end
  return true, ""
end

--- Проверка: цена облигации не превышает 100%% номинала.
local function checkBondPriceLimit(order)
  if not order:IsBuy() or not order:IsBond() then
    return true, ""
  end
  local nominal = 100.0
  if tonumber(order.Price) > tonumber(nominal) then
    local reason = string.format("bond price exceeds 100%% (price: %s%%)", tostring(order.Price))
    log.warn(string.format("%s %s", reason, order:Print()))
    return false, reason
  end
  return true, ""
end

--- Проверка: цена покупки не выше средней цены текущей позиции.
local function checkAvgPositionPrice(order)
  if not order:IsBuy() or order:IsBond() then
    return true, ""
  end
  local position = PositionService.GetPosition(order.SecurityCode)
  if position ~= nil and tonumber(position.wa_position_price) < tonumber(order.Price) then
    local reason =
      string.format("buy price exceeds average position price %s", string.format("%.2f", position.wa_position_price))
    log.warn(string.format("%s %s", reason, order:Print()))
    return false, reason
  end
  return true, ""
end

local checkChain = {
  checkNotNil,
  checkPriceBelowPricemin,
  checkPositionForSell,
  checkVolumeLimit,
  checkActuation,
  checkBondPriceLimit,
  checkAvgPositionPrice,
}

--- Запускает цепочку проверок ордера. Возвращает (true, "") при успехе или (false, причина) при отклонении.
function OrderValidator.CheckOrder(order)
  for _, check in ipairs(checkChain) do
    local passed, reason = check(order)
    if not passed then
      return false, reason
    end
  end
  return true, ""
end

--- Глобальная обёртка для OrderValidator.GetKoeffVolumeOrderMax.
function GetKoeffVolumeOrderMax(order, priceMin)
  return OrderValidator.GetKoeffVolumeOrderMax(order, priceMin)
end

--- Глобальная обёртка для OrderValidator.GetOrderVolumeMax.
function GetOrderVolumeMax(order, priceMin)
  return OrderValidator.GetOrderVolumeMax(order, priceMin)
end

--- Глобальная обёртка для OrderValidator.ClearVolumeWarnedTickers.
function ClearVolumeWarnedTickers()
  OrderValidator.ClearVolumeWarnedTickers()
end

--- Глобальная обёртка для OrderValidator.CheckOrder.
function CheckOrder(order)
  return OrderValidator.CheckOrder(order)
end

return OrderValidator
