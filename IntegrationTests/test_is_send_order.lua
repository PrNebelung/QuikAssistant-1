--- Интеграционные тесты для IsSendOrder.

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
require("Order")
require("SubmittingOrders")

-- ==========================================
local passed, failed, errors = 0, 0, {}

local function test(name, fn)
	sendOrdersSet = {}
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		table.insert(errors, string.format("FAIL: %s - %s", name, tostring(err)))
		print("  FAIL: " .. name)
	end
end

local function mkOrder(sec, op, price, qty)
	local o = Order:new(sec)
	o:SetOperation(op, price, qty)
	return o
end

-- ==========================================
print("=== IsSendOrder Tests ===\n")

print("--- Основные случаи ---")
test("заявка не отправлена -> false", function()
	local o = mkOrder("GAZP", "B", 1000, 10)
	assert(IsSendOrder(o) == false)
end)

test("заявка отправлена -> true", function()
	local o = mkOrder("GAZP", "B", 1000, 10)
	sendOrdersSet[o:GetDedupKey()] = true
	assert(IsSendOrder(o) == true)
end)

test("sendOrdersSet пуст -> false", function()
	sendOrdersSet = {}
	local o = mkOrder("GAZP", "B", 1000, 10)
	assert(IsSendOrder(o) == false)
end)

print("\n--- DedupKey ---")
test("разная qty -> разный ключ", function()
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("GAZP", "B", 1000, 20)
	sendOrdersSet[o1:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == false)
end)

test("разная цена -> разный ключ", function()
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("GAZP", "B", 900, 10)
	sendOrdersSet[o1:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == false)
end)

test("разная бумага -> разный ключ", function()
	mock.AddSecurity(
		"SBER",
		"TQBR",
		{ last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
	)
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("SBER", "B", 1000, 10)
	sendOrdersSet[o1:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == false)
end)

test("разная операция -> разный ключ", function()
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("GAZP", "S", 1000, 10)
	sendOrdersSet[o1:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == false)
end)

test("одинаковые заявки -> один ключ", function()
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("GAZP", "B", 1000, 10)
	sendOrdersSet[o1:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == true)
end)

print("\n--- Очистка ---")
test("очистка sendOrdersSet -> false", function()
	local o = mkOrder("GAZP", "B", 1000, 10)
	sendOrdersSet[o:GetDedupKey()] = true
	assert(IsSendOrder(o) == true)
	sendOrdersSet = {}
	assert(IsSendOrder(o) == false)
end)

test("множество заявок, удаление одной", function()
	mock.AddSecurity(
		"SBER",
		"TQBR",
		{ last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
	)
	local o1 = mkOrder("GAZP", "B", 1000, 10)
	local o2 = mkOrder("SBER", "B", 300, 10)
	sendOrdersSet[o1:GetDedupKey()] = true
	sendOrdersSet[o2:GetDedupKey()] = true
	assert(IsSendOrder(o1) == true)
	assert(IsSendOrder(o2) == true)
	sendOrdersSet[o1:GetDedupKey()] = nil
	assert(IsSendOrder(o1) == false)
	assert(IsSendOrder(o2) == true)
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
