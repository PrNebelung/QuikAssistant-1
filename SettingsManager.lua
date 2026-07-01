--- Модуль управления настройками через JSON-файл.
--- Формат settings.json: { "VTB": {...}, "PSB": {...}, ... }
--- Каждый брокер - отдельный блок настроек.

local json = require("json")
local Config = require("Config")

local SettingsManager = {}
local SETTINGS_FILE = getScriptPath() .. "\\settings.json"

local defaults = {
  clientCode = "",
  accountCode = "",
  firmId = "",
  volumeOrderMax = 0,
  bondVolumeOrderMax = 0,
  volumeOrderLimit = 200000,
  limitActuationOrderEdge = 5,
  limitActuationOrderBondEdge = 60,
  sessionMorningEnabled = false,
  sessionMainEnabled = false,
  sessionEveningEnabled = false,
  brokerEnabled = false,
  sessionMorningHour = 7,
  sessionMorningMin = 0,
  sessionMorningSec = 30,
  sessionMainHour = 10,
  sessionMainMin = 0,
  sessionMainSec = 30,
  sessionEveningHour = 19,
  sessionEveningMin = 2,
  sessionEveningSec = 10,
}

function SettingsManager.LoadAll()
  local f = io.open(SETTINGS_FILE, "r")
  if f == nil then
    return {}
  end
  local content = f:read("*a")
  f:close()
  if content == nil or content == "" then
    return {}
  end
  local ok, data = pcall(json.decode, content)
  if not ok then
    log.error(string.format("Ошибка парсинга settings.json: %s", tostring(data)))
    return {}
  end
  return data
end

function SettingsManager.SaveAll(data)
  local f = io.open(SETTINGS_FILE, "w")
  if f == nil then
    log.error("Cannot open settings.json for writing")
    return false
  end
  f:write(json.encode(data))
  f:close()
  return true
end

function SettingsManager.GetBroker(brokerName)
  local all = SettingsManager.LoadAll()
  local broker = all[brokerName] or {}
  local result = {}
  for k, v in pairs(defaults) do
    result[k] = broker[k] ~= nil and broker[k] or v
  end
  return result
end

function SettingsManager.SaveBroker(brokerName, data)
  local all = SettingsManager.LoadAll()
  all[brokerName] = data
  return SettingsManager.SaveAll(all)
end

function SettingsManager.ApplyBroker(brokerName)
  local all = SettingsManager.LoadAll()
  if not all[brokerName] then
    log.warn(string.format("Нет настроек для брокера %s, отключение", brokerName))
    Config.Broker = brokerName
    Config.BrokerEnabled = false
    Config.SessionMorningEnabled = false
    Config.SessionMainEnabled = false
    Config.SessionEveningEnabled = false
    return
  end

  local s = SettingsManager.GetBroker(brokerName)

  Config.Broker = brokerName
  Config.ClientCode = s.clientCode
  Config.AccountCode = s.accountCode
  Config.FirmId = s.firmId

  Config.VolumeOrderMax = tonumber(s.volumeOrderMax) or 0
  Config.BondVolumeOrderMax = tonumber(s.bondVolumeOrderMax) or 0
  Config.VolumeOrderLimit = tonumber(s.volumeOrderLimit) or 200000

  Config.LimitActuationOrderEdge = tonumber(s.limitActuationOrderEdge) or 5
  Config.LimitActuationOrderBondEdge = tonumber(s.limitActuationOrderBondEdge) or 60

  Config.SessionMorningEnabled = s.sessionMorningEnabled
  Config.SessionMainEnabled = s.sessionMainEnabled
  Config.SessionEveningEnabled = s.sessionEveningEnabled
  Config.BrokerEnabled = s.brokerEnabled

  Config.SessionMorning.hour = tonumber(s.sessionMorningHour) or 7
  Config.SessionMorning.min = tonumber(s.sessionMorningMin) or 0
  Config.SessionMorning.sec = tonumber(s.sessionMorningSec) or 30
  Config.SessionMain.hour = tonumber(s.sessionMainHour) or 10
  Config.SessionMain.min = tonumber(s.sessionMainMin) or 0
  Config.SessionMain.sec = tonumber(s.sessionMainSec) or 30
  Config.SessionEvening.hour = tonumber(s.sessionEveningHour) or 19
  Config.SessionEvening.min = tonumber(s.sessionEveningMin) or 2
  Config.SessionEvening.sec = tonumber(s.sessionEveningSec) or 10

  Config.FileBuyOrder = Config.Broker .. "_BuyOrders.csv"
  Config.FileSellOrder = Config.Broker .. "_SellOrders.csv"
  Config.FileBuyOrderEdge = Config.Broker .. "_BuyOrders_Edge.csv"
  Config.FileBuyOrderBondsEdge = Config.Broker .. "_BuyOrdersBonds_Edge.csv"
  Config.FileSellOrderEdge = Config.Broker .. "_SellOrders_Edge.csv"

  log.info(string.format("Настройки применены для брокера %s", brokerName))
end

return SettingsManager
