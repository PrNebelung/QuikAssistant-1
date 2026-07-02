--- Интеграционные тесты для TradeSave.

package.path = "?.lua;Tests/?.lua;" .. package.path

local mock = dofile("Tests/quik_mock.lua")

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
Broker = "VTB"

require("TradeSave")

-- ==========================================
-- Мок для захвата записи в файл
-- ==========================================
local writtenLines = {}
local originalIOOpen = io.open

io.open = function(path, mode)
	if mode == "a+" and string.find(path, "MyTrades%.csv") then
		return {
			write = function(self, data)
				table.insert(writtenLines, data)
			end,
			flush = function(self) end,
			close = function(self) end,
		}
	end
	return originalIOOpen(path, mode)
end

-- ==========================================
local passed, failed, errors = 0, 0, {}

local function test(name, fn)
	writtenLines = {}
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
print("=== TradeSave Tests ===\n")

print("--- Buy сделка ---")
test("buy trade: операция пустая (без минуса)", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	assert(#writtenLines == 1, "expected 1 line written")
	local line = writtenLines[1]
	assert(string.find(line, ";10;") ~= nil, "expected qty=10")
	assert(string.find(line, "GAZP") ~= nil, "expected GAZP")
	assert(string.find(line, "VTB") ~= nil, "expected broker VTB")
end)

test("buy trade: нет минуса перед qty", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	local line = writtenLines[1]
	-- Формат: DATE TIME;SEC_CODE;OPERATION+QTY;PRICE;BROKER
	-- Buy: операция пустая, qty без минуса
	assert(string.find(line, ";10;") ~= nil, "expected ;10; in line")
end)

print("\n--- Sell сделка ---")
test("sell trade: операция = '-'", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "S", qty = 10, price = 1000, flags = 0 })
	assert(#writtenLines == 1, "expected 1 line written")
	local line = writtenLines[1]
	assert(string.find(line, ";-10;") ~= nil, "expected ;-10; in line")
end)

test("sell trade: flags FLAG_SELL", function()
	TradeSave({ sec_code = "GAZP", buy_sell = nil, qty = 5, price = 500, flags = FLAG_SELL })
	assert(#writtenLines == 1)
	local line = writtenLines[1]
	assert(string.find(line, ";-5;") ~= nil, "expected ;-5; in line")
end)

test("sell trade: buy_sell=nil, flags=0 -> buy (нет минуса)", function()
	TradeSave({ sec_code = "GAZP", buy_sell = nil, qty = 10, price = 1000, flags = 0 })
	assert(#writtenLines == 1)
	local line = writtenLines[1]
	assert(string.find(line, ";10;") ~= nil, "expected ;10; (buy)")
end)

print("\n--- Формат строки ---")
test("строка содержит дату", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	local line = writtenLines[1]
	assert(string.find(line, "%d%d%d%d%-%d%d%-%d%d") ~= nil, "expected date YYYY-MM-DD")
end)

test("строка содержит секунду", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	local line = writtenLines[1]
	assert(string.find(line, "%d%d:%d%d:%d%d") ~= nil, "expected time HH:MM:SS")
end)

test("строка заканчивается переносом строки", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	local line = writtenLines[1]
	assert(string.sub(line, -1) == "\n", "expected newline at end")
end)

test("содержит sec_code, price, broker", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	local line = writtenLines[1]
	assert(string.find(line, "GAZP") ~= nil)
	assert(string.find(line, "1000") ~= nil)
	assert(string.find(line, "VTB") ~= nil)
end)

print("\n--- Прочее ---")
test("одна сделка = одна строка", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	assert(#writtenLines == 1)
end)

test("две сделки = две строки", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	TradeSave({ sec_code = "SBER", buy_sell = "S", qty = 5, price = 300, flags = 0 })
	assert(#writtenLines == 2)
end)

test("разные paper в разных строках", function()
	TradeSave({ sec_code = "GAZP", buy_sell = "B", qty = 10, price = 1000, flags = 0 })
	TradeSave({ sec_code = "SBER", buy_sell = "S", qty = 5, price = 300, flags = 0 })
	assert(string.find(writtenLines[1], "GAZP") ~= nil)
	assert(string.find(writtenLines[2], "SBER") ~= nil)
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
