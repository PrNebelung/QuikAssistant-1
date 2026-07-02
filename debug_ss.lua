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

print('Before: IsMainTime=' .. tostring(SessionScheduler.IsMainTime))
print('Config.SessionMainEnabled=' .. tostring(Config.SessionMainEnabled))

local result = SessionScheduler.CheckSession()
print('CheckSession result=' .. tostring(result))
print('After: IsMainTime=' .. tostring(SessionScheduler.IsMainTime))
print('After: IsSentOrders=' .. tostring(SessionScheduler.IsSentOrders))
