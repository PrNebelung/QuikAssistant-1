--- Интеграционные тесты для CheckOrder.

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
mock.AddSecurity(
  "RU000A10BFF4",
  "TQCB",
  {
    last = 100,
    pricemin = 80,
    pricemax = 120,
    lot = 1000,
    scale = 2,
    min_price_step = 0.01,
    facevalue = 1000,
    face_unit = "SUR",
  }
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
  mock.AddSecurity(
    "RU000A10BFF4",
    "TQCB",
    {
      last = 100,
      pricemin = 80,
      pricemax = 120,
      lot = 1000,
      scale = 2,
      min_price_step = 0.01,
      facevalue = 1000,
      face_unit = "SUR",
    }
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
test("sell ignores PRICEMIN", function()
  mock.AddPosition("GAZP", 100, 500)
  pass(S("GAZP", 100, 10))
end)
test("bond buy 50 < 80 -> reject", function()
  fail(B("RU000A10BFF4", 50, 1), "PRICEMIN")
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

print("\n--- checkBondPriceLimit ---")
test("bond price 105 > 100% -> reject by actuation", function()
  -- price=105, LAST=100 -> actuation=-4.76% < 60% -> reject by actuation (runs before bondPrice check)
  local sv = Config.VolumeOrderLimit
  Config.VolumeOrderLimit = 10000000
  fail(B("RU000A10BFF4", 105, 1), "actuation")
  Config.VolumeOrderLimit = sv
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

print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if #errors > 0 then
  print("\nFailures:")
  for _, e in ipairs(errors) do
    print("  " .. e)
  end
end
os.exit(failed > 0 and 1 or 0)
