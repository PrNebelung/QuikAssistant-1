--- Интеграционные тесты для методов Order и PriceAdjuster.

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
mock.AddSecurity(
	"TESTETF",
	"TQTF",
	{ last = 50, pricemin = 40, pricemax = 60, lot = 1, scale = 2, min_price_step = 0.01 }
)

log = require("log")
log.level = "fatal"
log.usecolor = false
json = require("json")
require("BrokerAdapter")
require("MarketData")
require("PositionService")
require("Order")
require("OrderValidator")
require("PriceAdjuster")
require("Constants")
_initConstants()

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
print("=== Order Methods & PriceAdjuster Tests ===\n")

-- 1. Order:new
print("--- Order:new ---")
test("создание заказа GAZP", function()
	local o = Order:new("GAZP")
	assert(o ~= nil, "order should not be nil")
	assert(o.SecurityCode == "GAZP")
	assert(o.Operation == "")
	assert(o.Quantity == 0)
	assert(o.Price == 0)
	assert(o.UseFileParams == false)
end)

test("неизвестная бумага -> nil", function()
	local o = Order:new("NONEXISTENT")
	assert(o == nil, "expected nil for unknown security")
end)

-- 2. IsBuy / IsSell
print("\n--- IsBuy / IsSell ---")
test("IsBuy после SetOperation B", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(o:IsBuy() == true)
	assert(o:IsSell() == false)
end)

test("IsSell после SetOperation S", function()
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	assert(o:IsSell() == true)
	assert(o:IsBuy() == false)
end)

test("пустая операция", function()
	local o = Order:new("GAZP")
	assert(o:IsBuy() == false)
	assert(o:IsSell() == false)
end)

-- 3. IsBond / IsOFZ / IsEtf
print("\n--- IsBond / IsOFZ / IsEtf ---")
test("GAZP не облигация", function()
	local o = Order:new("GAZP")
	assert(o:IsBond() == false)
end)

test("RU000A10BFF4 облигация (TQCB)", function()
	local o = Order:new("RU000A10BFF4")
	assert(o:IsBond() == true)
end)

test("GAZP не OFZ", function()
	local o = Order:new("GAZP")
	assert(o:IsOFZ() == false)
end)

test("TESTETF это ETF (TQTF)", function()
	local o = Order:new("TESTETF")
	assert(o:IsEtf() == true)
	assert(o:IsBond() == false)
end)

-- 4. IsExceptionFromLimitActuation
print("\n--- IsExceptionFromLimitActuation ---")
test("GAZP в списке исключений", function()
	local o = Order:new("GAZP")
	assert(o:IsExceptionFromLimitActuation() == true)
end)

test("SBER не в списке исключений", function()
	local o = Order:new("SBER")
	assert(o:IsExceptionFromLimitActuation() == false)
end)

-- 5. Clear
print("\n--- Clear ---")
test("Clear обнуляет поля", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	o:Clear()
	assert(o.Operation == "")
	assert(o.Quantity == 0)
	assert(o.Price == 0)
end)

-- 6. FormatPrice / FormatQuantity
print("\n--- FormatPrice / FormatQuantity ---")
test("FormatPrice с scale=2", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(o:FormatPrice() == "1000.00")
end)

test("FormatPrice с scale=2 дробная", function()
	local o = Order:new("SBER")
	o:SetOperation("B", 299.50, 10)
	assert(o:FormatPrice() == "299.50")
end)

test("FormatQuantity по умолчанию", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(o:FormatQuantity() == "10")
end)

test("FormatQuantity с n=2", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(o:FormatQuantity(2) == "10.00")
end)

-- 7. GetDedupKey
print("\n--- GetDedupKey ---")
test("формат ключа", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	local key = o:GetDedupKey()
	assert(string.find(key, "GAZP") ~= nil)
	assert(string.find(key, "B") ~= nil)
	assert(string.find(key, "10") ~= nil)
	assert(string.find(key, "1000") ~= nil)
end)

-- 8. GetPriceInCurrency
print("\n--- GetPriceInCurrency ---")
test("акция: цена без изменений", function()
	local o = Order:new("GAZP")
	assert(o:GetPriceInCurrency(100) == 100)
end)

test("облигация: цена * номинал / 100", function()
	local o = Order:new("RU000A10BFF4")
	assert(o:GetPriceInCurrency(80) == 800, "expected 80*1000/100=800, got " .. o:GetPriceInCurrency(80))
end)

test("облигация: цена 100% = номинал", function()
	local o = Order:new("RU000A10BFF4")
	assert(o:GetPriceInCurrency(100) == 1000)
end)

-- 9. SetOperation
print("\n--- SetOperation ---")
test("SetOperation B", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	assert(o.Operation == "B")
	assert(o.Price == 1000)
	assert(o.Quantity == 10)
end)

test("SetOperation price=0 -> min_price_step", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 0, 10)
	assert(o.Price == 0.1, "expected min_price_step=0.1, got " .. o.Price)
end)

test("SetOperation price=0, min_step=0.0001", function()
	mock.AddSecurity(
		"CHEAP",
		"TQBR",
		{ last = 1, pricemin = 0.01, pricemax = 10, lot = 1, scale = 4, min_price_step = 0.0001 }
	)
	local o = Order:new("CHEAP")
	o:SetOperation("B", 0, 10)
	assert(o.Price == 0.0001)
end)

-- 10. SetPriceMin
print("\n--- SetPriceMin ---")
test("SetPriceMin buy -> qty=1, price=min_step", function()
	local o = Order:new("GAZP")
	o:SetPriceMin("B")
	assert(o.Operation == "B")
	assert(o.Quantity == 1)
	assert(o.Price == 0.1)
end)

test("SetPriceMin sell -> qty=0, price=0", function()
	local o = Order:new("GAZP")
	o:SetPriceMin("S")
	assert(o.Operation == "S")
	assert(o.Quantity == 0)
	assert(o.Price == 0)
end)

-- 11. SetQuantity
print("\n--- SetQuantity ---")
test("SetQuantity buy: qty = limit / price / lot", function()
	local o = Order:new("GAZP")
	o:SetQuantity("B", 800, 10000)
	assert(o.Operation == "B")
	assert(o.Price == 800)
	assert(o.Quantity == 12, "expected floor(10000/800/1)=12, got " .. o.Quantity)
end)

test("SetQuantity buy bond: qty = limit / (price*nominal/100) / lot", function()
	local o = Order:new("RU000A10BFF4")
	o:SetQuantity("B", 80, 100000)
	-- priceRub = 80*1000/100 = 800, qty = floor(100000/800/1000) = 0 -> 1
	assert(o.Quantity >= 1, "expected at least 1")
end)

test("SetQuantity sell -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantity("S", 1000, 10000)
	assert(o.Quantity == 0, "sell should set qty=0")
end)

test("SetQuantity price=nil -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantity("B", nil, 10000)
	assert(o.Quantity == 0)
end)

test("SetQuantity limit=0 -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantity("B", 1000, 0)
	assert(o.Quantity == 0)
end)

test("SetQuantity qty вычисляется и >= 1", function()
	local o = Order:new("GAZP")
	o:SetQuantity("B", 1000, 500)
	assert(o.Quantity >= 1, "qty should be at least 1")
end)

-- 12. SetQuantitySell
print("\n--- SetQuantitySell ---")
test("SetQuantitySell sell: qty = position / lot", function()
	local o = Order:new("GAZP")
	o:SetQuantitySell("S", 1000, 50)
	assert(o.Operation == "S")
	assert(o.Price == 1000)
	assert(o.Quantity == 50, "expected 50/1=50, got " .. o.Quantity)
end)

test("SetQuantitySell buy -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantitySell("B", 1000, 50)
	assert(o.Quantity == 0)
end)

test("SetQuantitySell price=nil -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantitySell("S", nil, 50)
	assert(o.Quantity == 0)
end)

test("SetQuantitySell positionQty=nil -> qty=0", function()
	local o = Order:new("GAZP")
	o:SetQuantitySell("S", 1000, nil)
	assert(o.Quantity == 0)
end)

-- 13. GetVolume
print("\n--- GetVolume ---")
test("акция: qty * price * lot", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 100, 10)
	assert(o:GetVolume() == 1000, "expected 10*100*1=1000")
end)

test("облигация: qty * (price*nominal/100) * lot", function()
	local o = Order:new("RU000A10BFF4")
	o:SetOperation("B", 80, 10)
	-- 10 * (80*1000/100) * 1000 = 10 * 800 * 1000 = 8000000
	assert(o:GetVolume() == 8000000, "expected 8000000, got " .. o:GetVolume())
end)

-- 14. GetPriceRound
print("\n--- GetPriceRound ---")
test("buy: ceil к min_step", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 800.05, 10)
	-- ceil(800.05 / 0.1) * 0.1 = ceil(8000.5) * 0.1 = 8001 * 0.1 = 800.1
	assert(o.Price == 800.1, "expected 800.1, got " .. o.Price)
end)

test("sell: floor к min_step", function()
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000.05, 10)
	-- floor(1000.05 / 0.1) * 0.1 = floor(10000.5) * 0.1 = 10000 * 0.1 = 1000.0
	assert(o.Price == 1000.0, "expected 1000.0, got " .. o.Price)
end)

-- 15. Print
print("\n--- Print ---")
test("Print возвращает строку", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	local s = o:Print()
	assert(type(s) == "string")
	assert(string.find(s, "GAZP") ~= nil)
	assert(string.find(s, "B") ~= nil)
end)

-- 16. PriceAdjuster
print("\n--- PriceAdjuster ---")
test("UseFileParams -> цена не меняется", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 500, 10)
	o.UseFileParams = true
	AdjustPrice(o)
	assert(o.Price == 500, "expected 500, got " .. o.Price)
end)

test("buy: LAST < цена -> цена снижается на 10*step", function()
	-- LAST=1000, цена=1000 -> LAST не меньше цены, не снижается
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	AdjustPrice(o)
	assert(o.Price == 1000, "expected 1000, got " .. o.Price)
end)

test("buy: LAST=900 < цена=1000 -> цена=900-10*0.1=899", function()
	mock.securities["GAZP"]["TQBR"].params.LAST = "900"
	local o = Order:new("GAZP")
	o:SetOperation("B", 1000, 10)
	AdjustPrice(o)
	assert(o.Price == 899, "expected 899, got " .. o.Price)
	mock.securities["GAZP"]["TQBR"].params.LAST = "1000"
end)

test("buy: цена < PRICEMIN -> цена = PRICEMIN", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 700, 10)
	AdjustPrice(o)
	assert(o.Price == 800, "expected 800, got " .. o.Price)
end)

test("buy: цена >= PRICEMIN -> без изменений", function()
	local o = Order:new("GAZP")
	o:SetOperation("B", 900, 10)
	AdjustPrice(o)
	assert(o.Price == 900, "expected 900, got " .. o.Price)
end)

test("sell: LAST > цена -> цена повышается на 10*step", function()
	mock.securities["GAZP"]["TQBR"].params.LAST = "1100"
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	AdjustPrice(o)
	assert(o.Price == 1101, "expected 1101, got " .. o.Price)
	mock.securities["GAZP"]["TQBR"].params.LAST = "1000"
end)

test("sell: LAST <= цена -> без изменений", function()
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	AdjustPrice(o)
	assert(o.Price == 1000, "expected 1000, got " .. o.Price)
end)

test("sell: UseFileParams -> без изменений", function()
	mock.securities["GAZP"]["TQBR"].params.LAST = "1100"
	local o = Order:new("GAZP")
	o:SetOperation("S", 1000, 10)
	o.UseFileParams = true
	AdjustPrice(o)
	assert(o.Price == 1000, "expected 1000, got " .. o.Price)
	mock.securities["GAZP"]["TQBR"].params.LAST = "1000"
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
