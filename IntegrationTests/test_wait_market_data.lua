--- Интеграционные тесты для WaitForMarketData.

package.path = "?.lua;IntegrationTests/?.lua;" .. package.path

local mock = dofile("IntegrationTests/quik_mock.lua")

mock.AddSecurity(
  "GAZP",
  "TQBR",
  { last = 0, pricemin = 800, pricemax = 1200, lot = 1, scale = 2, min_price_step = 0.1 }
)
mock.AddSecurity(
  "SBER",
  "TQBR",
  { last = 0, pricemin = 250, pricemax = 350, lot = 1, scale = 2, min_price_step = 0.01 }
)

log = require("log")
log.level = "fatal"
log.usecolor = false
json = require("json")
require("Order")
require("Constants")
_initConstants()

-- Мок ДО require SubmittingOrders
local sleepCalls = {}
local getParamExCalls = {}
local lastGetParamExResult = { param_value = "0", result = "0" }

_G.getParamEx = function(classCode, secCode, param)
  table.insert(getParamExCalls, { classCode = classCode, secCode = secCode, param = param })
  return lastGetParamExResult
end

_G.sleep = function(ms)
  table.insert(sleepCalls, ms)
end

require("SubmittingOrders")

-- ==========================================
local passed, failed = 0, 0

local function check(name, condition)
  if condition then
    passed = passed + 1
    print("  PASS: " .. name)
  else
    failed = failed + 1
    print("  FAIL: " .. name)
  end
end

-- ==========================================
print("=== WaitForMarketData Tests ===\n")

print("--- Данные доступны сразу ---")
lastGetParamExResult = { param_value = "1000", result = "1" }
local r = WaitForMarketData()
check("LAST>0 -> return true", r == true)
check("без sleep если данные есть", #sleepCalls == 0)
check("getParamEx вызван для GAZP", getParamExCalls[1].secCode == "GAZP")
check("getParamEx вызван для LAST", getParamExCalls[1].param == "LAST")

-- marketDataWaited: проверяем что повторный вызов пропускается
print("\n--- Повторный вызов (skip) ---")
local callsBefore = #getParamExCalls
local r2 = WaitForMarketData()
check("второй вызов -> skip (nil)", r2 == nil)
check("без новых getParamEx", #getParamExCalls == callsBefore)

print(string.format("\n=== %d passed, %d failed ===", passed, failed))
os.exit(failed > 0 and 1 or 0)
