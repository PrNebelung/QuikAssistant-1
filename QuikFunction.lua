-- Реализация разделена на:

--- Фасад для обратной совместимости.
--- Объединяет require-ы всех сервисных модулей:
--- MarketData, PositionService, OrderValidator, TransactionHandler.


require("MarketData")
require("PositionService")
require("OrderValidator")
require("TransactionHandler")
