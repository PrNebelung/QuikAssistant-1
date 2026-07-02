Settings = {
	Name = "TradesInfoMySecurities",
}

chart_tag = "MySecurities"

function Start(securityCode)
	DelAllLabels(chart_tag)

	local iif = function(cond, ifTrue, ifFalse)
		if cond then
			return ifTrue
		end
		return ifFalse
	end

	local trades = {}
	local charts = {}

	local path = "c:\\Users\\Nebelung\\Documents\\quikassistant\\Data\\"

	local IMAGE_BUY = path .. "buy.bmp"
	local IMAGE_SELL = path .. "sell.bmp"

	-- заполняем таблицу сделок
	for line in io.lines(path .. "trades.csv") do
		local row = {}

		for column in string.gmatch(line, "([^;]+)") do
			table.insert(row, column)
		end

		local trade = {
			timestamp = row[1],
			ticker = row[2],
			lots = tonumber(row[3]),
			price = tonumber(row[4]),
			date = string.gsub(string.match(row[1], "(%d+-%d+-%d+)"), "-", ""),
			time = string.gsub(string.match(row[1], "(%d+:%d+:%d+)"), ":", ""),
			broker = row[5],
		}

		-- суммируем лоты сделок одного инструмента в один момент времени (минута) по одинаковой цене, чтобы не заграмождать график
		for _, t in pairs(trades) do
			if t.ticker == trade.ticker and t.timestamp == trade.timestamp and t.price == trade.price then
				t.lots = t.lots + trade.lots
			end
		end

		if trade.ticker == securityCode then
			table.insert(trades, trade)
		end
	end

	if #trades < 1 then
		return
	end

	-- добавляем метки по таблице сделок
	for _, t in pairs(trades) do
		local label = {
			-- параметры текста метки - отрисовываются со смещением от точки сделки :-(
			TEXT = iif(t.lots > 0, "5", "6"), -- в шрифте "Webdings" это значки треугольников
			FONT_FACE_NAME = "Webdings",
			FONT_HEIGHT = 16,
			R = iif(t.lots > 0, 0, 255),
			G = iif(t.lots > 0, 255, 0),
			B = iif(t.broker == "VTB", 255, 0),

			-- параметры картинки
			IMAGE_PATH = "", --iif( t.lots > 0, IMAGE_BUY, IMAGE_SELL ),
			ALIGNMENT = iif(t.lots > 0, "BOTTOM", "TOP"),
			TRANSPARENCY = 0,
			TRANSPARENT_BACKGROUND = 1,

			-- парамтеры координат
			YVALUE = t.price,
			DATE = t.date,
			TIME = t.time,

			-- всплывающая подсказка
			HINT = tostring(t.broker) .. " @ " .. tostring(t.lots) .. " @ " .. tostring(t.price),
		}

		local labelId = AddLabel(chart_tag, label)
	end
end

function Init()
	local info = getDataSourceInfo()
	Start(info.sec_code)
	return 1
end
function OnCalculate(index)
	return nil
end
