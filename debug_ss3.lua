package.path = '?.lua;Tests/?.lua;libs/?.lua;utils/?.lua;' .. package.path
dofile('Tests/quik_mock.lua')
require('Constants')
_initConstants()
Config = require('Config')
SessionScheduler = require('SessionScheduler')

print('SessionScheduler module id: ' .. tostring(SessionScheduler))

-- Set values
SessionScheduler.TimeMorningStart = os.date('*t', 0)
SessionScheduler.TimeMainStart = os.date('*t', 0)
SessionScheduler.IsMorningTime = true
SessionScheduler.IsMainTime = false
SessionScheduler.IsSentOrders = true
Config.SessionMainEnabled = true

print('IsMorningTime after set: ' .. tostring(SessionScheduler.IsMorningTime))
print('IsMainTime after set: ' .. tostring(SessionScheduler.IsMainTime))

-- Now require again
local SessionScheduler2 = require('SessionScheduler')
print('SessionScheduler2 module id: ' .. tostring(SessionScheduler2))
print('IsMorningTime in SessionScheduler2: ' .. tostring(SessionScheduler2.IsMorningTime))
print('IsMainTime in SessionScheduler2: ' .. tostring(SessionScheduler2.IsMainTime))
