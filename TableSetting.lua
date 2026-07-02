--- Таблица настроек в интерфейсе QUIK.
--- Отображает информацию о брокере, времени сервера,
--- файлах ордеров, портфеле (активы, прибыль/убыток)
--- и индексе MOEX. Поддерживает открытие файлов по двойному клику.

require("TableConstructor")
local Config = require("Config")

nameSettingServerTime = "Время сервера"
nameSettingBroker = "Брокер"
nameSettingClientCode = "Код клиента"
nameSettingAccountCode = "Код счета"
nameSettingVolumeOrderMax = "Максимальный размер суммы (рубли)"
nameSettingFileBuyOrder = "Файл с заявками на покупку"
nameSettingFileSellOrder = "Файл с заявками на продажу"
nameSettingFileBuyOrderEdge = "Файл с заявками на покупку на экстремумах"
nameSettingFileBuyOrderBondsEdge =
	"Файл с заявками на покупку облигаций на экстремумах"

nameSettingFileSellOrderEdge = "Файл с заказами на продажу (настольчик)"
nameSettingInAllAssets = "Все валюты активы"
nameSettingAllAssets = "Активы в валюте"
nameSettingProfitLoss = "Прибыль/убыток"
nameSettingRateChange = "% Изменение"
nameSettingIndexMOEX = "Индекс мосбиржи"

tableSetting = nil

--- Создаёт колонки таблицы настроек (параметр, значение, описание).
function CreateTableSetting(t)
	t:AddColumn("Параметр", QTABLE_STRING_TYPE, 40)
	t:AddColumn("Значение", QTABLE_STRING_TYPE, 30)
	t:AddColumn("Комментарий", QTABLE_STRING_TYPE, 50)
	t:SetCaption("Настройки")
	SetTableNotificationCallback(t.t_id, EventCallbackTableSetting)
end

--- Показывает таблицу настроек и устанавливает позицию.
function ShowTableSetting(t)
	t:Show()
	t:SetPosition(1, 430, 680, 320)
end

--- Обновляет таблицу: создаёт при первом вызове, восстанавливает если закрыта.
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

--- Заполняет таблицу начальными данными: время сервера, аккаунт, файлы ордеров.
function SetDataToTableSetting(t)
	SetServerTime(t)
	SetAccountSetting(t)
	SetFileOrders(t)
end

--- Обновляет динамические данные: время сервера, портфель.
function RefreshDataToTableSetting(t)
	SetServerTime(t)
	SetPortfolioInfo(t)
end

--- Ищет строку в таблице по имени параметра.
function FindSetting(t, setting)
	local rows, cols = t:GetSize()
	for i = 1, rows do
		local tabl = t:GetValue(i, "Параметр")
		if tabl.image == setting then
			return i
		end
	end
	return nil
end

--- Устанавливает время сервера QUIK в таблице.
function SetServerTime(t)
	local serverTime = getInfoParam("SERVERTIME")
	local problem = ""
	if serverTime == nil or serverTime == "" then
		problem = "Время сервера не получено"
	else
		problem = "Работает QUIK"
	end

	local row = FindSetting(t, nameSettingServerTime)
	if row == nil then
		row = t:AddLine()
	end

	SetCell(t.t_id, row, 1, nameSettingServerTime)
	SetCell(t.t_id, row, 2, serverTime)
	SetCell(t.t_id, row, 3, problem)
end

--- Устанавливает настройки брокера в таблице: имя, код клиента, код счёта, лимит.
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

--- Выравнивает текст по правому краю добавлением пробелов.
function AlignRight(text, n)
	return string.rep(" ", n - string.len(text)) .. text
end

--- Устанавливает информацию о портфеле: активы, прибыль/убыток, % изменения, индекс MOEX.
function SetPortfolioInfo(t)
	local portfolio = getPortfolioInfoEx(Config.FirmId, Config.ClientCode, 0)
	local problem = ""
	if portfolio == nil then
		problem = "Информация по портфелю не получена"
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

--- Получает значение параметра из таблицы по имени.
function GetSettingValue(t, param)
	local row = FindSetting(t, param)

	if row ~= nil then
		local value = t:GetValue(row, "Значение")
		return value.image
	end

	log.error(string.format("Параметр настройки %s не найден!", param))
	return nil
end

--- Устанавливает имена CSV-файлов ордеров в таблице.
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

--- Обработчик событий таблицы: двойной клик по файлу — открывает в Notepad.
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
				log.error(string.format("Недопустимое имя файла: %s", tostring(filename)))
			end
		end

		if param == nameSettingServerTime then
		end
	end
end
