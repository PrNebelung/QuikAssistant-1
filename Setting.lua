local Constants = require("Constants")
local BrokerAdapter = require("BrokerAdapter")
local Config = require("Config")

require("TableSetting")

--- Путь к папке данных QUIK
-- Initialize constants from Constants module
_initConstants()

--- Настройки ордеров

function SetSettingFinam()
  Config.Broker = "FINAM"
  Config.ClientCode = "0734A/0734A"
  Config.AccountCode = "L01+00000F00"
  Config.FirmId = "MC0061900000"
  Config.VolumeOrderMax = 70000
  Config.BondVolumeOrderMax = 100000
  Config.LimitActuationOrderEdge = 0
  Config.LimitActuationOrderBondEdge = 50
  Config.VolumeOrderLimit = 120000
end

-- Backward-compatible global wrappers
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
end
function SetSettingVTB()
  Config.Broker = "VTB"
  Config.ClientCode = "386507"
  Config.AccountCode = "L01-00000F00"
  Config.FirmId = "MC0003300000"
  Config.VolumeOrderMax = 20000
  Config.BondVolumeOrderMax = 20000
  Config.LimitActuationOrderEdge = 0
  Config.LimitActuationOrderBondEdge = 30
end

function SetSettingPSB()
  Config.Broker = "PSB"
  Config.ClientCode = "40200"
  Config.AccountCode = "L01+00000F00"
  Config.FirmId = "MC0038600000"
  Config.VolumeOrderMax = 50000
  Config.BondVolumeOrderMax = 100000
  Config.LimitActuationOrderEdge = 0
  Config.LimitActuationOrderBondEdge = 0
  Config.VolumeOrderLimit = 120000
end

function SetSettingRSHB()
  Config.Broker = "RSHB"
  Config.ClientCode = "496082"
  Config.AccountCode = "L01+00000F00"
  Config.FirmId = "MC0134700000"
  Config.VolumeOrderMax = 20000
  Config.BondVolumeOrderMax = 20000
  Config.LimitActuationOrderEdge = 0
  Config.LimitActuationOrderBondEdge = 60
end

function SetSettingTest()
  Config.Broker = "TEST"
  Config.ClientCode = "10567"
  Config.AccountCode = "NL0011100043"
  Config.FirmId = ""
  Config.VolumeOrderMax = 11000
  Config.BondVolumeOrderMax = 7000
end

--- Временные ограничения для ордеров
BrokerRegistry = {
  ["171783"] = SetSettingFinam,
  ["49653"] = SetSettingVTB,
  ["34146"] = SetSettingPSB,
  ["48640"] = SetSettingRSHB,
  ["119330"] = SetSettingTest,
}

function SetClientSetting()
  if ClearSecurityInfoCache then
    ClearSecurityInfoCache()
  end
  local userId = BrokerAdapter.GetInfoParam("USERID")

  local settingFunc = BrokerRegistry[userId]
  if settingFunc then
    settingFunc()
  else
    Config.Broker = ""
    Config.ClientCode = ""
    Config.AccountCode = ""
    Config.VolumeOrderMax = 0
  end

  Config.FileBuyOrder = Config.Broker .. "_BuyOrders.csv"
  Config.FileSellOrder = Config.Broker .. "_SellOrders.csv"
  Config.FileBuyOrderEdge = Config.Broker .. "_BuyOrders_Edge.csv"
  Config.FileBuyOrderBondsEdge = Config.Broker .. "_BuyOrdersBonds_Edge.csv"
  Config.FileSellOrderEdge = Config.Broker .. "_SellOrders_Edge.csv"

end
