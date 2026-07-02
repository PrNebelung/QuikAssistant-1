package.path = '?.lua;Tests/?.lua;libs/?.lua;utils/?.lua;' .. package.path
dofile('Tests/quik_mock.lua')
require('Constants')
_initConstants()
Config = require('Config')
SessionScheduler = require('SessionScheduler')

SessionScheduler.TimeMorningStart = os.date('*t', 0)
SessionScheduler.TimeMainStart = os.date('*t', 0)
SessionScheduler.IsMorningTime = true
SessionScheduler.IsMainTime = false
SessionScheduler.IsSentOrders = true
Config.SessionMainEnabled = true

print('=== Before CheckSession ===')
print('IsMainTime: ' .. tostring(SessionScheduler.IsMainTime))
print('IsSentOrders: ' .. tostring(SessionScheduler.IsSentOrders))

-- Manually run CheckSession logic
local now = os.time()
local sessions = {
    { time = SessionScheduler.TimeMorningStart, enabled = Config.SessionMorningEnabled, flag = "morning" },
    { time = SessionScheduler.TimeMainStart, enabled = Config.SessionMainEnabled, flag = "main" },
    { time = SessionScheduler.TimeEveningStart, enabled = Config.SessionEveningEnabled, flag = "evening" },
}

for _, session in ipairs(sessions) do
    local timeCheck = os.time(session.time) < now
    local enabledCheck = session.enabled
    local isTimeCheck = not SessionScheduler["Is" .. session.flag .. "Time"]
    print('Session ' .. session.flag .. ': enabled=' .. tostring(enabledCheck) .. ' time<' .. tostring(timeCheck) .. ' notIsTime=' .. tostring(isTimeCheck))
    if enabledCheck and timeCheck and isTimeCheck then
        print('  -> Setting Is' .. session.flag .. 'Time = true')
        SessionScheduler["Is" .. session.flag .. "Time"] = true
        SessionScheduler.IsSentOrders = false
    end
end

print('=== After manual CheckSession ===')
print('IsMainTime: ' .. tostring(SessionScheduler.IsMainTime))
print('IsSentOrders: ' .. tostring(SessionScheduler.IsSentOrders))
