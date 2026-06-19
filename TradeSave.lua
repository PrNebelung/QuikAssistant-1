--- Сохранение сделок в файл.
--- Записывает информацию о каждой исполненной сделке
--- (код, операция, количество, цена) в файл MyTrades.csv.


local BrokerAdapter = require("BrokerAdapter")

--Сохранение сделки в лог и в файл истории сделок
--- Записывает сделку в файл MyTrades.csv: дата, время, код, операция, количество, цена, брокер.
function TradeSave(trade)
  local Operation = ""
  if (trade.flags & FLAG_EXECUTED) ~= 0 then
    Operation = "-"
  else
    Operation = ""
  end

  local TradeLine = os.date("%Y-%m-%d")
    .. " "
    .. os.date("%X", os.time())
    .. ";"
    .. trade.sec_code
    .. ";"
    .. Operation
    .. trade.qty
    .. ";"
    .. trade.price
    .. ";"
    .. Broker
    .. "\n"

  local fp, err = io.open(BrokerAdapter.GetScriptPath() .. "//Data//MyTrades.csv", "a+")
  if not fp then
    log.error("Не удалось открыть MyTrades.csv: " .. tostring(err))
    return
  end

  local ok, werr = pcall(function()
    fp:write(TradeLine)
    fp:flush()
    fp:close()
  end)
  if not ok then
    log.error("Ошибка записи в MyTrades.csv: " .. werr)
  end
end
