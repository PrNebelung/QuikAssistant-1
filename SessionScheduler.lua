--- Планировщик торговых сессий.
--- Управляет таймерами и флагами для утренней, дневной и вечерней сессий.

local Config = require("Config")

local SessionScheduler = {}

SessionScheduler.TimeMainStart = nil
SessionScheduler.TimeMorningStart = nil
SessionScheduler.TimeEveningStart = nil

SessionScheduler.IsSentOrders = false
SessionScheduler.IsMorningTime = false
SessionScheduler.IsMainTime = false
SessionScheduler.IsEveningTime = false

function SessionScheduler.Initialization()
  SessionScheduler.TimeMainStart = os.date("!*t", os.time())
  SessionScheduler.TimeMainStart.hour = Config.SessionMain.hour
  SessionScheduler.TimeMainStart.min = Config.SessionMain.min
  SessionScheduler.TimeMainStart.sec = Config.SessionMain.sec

  SessionScheduler.TimeMorningStart = os.date("!*t", os.time())
  SessionScheduler.TimeMorningStart.hour = Config.SessionMorning.hour
  SessionScheduler.TimeMorningStart.min = Config.SessionMorning.min
  SessionScheduler.TimeMorningStart.sec = Config.SessionMorning.sec

  SessionScheduler.TimeEveningStart = os.date("!*t", os.time())
  SessionScheduler.TimeEveningStart.hour = Config.SessionEvening.hour
  SessionScheduler.TimeEveningStart.min = Config.SessionEvening.min
  SessionScheduler.TimeEveningStart.sec = Config.SessionEvening.sec

  SessionScheduler.IsSentOrders = false
  SessionScheduler.IsMorningTime = false
  SessionScheduler.IsMainTime = false
  SessionScheduler.IsEveningTime = false
end

--- Проверка времени сессий.
--- @return boolean shouldSubmit true если пора отправлять ордера
function SessionScheduler.CheckSession()
  local timeCurrent = os.time()

  if (os.time(SessionScheduler.TimeMorningStart) < timeCurrent) and not SessionScheduler.IsMorningTime then
    SessionScheduler.IsMorningTime = true
    if Config.SessionMorningEnabled then
      SessionScheduler.IsSentOrders = false
    end
  end

  if (os.time(SessionScheduler.TimeMainStart) < timeCurrent) and not SessionScheduler.IsMainTime then
    SessionScheduler.IsMainTime = true
    if Config.SessionMainEnabled then
      SessionScheduler.IsSentOrders = false
    end
  end

  if (os.time(SessionScheduler.TimeEveningStart) < timeCurrent) and not SessionScheduler.IsEveningTime then
    SessionScheduler.IsEveningTime = true
    if Config.SessionEveningEnabled then
      SessionScheduler.IsSentOrders = false
    end
  end

  if not SessionScheduler.IsSentOrders then
    if os.time(SessionScheduler.TimeMorningStart) < timeCurrent then
      return true
    end
  end

  return false
end

function SessionScheduler.MarkSent()
  SessionScheduler.IsSentOrders = true
end

return SessionScheduler
