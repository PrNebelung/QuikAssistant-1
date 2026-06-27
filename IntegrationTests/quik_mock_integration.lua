-- Реализация API QUIK
-- Содержит необходимые функции для работы с биржей и инструментами
-- Основана на документации - содержит все нужные функции

-- ==========================================
-- Глобальные переменные QUIK
-- ==========================================

_G.getScriptPath = function()
  local info = debug.getinfo(1, "S")
  local src = info.source
  if src and src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  local idx = src:find("QuikAssistant", 1, true)
  if idx then
    return src:sub(1, idx - 1)
  end
  return "."
end
_G.isConnected = function()
  return 1
end
_G.sleep = function(ms) end
_G.message = function(text) end

-- ==========================================
-- Кэш для хранения и быстрого поиска
-- ==========================================

_G.getInfoParam = function(param)
  if param == "USERID" then
    return "119330"
  end
  if param == "SERVERTIME" then
    return os.date("%H:%M:%S")
  end
  return ""
end

-- ==========================================
-- Параметры для тестирования
-- Баланс > 7 дней = активный, иначе = убыток
--
-- Пример:  Баланс 1000 руб, УБЫТ 800, ПРОЦ 1200, ШАГ 0.1
-- Результат: Баланс 100%, УБЫТ 80%, ПРОЦ 120%, ШАГ 0.01
-- ==========================================

function isBondTicker(sec_code)
  return #sec_code > 7
end

-- Для getSecurityInfo
-- Возвращает информацию об инструменте по коду бумаги и коду класса
_G.getSecurityInfo = function(class_code, sec_code)
  if sec_code == nil or sec_code == "" then
    return nil
  end

  local bondClasses = { TQCB = true, EQOB = true, TQIR = true, TQRD = true, TQOB = true }
  local stockClasses = { TQBR = true, SPBXM = true, FQBR = true, TQBD = true, TQTF = true, TQPI = true, MTQR = true }

  if isBondTicker(sec_code) then
    if bondClasses[class_code] then
      return {
        name = "Акции " .. sec_code,
        short_name = sec_code,
        code = sec_code,
        isin_code = sec_code,
        regnumber = "",
        class_name = "Рос. федерация: А+ акции/доля",
        class_code = class_code,
        face_value = 1000,
        face_unit = "SUR",
        scale = 2,
        min_price_step = 0.01,
        lot_size = 1,
      }
    end
  else
    if stockClasses[class_code] then
      return {
        name = "Облигации " .. sec_code,
        short_name = sec_code,
        code = sec_code,
        isin_code = "RU" .. sec_code,
        regnumber = "1-02-" .. sec_code,
        class_name = "Рос. федерация: А+ облигации и иные",
        class_code = class_code,
        face_value = 1,
        face_unit = "SUR",
        scale = 2,
        min_price_step = 0.1,
        lot_size = 1,
      }
    end
  end

  return nil
end

-- Для getParamEx
-- Возвращает значения параметров инструмента
_G.getParamEx = function(class_code, sec_code, param)
  if sec_code == nil then
    return { result = "0", param_value = "0" }
  end

  local stockParams = {
    LAST = "1000",
    PRICEMIN = "800",
    PRICEMAX = "1200",
    PREVPRICE = "990",
    LASTCHANGE = "1.5",
  }

  local bondParams = {
    LAST = "100",
    PRICEMIN = "80",
    PRICEMAX = "120",
    PREVPRICE = "99",
    LASTCHANGE = "0.5",
  }

  local params = isBondTicker(sec_code) and bondParams or stockParams

  return {
    result = "1",
    param_value = params[param] or "0",
  }
end

-- ==========================================
-- Глобальные таблицы (для хранения состояния)
-- ==========================================

local mockOrders = {}
local mockOrderCounter = 1000

-- Для sendTransaction
-- Имитирует обработку транзакции для отправки заявки
_G.sendTransaction = function(transaction)
  if transaction.ACTION == "NEW_ORDER" then
    mockOrderCounter = mockOrderCounter + 1
    local flags = FLAG_ACTIVE
    if transaction.OPERATION == "S" then
      flags = flags | FLAG_SELL
    end

    table.insert(mockOrders, {
      sec_code = transaction.SECCODE,
      class_code = transaction.CLASSCODE,
      flags = flags,
      trans_id = tonumber(transaction.TRANS_ID),
      order_num = mockOrderCounter,
      price = transaction.PRICE,
      qty = tonumber(transaction.QUANTITY),
      balance = tonumber(transaction.QUANTITY),
    })

    print(
      string.format(
        "  [MOCK TX] %s %s %s цена=%s объем=%s (order #%d)",
        transaction.OPERATION,
        transaction.SECCODE,
        transaction.CLASSCODE,
        transaction.QUANTITY,
        transaction.PRICE,
        mockOrderCounter
      )
    )
  elseif transaction.ACTION == "KILL_ORDER" then
    print(string.format("  [MOCK TX] KILL_ORDER %s order_key=%s", transaction.SECCODE, transaction.ORDER_KEY))
  end
  return ""
end

-- Для getNumberOf
_G.getNumberOf = function(table_name)
  if table_name == "orders" then
    return #mockOrders
  end
  if table_name == "depo_limits" then
    return #mockPositions
  end
  return 0
end

-- Для getItem
_G.getItem = function(table_name, index)
  if table_name == "orders" then
    return mockOrders[index + 1]
  end
  if table_name == "depo_limits" then
    return mockPositions[index + 1]
  end
  return nil
end

-- Для SearchItems
_G.SearchItems = function(table_name, from, to, func, params)
  local items
  if table_name == "orders" then
    items = mockOrders
  elseif table_name == "depo_limits" then
    items = mockPositions
  else
    items = {}
  end

  local results = {}
  for i = from + 1, to + 1 do
    if i <= #items then
      local item = items[i]
      if func then
        if table_name == "orders" then
          if func(item.flags) then
            table.insert(results, i - 1)
          end
        elseif table_name == "depo_limits" then
          if func(item.limit_kind, item.currentbal) then
            table.insert(results, i - 1)
          end
        end
      else
        table.insert(results, i - 1)
      end
    end
  end
  return results
end

-- ==========================================
-- Таблицы (для хранения данных)
-- ==========================================

mockPositions = {}

-- Массив для хранения активных заявок
function addTestPosition(sec_code, balance, wa_price)
  table.insert(mockPositions, {
    sec_code = sec_code,
    limit_kind = 2,
    currentbal = balance,
    wa_position_price = wa_price,
  })
end

-- ==========================================
-- Интерфейс QUIK (UI) функции
-- ==========================================

local table_id_counter = 100

_G.AllocTable = function()
  table_id_counter = table_id_counter + 1
  return table_id_counter
end
_G.CreateWindow = function(t_id) end
_G.DestroyTable = function(t_id) end
_G.IsWindowClosed = function(t_id)
  return false
end
_G.SetWindowCaption = function(t_id, caption) end
_G.GetWindowCaption = function(t_id)
  return ""
end
_G.SetWindowPos = function(t_id, x, y, dx, dy) end
_G.GetWindowRect = function(t_id)
  return 0, 0, 640, 480
end
_G.AddColumn = function(t_id, col, name, visible, c_type, width) end
_G.Clear = function(t_id) end
_G.InsertRow = function(t_id, pos)
  return math.random(1, 100)
end
_G.GetTableSize = function(t_id)
  return 0, 0
end
_G.SetCell = function(t_id, row, col, text, image) end
_G.GetCell = function(t_id, row, col)
  return { image = "", value = "" }
end
_G.SetColor = function(t_id, row, col, fg1, fg2, bg1, bg2) end
_G.SetTableNotificationCallback = function(t_id, func) end
_G.RGB = function(r, g, b)
  return r * 65536 + g * 256 + b
end

-- Статистика сделок
_G.QTABLE_STRING_TYPE = 1
_G.QTABLE_DOUBLE_TYPE = 2
_G.QTABLE_INT64_TYPE = 3
_G.QTABLE_NO_INDEX = -1
_G.QTABLE_DEFAULT_COLOR = 0xFFFFFF
_G.QTABLE_LBUTTONDBLCLK = 0x100

-- Массив для хранения сделок
_G.QTABLE_LBUTTONDOWN = 0x001
_G.QTABLE_RBUTTONDOWN = 0x002
_G.QTABLE_RBUTTONDBLCLK = 0x003
_G.QTABLE_SELCHANGED = 0x004
_G.QTABLE_CHAR = 0x005
_G.QTABLE_VKEY = 0x006
_G.QTABLE_CONTEXTMENU = 0x007
_G.QTABLE_MBUTTONDOWN = 0x008
_G.QTABLE_MBUTTONDBLCLK = 0x009
_G.QTABLE_LBUTTONUP = 0x00A
_G.QTABLE_RBUTTONUP = 0x00B
_G.QTABLE_CLOSE = 0x00C

-- ==========================================
-- Утилиты
-- ==========================================

_G.getPortfolioInfoEx = function(firm_id, client_code, flags)
  return {
    in_all_assets = 1500000,
    all_assets = 1200000,
    profit_loss = 50000,
    rate_change = 2.5,
  }
end

-- ==========================================
-- Переменные (глобальные)
-- ==========================================

_G.ClearSecurityInfoCache = function() end
_G.ClearPositionCache = function() end

-- ==========================================
-- Кэширование QUIK
-- ==========================================

_G.FLAG_ACTIVE = 0x1
_G.FLAG_EXECUTED = 0x2
_G.FLAG_SELL = 0x4
_G.ERR_PRICE_TOO_LOW = 579
_G.ERR_PRICE_TOO_HIGH = 580
_G.TRANS_STATUS_COMPLETED = 3
_G.PRICE_DEVIATION_MULTIPLIER = 10

-- ==========================================
-- Автоматическое обновление параметров
-- ==========================================

_G.Broker = "TEST"
_G.ClientCode = "10567"
_G.AccountCode = "NL0011100043"
_G.FirmId = ""
_G.VolumeOrderMax = 11000
_G.BondVolumeOrderMax = 7000
_G.VolumeOrderLimit = 200000
_G.LimitActuationOrderEdge = 5
_G.LimitActuationOrderBondEdge = 60

-- ==========================================
-- UI функции (используются для пользовательского интерфейса)
-- ==========================================

_G.tableOrdersControl = {
  Clear = function() end,
  Delete = function() end,
  IsClosed = function()
    return false
  end,
  Show = function() end,
  SetPosition = function() end,
  SetCaption = function() end,
  AddColumn = function() end,
  AddLine = function()
    return 1
  end,
  SetValue = function() end,
  GetValue = function()
    return { image = "" }
  end,
  GetSize = function()
    return 0, 0
  end,
  Red = function() end,
  Yellow = function() end,
  Green = function() end,
  Default = function() end,
  t_id = 999,
}

_G.tableSetting = {
  Clear = function() end,
  Delete = function() end,
  IsClosed = function()
    return false
  end,
  Show = function() end,
  SetPosition = function() end,
  SetCaption = function() end,
  AddColumn = function() end,
  AddLine = function()
    return 1
  end,
  SetValue = function() end,
  GetValue = function()
    return { image = "" }
  end,
  GetSize = function()
    return 0, 0
  end,
  Red = function() end,
  Yellow = function() end,
  Green = function() end,
  Default = function() end,
  t_id = 998,
}

-- ==========================================
-- N_SetLimitOrder (из Assistant.lua)
-- ==========================================

_G.N_SetLimitOrder = function(accountCode, clientCode, classCode, securityCode, operation, price, quantity)
  transId = transId + 1
  local Transaction = {
    ["TRANS_ID"] = tostring(transId),
    ["ACCOUNT"] = accountCode,
    ["CLASSCODE"] = classCode,
    ["SECCODE"] = securityCode,
    ["ACTION"] = "NEW_ORDER",
    ["TYPE"] = "L",
    ["OPERATION"] = operation,
    ["PRICE"] = price,
    ["QUANTITY"] = quantity,
    ["CLIENT_CODE"] = clientCode,
  }

  log.trace(json.encode(Transaction))

  local ok, Res = pcall(function()
    return sendTransaction(Transaction)
  end)
  if not ok then
    Res = "Ошибка sendTransaction: " .. tostring(Res)
  end
  if Res ~= "" then
    if N_OnTransSendError ~= nil then
      local trans = {}
      trans.trans_id = transId
      trans.transaction = Transaction
      trans.result_msg = Res
      trans.sec_code = securityCode
      trans.quantity = quantity
      N_OnTransSendError(trans)
    end
    return transId, Res
  end
  return transId, Res
end

-- ==========================================
-- N_CloseAllOrder (из Assistant.lua)
-- ==========================================

_G.N_CloseAllOrder = function()
  log.debug("N_CloseAllOrder() Вызов все активных заявок")
end

-- ==========================================
-- Моки для тестов
-- ==========================================

-- Вспомогательные функции для тестов
function clearMockData()
  mockOrders = {}
  mockOrderCounter = 1000
  mockPositions = {}
end

-- Инициализация модуля тестирования
function getSentOrdersCount()
  return #mockOrders
end

-- Статистика модуля тестирования
function getSentOrders()
  return mockOrders
end

print("[MOCK] Реализация для QUIK API инициализирована")
print("[MOCK] Параметры: баланс=1000, убыт=800, проц=1200, шаг=0.1")
print(
  "[MOCK] Результат (баланс > 7 дней активный): баланс=100%, убыт=80%, проц=120%, шаг=0.01"
)
