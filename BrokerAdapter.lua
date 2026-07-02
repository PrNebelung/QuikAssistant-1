--- Все вызовы обёрнуты в pcall для обработки ошибок.

local BrokerAdapter = {}

-- ==========================================
-- Инициализация и кэширование
-- ==========================================

local CLASS_CODES = "TQCB,TQBR,SPBXM,EQOB,TQIR,TQRD,TQOB,FQBR,TQTF,TQPI,MTQR,"
local securityInfoCache = {}

--- Очистка кэша информации о бумагах.
function BrokerAdapter.ClearSecurityInfoCache()
	securityInfoCache = {}
end

--- Получение информации о бумаге из QUIK по всем кодам классов.
--- @param securityCode string Код тикера бумаги
--- @return table|nil Таблица информации о бумаге или nil if not found
function BrokerAdapter.GetSecurityInfo(securityCode)
	if securityInfoCache[securityCode] then
		return securityInfoCache[securityCode]
	end
	for classCode in string.gmatch(CLASS_CODES, "(%P*),") do
		local info = getSecurityInfo(classCode, securityCode)
		if info ~= nil then
			securityInfoCache[securityCode] = info
			return info
		end
	end
	log.error(string.format("Не удалось найти бумагу: %s", securityCode))
	return nil
end

-- ==========================================
-- Рыночные данные
-- ==========================================

--- Получение значения параметра (LAST, PRICEMIN, PRICEMAX и др.). Возвращает строку или nil.
--- @param classCode string Код класса (например, "TQBR")
--- @param secCode string Код бумаги (например, "GAZP")
--- @param param string Имя параметра (например, "LAST", "PRICEMIN")
--- @return string|nil Значение параметра или nil
function BrokerAdapter.GetParamEx(classCode, secCode, param)
	local value = getParamEx(classCode, secCode, param)
	if value == nil or value.result == "0" then
		return nil
	end
	return value.param_value
end

--- Получение значения параметра по объекту Order.
--- @param table Объект Order с полями SecurityInfo.class_code и SecurityInfo.code
--- @param string Имя параметра
--- @return string Значение параметра или "0" при ошибке
function BrokerAdapter.GetParamInfo(order, param)
	local value = getParamEx(order.SecurityInfo.class_code, order.SecurityInfo.code, param)
	if value == nil or value.result == "0" then
		log.error(string.format("Параметр не найден: %s %s", param, order:Print()))
		return "0"
	end
	return value.param_value
end

-- ==========================================
-- Ордера
-- ==========================================

--- Возвращает количество ордеров в QUIK.
--- @return number Количество ордеров
function BrokerAdapter.GetNumberOfOrders()
	return getNumberOf("orders")
end

--- Поиск ордеров с использованием функции-фильтра.
--- @param filterFunc function Функция-фильтр для SearchItems
--- @param params string Параметры фильтрации
--- @return table Массив индексов найденных ордеров
function BrokerAdapter.SearchOrders(filterFunc, params)
	local count = BrokerAdapter.GetNumberOfOrders()
	if count <= 0 then
		log.debug("SearchOrders: нет ордеров в QUIK (count=0)")
		return {}
	end
	local ok, orders = pcall(function()
		return SearchItems("orders", 0, count - 1, filterFunc, params)
	end)
	if not ok then
		log.error(string.format("SearchOrders: ошибка SearchItems: %s (count=%d)", tostring(orders), count))
		return {}
	end
	if orders ~= nil then
		log.debug(
			string.format("SearchOrders: найдено %d ордеров (всего в QUIK=%d)", #orders, count)
		)
		return orders
	end
	log.warn(string.format("SearchOrders: SearchItems вернул nil (count=%d)", count))
	return {}
end

--- Получение ордера по индексу из QUIK.
--- @param index number Индекс ордера
--- @return table|nil Таблица ордера или nil
function BrokerAdapter.GetOrder(index)
	local ok, order = pcall(function()
		return getItem("orders", index)
	end)
	if ok then
		return order
	end
	return nil
end

-- ==========================================
-- Позиции (депо-лимиты)
-- ==========================================

--- Возвращает количество депозитарных позиций в QUIK.
--- @return number Количество позиций
function BrokerAdapter.GetNumberOfPositions()
	return getNumberOf("depo_limits")
end

--- Поиск депозитарных позиций с использованием функции-фильтра.
--- @param filterFunc function Функция-фильтр для SearchItems
--- @param params string Параметры фильтрации
--- @return table Массив индексов найденных позиций
function BrokerAdapter.SearchPositions(filterFunc, params)
	local count = BrokerAdapter.GetNumberOfPositions()
	if count <= 0 then
		return {}
	end
	local ok, positions = pcall(function()
		return SearchItems("depo_limits", 0, count - 1, filterFunc, params)
	end)
	if ok and positions ~= nil then
		return positions
	end
	return {}
end

--- Получение депозитарной позиции по индексу из QUIK.
--- @param index number Индекс позиции
--- @return table|nil Таблица позиции или nil
function BrokerAdapter.GetPosition(index)
	local ok, position = pcall(function()
		return getItem("depo_limits", index)
	end)
	if ok then
		return position
	end
	return nil
end

-- ==========================================
-- Транзакции
-- ==========================================

--- Отправка транзакции в QUIK (безопасная обёртка с pcall).
--- @param table Таблица транзакции
--- @return string Пустая строка при успехе, сообщение об ошибке при неудаче
function BrokerAdapter.SendTransaction(transaction)
	local ok, result = pcall(function()
		return sendTransaction(transaction)
	end)
	if not ok then
		return "sendTransaction error: " .. tostring(result)
	end
	return result or ""
end

-- ==========================================
-- Соединение и сервис
-- ==========================================

--- Возвращает true, если QUIK подключён к серверу.
--- @return boolean true, если подключён
function BrokerAdapter.IsConnected()
	return isConnected() == 1
end

--- Получение информационного параметра QUIK (USERID, SERVERTIME и др.).
--- @param string Имя параметра
--- @return string Значение параметра
function BrokerAdapter.GetInfoParam(param)
	return getInfoParam(param)
end

--- Получение информации о портфеле (деньги, активы).
--- @param string Код фирмы
--- @param string Код клиента
--- @return table Информация о портфеле
function BrokerAdapter.GetPortfolioInfo(firmId, clientCode)
	return getPortfolioInfoEx(firmId, clientCode, 0)
end

-- ==========================================
-- Путь к скрипту
-- ==========================================

--- Возвращает путь к текущему скрипту QUIK.
--- @return string Путь к скрипту
function BrokerAdapter.GetScriptPath()
	return getScriptPath()
end

return BrokerAdapter
