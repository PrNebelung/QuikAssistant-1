--- Обработка транзакций с заказами QUIK.
--- Управление статусами ордеров, исполнением транзакций ошибочных цен,
--- корректирующих сделок при отклонении цен
--- (579, 580, 133) и обработка ошибок исполнения.

local BrokerAdapter = require("BrokerAdapter")

local TransactionHandler = {}

--- Возвращает операцию по флагам: "S" если FLAG_SELL установлен, иначе "B".
function TransactionHandler.GetOperation(flags)
	if (flags & FLAG_SELL) > 0 then
		return "S"
	else
		return "B"
	end
end

--- Определяет статус ордера: не активен и не исполнен полностью.
function TransactionHandler.IsOrderExecuted(flags)
	return (flags & FLAG_ACTIVE) == 0 and (flags & FLAG_EXECUTED) == 0
end

--- Фильтр для поиска ордеров: активные или исполненные.
function TransactionHandler.FindOrder(flags, sec_code, class_code)
	if (flags & FLAG_ACTIVE) > 0 or TransactionHandler.IsOrderExecuted(flags) then
		return true
	else
		return false
	end
end

--- Перебирает ордера через фильтр и вызывает callback для каждого.
function TransactionHandler.forEachOrder(filterFunc, callback)
	local orderIndices = BrokerAdapter.SearchOrders(filterFunc, "flags, sec_code, class_code")
	for i = 1, #orderIndices do
		local order = BrokerAdapter.GetOrder(orderIndices[i])
		if order then
			callback(order)
		end
	end
end

--- Проверяет наличие ошибки в сообщении по коду ошибки.
function TransactionHandler.isError(result_msg, error_code)
	return string.find(result_msg, ": (" .. error_code .. ")", 1, true)
end

--- Получает все ордера из QUIK и передаёт их в OnOrder.
function TransactionHandler.GetQuikOrders()
	local count = 0
	TransactionHandler.forEachOrder(TransactionHandler.FindOrder, function(order)
		count = count + 1
		OnOrder(order)
	end)
	log.debug(string.format("Получено ордеров: %d шт.", count))
end

--- Проверяет наличие аналогичного ордера в QUIK (по коду, операции, цене).
function TransactionHandler.IsOrderExists(newOrder)
	local exists = false
	local count = 0
	TransactionHandler.forEachOrder(TransactionHandler.FindOrder, function(order)
		count = count + 1
		if not exists then
			local operation = TransactionHandler.GetOperation(order.flags)
			local priceNew = string.format("%." .. newOrder.SecurityInfo.scale .. "f", tonumber(newOrder.Price))
			local priceOld = string.format("%." .. newOrder.SecurityInfo.scale .. "f", tonumber(order.price))

			if order.sec_code == newOrder.SecurityCode and operation == newOrder.Operation and priceOld == priceNew then
				log.debug(
					string.format(
						"IsOrderExists: Найден такой же #%s %s %s цена=%s",
						order.order_num,
						order.sec_code,
						operation,
						priceOld
					)
				)
				exists = true
			end
		end
	end)
	log.debug(
		string.format(
			"IsOrderExists: Пока %s %s, найдено в QUIK: %d",
			newOrder.SecurityCode,
			newOrder.Operation,
			count
		)
	)
	return exists
end

--- Обрабатывает ошибки ценовых ограничений: 579 (цена ниже минимальной), 580 (цена выше максимальной), 133 (отклонено).
function TransactionHandler.SetLimitOrdersWithError(trans)
	local error579 = TransactionHandler.isError(trans.result_msg, ERR_PRICE_TOO_LOW)
	if error579 ~= nil then
		log.warn(
			"Error (579) for "
				.. " (qty="
				.. tostring(trans.quantity)
				.. ", price="
				.. tostring(trans.price)
				.. "): "
				.. trans.result_msg
		)
		return
	end

	local error580 = TransactionHandler.isError(trans.result_msg, ERR_PRICE_TOO_HIGH)
	if error580 ~= nil then
		local maxPrice = tonumber(string.match(trans.result_msg, "do %d+%.?%d*"))
		if maxPrice == nil then
			maxPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
		end
		local operation = "S"
		local order = Order:new(trans.sec_code)
		if order == nil then
			log.error(
				"Не удалось создать заказ для корректирующей сделки",
				trans.sec_code
			)
			return
		end
		order:SetOperation(operation, maxPrice, trans.quantity)
		log.info(
			string.format(
				"Создана корректирующая сделка на прод. цена: %s",
				order:Print()
			)
		)
		local orders = {}
		table.insert(orders, order)
		SubmitOrders(orders, false)
		return
	end

	local errorTest = string.find(trans.result_msg, "not compliant with min price for this security", 1, true)
	if errorTest ~= nil then
		local minPrice = tonumber(string.match(trans.result_msg, "ot %d+%.?%d*"))
		if minPrice == nil then
			minPrice = string.match(trans.result_msg, "%d+[%.]?%d+")
		end
		local operation = "B"
		local order = Order:new(trans.sec_code)
		if order == nil then
			log.error(
				"Не удалось создать заказ для корректирующей сделки",
				trans.sec_code
			)
			return
		end
		order:SetOperation(operation, minPrice, 0)
		log.info(
			string.format(
				"Создана корректирующая сделка на пок. цена: %s",
				order:Print()
			)
		)
		return
	end

	local error133 = TransactionHandler.isError(trans.result_msg, ERR_EXECUTION_REJECTED)
	if error133 ~= nil then
		log.warn(
			"Error (133) for "
				.. " (qty="
				.. tostring(trans.quantity)
				.. ", price="
				.. tostring(trans.price)
				.. "): "
				.. trans.result_msg
		)
		return
	end

	log.error(string.format("Непредвиденная ошибка исполнения. %s", trans.result_msg))
	log.error(json.encode(trans))
end

--- Обёртка для TransactionHandler.GetOperation.
function GetOperation(flags)
	return TransactionHandler.GetOperation(flags)
end

--- Обёртка для TransactionHandler.IsOrderExecuted.
function IsOrderExecuted(flags)
	return TransactionHandler.IsOrderExecuted(flags)
end

--- Обёртка для TransactionHandler.FindOrder.
function FindOrder(flags, sec_code, class_code)
	return TransactionHandler.FindOrder(flags, sec_code, class_code)
end

--- Обёртка для TransactionHandler.GetQuikOrders.
function GetQuikOrders()
	TransactionHandler.GetQuikOrders()
end

--- Обёртка для TransactionHandler.IsOrderExists.
function IsOrderExists(newOrder)
	return TransactionHandler.IsOrderExists(newOrder)
end

--- Обёртка для TransactionHandler.SetLimitOrdersWithError.
function SetLimitOrdersWithError(trans)
	TransactionHandler.SetLimitOrdersWithError(trans)
end

return TransactionHandler
