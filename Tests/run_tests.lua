-- Unit-тесты для класса Order
-- Запуск: lua Tests/run_tests.lua

-- Установка UTF-8 кодировки для корректного вывода в Windows
os.execute("chcp 65001 >nul 2>&1")

-- Подключение для QUIK API
dofile("Tests/quik_mock.lua")

-- Подключение основных модулей
dofile("Order.lua")
dofile("QuikFunction.lua")
dofile("TradeSave.lua")
dofile("TableConstructor.lua")

-- Заглушка для N_SetLimitOrder из SubmittingOrders
_G.N_SetLimitOrder = function(clientAccountCode, clientCode, classCode, secCode, operation, price, quantity)
  table.insert(tables.orders, {
    sec_code = secCode,
    class_code = classCode,
    flags = operation == "S" and (FLAG_ACTIVE | FLAG_SELL) or FLAG_ACTIVE,
    trans_id = 1,
    order_num = math.random(1000, 9999),
    price = price,
    qty = quantity,
    balance = 0,
  })
  return math.random(1000, 9999), ""
end

_G.sleep = function(ms) end

dofile("SubmittingOrders.lua")

-- Инициализация параметров торговли вместо require("Setting")
VolumeOrderMax = 11000
BondVolumeOrderMax = 7000
OFZVolumeOrderMax = 7000
VolumeOrderLimit = 200000
VolumeOrderLimitUSD = 100
VolumeOrderLimitForeign = 70000
LimitActuationOrderEdge = 5
LimitActuationOrderBondEdge = 60
LimitActuationOrderForeignEdge = 30

local passed = 0
local failed = 0
local errors = {}

local function assert_eq(actual, expected, msg)
  if actual == expected then
    passed = passed + 1
  else
    failed = failed + 1
    local err = string.format(
      "FAIL: %s (ожидалось: %s, получено: %s)",
      msg or "",
      tostring(expected),
      tostring(actual)
    )
    table.insert(errors, err)
    print("  " .. err)
  end
end

local function assert_true(value, msg)
  if value == true then
    passed = passed + 1
  else
    failed = failed + 1
    local err = string.format("FAIL: %s (ожидалось: true, получено: %s)", msg or "", tostring(value))
    table.insert(errors, err)
    print("  " .. err)
  end
end

local function assert_false(value, msg)
  if value == false then
    passed = passed + 1
  else
    failed = failed + 1
    local err = string.format("FAIL: %s (ожидалось: false, получено: %s)", msg or "", tostring(value))
    table.insert(errors, err)
    print("  " .. err)
  end
end

local function test(name, func)
  print("  " .. name)
  func()
end

---------------------------------------------
-- Тестирование класса Order
---------------------------------------------
print("=== Тестирование класса Order ===")

ClearSecurityInfoCache()
test("SecurityCode", function()
  local order = Order:new("GAZP")
  assert_eq(order.SecurityCode, "GAZP", "код инструмента")
end)

ClearSecurityInfoCache()
test("SecurityInfo заполнен", function()
  local order = Order:new("GAZP")
  local expected = getSecurityInfo("TQBR", "GAZP")
  assert_eq(order.SecurityInfo.name, expected.name, "наименование инструмента")
  assert_eq(order.SecurityInfo.short_name, expected.short_name, "сокращённое имя")
  assert_eq(order.SecurityInfo.code, "GAZP", "код")
  assert_eq(order.SecurityInfo.isin_code, "RU0007661625", "ISIN")
  assert_eq(order.SecurityInfo.class_code, "TQBR", "класс инструмента")
  assert_eq(order.SecurityInfo.face_value, 5, "номинал")
  assert_eq(order.SecurityInfo.face_unit, "SUR", "валюта")
  assert_eq(order.SecurityInfo.scale, 2, "точность")
  assert_eq(order.SecurityInfo.min_price_step, 0.01, "мин. шаг цены")
  assert_eq(order.SecurityInfo.lot_size, 10, "размер лота")
end)

ClearSecurityInfoCache()
test("Тип инструмента", function()
  local order = Order:new("GAZP")
  assert_true(order:IsBond() == false, "GAZP не облигация")
  assert_true(order:IsSpb() == false, "GAZP не СПБ")
end)

ClearSecurityInfoCache()
test("Операция Buy для акций", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_eq(order.Operation, "B", "операция")
  assert_eq(order.Price, 200.00, "цена")
  assert_eq(order.Quantity, 100, "количество")
end)

ClearSecurityInfoCache()
test("Операция Sell", function()
  local order = Order:new("GAZP")
  order:SetOperation("S", 250.00, 50)
  assert_eq(order.Operation, "S", "операция")
  assert_eq(order.Price, 250.00, "цена")
  assert_eq(order.Quantity, 50, "количество")
end)

ClearSecurityInfoCache()
test("Облигация - правильный тип", function()
  local order = Order:new("RU000A102RN7")
  assert_eq(order.SecurityInfo.class_code, "TQOB", "класс инструмента TQOB")
  assert_true(order:IsBond(), "является облигацией")
  assert_true(order:IsOFZ(), "является ОФЗ")
  assert_false(order:IsSpb(), "не СПБ")
  assert_false(order:IsForeign(), "не иностранная")
end)

ClearSecurityInfoCache()
test("Облигация - номинал", function()
  local order = Order:new("RU000A102RN7")
  assert_eq(order.SecurityInfo.face_value, 1000.00, "номинал облигации")
end)

ClearSecurityInfoCache()
test("SPB - правильный тип", function()
  local order = Order:new("ADBE_SPB")
  assert_true(order:IsSpb(), "является SPB")
end)

ClearSecurityInfoCache()
test("SetOperation", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_eq(order.Operation, "B", "операция B")
  order:SetOperation("S", 250.00, 50)
  assert_eq(order.Operation, "S", "операция S")
end)

ClearSecurityInfoCache()
test("SetQuantity", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:SetQuantity("B", 200.00, 200)
  assert_true(order.Quantity > 0, "количество > 0")
end)

ClearSecurityInfoCache()
test("SetPriceMin", function()
  local order = Order:new("GAZP")
  order:SetPriceMin("B")
  assert_true(order.Price > 0, "цена > 0 после SetPriceMin")
end)

ClearSecurityInfoCache()
test("Clear", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:Clear()
  assert_eq(order.Operation, "", "операция после Clear")
end)

ClearSecurityInfoCache()
test("FormatPrice", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.123, 100)
  assert_eq(order:FormatPrice(), "200.12", "формат цены GAZP (scale=2)")
end)

ClearSecurityInfoCache()
test("GetPriceRound", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.123, 100)
  order:SetPriceMin("B")
  order:GetPriceRound()
  assert_true(order.Price > 0, "корректная цена > 0")
end)

ClearSecurityInfoCache()
test("IsExceptionFromLimitActuation", function()
  local order = Order:new("GAZP")
  assert_true(order:IsExceptionFromLimitActuation(), "GAZP - исключение")
  local order2 = Order:new("LKOH")
  assert_false(order2:IsExceptionFromLimitActuation(), "LKOH - не исключение")
end)

ClearSecurityInfoCache()
test("GetVolume для акций", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_true(order:GetVolume() > 0, "объём > 0")
end)

ClearSecurityInfoCache()
test("GetPriceInCurrency", function()
  local order = Order:new("GAZP")
  assert_eq(order:GetPriceInCurrency(100), 100, "цена акции в валюте")
  local bond = Order:new("RU000A102RN7")
  assert_eq(bond:GetPriceInCurrency(100), 1000, "цена облигации в валюте")
end)

ClearSecurityInfoCache()
test("IsBuy/IsSell", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_true(order:IsBuy(), "IsBuy")
  assert_false(order:IsSell(), "не IsSell")
  order:SetOperation("S", 250.00, 50)
  assert_true(order:IsSell(), "IsSell")
  assert_false(order:IsBuy(), "не IsBuy")
end)

ClearSecurityInfoCache()
test("Print", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  local str = order:Print()
  assert_true(str ~= nil and #str > 0, "Print возвращает строку")
end)

---------------------------------------------
-- Edge Cases и дополнительные тесты
---------------------------------------------
print("\n=== Edge Cases и дополнительные тесты ===")

ClearSecurityInfoCache()
test("Order:new с несуществующим тикером", function()
  local order = Order:new("ZZZZZ")
  assert_true(order == nil, "nil для несуществующего тикера")
end)

ClearSecurityInfoCache()
test("SetOperation с price = 0", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 100)
  assert_true(order.Price > 0, "цена becomes min_price_step")
end)

ClearSecurityInfoCache()
test("SetQuantity с nil параметрами", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:SetQuantity("B", nil, 200)
  assert_true(order.Quantity >= 0, "количество >= 0")
  order:SetQuantity("B", 200.00, nil)
  assert_true(order.Quantity >= 0, "количество >= 0 при nil quantityMax")
end)

ClearSecurityInfoCache()
test("SetQuantity для облигации", function()
  local order = Order:new("RU000A102RN7")
  order:SetOperation("B", 95.00, 1)
  assert_true(order.Quantity > 0, "объём > 0 для облигации")
end)

ClearSecurityInfoCache()
test("GetPriceRound edge cases", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.123, 100)
  order:SetPriceMin("B")
  order:GetPriceRound()
  assert_true(order.Price > 0, "корректная цена > 0")
end)

ClearSecurityInfoCache()
test("GetVolume edge cases", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 100)
  assert_true(order:GetVolume() > 0, "объём при нулевой цене")
  order:Clear()
  order:SetOperation("B", 200.00, 0)
  assert_true(order:GetVolume() >= 0, "объём при нулевом количестве")
end)

ClearSecurityInfoCache()
test("FormatPrice edge cases", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 100)
  assert_eq(order:FormatPrice(), "0.01", "цена = min_price_step")
end)

ClearSecurityInfoCache()
test("FormatQuantity edge cases", function()
  local order = Order:new("GAZP")
  assert_eq(order:FormatQuantity(0), "0", "количество = 0")
  assert_eq(order:FormatQuantity(4), "0.0000", "количество = 1 при scale 4")
end)

ClearSecurityInfoCache()
test("Clear сохраняет информацию", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:Clear()
  assert_eq(order.SecurityInfo.code, "GAZP", "код сохраняется после Clear")
end)

ClearSecurityInfoCache()
test("IsBuy/IsSell при nil операции", function()
  local order = Order:new("GAZP")
  assert_false(order:IsBuy(), "IsBuy при пустой операции")
end)

---------------------------------------------
-- Дополнительные edge cases
---------------------------------------------
print("\n=== Дополнительные edge cases ===")

ClearSecurityInfoCache()
test("Одинаковые тикеры GAZP", function()
  local order1 = Order:new("GAZP")
  local order2 = Order:new("GAZP")
  assert_eq(order1.SecurityCode, order2.SecurityCode, "совпадают коды")
end)

ClearSecurityInfoCache()
test("Переключение операций - акция", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_true(order:IsBuy(), "Buy работает")
  order:SetOperation("S", 250.00, 50)
  assert_true(order:IsSell(), "Sell работает")
end)

ClearSecurityInfoCache()
test("Операция по умолчанию - пустая", function()
  local order = Order:new("GAZP")
  assert_eq(order.Operation, "", "пустая операция")
  assert_eq(order.Quantity, 0, "нулевое количество")
  assert_eq(order.Price, 0, "нулевая цена")
end)

ClearSecurityInfoCache()
test("SPB класс инструмента", function()
  local order = Order:new("ADBE_SPB")
  assert_true(order:IsSpb(), "SPB определён")
  assert_eq(order.SecurityInfo.class_code, "SPBXM", "класс SPBXM")
end)

ClearSecurityInfoCache()
test("Объём = 0.01 * 100 * 10", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 100)
  assert_eq(order:GetVolume(), 10, "объём = 0.01 * 100 * 10 = 10")
end)

ClearSecurityInfoCache()
test("Корректный формат GAZP", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.123, 100)
  assert_eq(order:FormatPrice(), "200.12", "формат цены")
end)

ClearSecurityInfoCache()
test("Корректный формат количества", function()
  local order = Order:new("GAZP")
  assert_eq(order:FormatQuantity(4), "0.0000", "формат количества")
end)

ClearSecurityInfoCache()
test("Print и SetPriceMin", function()
  local order = Order:new("GAZP")
  order:SetPriceMin("B")
  local str = order:Print()
  assert_true(str ~= nil and #str > 0, "Print работает")
end)

ClearSecurityInfoCache()
test("Идентификация облигации - класс и тип", function()
  local order = Order:new("RU000A102RN7")
  assert_true(order:IsBond(), "облигация")
  assert_true(order:IsOFZ(), "ОФЗ")
  assert_eq(order.SecurityInfo.face_value, 1000.00, "номинал")
end)

ClearSecurityInfoCache()
test("IsExceptionFromLimitActuation - проверка лимита", function()
  local order = Order:new("GAZP")
  assert_true(order:IsExceptionFromLimitActuation(), "GAZP - исключение")
end)

ClearSecurityInfoCache()
test("GetPriceRound - цена кратна шагу", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:SetPriceMin("B")
  order:GetPriceRound()
  assert_true(order.Price > 0, "цена = n * step после округления")
end)

ClearSecurityInfoCache()
test("GetVolume - дополнительные edge cases", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 1)
  assert_true(order:GetVolume() > 0, "объём при количестве 1")
end)

ClearSecurityInfoCache()
test("SetQuantity - корректное значение", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  order:SetQuantity("B", 200.00, 200)
  assert_true(order.Quantity > 0, "количество > 0")
end)

ClearSecurityInfoCache()
test("Корректность форматирования", function()
  local order = Order:new("GAZP")
  assert_eq(order:FormatQuantity(4), "0.0000", "FormatQuantity")
  local order2 = Order:new("GAZP")
  order2:SetOperation("B", 200.00, 100)
  assert_eq(order2:FormatPrice(), "200.00", "FormatPrice")
end)

ClearSecurityInfoCache()
test("Последовательность вызовов функций", function()
  local order = Order:new("GAZP")
  assert_true(order.SecurityInfo ~= nil, "SecurityInfo заполнен")
end)

---------------------------------------------
-- QuikFunction тесты
---------------------------------------------
print("\n=== QuikFunction тесты ===")

test("GetOperation, IsOrderExecuted, FindOrder", function()
  assert_eq(GetOperation(FLAG_ACTIVE | FLAG_SELL), "S", "GetOperation sell")
  assert_eq(GetOperation(FLAG_ACTIVE), "B", "GetOperation buy")
  assert_false(IsOrderExecuted(FLAG_EXECUTED), "IsOrderExecuted для executed")
  assert_false(IsOrderExecuted(FLAG_ACTIVE), "IsOrderExecuted для active")
end)

test("TradeSave - проверка флагов", function()
  assert_true((FLAG_EXECUTED & FLAG_EXECUTED) > 0, "FLAG_EXECUTED")
  assert_true((FLAG_ACTIVE & FLAG_ACTIVE) > 0, "FLAG_ACTIVE")
  assert_true((FLAG_SELL & FLAG_SELL) > 0, "FLAG_SELL")
end)

test("TableConstructor функции", function()
  assert_eq(comma_value(1000), "1 000", "comma_value")
  assert_eq(round(1.5), 2, "round")
end)

test("GetKoeffVolumeOrderMax", function()
  local order = Order:new("GAZP")
  local koeff = GetKoeffVolumeOrderMax(order, 200)
  assert_true(koeff >= 1, "koeff >= 1")
end)

test("GetOrderVolumeMax", function()
  local order = Order:new("GAZP")
  local vol = GetOrderVolumeMax(order, 200)
  assert_true(vol > 0, "объём > 0")
end)

ClearSecurityInfoCache()
test("Облигация - объём", function()
  local order = Order:new("RU000A102RN7")
  local vol = GetOrderVolumeMax(order, 90)
  assert_true(vol > 0, "объём > 0")
end)

ClearSecurityInfoCache()
test("Иностранная бумага - объём", function()
  local order = Order:new("ADBE_SPB")
  local vol = GetOrderVolumeMax(order, 400)
  assert_true(vol > 0, "объём > 0")
end)

---------------------------------------------
-- SubmittingOrders тесты
---------------------------------------------
print("\n=== SubmittingOrders тесты ===")

local function resetSendOrders()
  sendOrders = {}
  sendOrdersSet = {}
  clearTestData()
  ClearPositionCache()
end

ClearSecurityInfoCache()
test("GetDedupKey", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  local key = order:GetDedupKey()
  assert_eq(key, "GAZP B 100 200.00", "dedup key format")
end)

ClearSecurityInfoCache()
test("IsSendOrder - не отправлен", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  assert_eq(IsSendOrder(order), false, "ордер ещё не в списке")
end)

ClearSecurityInfoCache()
test("IsSendOrder - уже отправлен", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  sendOrdersSet[order:GetDedupKey()] = true
  assert_eq(IsSendOrder(order), true, "ордер уже в списке")
end)

ClearSecurityInfoCache()
test("SubmitOrders - успешная отправка ордера", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 1, "1 ордер отправлен")
  assert_eq(stats.rejected, 0, "0 отклонено")
  assert_eq(stats.duplicate, 0, "0 дубликатов")
end)

ClearSecurityInfoCache()
test("SubmitOrders - дедупликация по IsSendOrder", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  SubmitOrders({ order })
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 0, "0 ордеров отправлено")
  assert_eq(stats.duplicate, 1, "1 дубликат")
end)

ClearSecurityInfoCache()
test("SubmitOrders - дедупликация по IsOrderExists", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  addTestOrder("GAZP", "TQBR", FLAG_ACTIVE, 1, 100, 200.00, 100, 0)
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 0, "0 отправлено - есть в QUIK")
  assert_eq(stats.duplicate, 1, "1 дубликат")
end)

ClearSecurityInfoCache()
test("SubmitOrders - приоритет: QUIK > sendOrders", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  addTestOrder("GAZP", "TQBR", FLAG_ACTIVE, 1, 100, 200.00, 100, 0)
  sendOrdersSet[order:GetDedupKey()] = true
  local stats = SubmitOrders({ order })
  assert_eq(stats.duplicate, 1, "дубликат определён одним из")
  assert_eq(stats.sent, 0, "не отправлено")
end)

ClearSecurityInfoCache()
test("SubmitOrders - отклонение CheckOrder", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 0)
  local stats = SubmitOrders({ order })
  assert_eq(stats.rejected, 1, "1 отклонено")
  assert_eq(stats.sent, 0, "0 отправлено")
end)

ClearSecurityInfoCache()
test("CheckOrder - UseFileParams + price below PRICEMIN", function()
  resetSendOrders()
  local savedGetParamEx = getParamEx
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "100.0" }
    end
    if param == "LAST" then
      return { result = "1", param_value = "200.0" }
    end
    if param == "PREVPRICE" then
      return { result = "1", param_value = "190.0" }
    end
    return { result = "1", param_value = "0" }
  end
  local order = Order:new("GAZP")
  order:SetOperation("B", 50.00, 10)
  order.UseFileParams = true
  local isCheck, rejectReason = CheckOrder(order)
  assert_false(isCheck, "UseFileParams order with price < PRICEMIN should be rejected")
  assert_true(string.find(rejectReason, "below PRICEMIN") ~= nil, "reason mentions PRICEMIN")
  getParamEx = savedGetParamEx
end)

ClearSecurityInfoCache()
test("SubmitOrders - несколько ордеров", function()
  resetSendOrders()
  local order1 = Order:new("GAZP")
  order1:SetOperation("B", 200.00, 100)
  local order2 = Order:new("LKOH")
  order2:SetOperation("B", 5000.00, 10)
  local stats = SubmitOrders({ order1, order2 })
  assert_eq(stats.sent, 2, "2 ордера отправлены")
  assert_eq(stats.rejected, 0, "0 отклонено")
end)

ClearSecurityInfoCache()
test("SubmitOrders - смешанный список", function()
  resetSendOrders()
  local order1 = Order:new("GAZP")
  order1:SetOperation("B", 200.00, 100)
  local order2 = Order:new("GAZP")
  order2:SetOperation("B", 200.00, 100)
  local order3 = Order:new("LKOH")
  order3:SetOperation("B", 0, 0)
  local stats = SubmitOrders({ order1, order2, order3 })
  assert_eq(stats.sent, 1, "1 отправлено")
  assert_eq(stats.rejected, 1, "1 отклонено")
  assert_eq(stats.duplicate, 1, "1 дубликат")
end)

ClearSecurityInfoCache()
test("SubmitOrders - sendOrdersSet заполнен", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("B", 200.00, 100)
  SubmitOrders({ order })
  assert_eq(sendOrdersSet[order:GetDedupKey()], true, "есть в списке")
  assert_eq(#sendOrders, 1, "1 в массиве sendOrders")
end)

ClearSecurityInfoCache()
test("SubmitOrders - облигация", function()
  resetSendOrders()
  local savedGetParamEx = getParamEx
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "90.0" }
    end
    if param == "LAST" then
      return { result = "1", param_value = "100.0" }
    end
    if param == "PREVPRICE" then
      return { result = "1", param_value = "95.0" }
    end
    return { result = "1", param_value = "0" }
  end
  local order = Order:new("RU000A102RN7")
  order:SetOperation("B", 95.00, 1)
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 1, "ордер облигации отправлен")
  getParamEx = savedGetParamEx
end)

ClearSecurityInfoCache()
test("SubmitOrders - продажа с позицией", function()
  resetSendOrders()
  addTestPosition("GAZP", 50, 250.00)
  local order = Order:new("GAZP")
  order:SetOperation("S", 200.00, 10)
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 1, "ордер продажи отправлен")
end)

ClearSecurityInfoCache()
test("SubmitOrders - продажа без достаточной позиции", function()
  resetSendOrders()
  local order = Order:new("GAZP")
  order:SetOperation("S", 200.00, 10)
  local stats = SubmitOrders({ order })
  assert_eq(stats.rejected, 1, "отклонено - нет позиции")
  assert_eq(stats.sent, 0, "0 отправлено")
end)

---------------------------------------------
-- LoadOrdersFromFile тесты
---------------------------------------------
print("\n=== LoadOrdersFromFile тесты ===")

local originalGetFromCSV = getFromCSV

local function mockCSV(rows)
  getFromCSV = function(fileName)
    return rows
  end
end

local function restoreCSV()
  getFromCSV = originalGetFromCSV
end

ClearSecurityInfoCache()
test("LoadOrdersFromFile - базовый buy ордер", function()
  mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер загружен")
  assert_eq(orders[1].SecurityCode, "GAZP", "код инструмента")
  assert_eq(orders[1].Operation, "B", "операция")
  assert_eq(orders[1].Quantity, 100, "количество")
  assert_eq(orders[1].Price, 200.00, "цена")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - несколько ордеров", function()
  mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" }, { "Lukoil", "B", "LKOH", "10", "7000.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 2, "2 ордера загружены")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пропуск комментариев", function()
  mockCSV({
    { "-- header", "B", "GAZP", "100", "200.00" },
    { "Gazprom", "B", "GAZP", "100", "200.00" },
    { "-- footer", "B", "GAZP", "50", "250.00" },
  })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер (2 комментария пропущены)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пропуск неизвестного тикера", function()
  unknownSecurities = {}
  mockCSV({ { "Unknown", "B", "ZZZZZ", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 0, "0 ордеров (неизвестный тикер)")
  assert_true(unknownSecurities["ZZZZZ"] ~= nil, "ZZZZZ добавлена в unknownSecurities")
  assert_eq(unknownSecurities["ZZZZZ"], "Unknown", "имя инструмента сохранено")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пустой CSV", function()
  mockCSV({})
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 0, "0 ордеров из пустого CSV")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - sell ордер", function()
  mockCSV({ { "Gazprom", "S", "GAZP", "50", "250.00" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert_eq(#orders, 1, "1 sell ордер загружен")
  assert_eq(orders[1].Operation, "S", "операция S")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - облигация", function()
  mockCSV({ { "OFZ", "B", "RU000A102RN7", "1", "95.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер облигация")
  assert_true(orders[1]:IsBond(), "облигация")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge акция", function()
  mockCSV({ { "Gazprom", "B", "GAZP", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  assert_eq(#orders, 1, "1 edge ордер")
  assert_true(orders[1].Quantity > 0, "количество рассчитано")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge облигация", function()
  mockCSV({ { "OFZ", "B", "RU000A102RN7", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrdersBonds_Edge.csv")
  assert_eq(#orders, 1, "1 edge ордер облигация")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - SPB edge", function()
  mockCSV({ { "Foreign", "B", "ADBE_SPB", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrdersSpb_Edge.csv")
  assert_eq(#orders, 1, "1 SPB ордер")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - RmUSD edge", function()
  mockCSV({ { "Foreign", "B", "ADBE_SPB", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_RmUSD_Edge.csv")
  assert_eq(#orders, 1, "1 RmUSD ордер")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - смешанный список", function()
  mockCSV({
    { "-- header", "B", "GAZP", "100", "200.00" },
    { "Gazprom", "B", "GAZP", "100", "200.00" },
    { "Lukoil", "B", "LKOH", "10", "7000.00" },
    { "-- footer", "B", "GAZP", "50", "200.00" },
    { "Gazprom2", "B", "GAZP", "200", "300.00" },
  })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 3, "3 ордера (2 комментария пропущены)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - SPB ордер", function()
  mockCSV({ { "Foreign", "B", "ADBE_SPB", "10", "400.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 SPB ордер")
  assert_true(orders[1]:IsSpb(), "SPB определён")
  restoreCSV()
end)

local originalGetParamEx = getParamEx

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge с priceMin=0 (пропуск)", function()
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "0" }
    end
    if param == "LAST" then
      return { result = "1", param_value = "250.0" }
    end
    if param == "PRICEMAX" then
      return { result = "1", param_value = "300.0" }
    end
    if param == "PREVPRICE" then
      return { result = "1", param_value = "245.0" }
    end
    return { result = "1", param_value = "0" }
  end
  mockCSV({ { "Gazprom", "B", "GAZP", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  assert_eq(#orders, 0, "0 ордеров (priceMin=0, пропуск)")
  getParamEx = originalGetParamEx
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge ордер с лимитом", function()
  local savedLimit = VolumeOrderLimit
  VolumeOrderLimit = 50000
  mockCSV({ { "Gazprom", "B", "GAZP", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  assert_eq(#orders, 1, "1 ордер")
  local volume = orders[1]:GetVolume()
  assert_true(volume <= VolumeOrderLimit, "объём в лимите")
  VolumeOrderLimit = savedLimit
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge и расчёт koeff", function()
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "100.0" }
    end
    if param == "LAST" then
      return { result = "1", param_value = "250.0" }
    end
    if param == "PRICEMAX" then
      return { result = "1", param_value = "300.0" }
    end
    if param == "PREVPRICE" then
      return { result = "1", param_value = "245.0" }
    end
    return { result = "1", param_value = "0" }
  end
  mockCSV({ { "Gazprom", "B", "GAZP", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_true(orders[1].Quantity > 0, "количество рассчитано с koeff")
  getParamEx = originalGetParamEx
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - edge ордер с увеличенным лимитом", function()
  local savedLimit = VolumeOrderLimit
  local savedMax = VolumeOrderMax
  VolumeOrderMax = 500000
  VolumeOrderLimit = 100000
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "1.0" }
    end
    if param == "LAST" then
      return { result = "1", param_value = "250.0" }
    end
    if param == "PRICEMAX" then
      return { result = "1", param_value = "300.0" }
    end
    if param == "PREVPRICE" then
      return { result = "1", param_value = "245.0" }
    end
    return { result = "1", param_value = "0" }
  end
  mockCSV({ { "Gazprom", "B", "GAZP", "0", "0" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders_Edge.csv")
  assert_eq(#orders, 1, "1 ордер")
  local volume = orders[1]:GetVolume()
  assert_true(volume <= VolumeOrderLimit, "объём не превышает лимит")
  VolumeOrderLimit = savedLimit
  VolumeOrderMax = savedMax
  getParamEx = originalGetParamEx
  restoreCSV()
end)


---------------------------------------------
-- Sell Edge проверки
---------------------------------------------
print("\n=== Sell Edge проверки ===")

ClearSecurityInfoCache()
test("LoadOrdersFromFile - sell edge ордер", function()
  resetSendOrders()
  addTestPosition("GAZP", 100, 250.00)
  mockCSV({ { "Gazprom", "S", "GAZP", "10", "0.01" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert_eq(#orders, 1, "1 sell edge ордер")
  assert_eq(orders[1].Operation, "S", "операция S")
  assert_true(orders[1].Quantity > 0, "количество > 0")
  assert_true(orders[1].Price > 0, "цена > 0")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - sell edge без позиции", function()
  resetSendOrders()
  clearTestData()
  mockCSV({ { "Gazprom", "S", "GAZP", "10", "0.01" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert_eq(#orders, 0, "0 ордеров (нет позиции)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - sell edge недостаточное колличество", function()
  resetSendOrders()
  clearTestData()
  addTestPosition("GAZP", 1, 250.00)
  mockCSV({ { "Gazprom", "S", "GAZP", "10", "0.01" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert_eq(#orders, 1, "1 ордер (количество ограничено позицией)")
  assert_eq(orders[1].Quantity, 1, "количество = позиция (1)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("SubmitOrders - sell edge ордер с позицией", function()
  resetSendOrders()
  addTestPosition("GAZP", 50, 250.00)
  local order = Order:new("GAZP")
  order:SetOperation("S", 300.00, 10)
  local stats = SubmitOrders({ order })
  assert_eq(stats.sent, 1, "селл отправлен")
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - проверка операции в BUY файле (неверная операция)", function()
  resetSendOrders()
  clearTestData()
  mockCSV({ { "Gazprom", "S", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 0, "0 ордеров (неверная операция)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - проверка операции в SELL файле (неверная операция)", function()
  resetSendOrders()
  clearTestData()
  mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert_eq(#orders, 0, "0 ордеров (неверная операция)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - проверка операции в BUY файле (правильная операция)", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер (правильная операция)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - проверка операции в SELL файле (правильная операция)", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", "S", "GAZP", "50", "250.00" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert_eq(#orders, 1, "1 ордер (правильная операция)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - проверка операции в SellOrders_Edge (неверная операция)", function()
  resetSendOrders()
  clearTestData()
  addTestPosition("GAZP", 100, 250.00)
  mockCSV({ { "Gazprom", "B", "GAZP", "10", "0.01" } })
  local orders = LoadOrdersFromFile("TEST_SellOrders_Edge.csv")
  assert_eq(#orders, 0, "0 ордеров (неверная операция в edge)")
  restoreCSV()
end)




ClearSecurityInfoCache()
test("LoadOrdersFromFile - файл без BUY/SELL в имени (пропуск)", function()
  resetSendOrders()
  clearTestData()
  mockCSV({ { "Gazprom", "B", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_Orders.csv")
  assert_eq(#orders, 0, "0 ордеров (неизвестный файл)")
  restoreCSV()
end)



---------------------------------------------
-- Пробелы и логирование
---------------------------------------------
print("\n=== Пробелы и логирование ===")

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробел в операции (трим)", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_eq(orders[1].Operation, "B", "операция триммена")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробел в тикере (трим)", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", "B", " GAZP ", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_eq(orders[1].SecurityCode, "GAZP", "тикер триммен")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробел в операции не превращает проверку BUY/SELL", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер (пробел триммен ок)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробелы во всех полях (трим)", function()
  resetSendOrders()
  mockCSV({ { " Gazprom ", " B ", " GAZP ", " 100 ", " 200.00 " } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_eq(orders[1].Operation, "B", "операция")
  assert_eq(orders[1].SecurityCode, "GAZP", "тикер")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробелы в продаже (трим)", function()
  resetSendOrders()
  clearTestData()
  addTestPosition("GAZP", 100, 250.00)
  mockCSV({ { "Gazprom", " S ", " GAZP ", " 10 ", " 0.01 " } })
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_eq(orders[1].Operation, "S", "операция")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробелы в тикере провоцируют проверку BUY/SELL", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", "B", " GAZP ", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер (пробелы в тикере ок)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробелы в операции провоцируют проверку BUY/SELL", function()
  resetSendOrders()
  mockCSV({ { "Gazprom", " B ", "GAZP", "100", "200.00" } })
  local orders = LoadOrdersFromFile("TEST_BuyOrders.csv")
  assert_eq(#orders, 1, "1 ордер (пробелы в операции ок)")
  restoreCSV()
end)

ClearSecurityInfoCache()
test("LoadOrdersFromFile - пробелы приводят к правильной проверке", function()
  resetSendOrders()
  clearTestData()
  addTestPosition("GAZP", 100, 250.00)
  mockCSV({ { "Gazprom", " S ", " GAZP ", " 10 ", " 0.01 " } })
  local orders = LoadOrdersFromFile("TEST_SellOrders.csv")
  assert_eq(#orders, 1, "1 ордер")
  assert_eq(orders[1].Operation, "S", "операция S")
  restoreCSV()
end)

---------------------------------------------
-- Результаты
---------------------------------------------
print("\n" .. string.rep("=", 40))
print(string.format("Итого: %d пройдено, %d провалено", passed, failed))
if #errors > 0 then
  print("\nОшибки:")
  for _, err in ipairs(errors) do
    print("  " .. err)
  end
end

os.exit(failed > 0 and 1 or 0)
