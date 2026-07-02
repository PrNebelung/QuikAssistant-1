--- Legacy unit tests migrated from Tests/run_tests.lua
--- Adapted for Tests quik_mock environment

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
require("TransactionHandler")
require("PriceAdjuster")
SessionScheduler = require("SessionScheduler")
require("Constants")
_initConstants()
Config = require("Config")
require("TableConstructor")
require("SubmittingOrders")

-- Config setup for tests
Config.VolumeOrderMax = 11000
Config.BondVolumeOrderMax = 7000
Config.VolumeOrderLimit = 200000
Config.LimitActuationOrderEdge = 5
Config.LimitActuationOrderBondEdge = 60

local passed, failed, errors = 0, 0, {}

local function assert_eq(actual, expected, msg)
	if actual == expected then
		passed = passed + 1
	else
		failed = failed + 1
		local err = string.format(
			"FAIL: %s (expected: %s, actual: %s)",
			msg or "",
			tostring(expected),
			tostring(actual)
		)
		table.insert(errors, err)
		print("  " .. err)
	end
end

local function assert_true(value, msg)
	if value == true then
		passed = passed + 1
	else
		failed = failed + 1
		local err =
			string.format("FAIL: %s (expected: true, actual: %s)", msg or "", tostring(value))
		table.insert(errors, err)
		print("  " .. err)
	end
end

local function assert_false(value, msg)
	if value == false then
		passed = passed + 1
	else
		failed = failed + 1
		local err =
			string.format("FAIL: %s (expected: false, actual: %s)", msg or "", tostring(value))
		table.insert(errors, err)
		print("  " .. err)
	end
end

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

---------------------------------------------
-- TableConstructor functions
---------------------------------------------
print("=== TableConstructor functions ===")

test("comma_value", function()
	assert_eq(comma_value(1000), "1 000", "comma_value")
end)

test("round", function()
	assert_eq(round(1.5), 2, "round")
end)

---------------------------------------------
-- GetKoeffVolumeOrderMax and GetOrderVolumeMax
---------------------------------------------
print("\n=== GetKoeffVolumeOrderMax / GetOrderVolumeMax ===")

test("GetKoeffVolumeOrderMax", function()
	local order = Order:new("GAZP")
	order:SetOperation("B", 1000, 10)
	local koeff = GetKoeffVolumeOrderMax(order, 200)
	assert_true(koeff >= 1, "koeff >= 1")
end)

test("GetOrderVolumeMax", function()
	local order = Order:new("GAZP")
	order:SetOperation("B", 1000, 10)
	local vol = GetOrderVolumeMax(order, 200)
	assert_true(vol > 0, "volume > 0")
end)

test("GetOrderVolumeMax - bond", function()
	local order = Order:new("RU000A10BFF4")
	order:SetOperation("B", 80, 1)
	local vol = GetOrderVolumeMax(order, 80)
	assert_true(vol > 0, "volume > 0")
end)

test("GetOrderVolumeMax - SPB", function()
	-- Add SPB security
	mock.AddSecurity(
		"ADBE_SPB",
		"SPBXM",
		{ last = 400, pricemin = 300, pricemax = 500, lot = 1, scale = 2, min_price_step = 0.01 }
	)
	local order = Order:new("ADBE_SPB")
	order:SetOperation("B", 400, 1)
	local vol = GetOrderVolumeMax(order, 400)
	assert_true(vol > 0, "volume > 0")
end)

---------------------------------------------
-- LoadOrdersFromFile whitespace trimming tests
---------------------------------------------
print("\n=== LoadOrdersFromFile whitespace trimming ===")

-- Mock getFromCSV for these tests
local originalGetFromCSV = getFromCSV

local function mockCSV(rows)
	getFromCSV = function(fileName)
		return rows
	end
end

local function restoreCSV()
	getFromCSV = originalGetFromCSV
end

test("LoadOrdersFromFile - operation trimmed from whitespace", function()
	mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order")
	assert_eq(orders[1].Operation, "B", "operation trimmed")
	restoreCSV()
end)

test("LoadOrdersFromFile - security code trimmed from whitespace", function()
	mockCSV({ { "Gazprom", "B", " GAZP ", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order")
	assert_eq(orders[1].SecurityCode, "GAZP", "security code trimmed")
	restoreCSV()
end)

test("LoadOrdersFromFile - operation trimmed for BUY/SELL detection", function()
	mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order (BUY/SELL detected after trim)")
	restoreCSV()
end)

test("LoadOrdersFromFile - all fields trimmed", function()
	mockCSV({ { " Gazprom ", " B ", " GAZP ", " 100 ", " 200.00 " } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order")
	assert_eq(orders[1].Operation, "B", "operation")
	assert_eq(orders[1].SecurityCode, "GAZP", "security code")
	restoreCSV()
end)

test("LoadOrdersFromFile - sell trimmed from whitespace", function()
	mock.AddPosition("GAZP", 100, 250.00)
	mockCSV({ { "Gazprom", " S ", " GAZP ", " 10 ", " 0.01 " } })
	local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
	assert_eq(#orders, 1, "1 order")
	assert_eq(orders[1].Operation, "S", "operation")
	restoreCSV()
end)

test("LoadOrdersFromFile - security code trimmed for BUY/SELL detection", function()
	mockCSV({ { "Gazprom", "B", " GAZP ", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order (BUY/SELL detected after trim)")
	restoreCSV()
end)

test("LoadOrdersFromFile - operation trimmed for BUY/SELL detection sell", function()
	mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order (BUY/SELL detected after trim)")
	restoreCSV()
end)

test("LoadOrdersFromFile - sell with whitespace and position", function()
	mock.AddPosition("GAZP", 100, 250.00)
	mockCSV({ { "Gazprom", " S ", " GAZP ", " 10 ", " 0.01 " } })
	local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
	assert_eq(#orders, 1, "1 order")
	assert_eq(orders[1].Operation, "S", "operation S")
	restoreCSV()
end)

---------------------------------------------
-- File type mismatch guards (BUY file with SELL orders)
---------------------------------------------
print("\n=== File type mismatch guards ===")

test("LoadOrdersFromFile - SELL orders in BUY file rejected", function()
	mockCSV({ { "Gazprom", "S", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 0, "0 orders (mismatch)")
	restoreCSV()
end)

test("LoadOrdersFromFile - BUY orders in SELL file rejected", function()
	mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
	assert_eq(#orders, 0, "0 orders (mismatch)")
	restoreCSV()
end)

test("LoadOrdersFromFile - BUY orders in BUY file accepted", function()
	mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
	assert_eq(#orders, 1, "1 order (correct file type)")
	restoreCSV()
end)

test("LoadOrdersFromFile - SELL orders in SELL file accepted", function()
	mockCSV({ { "Gazprom", "S", "GAZP", "50", "250.00" } })
	local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
	assert_eq(#orders, 1, "1 order (correct file type)")
	restoreCSV()
end)

test("LoadOrdersFromFile - BUY orders in SellOrders_Edge rejected", function()
	mock.AddPosition("GAZP", 100, 250.00)
	mockCSV({ { "Gazprom", "B", "GAZP", "10", "0.01" } })
	local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
	assert_eq(#orders, 0, "0 orders (mismatch with edge)")
	restoreCSV()
end)

test("LoadOrdersFromFile - no BUY/SELL in generic file rejected", function()
	mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
	local orders = LoadOrdersFromFile("TEST_Orders.csv")
	assert_eq(#orders, 0, "0 orders (no BUY/SELL suffix in filename)")
	restoreCSV()
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
