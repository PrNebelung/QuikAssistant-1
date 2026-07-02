--- Таблица активных ордеров в интерфейсе QUIK.
--- Создаёт и обновляет таблицу с текущими ордерами:
--- название, код, операция, актуализация, цена, объём,
--- номер ордера с цветовой индикацией.

local BrokerAdapter = require("BrokerAdapter")

local nameColumnSecurityName = "Наименование инструмента"
local nameColumnSecurityCode = "Код бумаги (тикер)"
local nameColumnOperation = "Операция"
local nameColumnPriceLast = "Последняя цена"
local nameColumnOrderPrice = "Цена заявки"
local nameColumnQuantity = "Количество"
local nameColumnVolume = "Сумма с учётом номинала"
local nameColumnActuation = "Отклонение"
local nameColumnLastChange = "% Изменение от предыдущей"
local nameColumnOrderNum = "Номер заявки с сервера брокера "

tableOrdersControl = nil

--- Создаёт колонки таблицы ордеров (название, код, операция, актуализация, цена, объём и т.д.).
function CreateTableOrdersControl(t)
	t:AddColumn(nameColumnSecurityName, QTABLE_STRING_TYPE, 35)
	t:AddColumn(nameColumnSecurityCode, QTABLE_STRING_TYPE, 20)
	t:AddColumn(nameColumnOperation, QTABLE_STRING_TYPE, 10)
	t:AddColumn(nameColumnActuation, QTABLE_DOUBLE_TYPE, 10)
	t:AddColumn(nameColumnPriceLast, QTABLE_DOUBLE_TYPE, 20)
	t:AddColumn(nameColumnOrderPrice, QTABLE_DOUBLE_TYPE, 20)
	t:AddColumn(nameColumnQuantity, QTABLE_INT64_TYPE, 10)
	t:AddColumn(nameColumnVolume, QTABLE_DOUBLE_TYPE, 15)
	t:AddColumn(nameColumnLastChange, QTABLE_DOUBLE_TYPE, 10)
	t:AddColumn(nameColumnOrderNum, QTABLE_INT64_TYPE, 15)

	t:SetCaption("Управление заявками")
end

--- Показывает таблицу ордеров и устанавливает позицию на экране.
function ShowTableOrdersControl(t)
	t:Show()
	t:SetPosition(700, 1, 1200, 925)
end

--- Обновляет таблицу: создаёт при первом вызове, восстанавливает если закрыта, заполняет данными из QUIK.
function RefreshTableOrdersControl()
	if tableOrdersControl == nil then
		tableOrdersControl = QTable.new()
		CreateTableOrdersControl(tableOrdersControl)
		ShowTableOrdersControl(tableOrdersControl)
	end

	if tableOrdersControl:IsClosed() then
		ShowTableOrdersControl(tableOrdersControl)
	end

	local countOrders = BrokerAdapter.GetNumberOfOrders()
	local orders = BrokerAdapter.SearchOrders(FindOrder, "flags, sec_code, class_code")
	if orders ~= nil then
		for i = 1, #orders do
			local order = BrokerAdapter.GetOrder(orders[i])
			UpdateTableOrdersControl(tableOrdersControl, order)
		end
	end
end

--- Ищет строку в таблице по номеру ордера.
function FindRow(t, orderNum)
	if orderNum ~= nil then
		local rows, cols = t:GetSize()
		for i = 1, rows do
			local nameColumnOrderNum = t:GetValue(i, nameColumnOrderNum)
			if tonumber(nameColumnOrderNum.image) == tonumber(orderNum) then
				return i
			end
		end
	end
	return nil
end

--- Ищет строку по номеру ордера или создаёт новую.
function FindOrCreateRow(t, orderNum)
	local row = FindRow(t, orderNum)
	if row == nil then
		row = t:AddLine()
	end
	return row
end

--- Заполняет ячейки строки данными ордера.
function UpdateRowCells(t, row, secInfo, order, priceLast, operation, actuation, lastChange)
	SetCell(t.t_id, row, 1, secInfo.name)
	SetCell(t.t_id, row, 2, order.sec_code)
	SetCell(t.t_id, row, 3, operation)
	SetCell(t.t_id, row, 4, string.format("%.2f", actuation))
	SetCell(t.t_id, row, 5, format_num(tonumber(priceLast), 6))
	SetCell(t.t_id, row, 6, format_num(tonumber(order.price), 6))
	SetCell(t.t_id, row, 7, format_num(tonumber(order.qty)))
	SetCell(t.t_id, row, 8, format_num(tonumber(order.value), 2))
	SetCell(t.t_id, row, 9, string.format("%.2f", lastChange))
	SetCell(t.t_id, row, 10, string.format("%i", order.order_num))
end

--- Обновляет или добавляет строку для ордера с цветовой индикацией.
function UpdateTableOrdersControl(t, order)
	local secInfo = GetSecurityInfo(order.sec_code)
	if secInfo == nil then
		return
	end
	local priceLast = GetPriceCurrent(order.class_code, order.sec_code)
	local operation = GetOrderOperation(order)
	local actuation = (tonumber(priceLast) - tonumber(order.price)) / tonumber(order.price) * 100
	local lastChange = BrokerAdapter.GetParamEx(order.class_code, order.sec_code, "LASTCHANGE")
	lastChange = lastChange or 0

	local row = FindOrCreateRow(t, order.order_num)

	UpdateRowCells(t, row, secInfo, order, priceLast, operation, actuation, lastChange)

	-- Подсветка
	if math.abs(actuation) < ACTUATION_COLOR_RED then
		t:Red(row, 4)
	elseif math.abs(actuation) < ACTUATION_COLOR_YELLOW then
		t:Yellow(row, 4)
	else
		t:Default(row, 4)
	end

	if IsOrderExecuted(order.flags) then
		t:Green(row, QTABLE_NO_INDEX)
	end
end

--- Возвращает операцию ордера ("B"/"S") по флагам.
function GetOrderOperation(order)
	if order == nil then
		return ""
	end
	return GetOperation(order.flags)
end

--- Очищает таблицу ордеров.
function ClearTableOrdersControl()
	if tableOrdersControl ~= nil then
		tableOrdersControl:Clear()
	end
end

--- Получает текущую цену: LAST или PREVPRICE если LAST = 0.
function GetPriceCurrent(classCode, secCode)
	local priceLast = BrokerAdapter.GetParamEx(classCode, secCode, "LAST")
	if priceLast == nil or tonumber(priceLast) == 0 then
		priceLast = BrokerAdapter.GetParamEx(classCode, secCode, "PREVPRICE")
	end
	return priceLast or "0"
end

-- Module table for require()
TableOrders = {
	RefreshTableOrdersControl = RefreshTableOrdersControl,
	ClearTableOrdersControl = ClearTableOrdersControl,
	CreateTableOrdersControl = CreateTableOrdersControl,
	ShowTableOrdersControl = ShowTableOrdersControl,
	FindRow = FindRow,
	FindOrCreateRow = FindOrCreateRow,
	UpdateRowCells = UpdateRowCells,
	UpdateTableOrdersControl = UpdateTableOrdersControl,
	GetOrderOperation = GetOrderOperation,
	GetPriceCurrent = GetPriceCurrent,
}

return TableOrders
