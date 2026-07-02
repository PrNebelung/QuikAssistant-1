--- Загрузка ордеров из CSV-файлов.
--- Парсит CSV-файлы из папки Data и создаёт объекты Order
--- с заполненными параметрами (операция, цена, количество).

require("FileFunction")
require("Order")
require("MarketData")
require("PositionService")

local Config = require("Config")

local OrderLoader = {}

--- Загрузка ордеров из CSV-файла.
--- @param fileName string Имя CSV-файла в папке Data
--- @return table orders Массив объектов Order
function OrderLoader.LoadOrdersFromFile(fileName)
	local orders = {}
	local rows = getFromCSV(fileName)
	local isFileSellEdge = fileName:find("_SellOrders_Edge")
	local isEdge = fileName:find("_Edge") and not isFileSellEdge

	for i, row in ipairs(rows) do
		local securityName = row[1]
		local isComment = string.find(securityName, "--", 1, true)
		if isComment == nil and row[2] ~= nil and row[3] ~= nil then
			local operation = string.match(row[2], "^%s*(.-)%s*$")
			local securityCode = string.match(row[3], "^%s*(.-)%s*$")
			local quantity = tonumber(row[4])
			local price = tonumber(row[5])

			local isBuyFile = fileName:find("[Bb][Uu][Yy]") ~= nil
			local isSellFile = fileName:find("[Ss][Ee][Ll][Ll]") ~= nil
			if isBuyFile and operation ~= "B" then
				log.error(
					string.format(
						"[SKIP] Несоответствие операции в файле BUY: оператор %s, нужен B [%s]",
						operation,
						securityCode
					)
				)
			elseif isSellFile and operation ~= "S" then
				log.error(
					string.format(
						"[SKIP] Несоответствие операции в файле SELL: оператор %s, нужен S [%s]",
						operation,
						securityCode
					)
				)
			elseif not isBuyFile and not isSellFile then
				log.warn(
					string.format(
						"[SKIP] Файл %s не содержит BUY/SELL в имени, пропущен [%s]",
						fileName,
						securityCode
					)
				)
			elseif securityCode == nil or operation == nil then
				log.error(string.format("Некорректная строка в CSV: %s", json.encode(row)))
			else
				local order = Order:new(securityCode)
				if order == nil then
					log.error(string.format("Не удалось создать ордер %s", json.encode(row)))
					unknownSecurities[securityCode] = securityName
				else
					if isFileSellEdge ~= nil then
						local priceMax = GetPriceMax(order)
						if tonumber(priceMax) == nil or tonumber(priceMax) == 0 then
							log.warn(
								"Не удалось определить цену. Вх. Цен. Макс. Допуст. (PRICEMAX). "
									.. order:Print()
							)
						else
							local position = GetPosition(order.SecurityCode)
							local positionQty = 0
							if position ~= nil then
								positionQty = tonumber(position.currentbal)
							end
							if positionQty > 0 then
								order:SetQuantitySell(operation, priceMax, positionQty)
								order.UseFileParams = true
							else
								log.error(
									string.format(
										"[SKIP] Нет позиции для продажи [%s]",
										order.SecurityCode
									)
								)
							end
						end
					elseif isEdge ~= nil then
						local priceMin = GetPriceMin(order)
						if tonumber(priceMin) == nil or tonumber(priceMin) == 0 then
							log.warn(
								"Не удалось определить цену. Вх. Цен. Мин. Допуст. для ордера. (PRICEMIN). "
									.. order:Print()
							)
						else
							local progressOrderVolumeMax = GetOrderVolumeMax(order, priceMin)
							order:SetQuantity(operation, priceMin, progressOrderVolumeMax)
						end
					else
						if quantity ~= nil and price ~= nil then
							order:SetOperation(operation, price, quantity)
							order.UseFileParams = true
						else
							log.error(
								string.format(
									"Некорректные данные для ордера в CSV: %s",
									json.encode(row)
								)
							)
						end
					end
					if order.Quantity > 0 then
						table.insert(orders, order)
					end
				end
			end
		end
	end

	return orders
end

-- Глобальная обёртка для обратной совместимости
function LoadOrdersFromFile(fileName)
	return OrderLoader.LoadOrdersFromFile(fileName)
end

return OrderLoader
