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

print('TimeMainStart: ' .. tostring(os.time(SessionScheduler.TimeMainStart)))
print('now: ' .. tostring(os.time()))
print('os.time(TimeMainStart) < now: ' .. tostring(os.time(SessionScheduler.TimeMainStart) < os.time()))
print('Config.SessionMainEnabled: ' .. tostring(Config.SessionMainEnabled))
print('IsMainTime before: ' .. tostring(SessionScheduler.IsMainTime))
print('not IsMainTime: ' .. tostring(not SessionScheduler.IsMainTime))

local now = os.time()
local sessions = {
    { time = SessionScheduler.TimeMorningStart, enabled = Config.SessionMorningEnabled, flag = "morning" },
    { time = SessionScheduler.TimeMainStart, enabled = Config.SessionMainEnabled, flag = "main" },
    { time = SessionScheduler.TimeEveningStart, enabled = Config.SessionEveningEnabled, flag = "evening" },
}

for _, session in ipairs(sessions) do
    print('Session: ' .. session.flag .. ' enabled=' .. tostring(session.enabled) .. ' time=' .. tostring(os.time(session.time)) .. ' < now=' .. tostring(os.time(session.time) < now) .. ' IsTime=' .. tostring(SessionScheduler["Is" .. session.flag .. "Time"]))
end
