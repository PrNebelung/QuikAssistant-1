--- Интеграционные тесты для CheckOrder.

package.path = "?.lua;IntegrationTests/?.lua;libs/?.lua;utils/?.lua;" .. package.path

local mock = dofile("IntegrationTests/quik_mock.lua")

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

-- Mock SubmitOrders for TransactionHandler tests
SubmitOrders = function(orders, resubmit)
	for _, order in ipairs(orders) do
		local transaction = {
			ACTION = "NEW_ORDER",
			SECCODE = order.SecurityCode,
			CLASSCODE = order.SecurityInfo.class_code,
			OPERATION = order.Operation,
			PRICE = order:FormatPrice(),
			QUANTITY = order:FormatQuantity(),
		}
		BrokerAdapter.SendTransaction(transaction)
	end
end

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

local function pass(o)
	local ok, r = CheckOrder(o)
	if not ok then
		error("expected pass, got: " .. r)
	end
end
local function fail(o, exp)
	local ok, r = CheckOrder(o)
	if ok then
		error("expected reject")
	end
	if exp and not string.find(r, exp, 1, true) then
		error(string.format("expected '%s', got '%s'", exp, r))
	end
end
local function B(c, p, q)
	local o = Order:new(c)
	o:SetOperation("B", p, q)
	return o
end
local function S(c, p, q)
	local o = Order:new(c)
	o:SetOperation("S", p, q)
	return o
end

print("=== CheckOrder Tests ===\n")

-- 1. checkNotNil
print("--- checkNotNil ---")
test("nil -> reject", function()
	fail(nil, "Invalid")
end)
test("qty=0 -> reject", function()
	fail(B("GAZP", 500, 0), "Invalid")
end)
test("qty<0 -> reject", function()
	fail(B("GAZP", 500, -5), "Invalid")
end)
test("price=0 -> converted to min_price_step -> below PRICEMIN", function()
	-- SetOperation converts price=0 to min_price_step (0.1)
	-- 0.1 < PRICEMIN 800 -> rejected
	fail(B("GAZP", 0, 10), "PRICEMIN")
end)
test("price<0 -> reject", function()
	fail(B("GAZP", -100, 10), "Invalid")
end)
test("valid buy -> pass", function()
	pass(B("GAZP", 1000, 10))
end)
test("valid sell with pos -> pass", function()
	mock.AddPosition("GAZP", 100, 500)
	pass(S("GAZP", 1000, 10))
end)

-- 2. checkPriceBelowPricemin
print("\n--- checkPriceBelowPricemin ---")
test("buy 500 < 800 -> reject", function()
	fail(B("GAZP", 500, 10), "PRICEMIN")
end)
test("buy 800 = PRICEMIN -> pass", function()
	pass(B("GAZP", 800, 10))
end)
test("buy 900 > PRICEMIN -> pass", function()
	pass(B("GAZP", 900, 10))
end)
test("buy price=0 -> below PRICEMIN after conversion", function()
	fail(B("GAZP", 0, 10), "PRICEMIN")
end)
test("sell ignores PRICEMIN", function()
	mock.AddPosition("GAZP", 100, 500)
	pass(S("GAZP", 100, 10))
end)
test("bond buy 50 < 80 -> reject", function()
	fail(B("RU000A10BFF4", 50, 1), "PRICEMIN")
end)
test("bond buy 80 = PRICEMIN -> pass", function()
	local sv = Config.VolumeOrderLimit
	local se = Config.LimitActuationOrderBondEdge
	Config.VolumeOrderLimit = 10000000
	Config.LimitActuationOrderBondEdge = 0
	pass(B("RU000A10BFF4", 80, 1))
	Config.VolumeOrderLimit = sv
	Config.LimitActuationOrderBondEdge = se
end)

-- 3. checkPositionForSell
print("\n--- checkPositionForSell ---")
test("sell no pos -> reject", function()
	fail(S("GAZP", 1000, 10), "insufficient")
end)
test("sell qty>pos -> reject", function()
	mock.AddPosition("GAZP", 5, 500)
	fail(S("GAZP", 1000, 10), "insufficient")
end)
test("sell qty=pos -> pass", function()
	mock.AddPosition("GAZP", 10, 500)
	pass(S("GAZP", 1000, 10))
end)
test("sell qty<pos -> pass", function()
	mock.AddPosition("GAZP", 100, 500)
	pass(S("GAZP", 1000, 10))
end)
test("buy ignores position", function()
	mock.AddPosition("SBER", 100, 100)
	pass(B("GAZP", 1000, 10))
end)

-- 4. checkVolumeLimit
print("\n--- checkVolumeLimit ---")
test("volume > limit -> reject", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000
	fail(B("GAZP", 1000, 20), "exceeds limit")
	Config.VolumeOrderLimit = sv
end)
test("volume = limit -> pass", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000
	pass(B("GAZP", 1000, 10))
	Config.VolumeOrderLimit = sv
end)
test("volume < limit -> pass", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 100000
	pass(B("GAZP", 1000, 10))
	Config.VolumeOrderLimit = sv
end)
test("volume=0 -> reject by checkNotNil", function()
	fail(B("GAZP", 1000, 0), "Invalid")
end)
test("volume<0 -> reject by checkNotNil", function()
	fail(B("GAZP", 1000, -5), "Invalid")
end)
test("sell ignores volume", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 100
	mock.AddPosition("GAZP", 1000, 500)
	pass(S("GAZP", 1000, 100))
	Config.VolumeOrderLimit = sv
end)

-- 5. checkActuation
print("\n--- checkActuation ---")
-- Default: Edge=5, BondEdge=60
test("stock actuation 11% > edge 5% -> pass", function()
	pass(B("GAZP", 900, 10))
end)
test("stock actuation 25% > edge 5% -> pass", function()
	pass(B("GAZP", 800, 10))
end)
test("sell ignores actuation", function()
	mock.AddPosition("GAZP", 100, 500)
	pass(S("GAZP", 100, 10))
end)
test("bond actuation 25% < bondEdge 60% -> reject", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000000
	fail(B("RU000A10BFF4", 80, 1), "actuation")
	Config.VolumeOrderLimit = sv
end)
test("bond actuation 0% < bondEdge 60% -> reject", function()
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000000
	fail(B("RU000A10BFF4", 100, 1), "actuation")
	Config.VolumeOrderLimit = sv
end)
test("custom edge=30: 11% -> reject", function()
	local se = Config.LimitActuationOrderEdge
	Config.LimitActuationOrderEdge = 30
	-- SBER: LAST=300, price=270 -> actuation = (300-270)/270*100 = 11.1% < 30%
	local o = B("SBER", 270, 10)
	local ok, reason = CheckOrder(o)
	Config.LimitActuationOrderEdge = se
	if ok then
		error("expected reject, got pass")
	end
	if not string.find(reason, "actuation") then
		error("expected actuation, got: " .. reason)
	end
end)
test("edge=0 -> actuation check disabled -> pass", function()
	local sv = Config.VolumeOrderLimit
	local se = Config.LimitActuationOrderEdge
	Config.VolumeOrderLimit = 100000
	Config.LimitActuationOrderEdge = 0
	pass(B("GAZP", 900, 10))
	Config.VolumeOrderLimit = sv
	Config.LimitActuationOrderEdge = se
end)

print("\n--- checkBondPriceLimit ---")
test("bond price 105 > 100% -> reject by actuation", function()
	-- price=105, LAST=100 -> actuation=-4.76% < 60% -> reject by actuation (runs before bondPrice check)
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000000
	fail(B("RU000A10BFF4", 105, 1), "actuation")
	Config.VolumeOrderLimit = sv
end)
test("bond price = 100% -> pass (actuation ok)", function()
	local sv = Config.VolumeOrderLimit
	local se = Config.LimitActuationOrderBondEdge
	Config.VolumeOrderLimit = 10000000
	Config.LimitActuationOrderBondEdge = 0
	pass(B("RU000A10BFF4", 100, 1))
	Config.VolumeOrderLimit = sv
	Config.LimitActuationOrderBondEdge = se
end)
test("stock ignores bond limit", function()
	pass(B("GAZP", 2000, 10))
end)
test("sell bond ignores bond limit", function()
	mock.AddPosition("RU000A10BFF4", 100, 100)
	pass(S("RU000A10BFF4", 105, 1))
end)

-- 7. checkAvgPositionPrice
print("\n--- checkAvgPositionPrice ---")
test("buy 1100 > avg 500 -> reject", function()
	mock.AddPosition("GAZP", 100, 500)
	fail(B("GAZP", 1100, 10), "average position price")
end)
test("buy 900 > avg 500 -> reject", function()
	mock.AddPosition("GAZP", 100, 500)
	fail(B("GAZP", 900, 10), "average position price")
end)
test("buy 800 = avg 800 -> pass", function()
	mock.AddPosition("GAZP", 100, 800)
	pass(B("GAZP", 800, 10))
end)
test("buy 800 < avg 1000 -> pass", function()
	mock.AddPosition("GAZP", 100, 1000)
	pass(B("GAZP", 800, 10))
end)
test("sell ignores avg pos", function()
	mock.AddPosition("GAZP", 100, 500)
	pass(S("GAZP", 2000, 10))
end)
test("bond ignores avg pos", function()
	mock.AddPosition("RU000A10BFF4", 100, 50)
	local sv = Config.VolumeOrderLimit
	Config.VolumeOrderLimit = 10000000
	fail(B("RU000A10BFF4", 80, 1), "actuation")
	Config.VolumeOrderLimit = sv
end)
test("no position -> skip avg check", function()
	pass(B("GAZP", 2000, 10))
end)

-- ==========================================
-- 8. sell price < 0
-- ==========================================
print("\n--- sell price < 0 ---")
test("sell price=-100 -> reject (checkNotNil blocks negative)", function()
	mock.AddPosition("GAZP", 100, 500)
	fail(S("GAZP", -100, 10), "Invalid")
end)

-- ==========================================
-- 9. bond high yield (actuation with high profit)
-- ==========================================
print("\n--- bond high yield ---")
test("bond actuation 100% > bondEdge 60% -> pass", function()
	local sv = Config.VolumeOrderLimit
	local se = Config.LimitActuationOrderBondEdge
	Config.VolumeOrderLimit = 10000000
	Config.LimitActuationOrderBondEdge = 60
	-- Use price=85 to pass PRICEMIN check, actuation = (100-85)/85*100 = 17.6% < 60%
	-- Need price where actuation > 60% and price >= PRICEMIN
	-- price=85: actuation=17.6%, too low
	-- price=60: actuation=66.7%, but 60 < PRICEMIN=80
	-- Solution: raise PRICEMIN or use higher price
	-- Actually: actuation = (LAST - price) / price * 100
	-- For actuation > 60%: (100 - price) / price > 0.6 -> price < 62.5
	-- But PRICEMIN=80, so no valid price exists
	-- Use a different approach: lower PRICEMIN
	mock.AddSecurity(
		"BOND_TEST",
		"TQCB",
		{
			last = 100,
			pricemin = 10,
			pricemax = 120,
			lot = 1000,
			scale = 2,
			min_price_step = 0.01,
			facevalue = 1000,
			face_unit = "SUR",
		}
	)
	pass(B("BOND_TEST", 60, 1))
	Config.VolumeOrderLimit = sv
	Config.LimitActuationOrderBondEdge = se
end)

-- ==========================================
-- 10. PriceAdjuster + UseFileParams
-- ==========================================
print("\n--- PriceAdjuster / UseFileParams ---")
test("UseFileParams=true -> price not adjusted", function()
	local o = B("GAZP", 1000, 10)
	o.UseFileParams = true
	AdjustPrice(o)
	assert(o.Price == 1000, "expected price 1000, got " .. tostring(o.Price))
end)
test("UseFileParams=false, price > LAST -> buy adjusted down", function()
	local o = B("GAZP", 1100, 10)
	o.UseFileParams = false
	AdjustPrice(o)
	assert(o.Price < 1100, "expected price < 1100, got " .. tostring(o.Price))
end)
test("UseFileParams=false, price < PRICEMIN -> buy set to PRICEMIN", function()
	local o = B("GAZP", 500, 10)
	o.UseFileParams = false
	AdjustPrice(o)
	assert(o.Price >= 800, "expected price >= 800 (PRICEMIN), got " .. tostring(o.Price))
end)
test("UseFileParams=false, sell price < LAST -> sell adjusted up", function()
	mock.AddPosition("GAZP", 100, 500)
	local o = S("GAZP", 900, 10)
	o.UseFileParams = false
	AdjustPrice(o)
	assert(o.Price > 900, "expected price > 900, got " .. tostring(o.Price))
end)

-- ==========================================
-- 11. SetQuantity calculation
-- ==========================================
print("\n--- SetQuantity ---")
test("SetQuantity buy stock: 100000 / 1000 / 1 = 100", function()
	local o = B("GAZP", 1000, 0)
	o:SetQuantity("B", 1000, 100000)
	assert(o.Quantity == 100, "expected qty=100, got " .. tostring(o.Quantity))
end)
test("SetQuantity buy bond: correct lot calculation", function()
	local o = B("RU000A10BFF4", 80, 0)
	o:SetQuantity("B", 80, 100000)
	assert(o.Quantity >= 1, "expected qty >= 1, got " .. tostring(o.Quantity))
end)
test("SetQuantity with quantityMax=0 -> qty=0", function()
	local o = B("GAZP", 1000, 0)
	o:SetQuantity("B", 1000, 0)
	assert(o.Quantity == 0, "expected qty=0, got " .. tostring(o.Quantity))
end)
test("SetQuantity with price=0 -> qty=0", function()
	local o = B("GAZP", 1000, 0)
	o:SetQuantity("B", 0, 100000)
	assert(o.Quantity == 0, "expected qty=0, got " .. tostring(o.Quantity))
end)

-- ==========================================
-- 12. SetQuantitySell calculation
-- ==========================================
print("\n--- SetQuantitySell ---")
test("SetQuantitySell: position=100, lot=1 -> qty=100", function()
	mock.AddPosition("GAZP", 100, 500)
	local o = S("GAZP", 1000, 0)
	o:SetQuantitySell("S", 1000, 100)
	assert(o.Quantity == 100, "expected qty=100, got " .. tostring(o.Quantity))
end)
test("SetQuantitySell with position=0 -> qty=0", function()
	local o = S("GAZP", 1000, 0)
	o:SetQuantitySell("S", 1000, 0)
	assert(o.Quantity == 0, "expected qty=0, got " .. tostring(o.Quantity))
end)
test("SetQuantitySell with price=0 -> qty=0", function()
	local o = S("GAZP", 1000, 0)
	o:SetQuantitySell("S", 0, 100)
	assert(o.Quantity == 0, "expected qty=0, got " .. tostring(o.Quantity))
end)

-- ==========================================
-- 13. Transaction error codes (579, 580, 133)
-- ==========================================
print("\n--- TransactionHandler errors ---")
test("error 579 -> logged, no crash", function()
	local trans = { result_msg = "Error: (579) price too low", sec_code = "GAZP", quantity = 10, price = "100.00" }
	SetLimitOrdersWithError(trans)
end)
test("error 580 -> auto-recover sell", function()
	mock.AddPosition("GAZP", 50, 500)
	local trans =
		{ result_msg = "Error: (580) price too high, do 1200", sec_code = "GAZP", quantity = 10, price = 1300 }
	mock.ClearSent()
	SetLimitOrdersWithError(trans)
	assert(mock.GetSentCount() >= 1, "expected auto-recover transaction")
end)
test("error 133 -> logged, no crash", function()
	local trans = { result_msg = "Error: (133) rejected", sec_code = "GAZP", quantity = 10, price = "100.00" }
	SetLimitOrdersWithError(trans)
end)
test("unknown error -> logged", function()
	local trans = { result_msg = "Unknown error 999", sec_code = "GAZP", quantity = 10, price = "100.00" }
	SetLimitOrdersWithError(trans)
end)

-- ==========================================
-- 14. Deduplication (IsOrderExists)
-- ==========================================
print("\n--- IsOrderExists ---")
test("same order exists -> true", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		price = 1000,
		qty = 10,
		balance = 10,
		trans_id = 1,
		order_num = 1,
	})
	local o = B("GAZP", 1000, 10)
	assert(IsOrderExists(o) == true, "expected true")
end)
test("different price -> false", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		price = 1000,
		qty = 10,
		balance = 10,
		trans_id = 1,
		order_num = 1,
	})
	local o = B("GAZP", 900, 10)
	assert(IsOrderExists(o) == false, "expected false")
end)
test("different operation -> false", function()
	mock.AddOrder({
		sec_code = "GAZP",
		class_code = "TQBR",
		flags = FLAG_ACTIVE,
		price = 1000,
		qty = 10,
		balance = 10,
		trans_id = 1,
		order_num = 1,
	})
	local o = S("GAZP", 1000, 10)
	assert(IsOrderExists(o) == false, "expected false")
end)

-- ==========================================
-- 15. Session scheduling
-- ==========================================
print("\n--- Session scheduling ---")
test("SessionScheduler initializes correctly", function()
	SessionScheduler.Initialization()
	assert(SessionScheduler.TimeMorningStart ~= nil, "morning time not set")
	assert(SessionScheduler.TimeMainStart ~= nil, "main time not set")
	assert(SessionScheduler.TimeEveningStart ~= nil, "evening time not set")
end)
test("SessionScheduler.MarkSent sets flag", function()
	SessionScheduler.MarkSent()
	assert(SessionScheduler.IsSentOrders == true, "expected IsSentOrders=true")
end)
test("SessionScheduler.CheckSession returns boolean", function()
	local result = SessionScheduler.CheckSession()
	assert(type(result) == "boolean", "expected boolean, got " .. type(result))
end)

print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if #errors > 0 then
	print("\nFailures:")
	for _, e in ipairs(errors) do
		print("  " .. e)
	end
end
os.exit(failed > 0 and 1 or 0)
