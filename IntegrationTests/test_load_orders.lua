--- Интеграционные тесты для LoadOrdersFromFile.

package.path = "?.lua;IntegrationTests/?.lua;" .. package.path

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
  table.insert(
    N_Orders,
    {
      trans_id = N_LastTransID,
      order_num = N_LastOrderNum,
      sec_code = sec,
      class_code = class,
      operation = op,
      price = price,
      quantity = qty,
      balance = qty,
    }
  )
  return N_LastTransID, ""
end
function IsOrderExists(o)
  return false
end

require("SubmittingOrders")

-- Мокаем getFromCSV ПОСЛЕ всех require (иначе FileFunction перезапишет)
local csvData = {
  ["TEST_BuyOrders.csv"] = {
    { "GAZP", "B", "GAZP", "200", "50" },
    { "SBER", "B", "SBER", "100", "300" },
  },
  ["TEST_SellOrders.csv"] = {
    { "GAZP", "S", "GAZP", "50", "1000" },
  },
  ["TEST_BuyOrders_Edge.csv"] = {
    { "GAZP", "B", "GAZP", "10", "0" },
    { "SBER", "B", "SBER", "10", "0" },
  },
  ["TEST_SellOrders_Edge.csv"] = {
    { "GAZP", "S", "GAZP", "10", "0" },
  },
}

getFromCSV = function(fileName)
  return csvData[fileName] or {}
end

-- ==========================================
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
print("=== LoadOrdersFromFile Tests ===\n")

print("--- Buy файл ---")
test("читает заявки из BUY файла", function()
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert(#orders == 2, "expected 2, got " .. #orders)
end)

test("первая заявка: GAZP, B, 200, 50", function()
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert(orders[1].SecurityCode == "GAZP")
  assert(orders[1].Operation == "B")
  assert(tonumber(orders[1].Quantity) == 200)
  assert(tonumber(orders[1].Price) == 50)
end)

test("вторая заявка: SBER, B, 100, 300", function()
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert(orders[2].SecurityCode == "SBER")
  assert(orders[2].Operation == "B")
  assert(tonumber(orders[2].Quantity) == 100)
  assert(tonumber(orders[2].Price) == 300)
end)

test("UseFileParams = true", function()
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert(orders[1].UseFileParams == true)
end)

print("\n--- Sell файл ---")
test("читает заявки из SELL файла", function()
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert(#orders == 1, "expected 1, got " .. #orders)
end)

test("sell заявка: GAZP, S, 50, 1000", function()
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert(orders[1].SecurityCode == "GAZP")
  assert(orders[1].Operation == "S")
  assert(tonumber(orders[1].Quantity) == 50)
  assert(tonumber(orders[1].Price) == 1000)
end)

print("\n--- Edge файл ---")
test("edge buy: цена = PRICEMIN", function()
  local saved = Config.VolumeOrderMax
  Config.VolumeOrderMax = 20000
  mock.AddPosition("GAZP", 100, 500)
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  Config.VolumeOrderMax = saved
  assert(#orders >= 1, "expected at least 1 order")
  assert(orders[1].Price == 800, "expected price=800, got " .. tostring(orders[1].Price))
end)

test("edge buy: quantity > 0", function()
  local saved = Config.VolumeOrderMax
  Config.VolumeOrderMax = 20000
  mock.AddPosition("GAZP", 100, 500)
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  Config.VolumeOrderMax = saved
  assert(#orders >= 1)
  assert(orders[1].Quantity > 0, "expected quantity > 0")
end)

print("\n--- Sell Edge файл ---")
test("sell edge: quantity = позиция", function()
  mock.AddPosition("GAZP", 50, 500)
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert(#orders == 1, "expected 1, got " .. #orders)
  assert(orders[1].Quantity == 50, "expected qty=50, got " .. tostring(orders[1].Quantity))
end)

test("sell edge: нет позиции -> пропуск", function()
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert(#orders == 0, "expected 0, got " .. #orders)
end)

test("sell edge: PRICEMAX как цена", function()
  mock.AddPosition("GAZP", 100, 500)
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert(orders[1].Price == 1200, "expected 1200, got " .. tostring(orders[1].Price))
end)

print("\n--- Возврат ---")
test("возвращает таблицу", function()
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert(type(orders) == "table")
end)

test("несуществующий файл -> пустая таблица", function()
  local orders = LoadOrdersFromFile("NONEXISTENT.csv")
  assert(#orders == 0, "expected 0")
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
