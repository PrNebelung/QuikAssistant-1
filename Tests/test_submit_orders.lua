--- Интеграционные тесты для SubmitOrders.

package.path = "?.lua;Tests/?.lua;" .. package.path

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
mock.AddSecurity("RU000A10BFF4", "TQCB", {
	last = 100,
	pricemin = 80,
	pricemax = 120,
	lot = 1000,
	scale = 2,
	min_price_step = 0.01,
	facevalue = 1000,
	face_unit = "SUR",
})

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

function IsOrderExists(newOrder)
	for _, order in ipairs(N_Orders) do
		if order.sec_code == newOrder.SecurityCode and order.operation == newOrder.Operation then
			return true
		end
	end
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
	N_TransReplies = {}
	N_LastTransID = 0

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
	mock.AddSecurity("RU000A10BFF4", "TQCB", {
		last = 100,
		pricemin = 80,
		pricemax = 120,
		lot = 1000,
		scale = 2,
		min_price_step = 0.01,
		facevalue = 1000,
		face_unit = "SUR",
	})

	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		table.insert(errors, string.format("FAIL: %s - %s", name, tostring(err)))
		print("  FAIL: " .. name)
	end
end

local function mk(sec, op, price, qty, useFile)
	local o = Order:new(sec)
	o:SetOperation(op, price, qty)
	if useFile then
		o.UseFileParams = true
	end
	return o
end

-- ==========================================
-- Тесты
-- ==========================================
print("=== SubmitOrders Tests ===\n")

print("--- Основная отправка ---")
test("одна валидная заявка -> sent=1", function()
	local s = SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	assert(s.sent == 1, "expected sent=1, got " .. s.sent)
end)

test("две разные заявки -> sent=2", function()
	-- GAZP в списке исключений (actuation пропускается)
	-- SBER: price=280, LAST=300 -> actuation=7.14% > 5% -> pass
	local s = SubmitOrders({ mk("GAZP", "B", 1000, 10), mk("SBER", "B", 280, 10) })
	assert(s.sent == 2, "expected sent=2, got " .. s.sent)
end)

test("пустой список -> sent=0", function()
	local s = SubmitOrders({})
	assert(s.sent == 0, "expected sent=0")
end)

print("\n--- Отклонение (CheckOrder) ---")
test("qty=0 -> rejected", function()
	local o = Order:new("GAZP")
	o.Price = 500
	o.Quantity = 0
	o.Operation = "B"
	local s = SubmitOrders({ o })
	assert(s.rejected == 1, "expected rejected=1, got " .. s.rejected)
end)

test("ниже PRICEMIN -> AdjustPrice поднимает до PRICEMIN", function()
	local o = mk("GAZP", "B", 500, 10)
	SubmitOrders({ o })
	assert(o.Price == 800, "expected price=800 after adjust, got " .. tostring(o.Price))
end)

test("смешанный: AdjustPrice + CheckOrder", function()
	-- GAZP B 1000 -> pass (exception)
	-- GAZP B 500 -> AdjustPrice raises to 800, then passes
	local s = SubmitOrders({ mk("GAZP", "B", 1000, 10), mk("GAZP", "B", 500, 10) })
	assert(s.sent == 2, "expected sent=2, got " .. s.sent)
end)

test("sell без позиции -> rejected", function()
	local s = SubmitOrders({ mk("GAZP", "S", 1000, 10) })
	assert(s.rejected == 1, "expected rejected=1")
end)

print("\n--- Дубликаты ---")
test("одинаковые заявки -> duplicate=1", function()
	local s = SubmitOrders({ mk("GAZP", "B", 1000, 10), mk("GAZP", "B", 1000, 10) })
	assert(s.sent == 1, "expected sent=1")
	assert(s.duplicate == 1, "expected duplicate=1")
end)

test("повторная отправка -> duplicate", function()
	SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	local s = SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	assert(s.sent == 0, "expected sent=0")
	assert(s.duplicate == 1, "expected duplicate=1")
end)

print("\n--- AdjustPrice ---")
test("buy: цена < PRICEMIN -> цена = PRICEMIN", function()
	local o = mk("GAZP", "B", 700, 10)
	SubmitOrders({ o })
	assert(o.Price == 800, "expected 800, got " .. tostring(o.Price))
end)

test("sell: LAST > цена -> цена повышается", function()
	mock.AddPosition("GAZP", 100, 500)
	mock.securities["GAZP"]["TQBR"].params.LAST = "1100"
	local o = mk("GAZP", "S", 1000, 10)
	SubmitOrders({ o })
	assert(o.Price == 1101, "expected 1101, got " .. tostring(o.Price))
end)

test("UseFileParams -> цена не корректируется", function()
	local o = mk("GAZP", "B", 500, 10, true)
	SubmitOrders({ o })
	assert(o.Price == 500, "expected 500, got " .. tostring(o.Price))
end)

print("\n--- sendOrdersSet ---")
test("отправленная заявка в sendOrdersSet", function()
	SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	assert(sendOrdersSet["GAZP B 10 1000.00"] == true, "expected key in sendOrdersSet")
end)

test("sendOrders содержит отправленные", function()
	SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	assert(#sendOrders == 1, "expected 1 in sendOrders")
	assert(sendOrders[1].SecurityCode == "GAZP")
	assert(sendOrders[1].Operation == "B")
end)

print("\n--- SendTransaction ---")
test("заявка через sendTransaction", function()
	SubmitOrders({ mk("GAZP", "B", 1000, 10) })
	local txns = mock.GetSentTransactions()
	assert(#txns == 1, "expected 1 transaction")
	assert(txns[1].SECCODE == "GAZP")
	assert(txns[1].OPERATION == "B")
	assert(txns[1].ACTION == "NEW_ORDER")
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
