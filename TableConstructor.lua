EventTable = {
  [QTABLE_LBUTTONDOWN] = "������� ����� ������ ����",
  [QTABLE_RBUTTONDOWN] = "������� ������ ������ ����",
  [QTABLE_LBUTTONDBLCLK] = "������� ����",
  [QTABLE_RBUTTONDBLCLK] = "������� ������� �����",
  [QTABLE_SELCHANGED] = "��������� ������",
  [QTABLE_CHAR] = "������� �������",
  [QTABLE_VKEY] = "��� ������� ����������",
  [QTABLE_CONTEXTMENU] = "����������� ����",
  [QTABLE_MBUTTONDOWN] = "������� �� ������� ������",
  [QTABLE_MBUTTONDBLCLK] = "������� �������",
  [QTABLE_LBUTTONUP] = "���������� ����� ������ ����",
  [QTABLE_RBUTTONUP] = "���������� ������ ������ ����",
  [QTABLE_CLOSE] = "�������� ����",
}

QTable = {}
QTable.__index = QTable

-- ����������� � ��������� �������� ������� QTable
function QTable.new()
  local t_id = AllocTable()
  if t_id ~= nil then
    local q_table = {}
    setmetatable(q_table, QTable)
    q_table.t_id = t_id
    q_table.caption = ""
    q_table.created = false
    q_table.curr_col = 0
    -- ����������� � �������� ���������� ��������
    q_table.columns = {}
    return q_table
  else
    return nil
  end
end

function QTable:Show()
  -- �������� � ���������������� ���� �� ������ ��������
  CreateWindow(self.t_id)
  if self.caption ~= "" then
    -- ��������� ��������� ��� ����
    SetWindowCaption(self.t_id, self.caption)
  end
  self.created = true
end

function QTable:IsClosed()
  -- ���� ���� ��� �������, ���������� true
  return IsWindowClosed(self.t_id)
end

function QTable:Delete()
  -- �������� �������
  DestroyTable(self.t_id)
end

function QTable:GetCaption()
  if IsWindowClosed(self.t_id) then
    return self.caption
  else
    -- ���������� ������, ���������� ��������� ����
    return GetWindowCaption(self.t_id)
  end
end

-- ��������� ��������� �������
function QTable:SetCaption(s)
  self.caption = s
  if not IsWindowClosed(self.t_id) then
    res = SetWindowCaption(self.t_id, tostring(s))
  end
end

-- ���������� ������ ������� <name> ���� <c_type> � �������
-- <ff> ��� ������� �������������� ������ ��� �����������
function QTable:AddColumn(name, c_type, width, ff)
  local col_desc = {}
  self.curr_col = self.curr_col + 1
  col_desc.c_type = c_type
  col_desc.format_function = ff
  col_desc.id = self.curr_col
  self.columns[name] = col_desc
  -- <name> ������������ ��� ��������� ������� �������
  AddColumn(self.t_id, self.curr_col, name, true, c_type, width)
end

function QTable:Clear()
  -- ������� �������
  Clear(self.t_id)
end

-- ��������� �������� � ������
function QTable:SetValue(row, col_name, data)
  local col_ind = self.columns[col_name].id or nil
  if col_ind == nil then
    return false
  end
  -- ���� ���� ������� �������������� ������, �� ��� ������������
  local ff = self.columns[col_name].format_function

  if type(ff) == "function" then
    -- � ��������� ������ ������������ �������������� �� ���������
    -- ���������� ����������������� ������ � �������� ������
    SetCell(self.t_id, row, col_ind, ff(data), data)
    return true
  else
    SetCell(self.t_id, row, col_ind, tostring(data), data)
  end
end

function QTable:AddLine()
  -- ��������� � ����� ������� ����� ������ � ���������� � �����
  return InsertRow(self.t_id, -1)
end

function QTable:GetSize()
  -- ���������� ������ �������
  return GetTableSize(self.t_id)
end

-- ��������� ������ �� ������ �� ������ ������ � ����� �������
function QTable:GetValue(row, name)
  local t = {}
  local col_ind = self.columns[name].id
  if col_ind == nil then
    return nil
  end
  t = GetCell(self.t_id, row, col_ind)
  return t
end

-- ��������� ��������� ����
function QTable:SetPosition(x, y, dx, dy)
  return SetWindowPos(self.t_id, x, y, dx, dy)
end

-- ��������� ��������� �������� ����
function QTable:GetPosition()
  top, left, bottom, right = GetWindowRect(self.t_id)
  return top, left, right - left, bottom - top
end

-- ��������� ����� ������ �������
function QTable:Red(row, col)
  SetColor(self.t_id, row, col, RGB(255, 0, 0), RGB(0, 0, 0), RGB(255, 0, 0), RGB(0, 0, 0))
end
function QTable:Yellow(row, col)
  SetColor(self.t_id, row, col, RGB(240, 240, 0), RGB(0, 0, 0), RGB(240, 240, 0), RGB(0, 0, 0))
end
function QTable:Green(row, col)
  SetColor(self.t_id, row, col, RGB(0, 200, 0), RGB(0, 0, 0), RGB(0, 200, 0), RGB(0, 0, 0))
end
function QTable:Default(row, col)
  SetColor(self.t_id, row, col, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR, QTABLE_DEFAULT_COLOR)
end

-- from sam_lie
-- Compatible with Lua 5.0 and 5.1.
-- Disclaimer : use at own risk especially for hedge fund reports :-)

---============================================================
-- add comma to separate thousands
--
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

-- round() removed, using math.round from Order.lua
function round(val, decimal)
  return math.round(val, decimal)
end

--===================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
--
--
function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount, formatted, famount, remain

  amount = amount or 0
  decimal = decimal or 2 -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(math.round(amount, decimal))
  famount = math.floor(famount)

  remain = math.round(math.abs(amount) - famount, decimal)

  -- comma to separate the thousands
  formatted = comma_value(famount)

  -- attach the decimal portion
  if decimal > 0 then
    remain = string.sub(tostring(remain), 3)
    formatted = formatted .. "." .. remain .. string.rep("0", decimal - string.len(remain))
  end

  -- attach prefix string e.g '$'
  formatted = (prefix or "") .. formatted

  -- if value is negative then format accordingly
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
