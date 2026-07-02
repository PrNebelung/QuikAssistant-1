--- Обёртка для таблиц QUIK (QTable).
--- Предоставляет удобный QTable с управлением колонками,
--- цветом, форматированным выводом, событиями мыши,
--- и вспомогательными функциями форматирования.

local FormatUtils = require("FormatUtils")
EventTable = {
	[QTABLE_LBUTTONDOWN] = "Нажатие левой кнопки мыши",
	[QTABLE_RBUTTONDOWN] = "Нажатие правой кнопки мыши",
	[QTABLE_LBUTTONDBLCLK] = "Двойной щелчок",
	[QTABLE_RBUTTONDBLCLK] = "Двойной щелчок правой",
	[QTABLE_SELCHANGED] = "Изменение выделения",
	[QTABLE_CHAR] = "Нажатие клавиши",
	[QTABLE_VKEY] = "Код виртуальной клавиши",
	[QTABLE_CONTEXTMENU] = "Контекстное меню",
	[QTABLE_MBUTTONDOWN] = "Нажатие на среднюю кнопку мыши",
	[QTABLE_MBUTTONDBLCLK] = "Двойной щелчок",
	[QTABLE_LBUTTONUP] = "Отпускание левой кнопки мыши",
	[QTABLE_RBUTTONUP] = "Отпускание правой кнопки мыши",
	[QTABLE_CLOSE] = "Закрытие окна",
}

QTable = {}
QTable.__index = QTable

--- Создаёт новую таблицу QUIK. Возвращает объект QTable или nil.
function QTable.new()
	local t_id = AllocTable()
	if t_id ~= nil then
		local q_table = {}
		setmetatable(q_table, QTable)
		q_table.t_id = t_id
		q_table.caption = ""
		q_table.created = false
		q_table.curr_col = 0
		q_table.columns = {}
		return q_table
	else
		return nil
	end
end

--- Показывает окно таблицы.
function QTable:Show()
	CreateWindow(self.t_id)
	if self.caption ~= "" then
		SetWindowCaption(self.t_id, self.caption)
	end
	self.created = true
end

--- Возвращает true если окно закрыто пользователем.
function QTable:IsClosed()
	return IsWindowClosed(self.t_id)
end

--- Удаляет таблицу.
function QTable:Delete()
	DestroyTable(self.t_id)
end

--- Получение текущего заголовка.
function QTable:GetCaption()
	if IsWindowClosed(self.t_id) then
		return self.caption
	else
		return GetWindowCaption(self.t_id)
	end
end

--- Установка нового заголовка.
function QTable:SetCaption(s)
	self.caption = s
	if not IsWindowClosed(self.t_id) then
		res = SetWindowCaption(self.t_id, tostring(s))
	end
end

--- Добавление колонки: имя, тип (STRING/DOUBLE/INT64), ширина, необязательная функция форматирования.
function QTable:AddColumn(name, c_type, width, ff)
	local col_desc = {}
	self.curr_col = self.curr_col + 1
	col_desc.c_type = c_type
	col_desc.format_function = ff
	col_desc.id = self.curr_col
	self.columns[name] = col_desc
	AddColumn(self.t_id, self.curr_col, name, true, c_type, width)
end

--- Очистка всех строк таблицы.
function QTable:Clear()
	Clear(self.t_id)
end

--- Установка значения ячейки по номеру строки и имени колонки.
function QTable:SetValue(row, col_name, data)
	local col_ind = self.columns[col_name].id or nil
	if col_ind == nil then
		return false
	end
	local ff = self.columns[col_name].format_function

	if type(ff) == "function" then
		SetCell(self.t_id, row, col_ind, ff(data), data)
		return true
	else
		SetCell(self.t_id, row, col_ind, tostring(data), data)
	end
end

--- Добавляет новую строку в конец таблицы. Возвращает номер строки.
function QTable:AddLine()
	return InsertRow(self.t_id, -1)
end

--- Возвращает (количество_строк, количество_колонок).
function QTable:GetSize()
	return GetTableSize(self.t_id)
end

--- Получение значения ячейки. Возвращает объект {image=изображение}.
function QTable:GetValue(row, name)
	local t = {}
	local col_ind = self.columns[name].id
	if col_ind == nil then
		return nil
	end
	t = GetCell(self.t_id, row, col_ind)
	return t
end

--- Установка позиции и размеров окна таблицы.
function QTable:SetPosition(x, y, dx, dy)
	return SetWindowPos(self.t_id, x, y, dx, dy)
end

--- Возвращает (top, left, width, height) окна таблицы.
function QTable:GetPosition()
	top, left, bottom, right = GetWindowRect(self.t_id)
	return top, left, right - left, bottom - top
end

--- Установка цвета в красный.
function QTable:Red(row, col)
	SetColor(self.t_id, row, col, RGB(255, 0, 0), RGB(0, 0, 0), RGB(255, 0, 0), RGB(0, 0, 0))
end
--- Установка цвета в жёлтый.
function QTable:Yellow(row, col)
	SetColor(self.t_id, row, col, RGB(240, 240, 0), RGB(0, 0, 0), RGB(240, 240, 0), RGB(0, 0, 0))
end
--- Установка цвета в зелёный.
function QTable:Green(row, col)
	SetColor(self.t_id, row, col, RGB(0, 200, 0), RGB(0, 0, 0), RGB(0, 200, 0), RGB(0, 0, 0))
end
--- Сброс цвета ячейки на стандартный.
function QTable:Default(row, col)
	SetColor(
		self.t_id,
		row,
		col,
		QTABLE_DEFAULT_COLOR,
		QTABLE_DEFAULT_COLOR,
		QTABLE_DEFAULT_COLOR,
		QTABLE_DEFAULT_COLOR
	)
end

-- от sam_lie
-- Адаптировано под Lua 5.0 и 5.1.

---============================================================
-- Вспомогательные функции
--
--- Форматирование числа с разделителем разрядов (пробел).
function comma_value(amount)
	return FormatUtils.comma_value(amount)
end

--- Округление числа до decimal знаков. Использует math.round.
function round(val, decimal)
	return FormatUtils.round(val, decimal)
end

--===================================================================
-- Форматирование числа с разделителем разрядов
-- на основании исходного форматирования числа
--
--
--- Форматирование числа: количество знаков, десятичные, префикс, отрицательный префикс.
function format_num(amount, decimal, prefix, neg_prefix)
	return FormatUtils.format_num(amount, decimal, prefix, neg_prefix)
end

return QTable
