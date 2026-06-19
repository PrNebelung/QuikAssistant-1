--- Получение рыночных данных из QUIK.
--- Предоставляет функции GetPriceLast, GetPriceMin, GetPriceMax,
--- GetPricePrev для получения текущей, минимальной, максимальной
--- и предыдущей цены инструмента.


local BrokerAdapter = require("BrokerAdapter")

local MarketData = {}

--- Получает параметр инструмента (делегирует в BrokerAdapter.GetParamInfo).
function MarketData.GetParamInfo(order, param)
  return BrokerAdapter.GetParamInfo(order, param)
end

--- Получает последнюю цену. Если LAST = 0, возвращает PREVPRICE.
function MarketData.GetPriceLast(order)
  local priceLast = MarketData.GetParamInfo(order, "LAST")
  if tonumber(priceLast) == 0 then
    priceLast = MarketData.GetPricePrev(order)
  end
  return priceLast
end

--- Получает минимальную цену (PRICEMIN) — нижнюю границу стакана.
function MarketData.GetPriceMin(order)
  return MarketData.GetParamInfo(order, "PRICEMIN")
end

--- Получает максимальную цену (PRICEMAX) — верхнюю границу стакана.
function MarketData.GetPriceMax(order)
  return MarketData.GetParamInfo(order, "PRICEMAX")
end

--- Получает цену предыдущего закрытия (PREVPRICE).
function MarketData.GetPricePrev(order)
  return MarketData.GetParamInfo(order, "PREVPRICE")
end

-- Глобальные обёртки для обратной совместимости
--- Глобальная обёртка для MarketData.GetParamInfo (обратная совместимость).
function GetParamInfo(order, param)
  return MarketData.GetParamInfo(order, param)
end

--- Глобальная обёртка для MarketData.GetPriceLast.
function GetPriceLast(order)
  return MarketData.GetPriceLast(order)
end

--- Глобальная обёртка для MarketData.GetPriceMin.
function GetPriceMin(order)
  return MarketData.GetPriceMin(order)
end

--- Глобальная обёртка для MarketData.GetPriceMax.
function GetPriceMax(order)
  return MarketData.GetPriceMax(order)
end

--- Глобальная обёртка для MarketData.GetPricePrev.
function GetPricePrev(order)
  return MarketData.GetPricePrev(order)
end

return MarketData
