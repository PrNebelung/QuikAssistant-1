--- округления цен, расчёта объёма и форматирования для отправки в QUIK.

Order = {}
Order.__index = Order


-- ==========================================
-- Кеш информации об инструментах
-- ==========================================
local BrokerAdapter = require("BrokerAdapter")
local log = require("log")

--- Очистка кэша информации о бумагах (делегирует в BrokerAdapter).
function ClearSecurityInfoCache()
  BrokerAdapter.ClearSecurityInfoCache()
end

--- Получение информации о бумаге из QUIK (делегирует в BrokerAdapter).
--- @param securityCode string Код тикера бумаги
--- @return table|nil Таблица информации о бумаге или nil
function GetSecurityInfo(securityCode)
  return BrokerAdapter.GetSecurityInfo(securityCode)
end

-- ==========================================
-- Список исключений (настраиваемый)
-- ==========================================
local exceptionTickers = {}
for secCode in
  string.gmatch(
    "ENPG,RTKM,MTSS,NKNCP,UPRO,MGTSP,IRAO,MAGN,TGKA,GAZP,AFLT,ELFV,SMLT,SNGS,ALRS,MGNT,HYDR,VTBR,FEES,MVID,SGZH,AQUA,STSB,IVAT,UPRO,VKCO,",
    "(%P*),"
  )
do
  exceptionTickers[secCode] = true
end

-- ==========================================
-- Коды классов облигаций
-- ==========================================
local bondClassCodes = {}
for classCode in string.gmatch("TQCB,EQOB,TQIR,TQRD,TQOB,", "(%P*),") do
  bondClassCodes[classCode] = true
end

-- ==========================================
-- Методы ордера (на метатаблице)
-- ==========================================

--- Возвращает true, если тикер в списке исключений (проверка срабатывания не выполняется).
--- @return boolean true, если проверка срабатывания пропущена
function Order:IsExceptionFromLimitActuation()
  return exceptionTickers[self.SecurityCode] == true
end

--- Возвращает true, если бумага является облигацией (TQCB, EQOB, TQIR, TQRD, TQOB).
--- @return boolean true, если облигация
function Order:IsBond()
  return bondClassCodes[self.SecurityInfo.class_code] == true
end

--- Возвращает true, если бумага является ОФЗ (класс TQOB).
--- @return boolean true, если ОФЗ
function Order:IsOFZ()
  return self.SecurityInfo.class_code == "TQOB"
end

--- Возвращает true, если бумага является ETF (класс TQTF).
--- @return boolean true, если ETF
function Order:IsEtf()
  return self.SecurityInfo.class_code == "TQTF"
end

--- Возвращает true, если операция - покупка ("B").
--- @return boolean true, если покупка
function Order:IsBuy()
  return self.Operation ~= nil and self.Operation == "B"
end

--- Возвращает true, если операция - продажа ("S").
--- @return boolean true, если продажа
function Order:IsSell()
  return self.Operation ~= nil and self.Operation == "S"
end

--- Сброс полей ордера в пустое состояние.
function Order:Clear()
  self.Operation = ""
  self.Quantity = 0
  self.Price = 0
end

--- Форматирование цены в соответствии с точностью бумаги (знаки после запятой).
--- @return string Отформатированная строка цены
function Order:FormatPrice()
  return string.format("%." .. self.SecurityInfo.scale .. "f", tonumber(self.Price))
end

--- Форматирование количества с указанным количеством знаков после запятой.
--- @param n number|nil Количество знаков после запятой (по умолчанию: 0)
--- @return string Отформатированная строка количества
function Order:FormatQuantity(n)
  local n = (n or 0)
  return string.format("%." .. n .. "f", self.Quantity)
end

--- Возвращает ключ дедупликации: "код операция количество цена".
--- @return string Ключ дедупликации для обнаружения дубликатов
function Order:GetDedupKey()
  return self.SecurityInfo.code .. " " .. self.Operation .. " " .. self:FormatQuantity() .. " " .. self:FormatPrice()
end

--- Конвертация цены в сумму в валюте (для облигаций: цена * номинал / 100).
--- @param price number|string Значение цены
--- @return number Цена в единицах валюты
function Order:GetPriceInCurrency(price)
  if self:IsBond() then
    local nominal = self.SecurityInfo.face_value
    return tonumber(price) * tonumber(nominal) / 100
  else
    return tonumber(price)
  end
end

--- Установка операции, цены и количества с валидацией.
--- @param operation string Тип операции: "B" (покупка) или "S" (продажа)
--- @param price number|string Цена ордера (должна быть >= 0)
--- @param quantity number|string Количество ордера (должно быть >= 0)
function Order:SetOperation(operation, price, quantity)
  if operation ~= "B" and operation ~= "S" then
    log.error("SetOperation: неверная операция '%s' (ожидается 'B' или 'S')" .. tostring(operation))
    return
  end
  local numPrice = tonumber(price)
  if numPrice == nil or numPrice < 0 then
    log.error("SetOperation: неверная цена " .. tostring(price) .. " (ожидается >= 0)")
    return
  end
  local numQuantity = tonumber(quantity)
  if numQuantity == nil or numQuantity < 0 then
    log.error("SetOperation: неверное количество " .. tostring(quantity) .. " (ожидается >= 0)")
    return
  end
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

--- Установка ордера по минимальной цене (1 лот по min_price_step).
--- @param operation string Тип операции: "B" (покупка) или "S" (продажа)
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

--- Расчёт и установка количества на основе максимально доступной суммы.
--- @param operation string Тип операции: "B" (покупка) или "S" (продажа)
--- @param price number|string Цена за единицу
--- @param quantityMax number|string Максимальная сумма в валюте для траты
function Order:SetQuantity(operation, price, quantityMax)
  self.Operation = operation
  if price == nil then
    log.error("SetQuantity: цена равна nil")
    self.Quantity = 0
    return
  end
  if quantityMax == nil then
    log.error("SetQuantity: quantityMax равен nil")
    self.Quantity = 0
    return
  end
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

--- Установка количества для продажи на основе текущего размера позиции.
--- @param operation string Тип операции: "S" (продажа)
--- @param price number|string Цена за единицу
--- @param positionQty number|string Текущее количество позиции для продажи
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

--- Расчёт общего объёма ордера (количество * цена * размер лота).
--- @return number Общий объём в валюте
function Order:GetVolume()
  local priceInCurrency = 0
  if self:IsBond() then
    priceInCurrency = self:GetPriceInCurrency(self.Price)
  else
    priceInCurrency = self.Price
  end
  return tonumber(self.Quantity) * tonumber(priceInCurrency) * tonumber(self.SecurityInfo.lot_size)
end

--- Округление цены до min_price_step (ceil для покупки, floor для продажи).
--- @return number Округлённая цена
function Order:GetPriceRound()
  local FormatUtils = require("FormatUtils")
  local price = FormatUtils.round(self.Price, self.SecurityInfo.scale)

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

--- Возвращает отформатированную строку ордера.
--- @return string Строка с деталями ордера
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
-- Конструктор
-- ==========================================

--- Создание нового экземпляра Order.
--- @param securityCode string Код тикера бумаги (e.g. "GAZP")
--- @return table|nil Объект Order или nil, если бумага не найдена в QUIK
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
