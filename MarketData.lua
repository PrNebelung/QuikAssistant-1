--- и предыдущей цены инструмента.

local BrokerAdapter = require("BrokerAdapter")

local MarketData = {}

--- Получение информации о параметре для ордера (делегирует в BrokerAdapter).
--- @param table Объект Order
--- @param string Имя параметра
--- @return string Значение параметра
function MarketData.GetParamInfo(order, param)
  return BrokerAdapter.GetParamInfo(order, param)
end

--- Получение последней цены сделки. Если LAST=0, использует PREVPRICE.
--- @param table Объект Order
--- @return string Последняя цена или "0"
function MarketData.GetPriceLast(order)
  local priceLast = MarketData.GetParamInfo(order, "LAST")
  if tonumber(priceLast) == 0 then
    priceLast = MarketData.GetPricePrev(order)
  end
  return priceLast or "0"
end

--- Получение минимальной цены (PRICEMIN) для расчёта нижней границы.
--- @param table Объект Order
--- @return string Минимальная цена
function MarketData.GetPriceMin(order)
  return MarketData.GetParamInfo(order, "PRICEMIN")
end

--- Получение максимальной цены (PRICEMAX) для расчёта верхней границы.
--- @param table Объект Order
--- @return string Максимальная цена
function MarketData.GetPriceMax(order)
  return MarketData.GetParamInfo(order, "PRICEMAX")
end

--- Получение цены закрытия предыдущей сессии (PREVPRICE).
--- @param table Объект Order
--- @return string Цена предыдущей сессии
function MarketData.GetPricePrev(order)
  return MarketData.GetParamInfo(order, "PREVPRICE")
end

--- Глобальная обёртка для MarketData.GetParamInfo (обратная совместимость).
--- @param table Объект Order
--- @param string Имя параметра
--- @return string Значение параметра
function GetParamInfo(order, param)
  return MarketData.GetParamInfo(order, param)
end

--- Глобальная обёртка для MarketData.GetPriceLast (обратная совместимость).
--- @param table Объект Order
--- @return string Последняя цена
function GetPriceLast(order)
  return MarketData.GetPriceLast(order)
end

--- Глобальная обёртка для MarketData.GetPriceMin (обратная совместимость).
--- @param table Объект Order
--- @return string Минимальная цена
function GetPriceMin(order)
  return MarketData.GetPriceMin(order)
end

--- Глобальная обёртка для MarketData.GetPriceMax (обратная совместимость).
--- @param table Объект Order
--- @return string Максимальная цена
function GetPriceMax(order)
  return MarketData.GetPriceMax(order)
end

--- Глобальная обёртка для MarketData.GetPricePrev (обратная совместимость).
--- @param table Объект Order
--- @return string Цена предыдущей сессии
function GetPricePrev(order)
  return MarketData.GetPricePrev(order)
end

return MarketData
