--- Модуль управления настройками через JSON-файл.
--- Позволяет читать и записывать настройки извне (веб-интерфейс).

local json = require("json")
local Config = require("Config")

local SettingsManager = {}
local SETTINGS_FILE = getScriptPath() .. "\\Data\\settings.json"

-- Значения по умолчанию (из Config.lua)
local defaults = {
    Broker = "",
    ClientCode = "",
    AccountCode = "",
    FirmId = "",
    VolumeOrderMax = 0,
    BondVolumeOrderMax = 0,
    VolumeOrderLimit = 200000,
    VolumeOrderLimitUSD = 100,
    LimitActuationOrderEdge = 5,
    LimitActuationOrderBondEdge = 60,
    SessionMorningEnabled = true,
    SessionMainEnabled = true,
    SessionEveningEnabled = true,
    BrokerEnabled = true,
    SessionMorningHour = 7,
    SessionMorningMin = 0,
    SessionMorningSec = 30,
    SessionMainHour = 10,
    SessionMainMin = 0,
    SessionMainSec = 30,
    SessionEveningHour = 19,
    SessionEveningMin = 2,
    SessionEveningSec = 10,
}

--- Чтение настроек из JSON-файла
function SettingsManager.Load()
    local f = io.open(SETTINGS_FILE, "r")
    if f == nil then
        return nil
    end
    local content = f:read("*a")
    f:close()
    if content == nil or content == "" then
        return nil
    end
    local ok, data = pcall(json.decode, content)
    if not ok then
        log.error("Failed to parse settings.json: " .. tostring(data))
        return nil
    end
    return data
end

--- Запись настроек в JSON-файл
function SettingsManager.Save(data)
    local f = io.open(SETTINGS_FILE, "w")
    if f == nil then
        log.error("Cannot open settings.json for writing")
        return false
    end
    f:write(json.encode(data))
    f:close()
    return true
end

--- Применение настроек к Config
function SettingsManager.Apply(data)
    if data == nil then return end

    if data.Broker ~= nil then Config.Broker = data.Broker end
    if data.ClientCode ~= nil then Config.ClientCode = data.ClientCode end
    if data.AccountCode ~= nil then Config.AccountCode = data.AccountCode end
    if data.FirmId ~= nil then Config.FirmId = data.FirmId end

    if data.VolumeOrderMax ~= nil then Config.VolumeOrderMax = tonumber(data.VolumeOrderMax) or 0 end
    if data.BondVolumeOrderMax ~= nil then Config.BondVolumeOrderMax = tonumber(data.BondVolumeOrderMax) or 0 end
    if data.VolumeOrderLimit ~= nil then Config.VolumeOrderLimit = tonumber(data.VolumeOrderLimit) or 200000 end
    if data.VolumeOrderLimitUSD ~= nil then Config.VolumeOrderLimitUSD = tonumber(data.VolumeOrderLimitUSD) or 100 end

    if data.LimitActuationOrderEdge ~= nil then Config.LimitActuationOrderEdge = tonumber(data.LimitActuationOrderEdge) or 5 end
    if data.LimitActuationOrderBondEdge ~= nil then Config.LimitActuationOrderBondEdge = tonumber(data.LimitActuationOrderBondEdge) or 60 end

    if data.SessionMorningEnabled ~= nil then Config.SessionMorningEnabled = data.SessionMorningEnabled end
    if data.SessionMainEnabled ~= nil then Config.SessionMainEnabled = data.SessionMainEnabled end
    if data.SessionEveningEnabled ~= nil then Config.SessionEveningEnabled = data.SessionEveningEnabled end
    if data.BrokerEnabled ~= nil then Config.BrokerEnabled = data.BrokerEnabled end

    if data.SessionMorningHour ~= nil then Config.SessionMorning.hour = tonumber(data.SessionMorningHour) or 7 end
    if data.SessionMorningMin ~= nil then Config.SessionMorning.min = tonumber(data.SessionMorningMin) or 0 end
    if data.SessionMorningSec ~= nil then Config.SessionMorning.sec = tonumber(data.SessionMorningSec) or 30 end

    if data.SessionMainHour ~= nil then Config.SessionMain.hour = tonumber(data.SessionMainHour) or 10 end
    if data.SessionMainMin ~= nil then Config.SessionMain.min = tonumber(data.SessionMainMin) or 0 end
    if data.SessionMainSec ~= nil then Config.SessionMain.sec = tonumber(data.SessionMainSec) or 30 end

    if data.SessionEveningHour ~= nil then Config.SessionEvening.hour = tonumber(data.SessionEveningHour) or 19 end
    if data.SessionEveningMin ~= nil then Config.SessionEvening.min = tonumber(data.SessionEveningMin) or 2 end
    if data.SessionEveningSec ~= nil then Config.SessionEvening.sec = tonumber(data.SessionEveningSec) or 10 end

    Config.FileBuyOrder = Config.Broker .. "_BuyOrders.csv"
    Config.FileSellOrder = Config.Broker .. "_SellOrders.csv"
    Config.FileBuyOrderEdge = Config.Broker .. "_BuyOrders_Edge.csv"
    Config.FileBuyOrderBondsEdge = Config.Broker .. "_BuyOrdersBonds_Edge.csv"
    Config.FileSellOrderEdge = Config.Broker .. "_SellOrders_Edge.csv"

    log.info("Settings applied from settings.json")
end

--- Получение текущих настроек как таблица
function SettingsManager.GetCurrent()
    return {
        Broker = Config.Broker,
        ClientCode = Config.ClientCode,
        AccountCode = Config.AccountCode,
        FirmId = Config.FirmId,
        VolumeOrderMax = Config.VolumeOrderMax,
        BondVolumeOrderMax = Config.BondVolumeOrderMax,
        VolumeOrderLimit = Config.VolumeOrderLimit or 200000,
        VolumeOrderLimitUSD = Config.VolumeOrderLimitUSD or 100,
        LimitActuationOrderEdge = Config.LimitActuationOrderEdge,
        LimitActuationOrderBondEdge = Config.LimitActuationOrderBondEdge,
        SessionMorningEnabled = Config.SessionMorningEnabled,
        SessionMainEnabled = Config.SessionMainEnabled,
        SessionEveningEnabled = Config.SessionEveningEnabled,
        BrokerEnabled = Config.BrokerEnabled,
        SessionMorningHour = Config.SessionMorning.hour,
        SessionMorningMin = Config.SessionMorning.min,
        SessionMorningSec = Config.SessionMorning.sec,
        SessionMainHour = Config.SessionMain.hour,
        SessionMainMin = Config.SessionMain.min,
        SessionMainSec = Config.SessionMain.sec,
        SessionEveningHour = Config.SessionEvening.hour,
        SessionEveningMin = Config.SessionEvening.min,
        SessionEveningSec = Config.SessionEvening.sec,
    }
end

return SettingsManager
