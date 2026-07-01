--- Модуль настроек и управления параметрами подключения.
--- Содержит набор функций SetSettingVTB, SetSettingPSB, SetSettingFinam и др.
--- Для настройки Config используется файл settings.json.
--- Все настройки загружаются из USERID через BrokerRegistry.

local Constants = require("Constants")
local BrokerAdapter = require("BrokerAdapter")
local Config = require("Config")

require("TableSetting")
local SettingsManager = require("SettingsManager")

--- Кэш: какой USERID соответствует какому брокеру
BrokerUserMap = {
  ["171783"] = "FINAM",
  ["49653"] = "VTB",
  ["34146"] = "PSB",
  ["48640"] = "RSHB",
}


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


end
