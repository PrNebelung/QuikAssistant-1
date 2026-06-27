--- Модуль настроек и управления параметрами подключения.
--- Содержит набор функций SetSettingVTB, SetSettingPSB, SetSettingFinam и др.
--- Для настройки Config используется файл settings.json.
--- Все настройки загружаются из USERID через BrokerRegistry.

local Constants = require("Constants")
local BrokerAdapter = require("BrokerAdapter")
local Config = require("Config")

require("TableSetting")
local SettingsManager = require('SettingsManager')

--- Кэш: какой USERID соответствует какому брокеру
BrokerUserMap = {
  ["171783"] = "FINAM",
  ["49653"] = "VTB",
  ["34146"] = "PSB",
  ["48640"] = "RSHB",
  ["119330"] = "TEST",
}

--- Копирование значений Config.* в глобальные переменные
function _initSettingGlobals()
  Broker = Config.Broker
  ClientCode = Config.ClientCode
  AccountCode = Config.AccountCode
  FirmId = Config.FirmId
  VolumeOrderMax = Config.VolumeOrderMax
  BondVolumeOrderMax = Config.BondVolumeOrderMax
  VolumeOrderLimit = Config.VolumeOrderLimit
  VolumeOrderLimitUSD = Config.VolumeOrderLimitUSD
  LimitActuationOrderEdge = Config.LimitActuationOrderEdge
  LimitActuationOrderBondEdge = Config.LimitActuationOrderBondEdge
  FileBuyOrder = Config.FileBuyOrder
  FileSellOrder = Config.FileSellOrder
  FileBuyOrderEdge = Config.FileBuyOrderEdge
  FileBuyOrderBondsEdge = Config.FileBuyOrderBondsEdge
  FileSellOrderEdge = Config.FileSellOrderEdge
  SessionMorningEnabled = Config.SessionMorningEnabled
  SessionMainEnabled = Config.SessionMainEnabled
  SessionEveningEnabled = Config.SessionEveningEnabled
  BrokerEnabled = Config.BrokerEnabled
end

--- Определение брокера по USERID и применение настроек из settings.json
function SetClientSetting()
  if ClearSecurityInfoCache then
    ClearSecurityInfoCache()
  end

  local userId = BrokerAdapter.GetInfoParam("USERID")
  local brokerName = BrokerUserMap[userId]

  if brokerName then
    -- Загружаем настройки из settings.json для этого брокера
    SettingsManager.ApplyBroker(brokerName)
  else
    Config.Broker = ""
    Config.ClientCode = ""
    Config.AccountCode = ""
    Config.VolumeOrderMax = 0
    Config.BrokerEnabled = false
  end

  _initSettingGlobals()
end
