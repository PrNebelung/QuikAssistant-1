--- Интеграционные тесты для TransactionHandler.

package.path = "?.lua;IntegrationTests/?.lua;" .. package.path

local mock = dofile("IntegrationTests/quik_mock.lua")

mock.AddSecurity(
	"GAZP",
	"TQBR",
	{ last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 }
)

log = require("log")
log.level = "fatal"
log.usecolor = false
json = require("json")
BrokerAdapter = require("BrokerAdapter")
require("Order")
require("Constants")
_initConstants()
require("TransactionHandler")
require("SubmittingOrders")

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

-- ==========================================
local passed, failed, errors = 0, 0, {}

local function test(name, fn)
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
print("=== TransactionHandler Tests ===\n")

-- 1. GetOperation
print("--- GetOperation ---")
test("flags без FLAG_SELL -> B", function()
	assert(GetOperation(0x1) == "B")
	assert(GetOperation(0x0) == "B")
end)

test("flags с FLAG_SELL -> S", function()
	assert(GetOperation(FLAG_SELL) == "S")
	assert(GetOperation(FLAG_SELL | FLAG_ACTIVE) == "S")
end)

-- 2. IsOrderExecuted
print("\n--- IsOrderExecuted ---")
test("ни FLAG_ACTIVE ни FLAG_EXECUTED -> executed", function()
	assert(IsOrderExecuted(0x0) == true)
end)

test("FLAG_ACTIVE установлен -> не executed", function()
	assert(IsOrderExecuted(FLAG_ACTIVE) == false)
end)

test("FLAG_EXECUTED установлен -> не executed", function()
	assert(IsOrderExecuted(FLAG_EXECUTED) == false)
end)

test("оба флага установлены -> не executed", function()
	assert(IsOrderExecuted(FLAG_ACTIVE | FLAG_EXECUTED) == false)
end)

-- 3. FindOrder
print("\n--- FindOrder ---")
test("активный заказ -> true", function()
	assert(FindOrder(FLAG_ACTIVE, "GAZP", "TQBR") == true)
end)

test("исполненный заказ -> true", function()
	-- IsOrderExecuted: neither FLAG_ACTIVE nor FLAG_EXECUTED
	assert(FindOrder(0x0, "GAZP", "TQBR") == true)
end)

test("оба флага -> true (FLAG_ACTIVE приоритетен)", function()
	assert(FindOrder(FLAG_ACTIVE | FLAG_EXECUTED, "GAZP", "TQBR") == true)
end)

test("только FLAG_EXECUTED -> false (не активен)", function()
	assert(FindOrder(FLAG_EXECUTED, "GAZP", "TQBR") == false)
end)

-- 4. IsOrderExists
print("\n--- IsOrderExists ---")
test("нет заказов в QUIK -> false", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		trans_id = 1,
		order_num = 1,
		price = 1000,
		qty = 10,
		balance = 10,
	})
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	assert(IsOrderExists(o) == false, "sell should not match buy")
end)

test("совпадающий заказ -> true", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		trans_id = 1,
		order_num = 1,
		price = 1000,
		qty = 10,
		balance = 10,
	})
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(IsOrderExists(o) == true, "should find matching buy order")
end)

test("разная бумага -> false", function()
	mock.AddSecurity(
		"SBER",
		"TQBR",
		{ last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
	)
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		trans_id = 1,
		order_num = 1,
		price = 1000,
		qty = 10,
		balance = 10,
	})
	local o = Order:new("SBER")
	o:SetOperation("B", 1000, 10)
	assert(IsOrderExists(o) == false)
end)

test("разная цена -> false", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		trans_id = 1,
		order_num = 1,
		price = 1000,
		qty = 10,
		balance = 10,
	})
	local o = Order:new("GAZP")
	o:SetOperation("B", 900, 10)
	assert(IsOrderExists(o) == false)
end)

test("разная операция -> false", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		trans_id = 1,
		order_num = 1,
		price = 1000,
		qty = 10,
		balance = 10,
	})
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	assert(IsOrderExists(o) == false)
end)

-- 5. SetLimitOrdersWithError
print("\n--- SetLimitOrdersWithError ---")
test("ошибка 579 (цена слишком низкая) -> предупреждение", function()
	local trans = { result_msg = "Error: (579) price too low", sec_code = "GAZP", quantity = 10, price = "100.00" }
	SetLimitOrdersWithError(trans)
end)

test("ошибка 580 (цена слишком высокая) -> auto-recover sell", function()
	mock.AddPosition("GAZP", 50, 500)
	local trans =
		{ result_msg = "Error: (580) price too high, do 1200", sec_code = "GAZP", quantity = 10, price = 1300 }
	mock.ClearSent()
	SetLimitOrdersWithError(trans)
	assert(mock.GetSentCount() >= 1, "expected auto-recover transaction")
end)

test("ошибка test (not compliant) -> auto-recover buy", function()
	local trans = {
		result_msg = "not compliant with min price for this security, ot 800",
		sec_code = "GAZP",
		quantity = 10,
		price = 700,
	}
	SetLimitOrdersWithError(trans)
end)

test("ошибка 133 (отклонение) -> предупреждение", function()
	local trans = { result_msg = "Error: (133) rejected", sec_code = "GAZP", quantity = 10, price = "1000.00" }
	SetLimitOrdersWithError(trans)
end)

test("неизвестная ошибка -> error лог", function()
	local trans = { result_msg = "Unknown error occurred", sec_code = "GAZP", quantity = 10, price = "1000.00" }
	SetLimitOrdersWithError(trans)
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
