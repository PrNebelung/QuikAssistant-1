local Constants = require("Constants")
local BrokerAdapter = require("BrokerAdapter")
local Config = require("Config")

require("TableSetting")

--- Путь к папке данных QUIK
-- Initialize constants from Constants module
_initConstants()

--- Настройки ордеров
Broker = ""
ClientCode = ""
AccountCode = ""
FirmId = ""
VolumeOrderMax = 0
BondVolumeOrderMax = 0
--- Настройки по сумме ордера
VolumeOrderLimit = 200000
--- Настройки по сумме ордера и количеству
VolumeOrderLimitUSD = 100

--- Множитель количества для продажи
LimitActuationOrderEdge = 5
--- Множитель количества для продажи облигаций
LimitActuationOrderBondEdge = 60

FileBuyOrder = ""
FileSellOrder = ""
FileBuyOrderEdge = ""
FileBuyOrderBondsEdge = ""
FileSellOrderEdge = ""

function SetSettingFinam()
  Broker = "FINAM"
  ClientCode = "0734A/0734A"
  AccountCode = "L01+00000F00"
  FirmId = "MC0061900000"
  VolumeOrderMax = 70000
  BondVolumeOrderMax = 100000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 50
  VolumeOrderLimit = 120000
end

function SetSettingVTB()
  Broker = "VTB"
  ClientCode = "386507"
  AccountCode = "L01-00000F00"
  FirmId = "MC0003300000"
  VolumeOrderMax = 20000
  BondVolumeOrderMax = 20000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 30
end

function SetSettingPSB()
  Broker = "PSB"
  ClientCode = "40200"
  AccountCode = "L01+00000F00"
  FirmId = "MC0038600000"
  VolumeOrderMax = 50000
  BondVolumeOrderMax = 100000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 0
  VolumeOrderLimit = 120000
end

function SetSettingRSHB()
  Broker = "RSHB"
  ClientCode = "496082"
  AccountCode = "L01+00000F00"
  FirmId = "MC0134700000"
  VolumeOrderMax = 20000
  BondVolumeOrderMax = 20000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 60
end

function SetSettingTest()
  Broker = "TEST"
  ClientCode = "10567"
  AccountCode = "NL0011100043"
  FirmId = ""
  VolumeOrderMax = 11000
  BondVolumeOrderMax = 7000
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
    Broker = ""
    ClientCode = ""
    AccountCode = ""
    VolumeOrderMax = 0
  end

  FileBuyOrder = Broker .. "_BuyOrders.csv"
  FileSellOrder = Broker .. "_SellOrders.csv"
  FileBuyOrderEdge = Broker .. "_BuyOrders_Edge.csv"
  FileBuyOrderBondsEdge = Broker .. "_BuyOrdersBonds_Edge.csv"
  FileSellOrderEdge = Broker .. "_SellOrders_Edge.csv"

  Config.ApplyBrokerSettings()
end
