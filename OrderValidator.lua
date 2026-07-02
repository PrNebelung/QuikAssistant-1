--- Валидатор ордеров (цепочка проверок).

local Config = require("Config")
local MarketData = require("MarketData")
local PositionService = require("PositionService")
require("PriceAdjuster")
local Constants = require("Constants")

local OrderValidator = {}

--- Расчёт коэффициента объёма на основе разницы LAST/PRICEMIN.
--- @param table Объект Order
--- @param string|number priceMin Минимальная цена (PRICEMIN)
--- @return number Коэффициент объёма (>= 1)
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

--- Расчёт максимально допустимого объёма ордера в валюте.
--- @param table Объект Order
--- @param string|number priceMin Минимальная цена (PRICEMIN)
--- @return number Максимальный объём
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
-- Результат проверки: true, "" для успеха; false, причина для отклонения
-- ==========================================

--- Проверка: обязательные поля (цена, количество, операция) у ордера > 0.
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
		log.error(
			string.format(
				"некорректные параметры ордера: %s",
				order and order:Print() or "nil"
			)
		)
		return false, "Invalid order parameters"
	end
	return true, ""
end

--- Проверка: цена покупки не ниже минимально допустимой цены (PRICEMIN).
local function checkPriceBelowPricemin(order)
	if not order:IsBuy() then
		return true, ""
	end
	local priceMin = tonumber(MarketData.GetPriceMin(order))
	if priceMin ~= nil and priceMin > 0 and tonumber(order.Price) < priceMin then
		local reason = string.format("цена %s ниже PRICEMIN %s", tostring(order.Price), tostring(priceMin))
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
			"недостаточно позиции для продажи (есть: %s, нужно: %s)",
			tostring(position and position.currentbal or 0),
			tostring(order.Quantity)
		)
		return false, reason
	end
	return true, ""
end

--- Проверка: объём ордера не превышает максимально допустимый.
local function checkVolumeLimit(order)
	if not order:IsBuy() then
		return true, ""
	end
	local limit = Config.VolumeOrderLimit
	if order:GetVolume() > limit then
		local reason = string.format(
			"объём %s %s превышает лимит %s",
			tostring(order:GetVolume()),
			order.SecurityInfo.face_unit,
			tostring(limit)
		)
		order:Clear()
		return false, reason
	end
	return true, ""
end

--- Проверка: срабатывание (разница LAST и цены ордера) не ниже порога.
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
		local reason = string.format("срабатывание %.2f%% ниже лимита %s%%", actuation, tostring(limit))
		return false, reason
	end
	return true, ""
end

--- Проверка: цена облигации не превышает 100%%.
local function checkBondPriceLimit(order)
	if not order:IsBuy() or not order:IsBond() then
		return true, ""
	end
	local nominal = Constants.BOND_MAX_PRICE_PERCENT
	if tonumber(order.Price) > tonumber(nominal) then
		local reason = string.format("цена облигации превышает 100%% (цена: %s%%)", tostring(order.Price))
		log.warn(string.format("%s %s", reason, order:Print()))
		return false, reason
	end
	return true, ""
end

--- Проверка: цена покупки не выше средней цены позиции.
local function checkAvgPositionPrice(order)
	if not order:IsBuy() or order:IsBond() then
		return true, ""
	end
	local position = PositionService.GetPosition(order.SecurityCode)
	if position ~= nil and tonumber(position.wa_position_price) < tonumber(order.Price) then
		local reason = string.format(
			"цена покупки превышает среднюю цену позиции %s",
			string.format("%.2f", position.wa_position_price)
		)
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

--- Валидация ордера через все проверки (nil, pricemin, позиция, объём, срабатывание, облигация, средняя цена).
--- @param table Объект Order для валидации
--- @return boolean true, если ордер прошёл все проверки
--- @return string Пустая строка при успехе, причина отклонения при неудаче
function OrderValidator.CheckOrder(order)
	if order == nil then
		log.error("CheckOrder: ордер равен nil")
		return false, "order is nil"
	end
	for _, check in ipairs(checkChain) do
		local passed, reason = check(order)
		if not passed then
			return false, reason
		end
	end
	return true, ""
end

--- Глобальная обёртка для OrderValidator.GetKoeffVolumeOrderMax (обратная совместимость).
--- @param table Объект Order
--- @param string|number priceMin Минимальная цена
--- @return number Коэффициент объёма
function GetKoeffVolumeOrderMax(order, priceMin)
	return OrderValidator.GetKoeffVolumeOrderMax(order, priceMin)
end

--- Глобальная обёртка для OrderValidator.GetOrderVolumeMax (обратная совместимость).
--- @param table Объект Order
--- @param string|number priceMin Минимальная цена
--- @return number Максимальный объём
function GetOrderVolumeMax(order, priceMin)
	return OrderValidator.GetOrderVolumeMax(order, priceMin)
end


--- Глобальная обёртка для OrderValidator.CheckOrder (обратная совместимость).
--- @param table Объект Order
--- @return boolean true, если валиден
--- @return string Пустая строка или причина отклонения
function CheckOrder(order)
	return OrderValidator.CheckOrder(order)
end

return OrderValidator
