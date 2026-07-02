--- »нтеграционные тесты дл€ IsOrderExists и AdjustPrice.

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
require("Constants")
_initConstants()
Config = require("Config")
require("TransactionHandler")

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
	PositionService.ClearCache()
	mock.Reset()
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
-- IsOrderExists Tests
-- ==========================================
print("=== IsOrderExists Tests ===\n")

print("--- јктивные ордера ---")
test("Ќайти активный BUY ордер в QUIK", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_ACTIVE, price = "1000.00", qty = 10 })
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	if not IsOrderExists(o) then
		error("ожидалось совпадение с активным ордером")
	end
end)

test("Ќе найти ордер когда QUIK пуст", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	if IsOrderExists(o) then
		error("не ожидалось совпадение Ч QUIK пуст")
	end
end)

test("Ќе найти ордер с другой ценой", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_ACTIVE, price = "1000.00", qty = 10 })
	local o = Order:new("GAZP")
	o:SetOperation("B", 999, 10)
	if IsOrderExists(o) then
		error("не ожидалось совпадение Ч цена отличаетс€")
	end
end)

test("Ќе найти ордер с другой операцией", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_ACTIVE, price = "1000.00", qty = 10 })
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	if IsOrderExists(o) then
		error("не ожидалось совпадение Ч операци€ отличаетс€")
	end
end)

test("Ќе найти ордер с другим инструментом", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_ACTIVE, price = "1000.00", qty = 10 })
	local o = Order:new("SBER")
	o:SetOperation("B", 300, 10)
	if IsOrderExists(o) then
		error("не ожидалось совпадение Ч другой инструмент")
	end
end)

test("Ќайти среди нескольких ордеров", function()
	mock.AddOrder({ sec_code = "SBER", class_code = "TQBR", flags = FLAG_ACTIVE, price = "300.00", qty = 5 })
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_ACTIVE, price = "1000.00", qty = 10 })
	mock.AddOrder({ sec_code = "SBER", class_code = "TQBR", flags = FLAG_ACTIVE, price = "250.00", qty = 20 })
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	if not IsOrderExists(o) then
		error("ожидалось совпадение среди нескольких ордеров")
	end
end)

print("\n--- »сполненные/отменЄнные ордера ---")
test("Ќайти исполненный ордер (flags=24, ни ACTIVE ни EXECUTED)", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = 24, price = "1000.00", qty = 10 })
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	if not IsOrderExists(o) then
		error("ожидалось совпадение с ордером flags=24")
	end
end)

test("Ќе найти ордер с флагом EXECUTED (flags=2)", function()
	mock.AddOrder({ sec_code = "GAZP", class_code = "TQBR", flags = FLAG_EXECUTED, price = "1000.00", qty = 10 })
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	if IsOrderExists(o) then
		error("не ожидалось совпадение Ч ордер исполнен (FLAG_EXECUTED)")
	end
end)

print("\n--- Sell ордера ---")
test("Ќайти активный SELL ордер", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE + FLAG_SELL,
		price = "1100.00",
		qty = 5,
	})
	local o = Order:new("GAZP")
	o:SetOperation("S", 1100, 5)
	if not IsOrderExists(o) then
		error("ожидалось совпадение с SELL ордером")
	end
end)

-- ==========================================
-- AdjustPrice Tests
-- ==========================================
print("\n\n=== AdjustPrice Tests ===\n")

print("--- UseFileParams ---")
test("Ќе корректировать цену если UseFileParams=true", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 950, 10)
	o.UseFileParams = true
	AdjustPrice(o)
	if tonumber(o.Price) ~= 950 then
		error("цена не должна мен€тьс€: ожидалось 950, получено " .. o.Price)
	end
end)

print("\n--- ѕокупка ---")
test(" упить: цена выше LAST -> понизить до LAST - 10*шаг", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1100, 10)
	AdjustPrice(o)
	local expected = 1000 - 10 * 0.1
	if math.abs(tonumber(o.Price) - expected) > 0.01 then
		error(string.format("ожидалось %.2f, получено %s", expected, o.Price))
	end
end)

test(" упить: цена ниже LAST -> не понижать", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 900, 10)
	AdjustPrice(o)
	if tonumber(o.Price) ~= 900 then
		error("цена не должна мен€тьс€: ожидалось 900, получено " .. o.Price)
	end
end)

test(" упить: цена ниже PRICEMIN -> подн€ть до PRICEMIN", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 500, 10)
	AdjustPrice(o)
	if tonumber(o.Price) ~= 800 then
		error("цена должна быть PRICEMIN: ожидалось 800, получено " .. o.Price)
	end
end)

print("\n--- ѕродажа ---")
test("ѕродать: цена ниже LAST -> повысить до LAST + 10*шаг", function()
	local o = Order:new("GAZP")
	o:SetOperation("S", 900, 10)
	AdjustPrice(o)
	local expected = 1000 + 10 * 0.1
	if math.abs(tonumber(o.Price) - expected) > 0.01 then
		error(string.format("ожидалось %.2f, получено %s", expected, o.Price))
	end
end)

test("ѕродать: цена выше LAST -> не повышать", function()
	local o = Order:new("GAZP")
	o:SetOperation("S", 1100, 10)
	AdjustPrice(o)
	if tonumber(o.Price) ~= 1100 then
		error("цена не должна мен€тьс€: ожидалось 1100, получено " .. o.Price)
	end
end)

-- ==========================================
-- »тоги
-- ==========================================
print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if #errors > 0 then
	print("\nFailures:")
	for _, e in ipairs(errors) do
		print("  " .. e)
	end
end
os.exit(failed > 0 and 1 or 0)
