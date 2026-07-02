--- Интеграционные тесты для TradeClosePosition.

package.path = "?.lua;Tests/?.lua;libs/?.lua;utils/?.lua;" .. package.path

local mock = dofile("Tests/quik_mock.lua")

mock.AddSecurity(
	"GAZP",
	"TQBR",
	{ last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 }
)
mock.AddSecurity(
	"SBER",
	"TQBR",
	{ last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
)

log = require("log")
log.level = "fatal"
log.usecolor = false
json = require("json")
BrokerAdapter = require("BrokerAdapter")
MarketData = require("MarketData")
PositionService = require("PositionService")
require("Order")
require("OrderValidator")
require("PriceAdjuster")
require("Constants")
_initConstants()
Config = require("Config")

-- Мокаем N_SetLimitOrder
N_Orders = {}
N_LastOrderNum = 0
N_TransReplies = {}
N_LastTransID = 0
function N_SetLimitOrder(ac, cc, class, sec, op, price, qty)
	N_LastOrderNum = N_LastOrderNum + 1
	N_LastTransID = N_LastTransID + 1
	table.insert(N_Orders, {
		trans_id = N_LastTransID,
		order_num = N_LastOrderNum,
		sec_code = sec,
		class_code = class,
		operation = op,
		price = price,
		quantity = qty,
		balance = qty,
	})
	BrokerAdapter.SendTransaction({ ACTION = "NEW_ORDER", SECCODE = sec, OPERATION = op, PRICE = price, QUANTITY = qty })
	return N_LastTransID, ""
end
function IsOrderExists(o)
	return false
end

require("SubmittingOrders")

-- ==========================================
-- Утилиты
-- ==========================================
local passed, failed, errors = 0, 0, {}

local function test(name, fn)
	PositionService.ClearCache()
	mock.Reset()
	mock.ClearSent()
	sendOrders = {}
	sendOrdersSet = {}
	N_Orders = {}
	N_LastOrderNum = 0

	mock.AddSecurity(
		"GAZP",
		"TQBR",
		{ last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 }
	)
	mock.AddSecurity(
		"SBER",
		"TQBR",
		{ last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
	)

	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		table.insert(errors, string.format("FAIL: %s - %s", name, tostring(err)))
		print("  FAIL: " .. name)
	end
end

-- ==========================================
-- Тесты
-- ==========================================
print("=== TradeClosePosition Tests ===\n")

print("--- Определение стороны сделки ---")
test("buy trade -> создаёт sell order", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 1, "expected 1 order, got " .. #N_Orders)
	assert(N_Orders[1].operation == "S", "expected S, got " .. N_Orders[1].operation)
	assert(N_Orders[1].sec_code == "GAZP", "expected GAZP")
end)

test("sell trade -> ничего не делает", function()
	local trade = { sec_code = "GAZP", buy_sell = "S", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 0, "expected 0 orders")
end)

test("trade с flags FLAG_SELL -> ничего не делает", function()
	local trade = { sec_code = "GAZP", buy_sell = nil, qty = "10", price = 1000, flags = FLAG_SELL }
	TradeClosePosition(trade)
	assert(#N_Orders == 0, "expected 0 orders")
end)

test("trade без buy_sell, без FLAG_SELL -> buy", function()
	local trade = { sec_code = "GAZP", buy_sell = nil, qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 1, "expected 1 order")
	assert(N_Orders[1].operation == "S")
end)

print("\n--- Неизвестная бумага ---")
test("неизвестный sec_code -> ничего не делает", function()
	local trade = { sec_code = "UNKNOWN", buy_sell = "B", qty = "10", price = 100, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 0, "expected 0 orders")
end)

print("\n--- Цена продажи (PRICEMAX) ---")
test("PRICEMAX=1200 -> sell по 1200", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 1)
	assert(N_Orders[1].price == "1200.00", "expected price 1200, got " .. tostring(N_Orders[1].price))
end)

test("PRICEMAX=0 -> ничего не делает", function()
	mock.securities["GAZP"]["TQBR"].params.PRICEMAX = "0"
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#N_Orders == 0, "expected 0 orders when PRICEMAX=0")
	mock.securities["GAZP"]["TQBR"].params.PRICEMAX = "1200"
end)

print("\n--- Формирование ордера ---")
test("quantity из сделки", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "25", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(N_Orders[1].quantity == "25", "expected qty 25, got " .. tostring(N_Orders[1].quantity))
end)

test("operation = S", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(N_Orders[1].operation == "S")
end)

test("sendOrders содержит запись", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(#sendOrders == 1, "expected 1 in sendOrders")
	assert(sendOrders[1].SecurityCode == "GAZP")
	assert(sendOrders[1].Operation == "S")
end)

test("sendOrdersSet содержит ключ", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	local found = false
	for k, v in pairs(sendOrdersSet) do
		if string.find(k, "GAZP") and string.find(k, "S") then
			found = true
		end
	end
	assert(found, "expected GAZP S in sendOrdersSet")
end)

test("sendTransaction вызван", function()
	local trade = { sec_code = "GAZP", buy_sell = "B", qty = "10", price = 1000, flags = 0 }
	TradeClosePosition(trade)
	assert(mock.GetSentCount() == 1, "expected 1 transaction")
end)

-- ==========================================
print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if #errors > 0 then
	print("\nFailures:")
	for _, e in ipairs(errors) do
		print("  " .. e)
	end
end
os.exit(failed > 0 and 1 or 0)
