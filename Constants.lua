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

-- ==========================================
-- Временные константы
-- ==========================================
Constants.SLEEP_MAIN_LOOP_MS = 1000
Constants.SLEEP_ERROR_MS = 5000
Constants.SLEEP_BETWEEN_FILES_MS = 3000
Constants.SLEEP_SHORT_MS = 1000

-- ==========================================
-- Константы повторных попыток
-- ==========================================
Constants.MARKET_DATA_MAX_RETRIES = 30
Constants.MARKET_DATA_RETRY_INTERVAL_S = 2
Constants.MAX_RECURSION_DEPTH = 3

-- ==========================================
-- Пороги цвета и лимиты
-- ==========================================
Constants.ACTUATION_COLOR_RED = 2
Constants.ACTUATION_COLOR_YELLOW = 5
Constants.BOND_MAX_PRICE_PERCENT = 100.0
Constants.RETRY_LOG_INTERVAL = 5
Constants.TRADE_CLOSE_SLEEP_MS = 500

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
	SLEEP_MAIN_LOOP_MS = Constants.SLEEP_MAIN_LOOP_MS
	SLEEP_ERROR_MS = Constants.SLEEP_ERROR_MS
	SLEEP_BETWEEN_FILES_MS = Constants.SLEEP_BETWEEN_FILES_MS
	SLEEP_SHORT_MS = Constants.SLEEP_SHORT_MS
	MARKET_DATA_MAX_RETRIES = Constants.MARKET_DATA_MAX_RETRIES
	MARKET_DATA_RETRY_INTERVAL_S = Constants.MARKET_DATA_RETRY_INTERVAL_S
	MAX_RECURSION_DEPTH = Constants.MAX_RECURSION_DEPTH
	ACTUATION_COLOR_RED = Constants.ACTUATION_COLOR_RED
	ACTUATION_COLOR_YELLOW = Constants.ACTUATION_COLOR_YELLOW
	BOND_MAX_PRICE_PERCENT = Constants.BOND_MAX_PRICE_PERCENT
	RETRY_LOG_INTERVAL = Constants.RETRY_LOG_INTERVAL
	TRADE_CLOSE_SLEEP_MS = Constants.TRADE_CLOSE_SLEEP_MS
end

_initConstants()

return Constants
