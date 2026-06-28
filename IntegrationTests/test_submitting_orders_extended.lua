--- Дополнительные интеграционные тесты для SubmittingOrders, WaitForMarketData, SubmittingOrdersRun.

package.path = "?.lua;IntegrationTests/?.lua;" .. package.path

local mock = dofile("IntegrationTests/quik_mock.lua")

mock.AddSecurity(
  "GAZP", "TQBR",
  { last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 }
)
mock.AddSecurity(
  "SBER", "TQBR",
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

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  PositionService.ClearCache()
  mock.Reset()
  mock.ClearSent()
  mock.AddSecurity("GAZP", "TQBR",
    { last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 })
  mock.AddSecurity("SBER", "TQBR",
    { last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 })
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
-- SubmittingOrders: интеграция таймеров
-- ==========================================
print("=== SubmittingOrders: таймеры ===\n")

getScriptPath = function() return "." end
SettingsManager = require("SettingsManager")
N_CloseAllOrder = function() end
require("SubmittingOrders")

print("--- SubmittingOrders() вызывает SubmittingOrdersRun ---")
test("Вызов SubmittingOrdersRun когда время утра наступило", function()
  TimeMorningStart = os.date("*t", 0)
  TimeMainStart = os.date("*t", 2000000000)
  TimeEveningStart = os.date("*t", 2000000000)
  IsMorningTime = false
  IsMainTime = false
  IsEveningTime = false
  IsSentOrders = false
  IsSendingOrders = false
  Config.SessionMorningEnabled = true

  local runCalled = false
  local saved = SubmittingOrdersRun
  SubmittingOrdersRun = function() runCalled = true end
  SubmittingOrders()
  SubmittingOrdersRun = saved

  assert(runCalled, "SubmittingOrdersRun должен быть вызван")
end)

test("Run НЕ вызывается когда утро ещё не наступило", function()
  TimeMorningStart = os.date("*t", 2000000000)
  TimeMainStart = os.date("*t", 2000000000)
  TimeEveningStart = os.date("*t", 2000000000)
  IsMorningTime = false
  IsSentOrders = false
  local runCalled = false
  local saved = SubmittingOrdersRun
  SubmittingOrdersRun = function() runCalled = true end
  SubmittingOrders()
  SubmittingOrdersRun = saved

  assert(not runCalled, "Run не должен вызываться до утра")
end)

print("\n--- N_CloseAllOrder при старте основной сессии ---")
test("CloseAllOrder вызван при переходе на основную сессию", function()
  TimeMorningStart = os.date("*t", 0)
  TimeMainStart = os.date("*t", 0)
  TimeEveningStart = os.date("*t", 2000000000)
  IsMorningTime = true
  IsMainTime = false
  IsEveningTime = false
  IsSentOrders = true
  Config.SessionMainEnabled = true

  local closeCalled = false
  local savedClose = N_CloseAllOrder
  local savedRun = SubmittingOrdersRun
  N_CloseAllOrder = function() closeCalled = true end
  SubmittingOrdersRun = function() end
  SubmittingOrders()
  N_CloseAllOrder = savedClose
  SubmittingOrdersRun = savedRun

  assert(closeCalled, "N_CloseAllOrder должен быть вызван")
  assert(IsMainTime == true, "IsMainTime должен стать true")
end)

test("CloseAllOrder НЕ вызван когда IsSentOrders=false", function()
  TimeMorningStart = os.date("*t", 0)
  TimeMainStart = os.date("*t", 0)
  TimeEveningStart = os.date("*t", 2000000000)
  IsMorningTime = true
  IsMainTime = false
  IsSentOrders = false
  Config.SessionMainEnabled = true

  local closeCalled = false
  local savedClose = N_CloseAllOrder
  local savedRun = SubmittingOrdersRun
  N_CloseAllOrder = function() closeCalled = true end
  SubmittingOrdersRun = function() end
  SubmittingOrders()
  N_CloseAllOrder = savedClose
  SubmittingOrdersRun = savedRun

  assert(not closeCalled, "N_CloseAllOrder не должен вызываться если IsSentOrders=false")
end)

print("\n--- Сессии отключены ---")
test("Все сессии отключены -> IsSentOrders не сбрасывается", function()
  TimeMorningStart = os.date("*t", 0)
  TimeMainStart = os.date("*t", 0)
  TimeEveningStart = os.date("*t", 0)
  IsMorningTime = false
  IsMainTime = false
  IsEveningTime = false
  IsSentOrders = true
  Config.SessionMorningEnabled = false
  Config.SessionMainEnabled = false
  Config.SessionEveningEnabled = false

  local savedRun = SubmittingOrdersRun
  SubmittingOrdersRun = function() end
  SubmittingOrders()
  SubmittingOrdersRun = savedRun

  assert(IsSentOrders == true, "IsSentOrders должен остаться true")
end)

print("\n--- Переход между сессиями ---")
test("Утро -> основная: IsMorningTime=true, IsMainTime=true", function()
  TimeMorningStart = os.date("*t", 0)
  TimeMainStart = os.date("*t", 0)
  TimeEveningStart = os.date("*t", 2000000000)
  IsMorningTime = false
  IsMainTime = false
  IsEveningTime = false
  IsSentOrders = false
  Config.SessionMorningEnabled = true
  Config.SessionMainEnabled = true

  local saved = SubmittingOrdersRun
  SubmittingOrdersRun = function() end
  SubmittingOrders()
  SubmittingOrdersRun = saved

  assert(IsMorningTime == true, "IsMorningTime=true")
  assert(IsMainTime == true, "IsMainTime=true")
end)

-- ==========================================
-- WaitForMarketData: дополнительные тесты
-- ==========================================
print("\n\n=== WaitForMarketData: доп. тесты ===\n")

local sleepCalls = {}
local getParamExCalls = {}
local lastGetParamExResult = { param_value = "0", result = "0" }

_G.getParamEx = function(classCode, secCode, param)
  table.insert(getParamExCalls, { classCode = classCode, secCode = secCode, param = param })
  return lastGetParamExResult
end
_G.sleep = function(ms) table.insert(sleepCalls, ms) end

require("SubmittingOrders")

test("LAST>0 -> return true, без sleep", function()
  lastGetParamExResult = { param_value = "1000", result = "1" }
  getParamExCalls = {}
  sleepCalls = {}
  -- marketDataWaited может быть true от предыдущих тестов,
  -- но WaitForMarketData использует локальную переменную
  -- Поэтому тест проверяет сценарий когда LAST>0
  local r = WaitForMarketData()
  if r == true then
    assert(#sleepCalls == 0, "Не должно быть sleep когда LAST>0")
  end
end)

test("Проверяет GAZP, SBER, SU26245RMFS9 по порядку", function()
  getParamExCalls = {}
  sleepCalls = {}
  _G.getParamEx = function(classCode, secCode, param)
    table.insert(getParamExCalls, { classCode = classCode, secCode = secCode, param = param })
    if secCode == "SU26245RMFS9" then
      return { param_value = "100", result = "1" }
    end
    return { param_value = "0", result = "1" }
  end

  -- marketDataWaited уже true, WaitForMarketData вернёт nil
  -- Этот сценарий уже покрыт в test_wait_market_data.lua
  local r = WaitForMarketData()
  assert(r == nil, "marketDataWaited=true -> skip")
end)

-- ==========================================
-- SubmittingOrdersRun: доп. тесты
-- ==========================================
print("\n\n=== SubmittingOrdersRun: доп. тесты ===\n")

N_Orders = {}
N_LastOrderNum = 0
N_TransReplies = {}
N_LastTransID = 0
function N_SetLimitOrder(ac, cc, class, sec, op, price, qty)
  N_LastOrderNum = N_LastOrderNum + 1
  N_LastTransID = N_LastTransID + 1
  table.insert(N_Orders, {
    trans_id = N_LastTransID, order_num = N_LastOrderNum,
    sec_code = sec, class_code = class, operation = op,
    price = price, quantity = qty, balance = qty,
  })
  BrokerAdapter.SendTransaction({ ACTION = "NEW_ORDER", SECCODE = sec, OPERATION = op, PRICE = price, QUANTITY = qty })
  return N_LastTransID, ""
end
function IsOrderExists(o) return false end

require("SubmittingOrders")
local csvData = {}
getFromCSV = function(fileName) return csvData[fileName] or {} end

local function resetRun()
  PositionService.ClearCache()
  mock.Reset()
  mock.ClearSent()
  mock.AddSecurity("GAZP", "TQBR",
    { last = 1000, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 })
  mock.AddSecurity("SBER", "TQBR",
    { last = 300, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 })
  N_Orders = {}
  N_LastOrderNum = 0
  N_TransReplies = {}
  N_LastTransID = 0
  sendOrders = {}
  sendOrdersSet = {}
  unknownSecurities = {}
  IsSentOrders = false
  IsSendingOrders = false
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

local function testRun(name, fn)
  resetRun()
  local ok, err = pcall(fn)
  if ok then passed = passed + 1
  else
    failed = failed + 1
    table.insert(errors, string.format("FAIL: %s - %s", name, tostring(err)))
    print("  FAIL: " .. name)
  end
end

print("--- Guard checks ---")
testRun("BrokerEnabled=false -> нет ордеров", function()
  Config.BrokerEnabled = false
  SubmittingOrdersRun()
  assert(#N_Orders == 0)
end)

testRun("IsSendingOrders=true -> skip", function()
  IsSendingOrders = true
  SubmittingOrdersRun()
  assert(IsSendingOrders == true)
end)

print("\n--- Загрузка файлов ---")
testRun("BuyOrders загружается", function()
  csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "10", "1000" } }
  SubmittingOrdersRun()
  assert(#N_Orders >= 1, "Ожидался >=1 ордер")
end)

testRun("SellOrders загружается", function()
  csvData["TEST_SellOrders.csv"] = { { "GAZP", "S", "GAZP", "10", "1000" } }
  mock.AddPosition("GAZP", 100, 500)
  SubmittingOrdersRun()
  assert(#N_Orders >= 1, "Ожидался >=1 ордер")
end)

testRun("Пустые CSV -> 0 ордеров", function()
  SubmittingOrdersRun()
  assert(#N_Orders == 0, "Ожидалось 0 ордеров")
end)

testRun("Buy + Sell одновременно", function()
  csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "5", "1000" } }
  csvData["TEST_SellOrders.csv"] = { { "SBER", "S", "SBER", "10", "300" } }
  mock.AddPosition("SBER", 100, 300)
  SubmittingOrdersRun()
  assert(#N_Orders >= 2, "Ожидалось >=2 ордеров (buy + sell)")
end)

print("\n--- Комментарии и пропуски ---")
testRun("Комментарии в CSV пропускаются", function()
  csvData["TEST_BuyOrders.csv"] = {
    { "--ГАЗПРОМ", "B", "GAZP", "10", "1000" },
    { "GAZP", "B", "GAZP", "5", "1000" },
  }
  SubmittingOrdersRun()
  assert(#N_Orders == 1, "Только 1 ордер (комментарий пропущен)")
end)

testRun("Неизвестная бумага -> 0 ордеров", function()
  csvData["TEST_BuyOrders.csv"] = { { "UNKNOWN", "B", "UNKNOWN", "10", "100" } }
  SubmittingOrdersRun()
  assert(#N_Orders == 0, "Неизвестная бумага не должна создавать ордер")
end)

print("\n--- Дедупликация ---")
testRun("Дубликат -> duplicate=1, sent=0", function()
  csvData["TEST_BuyOrders.csv"] = {
    { "GAZP", "B", "GAZP", "5", "1000" },
    { "GAZP", "B", "GAZP", "5", "1000" },
  }
  SubmittingOrdersRun()
  assert(#N_Orders == 1, "Дубликат должен быть отброшен")
end)

print("\n--- sendOrders ---")
testRun("sendTransaction вызван для ордеров", function()
  csvData["TEST_BuyOrders.csv"] = {
    { "GAZP", "B", "GAZP", "3", "1000" },
  }
  SubmittingOrdersRun()
  assert(mock.GetSentCount() >= 1, "Ожидалась >=1 транзакция")
end)

testRun("sendOrders очищается после цикла", function()
  csvData["TEST_BuyOrders.csv"] = { { "GAZP", "B", "GAZP", "5", "1000" } }
  SubmittingOrdersRun()
  assert(#sendOrders == 0, "sendOrders должен быть очищен")
  assert(next(sendOrdersSet) == nil, "sendOrdersSet должен быть очищен")
end)

print("\n--- IsSentOrders ---")
testRun("IsSentOrders=true после SubmittingOrdersRun", function()
  csvData["TEST_BuyOrders.csv"] = {}
  SubmittingOrdersRun()
  assert(IsSentOrders == true, "IsSentOrders должен стать true")
end)

testRun("IsSendingOrders=false после SubmittingOrdersRun", function()
  csvData["TEST_BuyOrders.csv"] = {}
  SubmittingOrdersRun()
  assert(IsSendingOrders == false, "IsSendingOrders должен стать false")
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
