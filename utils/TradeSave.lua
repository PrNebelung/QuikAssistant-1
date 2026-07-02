--- Сохранение сделок в файл.
--- Сохраняет информацию о исполненных заявках
--- (тикер, операция, количество, цена) в файл MyTrades.csv.

local BrokerAdapter = require("BrokerAdapter")
local Config = require("Config")

--Сохранение сделок в файл и в таблицу заявок
--- Сохранение сделок в файл MyTrades.csv: дата, время, тикер, операция, количество, цена, брокер.
--- Сохранение сделки в файл MyTrades.csv.
--- @param trade table объект сделки из QUIK API
function TradeSave(trade)
	local isSell = (trade.buy_sell == "S") or ((trade.flags & FLAG_SELL) > 0)
	local Operation = ""
	if isSell then
		Operation = "-"
	end
	log.debug(
		string.format(
			"TradeSave: sec=%s buy_sell=%s flags=%s isSell=%s qty=%s",
			trade.sec_code,
			tostring(trade.buy_sell),
			tostring(trade.flags),
			tostring(isSell),
			trade.qty
		)
	)

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
		.. Config.Broker
		.. "\n"

	local fp, err = io.open(BrokerAdapter.GetScriptPath() .. "//Data//MyTrades.csv", "a+")
	if not fp then
		log.error(string.format("Не удалось открыть MyTrades.csv: %s", tostring(err)))
		return
	end

	local ok, werr = pcall(function()
		fp:write(TradeLine)
		fp:flush()
		fp:close()
	end)
	if not ok then
		log.error(string.format("Ошибка записи в MyTrades.csv: %s", werr))
	end
end
