--- Корректировщик цен ордеров.
--- Автоматически корректирует цену покупки/продажи относительно
--- последней цены (LAST) и минимального шага цены (PRICEMIN).
--- Не изменяет цены, заданные из файла (UseFileParams).


local MarketData = require("MarketData")
local Constants = require("Constants")

local PriceAdjuster = {}

--- Корректирует цену ордера.
--- Для покупки: если LAST < цена, снижает на 10 шагов;
--- если цена < PRICEMIN, ставит PRICEMIN.
--- Для продажи: если LAST > цена, повышает на 10 шагов.
--- Не трогает цены из файла (UseFileParams).

function PriceAdjuster.AdjustPrice(order)
  if order.UseFileParams then
    return
  end

  local priceLast = MarketData.GetPriceLast(order)

  if order:IsBuy() then
    if tonumber(priceLast) < tonumber(order.Price) and tonumber(priceLast) ~= 0 then
      order.Price = priceLast - Constants.PRICE_DEVIATION_MULTIPLIER * order.SecurityInfo.min_price_step
    end
    local priceMin = tonumber(MarketData.GetPriceMin(order))
    if priceMin ~= nil and priceMin > 0 and tonumber(order.Price) < priceMin then
      order.Price = priceMin
      order:GetPriceRound()
    end
  end

  if order:IsSell() then
    if tonumber(priceLast) > tonumber(order.Price) and tonumber(priceLast) ~= 0 then
      order.Price = priceLast + Constants.PRICE_DEVIATION_MULTIPLIER * order.SecurityInfo.min_price_step
    end
  end
end

--- Глобальная обёртка для PriceAdjuster.AdjustPrice.
function AdjustPrice(order)
  PriceAdjuster.AdjustPrice(order)
end

return PriceAdjuster
