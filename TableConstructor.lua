--- Универсальный конструктор таблиц QUIK (QTable).
--- Реализует класс QTable с методами добавления колонок,
--- строк, позиционирования окна, окраски ячеек,
--- а также утилиты форматирования чисел.


EventTable = {
  [QTABLE_LBUTTONDOWN] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_RBUTTONDOWN] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_LBUTTONDBLCLK] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_RBUTTONDBLCLK] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_SELCHANGED] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_CHAR] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_VKEY] = "пїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_CONTEXTMENU] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_MBUTTONDOWN] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_MBUTTONDBLCLK] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ",
  [QTABLE_LBUTTONUP] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_RBUTTONUP] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
  [QTABLE_CLOSE] = "пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅ",
}

QTable = {}
QTable.__index = QTable

--- Создаёт новый экземпляр таблицы QUIK. Возвращает объект QTable или nil.
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

--- Возвращает true если окно таблицы закрыто.
function QTable:IsClosed()
  return IsWindowClosed(self.t_id)
end

--- Уничтожает таблицу.
function QTable:Delete()
  DestroyTable(self.t_id)
end

--- Возвращает заголовок окна.
function QTable:GetCaption()
  if IsWindowClosed(self.t_id) then
    return self.caption
  else
    return GetWindowCaption(self.t_id)
  end
end

--- Устанавливает заголовок окна.
function QTable:SetCaption(s)
  self.caption = s
  if not IsWindowClosed(self.t_id) then
    res = SetWindowCaption(self.t_id, tostring(s))
  end
end

--- Добавляет колонку: имя, тип (STRING/DOUBLE/INT64), ширина, опциональная функция форматирования.
function QTable:AddColumn(name, c_type, width, ff)
  local col_desc = {}
  self.curr_col = self.curr_col + 1
  col_desc.c_type = c_type
  col_desc.format_function = ff
  col_desc.id = self.curr_col
  self.columns[name] = col_desc
  AddColumn(self.t_id, self.curr_col, name, true, c_type, width)
end

--- Очищает все строки таблицы.
function QTable:Clear()
  Clear(self.t_id)
end

--- Устанавливает значение ячейки по номеру строки и имени колонки.
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

--- Получает значение ячейки. Возвращает таблицу {image=значение}.
function QTable:GetValue(row, name)
  local t = {}
  local col_ind = self.columns[name].id
  if col_ind == nil then
    return nil
  end
  t = GetCell(self.t_id, row, col_ind)
  return t
end

--- Устанавливает позицию и размер окна таблицы.
function QTable:SetPosition(x, y, dx, dy)
  return SetWindowPos(self.t_id, x, y, dx, dy)
end

--- Возвращает (top, left, width, height) окна таблицы.
function QTable:GetPosition()
  top, left, bottom, right = GetWindowRect(self.t_id)
  return top, left, right - left, bottom - top
end

--- Окрашивает ячейку в красный.
function QTable:Red(row, col)
  SetColor(self.t_id, row, col, RGB(255, 0, 0), RGB(0, 0, 0), RGB(255, 0, 0), RGB(0, 0, 0))
end
--- Окрашивает ячейку в жёлтый.
function QTable:Yellow(row, col)
  SetColor(self.t_id, row, col, RGB(240, 240, 0), RGB(0, 0, 0), RGB(240, 240, 0), RGB(0, 0, 0))
end
--- Окрашивает ячейку в зелёный.
function QTable:Green(row, col)
  SetColor(self.t_id, row, col, RGB(0, 200, 0), RGB(0, 0, 0), RGB(0, 200, 0), RGB(0, 0, 0))
end
--- Сбрасывает цвет ячейки на стандартный.
function QTable:Default(row, col)
  SetColor(self.t_id, row, col, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR)
end

-- Из sam_lie
-- Совместимость с Lua 5.0 и 5.1.

---============================================================
-- добавление разделителя тысяч
--
--- Форматирует число с разделителем тысяч (пробел).
function comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1 %2")
    if k == 0 then
      break
    end
  end
  return formatted
end


--- Округляет число до decimal знаков. Делегирует в math.round.
function round(val, decimal)
  return math.round(val, decimal)
end

--===================================================================
-- форматирует число с разделителем тысяч
-- и округлением до заданного количества знаков
--
--
--- Форматирует число: разделитель тысяч, десятичная часть, префикс, знак для отрицательных.
function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount, formatted, famount, remain

  amount = amount or 0
  decimal = decimal or 2 -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(math.round(amount, decimal))
  famount = math.floor(famount)

  remain = math.round(math.abs(amount) - famount, decimal)

  -- добавление разделителя тысяч
  formatted = comma_value(famount)

  -- добавление дробной части
  if decimal > 0 then
    remain = string.sub(tostring(remain), 3)
    formatted = formatted .. "." .. remain .. string.rep("0", decimal - string.len(remain))
  end

  -- добавление префикса
  formatted = (prefix or "") .. formatted

  -- форматирование отрицательных значений
  if amount < 0 then
    if neg_prefix == "()" then
      formatted = "(" .. formatted .. ")"
    else
      formatted = neg_prefix .. formatted
    end
  end

  return formatted
end

return TableConstructor
