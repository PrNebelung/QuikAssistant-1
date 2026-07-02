--- и очистку кеша позиций.

local BrokerAdapter = require("BrokerAdapter")

local PositionService = {}

local positionCache = {}

--- Очистка кэша позиций.
function PositionService.ClearCache()
	positionCache = {}
end

--- Функция-фильтр: поиск depo_limits с limit_kind=2 и ненулевым балансом.
--- @param limit_kind number Тип лимита позиции
--- @param currentbal number Текущий баланс
--- @return boolean true, если позиция соответствует фильтру
function PositionService.FindPosition(limit_kind, currentbal)
	if limit_kind == 2 and tonumber(currentbal) ~= 0 then
		return true
	end
	return false
end

--- Получение позиции по коду бумаги. Использует кэш для производительности.
--- @param securityCode string Код тикера бумаги
--- @return table|nil Таблица позиции или nil if not found
function PositionService.GetPosition(securityCode)
	if positionCache[securityCode] then
		return positionCache[securityCode]
	end

	local positionIndices = BrokerAdapter.SearchPositions(PositionService.FindPosition, "limit_kind, currentbal")
	for i = 1, #positionIndices do
		local position = BrokerAdapter.GetPosition(positionIndices[i])
		if position and position.sec_code == securityCode then
			log.debug("Позиция найдена. ", securityCode)
			log.trace(json.encode(position))
			positionCache[securityCode] = position
			return position
		end
	end

	return nil
end

--- Глобальная обёртка для PositionService.FindPosition (обратная совместимость).
--- @param limit_kind number Тип лимита позиции
--- @param currentbal number Текущий баланс
--- @return boolean true, если позиция соответствует фильтру
function FindPosition(limit_kind, currentbal)
	return PositionService.FindPosition(limit_kind, currentbal)
end

--- Глобальная обёртка для PositionService.ClearCache (обратная совместимость).
function ClearPositionCache()
	PositionService.ClearCache()
end

--- Глобальная обёртка для PositionService.GetPosition (обратная совместимость).
--- @param securityCode string Код тикера бумаги
--- @return table|nil Таблица позиции или nil
function GetPosition(securityCode)
	return PositionService.GetPosition(securityCode)
end

return PositionService
