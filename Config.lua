--- Глобальный конфигурационный модуль настроек.
--- Хранит все настройки: данные брокера, лимиты заявок,
--- параметры сессий, пути файлов заявок и переключатели.


local Config = {}

-- ==========================================
-- Данные брокера
-- ==========================================
Config.Broker = ""
Config.ClientCode = ""
Config.AccountCode = ""
Config.FirmId = ""

-- ==========================================
-- Лимиты заявок
-- ==========================================
Config.VolumeOrderMax = 0
Config.BondVolumeOrderMax = 0
Config.VolumeOrderLimit = 200000

-- ==========================================
-- Параметры исполнения заявок
-- ==========================================
Config.LimitActuationOrderEdge = 5
Config.LimitActuationOrderBondEdge = 60

-- ==========================================
-- Файлы заявок
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

-- Переключатели отправки заявок по сессиям
Config.SessionMorningEnabled = true
Config.SessionMainEnabled = true
Config.SessionEveningEnabled = true

-- ==========================================
-- Включение/выключение брокера
-- ==========================================
Config.BrokerEnabled = true

return Config
