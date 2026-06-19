--- Модуль торгового ордера (Order).
--- Реализует конструктор Order:new(), методы установки цены,
--- количества, операции, проверки типа инструмента (акция/облигация/ETF),
--- округления цен, расчёта объёма и форматирования для отправки в QUIK.


Order = {}
Order.__index = Order

math.round = function(num, idp)
  if num == nil then
    return nil
  end
  local mult = 10 ^ (idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- ==========================================
-- Security Info Cache
-- ==========================================
local BrokerAdapter = require("BrokerAdapter")

function ClearSecurityInfoCache()
  BrokerAdapter.ClearSecurityInfoCache()
end

function GetSecurityInfo(securityCode)
  return BrokerAdapter.GetSecurityInfo(securityCode)
end

-- ==========================================
-- Exception tickers (configurable)
-- ==========================================
local exceptionTickers = {}
for secCode in string.gmatch("ENPG,RTKM,MTSS,NKNCP,UPRO,MGTSP,IRAO,MAGN,TGKA,GAZP,AFLT,ELFV,SMLT,SNGS,ALRS,MGNT,HYDR,VTBR,FEES,MVID,SGZH,AQUA,STSB,IVAT,UPRO,VKCO,", "(%P*),") do
  exceptionTickers[secCode] = true
end

-- ==========================================
-- Bond class codes
-- ==========================================
local bondClassCodes = {}
for classCode in string.gmatch("TQCB,EQOB,TQIR,TQRD,TQOB,", "(%P*),") do
  bondClassCodes[classCode] = true
end

-- ==========================================
-- Order Methods (on metatable, not per-instance)
-- ==========================================

function Order:IsExceptionFromLimitActuation()
  return exceptionTickers[self.SecurityCode] == true
end

function Order:IsBond()
  return bondClassCodes[self.SecurityInfo.class_code] == true
end

function Order:IsOFZ()
  return self.SecurityInfo.class_code == "TQOB"
end

function Order:IsEtf()
  return self.SecurityInfo.class_code == "TQTF"
end

function Order:IsBuy()
  return self.Operation ~= nil and self.Operation == "B"
end

function Order:IsSell()
  return self.Operation ~= nil and self.Operation == "S"
end

function Order:Clear()
  self.Operation = ""
  self.Quantity = 0
  self.Price = 0
end

function Order:FormatPrice()
  return string.format("%." .. self.SecurityInfo.scale .. "f", tonumber(self.Price))
end

function Order:FormatQuantity(n)
  local n = (n or 0)
  return string.format("%." .. n .. "f", self.Quantity)
end

function Order:GetDedupKey()
  return self.SecurityInfo.code .. " " .. self.Operation .. " " .. self:FormatQuantity() .. " " .. self:FormatPrice()
end

function Order:GetPriceInCurrency(price)
  if self:IsBond() then
    local nominal = self.SecurityInfo.face_value
    return tonumber(price) * tonumber(nominal) / 100
  else
    return tonumber(price)
  end
end

function Order:SetOperation(operation, price, quantity)
  self.Operation = operation
  self.Quantity = quantity
  self.Price = price
  self:GetPriceRound()

  if price == 0 then
    if self.SecurityInfo.min_price_step <= 0.0001 then
      self.Price = 0.0001
    else
      self.Price = self.SecurityInfo.min_price_step
    end
  end
end

function Order:SetPriceMin(operation)
  self.Operation = operation
  if self:IsBuy() then
    self.Quantity = 1
    self.Price = self.SecurityInfo.min_price_step
  else
    self.Quantity = 0
    self.Price = 0
  end
end

function Order:SetQuantity(operation, price, quantityMax)
  self.Operation = operation
  if price ~= nil and tonumber(price) > 0 and quantityMax ~= nil and tonumber(quantityMax) > 0 and self:IsBuy() then
    self.Price = tonumber(price)
    self:GetPriceRound()

    if self:IsBond() then
      local priceRub = self:GetPriceInCurrency(price)
      self.Quantity = math.floor(tonumber(quantityMax) / tonumber(priceRub) / tonumber(self.SecurityInfo.lot_size))
    else
      self.Quantity = math.floor(tonumber(quantityMax) / tonumber(self.Price) / tonumber(self.SecurityInfo.lot_size))
    end

    if self.Quantity <= 0 then
      self.Quantity = 1
    end
  else
    self.Quantity = 0
  end
end

function Order:SetQuantitySell(operation, price, positionQty)
  self.Operation = operation
  if price ~= nil and tonumber(price) > 0 and positionQty ~= nil and tonumber(positionQty) > 0 and self:IsSell() then
    self.Price = tonumber(price)
    self:GetPriceRound()
    self.Quantity = math.floor(tonumber(positionQty) / tonumber(self.SecurityInfo.lot_size))
  else
    self.Quantity = 0
  end
end

function Order:GetVolume()
  local priceInCurrency = 0
  if self:IsBond() then
    priceInCurrency = self:GetPriceInCurrency(self.Price)
  else
    priceInCurrency = self.Price
  end
  return tonumber(self.Quantity) * tonumber(priceInCurrency) * tonumber(self.SecurityInfo.lot_size)
end

function Order:GetPriceRound()
  local price = math.round(self.Price, self.SecurityInfo.scale)

  if price == nil then
    price = 0
  end

  if self:IsBuy() then
    price = math.ceil(price / self.SecurityInfo.min_price_step) * self.SecurityInfo.min_price_step
  elseif self:IsSell() then
    price = math.floor(price / self.SecurityInfo.min_price_step) * self.SecurityInfo.min_price_step
  else
    price = 0
  end
  self.Price = price
end

function Order:Print()
  return string.format(
    "[Instrument: %s; Code: %s; Class: %s; Operation: %s; Price: %f; Quantity: %f; Volume: %f;]",
    self.SecurityInfo.name,
    self.SecurityCode,
    self.SecurityInfo.class_code,
    self.Operation,
    self.Price,
    self.Quantity,
    self:GetVolume()
  )
end

-- ==========================================
-- Constructor
-- ==========================================

function Order:new(securityCode)
  local obj = {}
  setmetatable(obj, self)

  obj.SecurityInfo = GetSecurityInfo(securityCode)
  obj.SecurityCode = securityCode
  obj.Operation = ""
  obj.Quantity = 0
  obj.Price = 0
  obj.UseFileParams = false

  if obj.SecurityInfo == nil then
    return nil
  end

  return obj
end
