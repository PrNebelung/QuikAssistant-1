-- Тесты граничных случаев (edge cases) для QUIK Assistant
-- Запуск: lua IntegrationTests/run_edge_cases.lua

os.execute("chcp 65001 >nul 2>&1")
package.path = "C:\\Users\\Dexter\\source\\repos\\QuikAssistant\\?.lua;" .. package.path

dofile("IntegrationTests/quik_mock_integration.lua")
dofile("IntegrationTests/broker_settings.lua")

_G.getInfoParam = function(param)
  if param == "USERID" then
    return "119330"
  end
  if param == "SERVERTIME" then
    return os.date("%H:%M:%S")
  end
  return ""
end

log = require("log")
log.level = "fatal"
log.usecolor = false

require("TableConstructor")
require("TableSetting")
require("Setting")
require("FileFunction")
require("Order")
require("MarketData")
require("PositionService")
require("OrderValidator")
require("TransactionHandler")
require("TradeSave")
require("TableOrders")
require("SubmittingOrders")
json = require("json")

local passed = 0
local failed = 0
local errors = {}

local function assert_eq(a, e, m)
  if a == e then
    passed = passed + 1
  else
    failed = failed + 1
    table.insert(errors, string.format("FAIL: %s (ожид:%s получ:%s)", m or "", tostring(e), tostring(a)))
    print("  FAIL: " .. (m or ""))
  end
end
local function assert_true(v, m)
  assert_eq(v, true, m)
end
local function assert_false(v, m)
  assert_eq(v, false, m)
end
local function assert_not_nil(v, m)
  if v ~= nil then
    passed = passed + 1
  else
    failed = failed + 1
    table.insert(errors, "FAIL: " .. (m or "") .. " (nil)")
    print("  FAIL: " .. (m or "") .. " (nil)")
  end
end
local function test(n, f)
  print("  " .. n)
  local ok, e = pcall(f)
  if not ok then
    failed = failed + 1
    table.insert(errors, "FAIL: " .. n .. " - " .. tostring(e))
    print("  FAIL: " .. n)
  end
end

print("=== EDGE CASE TESTS ===\n")

transId = os.time()
N_TransReplies = {}
N_LastTransID = 0
N_Orders = {}
N_LastOrderNum = 0
N_Trades = {}
N_LastTradeNum = 0
SetClientSetting()
Initialization()
TimeMainStart = os.date("!*t", os.time())
TimeMainStart.hour = 10
TimeMainStart.min = 0
TimeMainStart.sec = 30
TimeMorningStart = os.date("!*t", os.time())
TimeMorningStart.hour = 7
TimeMorningStart.min = 0
TimeMorningStart.sec = 30
TimeEveningStart = os.date("!*t", os.time())
TimeEveningStart.hour = 19
TimeEveningStart.min = 2
TimeEveningStart.sec = 10
IsSentOrders = false
IsSendingOrders = false
IsMorningTime = false
IsMainTime = false
IsEveningTime = false

-- Order
print("--- Order ---")
test("nil -> nil", function()
  local ok, r = pcall(function()
    return Order:new(nil)
  end)
  assert_true(not ok or r == nil)
end)
test("пустая -> nil", function()
  local ok, r = pcall(function()
    return Order:new("")
  end)
  assert_true(not ok or r == nil)
end)
test("GAZP создана", function()
  local o = Order:new("GAZP")
  assert_not_nil(o)
  assert_false(o:IsBond())
end)
test("Облигация создана", function()
  local o = Order:new("RU000A10BFF4")
  assert_not_nil(o)
  assert_true(o:IsBond())
end)
test("SetOperation B цена=0 -> цена>0", function()
  local o = Order:new("GAZP")
  o:SetOperation("B", 0, 100)
  assert_true(o.Price > 0)
end)
test("GetVolume акция=1000", function()
  local o = Order:new("GAZP")
  o:SetOperation("B", 100, 10)
  assert_eq(o:GetVolume(), 1000)
end)
test("GetVolume облигация=10000", function()
  local o = Order:new("RU000A10BFF4")
  o:SetOperation("B", 100, 10)
  assert_eq(o:GetVolume(), 10000)
end)
test("Clear", function()
  local o = Order:new("GAZP")
  o:SetOperation("B", 100, 50)
  o:Clear()
  assert_eq(o.Operation, "")
end)

-- CheckOrder
print("\n--- CheckOrder ---")
test("nil заявка -> ошибка", function()
  local ok = pcall(function()
    return CheckOrder(nil)
  end)
  assert_true(not ok)
end)
test("кол-во=0 -> отклонено", function()
  local o = Order:new("GAZP")
  o:SetOperation("B", 100, 0)
  assert_false(CheckOrder(o))
end)
test("пустая операция -> отклонено", function()
  local o = Order:new("GAZP")
  o.Price = 100
  o.Quantity = 10
  o.Operation = ""
  assert_false(CheckOrder(o))
end)
test("объём > лимит -> отклонено", function()
  clearMockData()
  local o = Order:new("GAZP")
  o:SetOperation("B", 1000, 500)
  assert_false(CheckOrder(o))
end)
test("объём < лимит -> принято", function()
  clearMockData()
  local o = Order:new("GAZP")
  o:SetOperation("B", 100, 10)
  assert_true(CheckOrder(o))
end)
test("продажа без позиции -> отклонено", function()
  ClearPositionCache()
  clearMockData()
  local o = Order:new("GAZP")
  o:SetOperation("S", 100, 10)
  assert_false(CheckOrder(o))
end)
test("продажа мало позиции -> отклонено", function()
  ClearPositionCache()
  clearMockData()
  addTestPosition("GAZP", 5, 100)
  local o = Order:new("GAZP")
  o:SetOperation("S", 100, 10)
  assert_false(CheckOrder(o))
end)
test("продажа достаточно -> принято", function()
  ClearPositionCache()
  clearMockData()
  addTestPosition("GAZP", 100, 100)
  local o = Order:new("GAZP")
  o:SetOperation("S", 100, 10)
  assert_true(CheckOrder(o))
end)
test("облигация >100% -> отклонено", function()
  clearMockData()
  local o = Order:new("RU000A10BFF4")
  o:SetOperation("B", 105, 10)
  assert_false(CheckOrder(o))
end)
test("облигация actuation<60% -> отклонено", function()
  clearMockData()
  local o = Order:new("RU000A10BFF4")
  o:SetOperation("B", 100, 10)
  assert_false(CheckOrder(o))
end)

-- Mock
print("\n--- Mock ---")
test("getSecurityInfo TQBR", function()
  local i = getSecurityInfo("TQBR", "GAZP")
  assert_not_nil(i)
  assert_eq(i.min_price_step, 0.1)
end)
test("getSecurityInfo TQOB", function()
  local i = getSecurityInfo("TQOB", "RU000A10BFF4")
  assert_not_nil(i)
  assert_eq(i.min_price_step, 0.01)
end)
test("getSecurityInfo неверный класс", function()
  assert_eq(getSecurityInfo("TQOB", "GAZP"), nil)
end)
test("getParamEx LAST=1000", function()
  assert_eq(getParamEx("TQBR", "GAZP", "LAST").param_value, "1000")
end)
test("getParamEx PRICEMIN=800", function()
  assert_eq(getParamEx("TQBR", "GAZP", "PRICEMIN").param_value, "800")
end)
test("getParamEx PRICEMAX=1200", function()
  assert_eq(getParamEx("TQBR", "GAZP", "PRICEMAX").param_value, "1200")
end)
test("getParamEx облиг LAST=100", function()
  assert_eq(getParamEx("TQOB", "RU000A10BFF4", "LAST").param_value, "100")
end)
test("getParamEx облиг PRICEMIN=80", function()
  assert_eq(getParamEx("TQOB", "RU000A10BFF4", "PRICEMIN").param_value, "80")
end)
test("sendTransaction NEW_ORDER", function()
  clearMockData()
  sendTransaction({
    ACTION = "NEW_ORDER",
    SECCODE = "GAZP",
    CLASSCODE = "TQBR",
    OPERATION = "B",
    PRICE = "100.00",
    QUANTITY = "10",
  })
  assert_eq(getSentOrdersCount(), 1)
end)

print(string.format("\n=== ИТОГО: %d пройдено, %d провалено ===", passed, failed))
if #errors > 0 then
  print("\nОшибки:")
  for _, e in ipairs(errors) do
    print("  " .. e)
  end
end
log.close()
os.exit(failed > 0 and 1 or 0)
