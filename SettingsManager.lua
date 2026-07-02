--- Модуль управления настройками через JSON-файл.
--- Формат settings.json: { "VTB": {...}, "PSB": {...}, ... }
--- Каждый брокер - отдельный блок настроек.

local json = require("json")
local Config = require("Config")

local SettingsManager = {}
local SETTINGS_FILE = getScriptPath() .. "\\settings.json"

--- Загрузка всех настроек из settings.json.
--- @return table все настройки брокеров, ключ — имя брокера
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

--- Сохранение всех настроек в settings.json.
--- @param data table все настройки для сохранения
--- @return boolean результат операции (true при успехе)
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

--- Получение настроек брокера с значениями по умолчанию.
--- @param brokerName string идентификатор брокера
--- @return table настройки брокера с применёнными значениями по умолчанию
function SettingsManager.GetBroker(brokerName)
	local all = SettingsManager.LoadAll()
	local broker = all[brokerName] or {}
	return {
		clientCode = broker.clientCode or Config.ClientCode,
		accountCode = broker.accountCode or Config.AccountCode,
		firmId = broker.firmId or Config.FirmId,
		volumeOrderMax = broker.volumeOrderMax or Config.VolumeOrderMax,
		bondVolumeOrderMax = broker.bondVolumeOrderMax or Config.BondVolumeOrderMax,
		volumeOrderLimit = broker.volumeOrderLimit or Config.VolumeOrderLimit,
		limitActuationOrderEdge = broker.limitActuationOrderEdge or Config.LimitActuationOrderEdge,
		limitActuationOrderBondEdge = broker.limitActuationOrderBondEdge or Config.LimitActuationOrderBondEdge,
		sessionMorningEnabled = broker.sessionMorningEnabled or Config.SessionMorningEnabled,
		sessionMainEnabled = broker.sessionMainEnabled or Config.SessionMainEnabled,
		sessionEveningEnabled = broker.sessionEveningEnabled or Config.SessionEveningEnabled,
		brokerEnabled = broker.brokerEnabled or Config.BrokerEnabled,
		sessionMorningHour = broker.sessionMorningHour or Config.SessionMorning.hour,
		sessionMorningMin = broker.sessionMorningMin or Config.SessionMorning.min,
		sessionMorningSec = broker.sessionMorningSec or Config.SessionMorning.sec,
		sessionMainHour = broker.sessionMainHour or Config.SessionMain.hour,
		sessionMainMin = broker.sessionMainMin or Config.SessionMain.min,
		sessionMainSec = broker.sessionMainSec or Config.SessionMain.sec,
		sessionEveningHour = broker.sessionEveningHour or Config.SessionEvening.hour,
		sessionEveningMin = broker.sessionEveningMin or Config.SessionEvening.min,
		sessionEveningSec = broker.sessionEveningSec or Config.SessionEvening.sec,
	}
end

--- Сохранение настроек брокера.
--- @param brokerName string идентификатор брокера
--- @param data table настройки брокера
--- @return boolean результат операции
function SettingsManager.SaveBroker(brokerName, data)
	local all = SettingsManager.LoadAll()
	all[brokerName] = data
	return SettingsManager.SaveAll(all)
end

--- Применение настроек брокера к глобальному модулю Config.
--- @param brokerName string идентификатор брокера
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
