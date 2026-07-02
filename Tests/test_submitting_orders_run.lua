--- Интеграционные тесты для SubmittingOrdersRun.

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

local csvData = {}
getFromCSV = function(fileName)
	return csvData[fileName] or {}
end

-- ==========================================
local passed, failed, errors = 0, 0, {}

local function resetAll()
	PositionService.ClearCache()
	mock.Reset()
	mock.ClearSent()
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
	N_Orders = {}
	N_LastOrderNum = 0
	N_TransReplies = {}
	N_LastTransID = 0
	sendOrders = {}
	sendOrdersSet = {}
	unknownSecurities = {}
	SessionScheduler.IsSentOrders = false
	IsSendingOrders = false
	SessionScheduler.IsMorningTime = false
	SessionScheduler.IsMainTime = false
	SessionScheduler.IsEveningTime = false
	csvData = {}

	Config.BrokerEnabled = true
	Config.FileBuyOrder = "TEST_BuyOrders.csv"
	Config.FileSellOrder = "TEST_SellOrders.csv"
	Config.FileBuyOrderEdge = "TEST_BuyOrders_Edge.csv"
	Config.FileBuyOrderBondsEdge = "TEST_BuyOrdersBonds_Edge.csv"
	Config.FileSellOrderEdge = "TEST_SellOrders_Edge.csv"
	Config.VolumeOrderMax = 20000
	Config.VolumeOrderLimit = 200000
end

local function test(name, fn)
	resetAll()
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
print("=== SubmittingOrdersRun Tests ===\n")

print("--- Guard checks ---")
test("BrokerEnabled=false -> skip", function()
	Config.BrokerEnabled = false
	SubmittingOrdersRun()
	assert(#N_Orders == 0)
	assert(IsSentOrders == false)
end)

test("IsSendingOrders=true -> skip", function()
	IsSendingOrders = true
	SubmittingOrdersRun()
	assert(#N_Orders == 0)
	assert(IsSendingOrders == true)
end)

print("\n--- Нормальный цикл ---")
test("загружает BuyOrders", function()
	csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
	SubmittingOrdersRun()
	assert(#N_Orders >= 1, "expected at least 1 order")
end)

test("загружает SellOrders", function()
	csvData["TEST_SellOrders.csv"] = { { "GAZP", "S", "GAZP", "10", "1000" } }
	mock.AddPosition("GAZP", 100, 500)
	SubmittingOrdersRun()
	assert(#N_Orders >= 1, "expected at least 1 order")
end)

test("IsSentOrders=true после цикла", function()
	csvData["TEST_BuyOrders.csv"] = {}
	SubmittingOrdersRun()
	assert(IsSentOrders == true)
end)

test("IsSendingOrders=false после цикла", function()
	csvData["TEST_BuyOrders.csv"] = {}
	SubmittingOrdersRun()
	assert(IsSendingOrders == false)
end)

print("\n--- sendOrders ---")
test("sendOrders заполняется во время цикла", function()
	csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
	SubmittingOrdersRun()
	assert(mock.GetSentCount() >= 1, "expected at least 1 transaction")
end)

test("sendOrders очищается после цикла", function()
	csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
	SubmittingOrdersRun()
	assert(#sendOrders == 0, "sendOrders should be cleared")
	assert(next(sendOrdersSet) == nil, "sendOrdersSet should be cleared")
end)

print("\n--- Пустые файлы ---")
test("все файлы пустые -> ничего не отправлено", function()
	SubmittingOrdersRun()
	assert(#N_Orders == 0)
end)

test("только buy файл", function()
	csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
	SubmittingOrdersRun()
	assert(#N_Orders >= 1)
end)

print("\n--- Транзакции ---")
test("sendTransaction вызывается", function()
	csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
	SubmittingOrdersRun()
	assert(mock.GetSentCount() >= 1, "expected at least 1 transaction")
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
