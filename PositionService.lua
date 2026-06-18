local BrokerAdapter = require("BrokerAdapter")

local PositionService = {}

local positionCache = {}

function PositionService.ClearCache()
  positionCache = {}
end

function PositionService.FindPosition(limit_kind, currentbal)
  if limit_kind == 2 and tonumber(currentbal) ~= 0 then
    return true
  end
  return false
end

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

-- Global wrappers for backward compatibility
function FindPosition(limit_kind, currentbal)
  return PositionService.FindPosition(limit_kind, currentbal)
end

function ClearPositionCache()
  PositionService.ClearCache()
end

function GetPosition(securityCode)
  return PositionService.GetPosition(securityCode)
end

return PositionService
