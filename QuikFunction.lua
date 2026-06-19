-- QuikFunction.lua - Facade for backward compatibility
-- Actual implementation split into:
--   MarketData.lua      - price queries (GetPriceLast, GetPriceMin, GetPriceMax, GetPricePrev)
--   PositionService.lua - position cache and lookup (GetPosition, ClearPositionCache)
--   OrderValidator.lua  - order validation and price adjustment (CheckOrder, AdjustPrice)
--   TransactionHandler.lua - QUIK order operations (IsOrderExists, FindOrder, SetLimitOrdersWithError)

--- Фасад для обратной совместимости.
--- Объединяет require-ы всех сервисных модулей:
--- MarketData, PositionService, OrderValidator, TransactionHandler.


require("MarketData")
require("PositionService")
require("OrderValidator")
require("TransactionHandler")
