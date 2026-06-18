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
-- Session Times (UTC)
-- ==========================================
Config.SessionMorning = { hour = 7, min = 0, sec = 30 }
Config.SessionMain = { hour = 10, min = 0, sec = 30 }
Config.SessionEvening = { hour = 19, min = 2, sec = 10 }

return Config
