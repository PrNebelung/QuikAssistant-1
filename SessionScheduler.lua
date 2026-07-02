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
  local now = os.time()
  local sessions = {
    { time = SessionScheduler.TimeMorningStart, enabled = Config.SessionMorningEnabled, flag = "morning" },
    { time = SessionScheduler.TimeMainStart, enabled = Config.SessionMainEnabled, flag = "main" },
    { time = SessionScheduler.TimeEveningStart, enabled = Config.SessionEveningEnabled, flag = "evening" },
  }
  for _, session in ipairs(sessions) do
    if session.enabled and os.time(session.time) < now and not SessionScheduler["Is" .. session.flag .. "Time"] then
      SessionScheduler["Is" .. session.flag .. "Time"] = true
      SessionScheduler.IsSentOrders = false
    end
  end
  return not SessionScheduler.IsSentOrders and os.time(SessionScheduler.TimeMorningStart) < now
end

function SessionScheduler.MarkSent()
  SessionScheduler.IsSentOrders = true
end

return SessionScheduler
