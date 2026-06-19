--- Сервис позиций депо-лимитов.
--- Реализует кешированный поиск позиций по депо-лимитам,
--- определение текущей позиции по коду инструмента
--- и очистку кеша позиций.


local BrokerAdapter = require("BrokerAdapter")

local PositionService = {}

local positionCache = {}

--- Очищает кеш позиций.
function PositionService.ClearCache()
  positionCache = {}
end

--- Фильтр позиций: только depo_limits с limit_kind=2 и ненулевым балансом.
function PositionService.FindPosition(limit_kind, currentbal)
  if limit_kind == 2 and tonumber(currentbal) ~= 0 then
    return true
  end
  return false
end

--- Получает позицию по коду инструмента. Ищет в кеше, затем в QUIK.
function PositionService.GetPosition(securityCode)
  if positionCache[securityCode] then
    return positionCache[securityCode]
  end

  local positionIndices = BrokerAdapter.SearchPositions(PositionService.FindPosition, "limit_kind, currentbal")
  for i = 1, #positionIndices do
    local position = BrokerAdapter.GetPosition(positionIndices[i])
    if position and position.sec_code == securityCode then
      log.debug("Position found. ", securityCode)
      log.trace(json.encode(position))
      positionCache[securityCode] = position
      return position
    end
  end

  return nil
end

-- Глобальные обёртки для обратной совместимости
--- Глобальная обёртка для PositionService.FindPosition.
function FindPosition(limit_kind, currentbal)
  return PositionService.FindPosition(limit_kind, currentbal)
end

--- Глобальная обёртка для PositionService.ClearCache.
function ClearPositionCache()
  PositionService.ClearCache()
end

--- Глобальная обёртка для PositionService.GetPosition.
function GetPosition(securityCode)
  return PositionService.GetPosition(securityCode)
end

return PositionService
