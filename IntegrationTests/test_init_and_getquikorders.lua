--- Интеграционные тесты для Initialization и GetQuikOrders.

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
require("Constants")
_initConstants()
Config = require("Config")

N_Orders = {}
N_LastOrderNum = 0
N_TransReplies = {}
N_LastTransID = 0
sendOrders = {}
sendOrdersSet = {}

function OnOrder(order)
  table.insert(N_Orders, order)
end

require("SubmittingOrders")

local passed, failed = 0, 0
local function ok(name, cond)
  if cond then
    passed = passed + 1
    print("  PASS: " .. name)
  else
    failed = failed + 1
    print("  FAIL: " .. name)
  end
end

-- ==========================================
print("=== Initialization Tests ===\n")

local called = false
local orig = SetClientSetting
SetClientSetting = function()
  called = true
end
Initialization()
SetClientSetting = orig
ok("SetClientSetting вызывается", called)

Initialization()
ok("TimeMainStart.hour = Config.SessionMain.hour", TimeMainStart.hour == Config.SessionMain.hour)
ok("TimeMorningStart.hour = Config.SessionMorning.hour", TimeMorningStart.hour == Config.SessionMorning.hour)
ok("TimeEveningStart.hour = Config.SessionEvening.hour", TimeEveningStart.hour == Config.SessionEvening.hour)

IsSentOrders = true
IsSendingOrders = true
IsMorningTime = true
IsMainTime = true
IsEveningTime = true
Initialization()
ok("IsSentOrders=false", IsSentOrders == false)
ok("IsSendingOrders=false", IsSendingOrders == false)
ok("IsMorningTime=false", IsMorningTime == false)
ok("IsMainTime=false", IsMainTime == false)
ok("IsEveningTime=false", IsEveningTime == false)

-- ==========================================
print("\n=== GetQuikOrders Tests ===\n")

N_Orders = {}
GetQuikOrders()
ok("нет заказов -> N_Orders пуст", #N_Orders == 0)

mock.Reset()
mock.AddOrder({
  sec_code = "GAZP",
  class_code = "TQBR",
  flags = FLAG_ACTIVE,
  trans_id = 1,
  order_num = 1,
  price = 1000,
  qty = 10,
  balance = 10,
})
N_Orders = {}
GetQuikOrders()
ok("1 активный заказ -> N_Orders=1", #N_Orders == 1)
ok("sec_code = GAZP", N_Orders[1] and N_Orders[1].sec_code == "GAZP")

mock.AddOrder({
  sec_code = "SBER",
  class_code = "TQBR",
  flags = FLAG_ACTIVE,
  trans_id = 2,
  order_num = 2,
  price = 300,
  qty = 10,
  balance = 10,
})
N_Orders = {}
GetQuikOrders()
ok("2 активных заказа -> N_Orders>=2", #N_Orders >= 2)

-- ==========================================
print(string.format("\n=== %d passed, %d failed ===", passed, failed))
os.exit(failed > 0 and 1 or 0)
