--- ������ ���������������� ������ �������.
--- ������ ��� ���������: ��������� �������, ������ �������,
--- ��������� ��������, ����� ������ ������� � ���������� ������.


local Config = {}

-- ==========================================
-- ��������� �������
-- ==========================================
Config.Broker = ""
Config.ClientCode = ""
Config.AccountCode = ""
Config.FirmId = ""

-- ==========================================
-- ������ �������
-- ==========================================
Config.VolumeOrderMax = 0
Config.BondVolumeOrderMax = 0
Config.VolumeOrderLimit = 200000

-- ==========================================
-- ��������� �������� ������������
-- ==========================================
Config.LimitActuationOrderEdge = 5
Config.LimitActuationOrderBondEdge = 60

-- ==========================================
-- ����� �������
-- ==========================================
Config.FileBuyOrder = ""
Config.FileSellOrder = ""
Config.FileBuyOrderEdge = ""
Config.FileBuyOrderBondsEdge = ""
Config.FileSellOrderEdge = ""

-- ==========================================
-- ���������� ������ (UTC)
-- ==========================================
Config.SessionMorning = { hour = 7, min = 0, sec = 30 }
Config.SessionMain = { hour = 10, min = 0, sec = 30 }
Config.SessionEvening = { hour = 19, min = 2, sec = 10 }

-- Session submission toggles
Config.SessionMorningEnabled = true
Config.SessionMainEnabled = true
Config.SessionEveningEnabled = true

-- ==========================================
-- ���������/���������� �������
-- ==========================================
Config.BrokerEnabled = true

return Config
