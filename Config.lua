--- Единый конфигурационный модуль проекта.
--- Хранит все настройки: параметры брокера, лимиты объёмов,
--- пороговые значения, имена файлов ордеров и расписание сессий.


local Config = {}

-- ==========================================
-- Параметры брокера
-- ==========================================
Config.Broker = ""
Config.ClientCode = ""
Config.AccountCode = ""
Config.FirmId = ""

-- ==========================================
-- Лимиты объёмов
-- ==========================================
Config.VolumeOrderMax = 0
Config.BondVolumeOrderMax = 0
Config.VolumeOrderLimit = 200000
Config.VolumeOrderLimitUSD = 100

-- ==========================================
-- Пороговые значения срабатывания
-- ==========================================
Config.LimitActuationOrderEdge = 5
Config.LimitActuationOrderBondEdge = 60

-- ==========================================
-- Файлы ордеров
-- ==========================================
Config.FileBuyOrder = ""
Config.FileSellOrder = ""
Config.FileBuyOrderEdge = ""
Config.FileBuyOrderBondsEdge = ""
Config.FileSellOrderEdge = ""

-- ==========================================
-- Расписание сессий (UTC)
-- ==========================================
Config.SessionMorning = { hour = 7, min = 0, sec = 30 }
Config.SessionMain = { hour = 10, min = 0, sec = 30 }
Config.SessionEvening = { hour = 19, min = 2, sec = 10 }

-- Session submission toggles
Config.SessionMorningEnabled = true
Config.SessionMainEnabled = true
Config.SessionEveningEnabled = true

return Config
