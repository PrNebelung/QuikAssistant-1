--
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

--- Модуль логирования (log).
--- Поддерживает уровни TRACE/DEBUG/INFO/WARN/ERROR/FATAL.
--- INFO и выше записываются в файл Log/<Broker>/<дата>.log,
--- для отладки используются цвета в консоли QUIK.


local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = nil
log.level = "trace"

local logFileHandle = nil
local logFilePath = nil

local modes = {
  { name = "trace", color = "\27[34m" },
  { name = "debug", color = "\27[36m" },
  { name = "info", color = "\27[32m" },
  { name = "warn", color = "\27[33m" },
  { name = "error", color = "\27[31m" },
  { name = "fatal", color = "\27[35m" },
}

--- Формирует путь к файлу лога: /Log/<Broker>/<дата>.log.
local function getLogFile()
  local datetime = os.date("*t", os.time())
  local broker = Broker or ""
  return string.format("/Log/%s/%04d-%02d-%02d.log", broker, datetime.year, datetime.month, datetime.day)
end

--- Открывает файл лога для записи. Переиспользует дескриптор если файл уже открыт.
local function openLogFile()
  local filePath = getLogFile()
  if logFilePath == filePath and logFileHandle then
    return logFileHandle
  end
  if logFileHandle then
    pcall(function()
      logFileHandle:close()
    end)
    logFileHandle = nil
  end
  local fp = io.open(getScriptPath() .. filePath, "ab")
  if fp then
    logFileHandle = fp
    logFilePath = filePath
    return fp
  end
  return nil
end

--- Перезаписывает файл для нового периода (используется при смене дня).
local function reopenLogFile()
  if logFileHandle then
    pcall(function()
      logFileHandle:close()
    end)
    logFileHandle = nil
    logFilePath = nil
  end
  return openLogFile()
end

--- Убирает лишний путь из имени файла для краткого вывода.
local function makeRelativePath(path)
  if not path or path == "" then
    return path
  end
  -- Убирает лишний путь из имени файла
  local filename = path:match("([^/\\]+)$")
  return filename or path
end
local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end

local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
end

local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, 0.01)
    end
    t[#t + 1] = _tostring(x)
  end
  return table.concat(t, " ")
end

for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)
    -- Пропускаем если уровень ниже установленного
    if i < levels[log.level] then
      return
    end

    local msg = tostring(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = makeRelativePath(tostring(info.short_src)) .. ":" .. info.currentline

    -- Вывод в консоль
    print(
      string.format(
        "%s[%-6s%s]%s %s: %s",
        log.usecolor and x.color or "",
        nameupper,
        os.date("%H:%M:%S"),
        log.usecolor and "\27[0m" or "",
        lineinfo,
        msg
      )
    )

    -- Вывод в файл лога (если доступен)
    if Broker and Broker ~= "" then
      local str = string.format("%-6s %s [%s] %s: %s\n", nameupper, os.date("%H:%M:%S"), Broker, lineinfo, msg)
      local fp = openLogFile()
      if not fp then
        fp = reopenLogFile()
      end
      if fp then
        local ok = pcall(function()
          fp:write(str)
          fp:flush()
        end)
        if not ok then
          fp = reopenLogFile()
          if fp then
            pcall(function()
              fp:write(str)
              fp:flush()
            end)
          end
        end
      else
        -- Если не удалось записать в файл - выводим в консоль
        print(string.format("LOG WRITE FAILED: %s", str))
      end
    end
  end
end

--- Закрывает файл лога.
function log.close()
  if logFileHandle then
    pcall(function()
      logFileHandle:close()
    end)
    logFileHandle = nil
    logFilePath = nil
  end
end

return log
