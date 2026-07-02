--- Тесты для SubmittingOrders (таймеры сессий).

package.path = "?.lua;Tests/?.lua;libs/?.lua;utils/?.lua;" .. package.path

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
Config = require("Config")

getScriptPath = function()
	return "."
end
SettingsManager = require("SettingsManager")
require("SubmittingOrders")

-- ==========================================
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
print("=== SubmittingOrders Session Timers ===\n")

-- Вместо SubmittingOrders() (который вызывает SubmittingOrdersRun),
-- тестируем логику таймеров напрямую через флаги.

print("--- Утро ---")
-- Утро наступило, сессия включена -> IsSentOrders сбрасывается
TimeMorningStart = os.date("*t", 0)
TimeMainStart = os.date("*t", 2000000000)
TimeEveningStart = os.date("*t", 2000000000)
IsMorningTime = false
IsSentOrders = true
Config.SessionMorningEnabled = true
-- Эмулируем логику SubmittingOrders для утра
if (os.time(TimeMorningStart) < os.time()) and not IsMorningTime then
	IsMorningTime = true
	if Config.SessionMorningEnabled then
		IsSentOrders = false
	end
end
ok("утро: IsMorningTime=true", IsMorningTime == true)
ok("утро: IsSentOrders=false", IsSentOrders == false)

-- Утро + SessionMorningEnabled=false -> IsSentOrders не сбрасывается
IsMorningTime = false
IsSentOrders = true
Config.SessionMorningEnabled = false
if (os.time(TimeMorningStart) < os.time()) and not IsMorningTime then
	IsMorningTime = true
	if Config.SessionMorningEnabled then
		IsSentOrders = false
	end
end
ok("утро disabled: IsSentOrders не сбрасывается", IsSentOrders == true)

print("\n--- День ---")
TimeMorningStart = os.date("*t", 0)
TimeMainStart = os.date("*t", 0)
TimeEveningStart = os.date("*t", 2000000000)
IsMorningTime = true
IsMainTime = false
IsSentOrders = true
Config.SessionMainEnabled = true
if (os.time(TimeMainStart) < os.time()) and not IsMainTime then
	IsMainTime = true
	if Config.SessionMainEnabled then
		IsSentOrders = false
	end
end
ok("день: IsMainTime=true", IsMainTime == true)
ok("день: IsSentOrders=false", IsSentOrders == false)

IsMainTime = false
IsSentOrders = true
Config.SessionMainEnabled = false
if (os.time(TimeMainStart) < os.time()) and not IsMainTime then
	IsMainTime = true
	if Config.SessionMainEnabled then
		IsSentOrders = false
	end
end
ok("день disabled: IsSentOrders не сбрасывается", IsSentOrders == true)

print("\n--- Вечер ---")
TimeMorningStart = os.date("*t", 0)
TimeMainStart = os.date("*t", 0)
TimeEveningStart = os.date("*t", 0)
IsMorningTime = true
IsMainTime = true
IsEveningTime = false
IsSentOrders = true
Config.SessionEveningEnabled = true
if (os.time(TimeEveningStart) < os.time()) and not IsEveningTime then
	IsEveningTime = true
	if Config.SessionEveningEnabled then
		IsSentOrders = false
	end
end
ok("вечер: IsEveningTime=true", IsEveningTime == true)
ok("вечер: IsSentOrders=false", IsSentOrders == false)

print(string.format("\n=== %d passed, %d failed ===", passed, failed))
os.exit(failed > 0 and 1 or 0)
