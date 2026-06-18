require("TableConstructor")

nameSettingServerTime = "����� �������"
nameSettingBroker = "������"
nameSettingClientCode = "��� �������"
nameSettingAccountCode = "��� �����"
nameSettingVolumeOrderMax = "������������ ������ ����� (�����)"
nameSettingFileBuyOrder = "���� � �������� �� �������"
nameSettingFileSellOrder = "���� � �������� �� �������"
nameSettingFileBuyOrderEdge = "���� � �������� �� ������� �� �����������"
nameSettingFileBuyOrderBondsEdge =
  "���� � �������� �� ������� ��������� �� �����������"

nameSettingFileSellOrderEdge = "���� � �������� �� ������� (����������)"
nameSettingInAllAssets = "��� ������ ������"
nameSettingAllAssets = "������ � ������"
nameSettingProfitLoss = "�������/������"
nameSettingRateChange = "% ���������"
nameSettingIndexMOEX = "������ ��������"

tableSetting = nil

function CreateTableSetting(t)
  t:AddColumn("��������", QTABLE_STRING_TYPE, 40)
  t:AddColumn("��������", QTABLE_STRING_TYPE, 30)
  t:AddColumn("�����������", QTABLE_STRING_TYPE, 50)
  t:SetCaption("���������")
  SetTableNotificationCallback(t.t_id, EventCallbackTableSetting)
end

function ShowTableSetting(t)
  t:Show()
  t:SetPosition(1, 420, 680, 320)
end

function UpdateTableSetting()
  if tableSetting == nil then
    tableSetting = QTable.new()
    CreateTableSetting(tableSetting)
    ShowTableSetting(tableSetting)
    SetDataToTableSetting(tableSetting)
  end

  if tableSetting:IsClosed() then
    ShowTableSetting(tableSetting)
  end
end

function SetDataToTableSetting(t)
  SetServerTime(t)
  SetAccountSetting(t)
  SetFileOrders(t)
end

function RefreshDataToTableSetting(t)
  SetServerTime(t)
  SetPortfolioInfo(t)
end

function FindSetting(t, setting)
  local rows, cols = t:GetSize()
  for i = 1, rows do
    local tabl = t:GetValue(i, "��������")
    if tabl.image == setting then
      return i
    end
  end
  return nil
end

function SetServerTime(t)
  local serverTime = getInfoParam("SERVERTIME")
  local problem = ""
  if serverTime == nil or serverTime == "" then
    problem = "����� ������� �� ��������"
  else
    problem = "�������� QUIK"
  end

  local row = FindSetting(t, nameSettingServerTime)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingServerTime)
  SetCell(t.t_id, row, 2, serverTime)
  SetCell(t.t_id, row, 3, problem)
end

function SetAccountSetting(t)
  local problem = ""

  local row = FindSetting(t, nameSettingBroker)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingBroker)
  SetCell(t.t_id, row, 2, AlignRight(Config.Broker, 50))
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingClientCode)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingClientCode)
  SetCell(t.t_id, row, 2, Config.ClientCode)
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingAccountCode)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingAccountCode)
  SetCell(t.t_id, row, 2, Config.AccountCode)
  SetCell(t.t_id, row, 3, problem)

  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingVolumeOrderMax)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingVolumeOrderMax)
  SetCell(t.t_id, row, 2, tostring(Config.VolumeOrderMax))
  SetCell(t.t_id, row, 3, problem)
end

function AlignRight(text, n)
  return string.rep(" ", n - string.len(text)) .. text
end

function SetPortfolioInfo(t)
  local portfolio = getPortfolioInfoEx(Config.FirmId, Config.ClientCode, 0)
  local problem = ""
  if portfolio == nil then
    problem = "���������� �� �������� �� ��������"
    log.error(problem)
    return
  end

  local row = FindSetting(t, nameSettingInAllAssets)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingInAllAssets)
  SetCell(t.t_id, row, 2, format_num(tonumber(portfolio.in_all_assets), 2))
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingAllAssets)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingAllAssets)
  SetCell(t.t_id, row, 2, format_num(tonumber(portfolio.all_assets), 2))
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingProfitLoss)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingProfitLoss)
  SetCell(t.t_id, row, 2, format_num(tonumber(portfolio.profit_loss), 2))
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingRateChange)
  if row == nil then
    row = t:AddLine()
  end

  local rateChange = portfolio.rate_change or 0
  SetCell(t.t_id, row, 1, nameSettingRateChange)
  SetCell(t.t_id, row, 2, string.format("%.2f", rateChange))
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingIndexMOEX)
  if row == nil then
    row = t:AddLine()
  end

  local result = getParamEx("INDX", "IMOEX", "LASTCHANGE")
  local lastChange = result and result.param_value or 0

  SetCell(t.t_id, row, 1, nameSettingIndexMOEX)
  SetCell(t.t_id, row, 2, string.format("%.2f", tonumber(lastChange) or 0))
  SetCell(t.t_id, row, 3, problem)
end

function GetSettingValue(t, param)
  local row = FindSetting(t, param)

  if row ~= nil then
    local value = t:GetValue(row, "��������")
    return value.image
  end

  log.error(string.format("�������� ��������� %s �� ������!", param))
  return nil
end

function SetFileOrders(t)
  local problem = ""

  local row = FindSetting(t, nameSettingFileBuyOrder)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingFileBuyOrder)
  SetCell(t.t_id, row, 2, Config.FileBuyOrder)
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingFileSellOrder)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingFileSellOrder)
  SetCell(t.t_id, row, 2, Config.FileSellOrder)
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingFileBuyOrderEdge)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingFileBuyOrderEdge)
  SetCell(t.t_id, row, 2, Config.FileBuyOrderEdge)
  SetCell(t.t_id, row, 3, problem)

  local row = FindSetting(t, nameSettingFileBuyOrderBondsEdge)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingFileBuyOrderBondsEdge)
  SetCell(t.t_id, row, 2, Config.FileBuyOrderBondsEdge)

  local row = FindSetting(t, nameSettingFileSellOrderEdge)
  if row == nil then
    row = t:AddLine()
  end

  SetCell(t.t_id, row, 1, nameSettingFileSellOrderEdge)
  SetCell(t.t_id, row, 2, Config.FileSellOrderEdge)
  SetCell(t.t_id, row, 3, problem)
end

function EventCallbackTableSetting(t_id, msg, par1, par2)
  local row = par1
  local col = par2

  if msg == QTABLE_LBUTTONDBLCLK then
    local param = GetCell(t_id, row, 1).image

    if
      param == nameSettingFileBuyOrder
      or param == nameSettingFileSellOrder
      or param == nameSettingFileBuyOrderEdge
      or param == nameSettingFileSellOrderEdge
      or param == nameSettingFileBuyOrderBondsEdge
    then
      local file = getScriptPath() .. "//Data//" .. GetCell(t_id, row, 2).image
      local filename = GetCell(t_id, row, 2).image
      if filename and filename:match("^[%%w%s%%._%%-/\\]+$") then
        local file = getScriptPath() .. "//Data//" .. filename
        os.execute('start "" notepad.exe "' .. file .. '"')
      else
        log.error("������������ ��� �����: " .. tostring(filename))
      end
    end

    if param == nameSettingServerTime then
      --CloseQuik();
    end
  end
end

return TableSetting
