--- Фейковый QUIK API для интеграционных тестов.
--- Позволяет настраивать данные инструментов, позиции, заявки.
--- Отслеживает все вызовы API и отправленные транзакции.

-- ==========================================
-- QUIK-константы (таблицы, события)
-- ==========================================
_G.QTABLE_LBUTTONDOWN = 1
_G.QTABLE_RBUTTONDOWN = 2
_G.QTABLE_LBUTTONDBLCLK = 3
_G.QTABLE_RBUTTONDBLCLK = 4
_G.QTABLE_SELCHANGED = 5
_G.QTABLE_CHAR = 6
_G.QTABLE_VKEY = 7
_G.QTABLE_CONTEXTMENU = 8
_G.QTABLE_MBUTTONDOWN = 9
_G.QTABLE_MBUTTONDBLCLK = 10
_G.QTABLE_LBUTTONUP = 11
_G.QTABLE_RBUTTONUP = 12
_G.QTABLE_CLOSE = 13
_G.QTABLE_STRING_TYPE = "string"
_G.QTABLE_DOUBLE_TYPE = "double"

local QuikMock = {}

-- ==========================================
-- Хранилище данных
-- ==========================================

-- Инструменты: secCode -> { securityInfo, params }
QuikMock.securities = {}

-- Позиции (depo_limits): таблица [{sec_code, currentbal, wa_position_price, limit_kind}]
QuikMock.positions = {}

-- Заявки (orders): таблица [{sec_code, class_code, flags, price, qty, balance, trans_id, order_num}]
QuikMock.orders = {}

-- Сделки (trades): таблица [{sec_code, buy_sell, flags, price, qty, order_num, trade_num, trans_id}]
QuikMock.trades = {}

-- Отправленные транзакции
QuikMock.sentTransactions = {}

-- Счётчики для ID
QuikMock.nextOrderNum = 1000
QuikMock.nextTradeNum = 1000
QuikMock.nextTransId = 1000

-- ==========================================
-- Настройка данных
-- ==========================================

--- Добавить инструмент с данными.
--- @param secCode string Тикер/ISIN
--- @param classCode string Код класса (TQBR, TQCB и т.д.)
--- @param data table { last, pricemin, pricemax, prevprice, lot, scale, min_price_step }
function QuikMock.AddSecurity(secCode, classCode, data)
	classCode = classCode or "TQBR"
	QuikMock.securities[secCode] = QuikMock.securities[secCode] or {}
	QuikMock.securities[secCode][classCode] = {
		securityInfo = {
			code = secCode,
			class_code = classCode,
			class_name = data.class_name or classCode,
			name = data.name or secCode,
			short_name = data.short_name or secCode,
			isin_code = data.isin or secCode,
			regnumber = data.regnumber or "",
			lot = data.lot or 1,
			lot_size = data.lot or 1,
			scale = data.scale or 2,
			min_price_step = data.min_price_step or 0.01,
			face_value = data.facevalue or 0,
			face_unit = data.face_unit or "SUR",
		},
		params = {
			LAST = data.last or "0",
			PRICEMIN = data.pricemin or "0",
			PRICEMAX = data.pricemax or "0",
			PREVPRICE = data.prevprice or "0",
		},
	}
end

--- Добавить позицию (depo_limit).
--- @param secCode string Тикер
--- @param balance number Текущий баланс
--- @param waPrice number Средняя цена позиции
--- @param limitKind number Тип лимита (2 = собственный)
function QuikMock.AddPosition(secCode, balance, waPrice, limitKind)
	table.insert(QuikMock.positions, {
		sec_code = secCode,
		currentbal = tostring(balance),
		wa_position_price = tostring(waPrice),
		limit_kind = limitKind or 2,
	})
end

--- Добавить существующую заявку.
function QuikMock.AddOrder(order)
	QuikMock.nextOrderNum = QuikMock.nextOrderNum + 1
	order.order_num = order.order_num or QuikMock.nextOrderNum
	order.trans_id = order.trans_id or 0
	order.flags = order.flags or 0x1
	order.balance = order.balance or order.qty
	table.insert(QuikMock.orders, order)
end

--- Очистить все данные.
function QuikMock.Reset()
	QuikMock.securities = {}
	QuikMock.positions = {}
	QuikMock.orders = {}
	QuikMock.trades = {}
	QuikMock.sentTransactions = {}
	QuikMock.nextOrderNum = 1000
	QuikMock.nextTradeNum = 1000
	QuikMock.nextTransId = 1000
end

--- Получить список отправленных транзакций.
function QuikMock.GetSentTransactions()
	return QuikMock.sentTransactions
end

--- Получить количество отправленных транзакций.
function QuikMock.GetSentCount()
	return #QuikMock.sentTransactions
end

--- Очистить отправленные транзакции.
function QuikMock.ClearSent()
	QuikMock.sentTransactions = {}
end

-- ==========================================
-- Фейковые функции QUIK API
-- ==========================================

--- getSecurityInfo(classCode, secCode)
function _G.getSecurityInfo(classCode, secCode)
	local sec = QuikMock.securities[secCode]
	if sec and sec[classCode] then
		return sec[classCode].securityInfo
	end
	return nil
end

--- getParamEx(classCode, secCode, param)
function _G.getParamEx(classCode, secCode, param)
	local sec = QuikMock.securities[secCode]
	if sec and sec[classCode] then
		local value = sec[classCode].params[param]
		if value ~= nil then
			return { param_value = tostring(value), result = "1" }
		end
	end
	return { param_value = "0", result = "0" }
end

--- getNumberOf(itemType)
function _G.getNumberOf(itemType)
	if itemType == "orders" then
		return #QuikMock.orders
	elseif itemType == "depo_limits" then
		return #QuikMock.positions
	end
	return 0
end

--- SearchItems(itemType, startIndex, endIndex, filterFunc, params)
--- params — строка полей через запятую: "field1, field2"
--- QUIK передаёт в filterFunc значения полей, а не весь объект.
function _G.SearchItems(itemType, startIndex, endIndex, filterFunc, params)
	local items = {}
	local list
	if itemType == "orders" then
		list = QuikMock.orders
	elseif itemType == "depo_limits" then
		list = QuikMock.positions
	else
		return {}
	end

	local fields = {}
	if params then
		for field in string.gmatch(params, "([^,]+)") do
			fields[#fields + 1] = field:match("^%s*(.-)%s*$")
		end
	end

	for i = startIndex + 1, math.min(endIndex + 1, #list) do
		local item = list[i]
		if item and filterFunc then
			local args = {}
			for _, field in ipairs(fields) do
				args[#args + 1] = item[field]
			end
			local ok, result = pcall(filterFunc, table.unpack(args))
			if ok and result then
				table.insert(items, i - 1)
			end
		end
	end
	return items
end

--- getItem(itemType, index)
function _G.getItem(itemType, index)
	local list
	if itemType == "orders" then
		list = QuikMock.orders
	elseif itemType == "depo_limits" then
		list = QuikMock.positions
	else
		return nil
	end
	return list[index + 1]
end

--- sendTransaction(transaction)
function _G.sendTransaction(transaction)
	table.insert(QuikMock.sentTransactions, transaction)
	QuikMock.nextTransId = QuikMock.nextTransId + 1
	return ""
end

--- isConnected()
function _G.isConnected()
	return 1
end

--- getInfoParam(param)
function _G.getInfoParam(param)
	if param == "USERID" then
		return QuikMock.userId or "49653"
	end
	if param == "SERVERTIME" then
		return os.date("%H:%M:%S")
	end
	return ""
end

--- getPortfolioInfoEx(firmId, clientCode, dataType)
function _G.getPortfolioInfoEx(firmId, clientCode, dataType)
	return QuikMock.portfolio or {
		in_all_assets = 0,
		all_assets = 0,
		profit_loss = 0,
		rate_change = 0,
	}
end

--- getScriptPath()
function _G.getScriptPath()
	return QuikMock.scriptPath or (io.popen("cd"):read("*l") .. "\\")
end

--- sleep(ms)
function _G.sleep(ms)
	-- Не спим в тестах
end

return QuikMock
