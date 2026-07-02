--- Tests for SettingsManager.

package.path = "?.lua;IntegrationTests/?.lua;" .. package.path

local mock = dofile("IntegrationTests/quik_mock.lua")

log = require("log")
log.level = "fatal"
log.usecolor = false
json = require("json")
require("Order")
require("Constants")
_initConstants()
Config = require("Config")

-- Use a test-specific file name to avoid overwriting real settings.json
local testFileName = "_test_settings_" .. os.time() .. ".json"

getScriptPath = function()
	return "."
end

-- Override io.open to redirect settings.json to our test file
local originalIOOpen = io.open
io.open = function(path, mode)
	if path:find("settings%.json$") then
		return originalIOOpen(testFileName, mode)
	end
	return originalIOOpen(path, mode)
end

-- Reload SettingsManager
package.loaded["SettingsManager"] = nil
SettingsManager = require("SettingsManager")

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
print("=== SettingsManager Tests ===")

print("\n--- LoadAll ---")
test("file does not exist -> empty table", function()
	os.remove(testFileName)
	local result = SettingsManager.LoadAll()
	assert(next(result) == nil)
end)

test("valid JSON -> table", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "386507"}}')
	f:close()
	local result = SettingsManager.LoadAll()
	assert(result.VTB.clientCode == "386507")
end)

test("multiple brokers", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "386507"}, "PSB": {"clientCode": "40200"}}')
	f:close()
	local result = SettingsManager.LoadAll()
	assert(result.VTB ~= nil and result.PSB ~= nil)
end)

test("invalid JSON -> empty table", function()
	local f = io.open(testFileName, "w")
	f:write("{invalid json")
	f:close()
	local result = SettingsManager.LoadAll()
	assert(next(result) == nil)
end)

print("\n--- SaveAll ---")
test("saves data", function()
	local data = { VTB = { clientCode = "386507" } }
	SettingsManager.SaveAll(data)
	local f = io.open(testFileName, "r")
	local content = f:read("*a")
	f:close()
	local saved = json.decode(content)
	assert(saved.VTB.clientCode == "386507")
end)

test("overwrites data", function()
	local f = io.open(testFileName, "w")
	f:write('{"OLD": {}}')
	f:close()
	SettingsManager.SaveAll({ NEW = { clientCode = "123" } })
	local f2 = io.open(testFileName, "r")
	local content = f2:read("*a")
	f2:close()
	local saved = json.decode(content)
	assert(saved.NEW ~= nil and saved.OLD == nil)
end)

print("\n--- GetBroker ---")
test("broker exists -> data from file", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "386507", "volumeOrderMax": 20000}}')
	f:close()
	local r = SettingsManager.GetBroker("VTB")
	assert(r.clientCode == "386507" and r.volumeOrderMax == 20000)
end)

test("broker not found -> defaults", function()
	local f = io.open(testFileName, "w")
	f:write('{"PSB": {}}')
	f:close()
	local r = SettingsManager.GetBroker("VTB")
	assert(r.clientCode == "" and r.volumeOrderMax == 0 and r.brokerEnabled == false)
end)

test("partial data -> defaults for rest", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "386507"}}')
	f:close()
	local r = SettingsManager.GetBroker("VTB")
	assert(r.clientCode == "386507" and r.volumeOrderLimit == 200000 and r.sessionMorningHour == 7)
end)

print("\n--- SaveBroker ---")
test("adds new broker", function()
	local f = io.open(testFileName, "w")
	f:write('{"PSB": {"clientCode": "40200"}}')
	f:close()
	SettingsManager.SaveBroker("VTB", { clientCode = "386507" })
	local f2 = io.open(testFileName, "r")
	local saved = json.decode(f2:read("*a"))
	f2:close()
	assert(saved.VTB.clientCode == "386507" and saved.PSB.clientCode == "40200")
end)

test("overwrites existing broker", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "OLD"}}')
	f:close()
	SettingsManager.SaveBroker("VTB", { clientCode = "NEW" })
	local f2 = io.open(testFileName, "r")
	local saved = json.decode(f2:read("*a"))
	f2:close()
	assert(saved.VTB.clientCode == "NEW")
end)

print("\n--- ApplyBroker ---")
test("broker exists -> Config filled", function()
	local f = io.open(testFileName, "w")
	f:write(
		'{"VTB": {"clientCode": "386507", "volumeOrderMax": 20000, "brokerEnabled": true, "sessionMainEnabled": true, "sessionMainHour": 10}}'
	)
	f:close()
	SettingsManager.ApplyBroker("VTB")
	assert(Config.Broker == "VTB" and Config.ClientCode == "386507")
	assert(Config.VolumeOrderMax == 20000 and Config.BrokerEnabled == true)
	assert(Config.SessionMainEnabled == true and Config.SessionMain.hour == 10)
	assert(Config.FileBuyOrder == "VTB_BuyOrders.csv")
end)

test("broker not found -> disabled", function()
	local f = io.open(testFileName, "w")
	f:write('{"PSB": {}}')
	f:close()
	SettingsManager.ApplyBroker("VTB")
	assert(Config.BrokerEnabled == false)
	assert(Config.SessionMainEnabled == false)
end)

test("default values applied", function()
	local f = io.open(testFileName, "w")
	f:write('{"VTB": {"clientCode": "386507"}}')
	f:close()
	SettingsManager.ApplyBroker("VTB")
	assert(Config.VolumeOrderMax == 0 and Config.LimitActuationOrderEdge == 5)
	assert(Config.SessionMain.hour == 10)
end)

test("File paths from broker name", function()
	local f = io.open(testFileName, "w")
	f:write('{"FINAM": {"clientCode": "test"}}')
	f:close()
	SettingsManager.ApplyBroker("FINAM")
	assert(Config.FileBuyOrder == "FINAM_BuyOrders.csv")
	assert(Config.FileSellOrder == "FINAM_SellOrders.csv")
	assert(Config.FileBuyOrderEdge == "FINAM_BuyOrders_Edge.csv")
end)

-- Cleanup
os.remove(testFileName)

-- ==========================================
print(string.format("\n=== %d passed, %d failed ===", passed, failed))
if #errors > 0 then
	print("\nFailures:")
	for _, e in ipairs(errors) do
		print("  " .. e)
	end
end
os.exit(failed > 0 and 1 or 0)
