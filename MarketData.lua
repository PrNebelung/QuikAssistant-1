local BrokerAdapter = require("BrokerAdapter")

local MarketData = {}

function MarketData.GetParamInfo(order, param)
  return BrokerAdapter.GetParamInfo(order, param)
end

function MarketData.GetPriceLast(order)
  local priceLast = MarketData.GetParamInfo(order, "LAST")
  if tonumber(priceLast) == 0 then
    priceLast = MarketData.GetPricePrev(order)
  end
  return priceLast
end

function MarketData.GetPriceMin(order)
  return MarketData.GetParamInfo(order, "PRICEMIN")
end

function MarketData.GetPriceMax(order)
  return MarketData.GetParamInfo(order, "PRICEMAX")
end

function MarketData.GetPricePrev(order)
  return MarketData.GetParamInfo(order, "PREVPRICE")
end

-- Global wrappers for backward compatibility
function GetParamInfo(order, param)
  return MarketData.GetParamInfo(order, param)
end

function GetPriceLast(order)
  return MarketData.GetPriceLast(order)
end

function GetPriceMin(order)
  return MarketData.GetPriceMin(order)
end

function GetPriceMax(order)
  return MarketData.GetPriceMax(order)
end

function GetPricePrev(order)
  return MarketData.GetPricePrev(order)
end

return MarketData
