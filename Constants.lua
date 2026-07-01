--- Глобальные константы QUIK.
--- Содержит основные константы QUIK (FLAG_ACTIVE, FLAG_SELL и др.),
--- коды ошибок (ERR_PRICE_TOO_LOW и др.), статусы транзакций
--- и пороговые значения для расчётов.

local Constants = {}

-- ==========================================
-- Флаги ордеров QUIK
-- ==========================================
Constants.FLAG_ACTIVE = 0x1
Constants.FLAG_EXECUTED = 0x2
Constants.FLAG_SELL = 0x4

-- ==========================================
-- Коды ошибок QUIK
-- ==========================================
Constants.ERR_PRICE_TOO_LOW = 579
Constants.ERR_PRICE_TOO_HIGH = 580
Constants.ERR_EXECUTION_REJECTED = 133

-- ==========================================
-- Статусы транзакций
-- ==========================================
Constants.TRANS_STATUS_COMPLETED = 3

-- ==========================================
-- Пороговые значения
-- ==========================================
Constants.PRICE_DEVIATION_MULTIPLIER = 10

--- Продвижение Constants.* в глобальное пространство (FLAG_ACTIVE и др.) для обратной совместимости.
function _initConstants()
  FLAG_ACTIVE = Constants.FLAG_ACTIVE
  FLAG_EXECUTED = Constants.FLAG_EXECUTED
  FLAG_SELL = Constants.FLAG_SELL
  ERR_PRICE_TOO_LOW = Constants.ERR_PRICE_TOO_LOW
  ERR_PRICE_TOO_HIGH = Constants.ERR_PRICE_TOO_HIGH
  ERR_EXECUTION_REJECTED = Constants.ERR_EXECUTION_REJECTED
  TRANS_STATUS_COMPLETED = Constants.TRANS_STATUS_COMPLETED
  PRICE_DEVIATION_MULTIPLIER = Constants.PRICE_DEVIATION_MULTIPLIER
end

_initConstants()

return Constants
