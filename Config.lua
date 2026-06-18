local Config = {}

-- ==========================================
-- Broker Settings
-- ==========================================
Config.Broker = ""
Config.ClientCode = ""
Config.AccountCode = ""
Config.FirmId = ""

-- ==========================================
-- Volume Limits
-- ==========================================
Config.VolumeOrderMax = 0
Config.BondVolumeOrderMax = 0
Config.VolumeOrderLimit = 200000
Config.VolumeOrderLimitUSD = 100

-- ==========================================
-- Actuation Thresholds
-- ==========================================
Config.LimitActuationOrderEdge = 5
Config.LimitActuationOrderBondEdge = 60

-- ==========================================
-- Order Files
-- ==========================================
Config.FileBuyOrder = ""
Config.FileSellOrder = ""
Config.FileBuyOrderEdge = ""
Config.FileBuyOrderBondsEdge = ""
Config.FileSellOrderEdge = ""

-- ==========================================
-- Apply Settings from Setting module
-- ==========================================
function Config.ApplyBrokerSettings()
  Config.Broker = Broker
  Config.ClientCode = ClientCode
  Config.AccountCode = AccountCode
  Config.FirmId = FirmId
  Config.VolumeOrderMax = VolumeOrderMax
  Config.BondVolumeOrderMax = BondVolumeOrderMax
  Config.VolumeOrderLimit = VolumeOrderLimit
  Config.VolumeOrderLimitUSD = VolumeOrderLimitUSD or 100
  Config.LimitActuationOrderEdge = LimitActuationOrderEdge
  Config.LimitActuationOrderBondEdge = LimitActuationOrderBondEdge
  Config.FileBuyOrder = FileBuyOrder
  Config.FileSellOrder = FileSellOrder
  Config.FileBuyOrderEdge = FileBuyOrderEdge
  Config.FileBuyOrderBondsEdge = FileBuyOrderBondsEdge
  Config.FileSellOrderEdge = FileSellOrderEdge
end

return Config
