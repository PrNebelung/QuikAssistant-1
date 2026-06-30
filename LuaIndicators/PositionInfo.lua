Settings=
  {
    Name = "PositionInfo"
  }
-- Настройки

-- Метка. Это же значение необходимо указать в настройках графика на закладке "Дополнительно" в поле "Идентификатор"
chart_tag = "MySecurities"

Broker = "";
ClientCode = "";
AccountCode= "";
ClassCode = "";
FirmId= "";



function SetClientSetting()

  local userId = getInfoParam("USERID");
  if (userId == nil or userId == "") then
  end

  if (userId == "171783") then
    SetSettingFinam();
  elseif (userId == "49653") then
    SetSettingVTB();
  end;
end;

function SetSettingFinam()
  Broker = "FINAM";
  ClientCode = "0734A/0734A";
  AccountCode = "L01+00000F00";
  FirmId= "MC0061900000";
end;

function SetSettingVTB()
  Broker = "VTB";
  ClientCode = "386507";
  AccountCode= "L01-00000F00";
  FirmId= "MC0003300000";
end;

function comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
    if (k==0) then
      break
    end
  end
  return formatted
end

---============================================================
-- rounds a number to the nearest decimal places
--
function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

--===================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
--
--
function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount,  formatted, famount, remain

  decimal = decimal or 2  -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(round(amount,decimal))
  famount = math.floor(famount)

  remain = round(math.abs(amount) - famount, decimal)

  -- comma to separate the thousands
  formatted = comma_value(famount)

  -- attach the decimal portion
  if (decimal > 0) then
    remain = string.sub(tostring(remain),3)
    formatted = formatted .. "." .. remain ..
      string.rep("0", decimal - string.len(remain))
  end

  -- attach prefix string e.g '$'
  formatted = (prefix or "") .. formatted

  -- if value is negative then format accordingly
  if (amount<0) then
    if (neg_prefix=="()") then
      formatted = "("..formatted ..")"
    else
      formatted = neg_prefix .. formatted
    end
  end

  local addLength = 13 - string.len(formatted)

  for i = 1, addLength do
    formatted = " " .. formatted
  end
  return formatted
end

function PlaceLabel(text)

  --  local boo = DelAllLabels("MySecurities")
  --   message("boo = " .. tostring(boo) );

  label_params = {
    -- Если подпись не требуется то оставить строку пустой ""
    TEXT = text,
    -- Если картинка не требуется оставить значение пустым ""
    IMAGE_PATH = "",
    -- Расположение картинки относительно текста (возможно 4 варианта: LEFT, RIGHT, TOP, BOTTOM)
    ALIGNMENT = "",
    -- Значение параметра на оси Y, к которому будет привязана метка
    YVALUE = 300,
    -- Дата в формате «ГГГГММДД», к которой привязана метка
    DATE = "20190203",
    -- Время в формате «ЧЧММСС», к которому будет привязана метка
    TIME = "110000",
    -- Красная компонента цвета в формате RGB. Число в интервале [0;255]
    R = 100,
    -- Зеленая компонента цвета в формате RGB. Число в интервале [0;255]
    G = 200,
    -- Синяя компонента цвета в формате RGB. Число в интервале [0;255]
    B = 80,
    -- Прозрачность метки в процентах. Значение должно быть в промежутке [0; 100]
    TRANSPARENCY = 10,
    -- Прозрачность фона картинки. Возможные значения: «0» – прозрачность отключена, «1» – прозрачность включена
    TRANSPARENT_BACKGROUND = 1,
    -- Название шрифта (например «Arial»)
    FONT_FACE_NAME = "Arial",
    -- Размер шрифта
    FONT_HEIGHT = 12,
    -- Текст всплывающей подсказки
    HINT = "This is hint"
  }

  --DelAllLabels(chart_tag)
  --  local labelParams = GetLabelParams("MySecurities", 1)
  --     message("labelParams = " .. tostring(labelParams) );

  --label_params.TEXT = text;
  -- Добавляем метку и запоминаем ее ID
  --  local label_id = AddLabel("MySecurities", label_params)
  --   message("label_id = " .. tostring(label_id) );
  --
  local labelParams = GetLabelParams("MySecurities", 1)
  message("labelParams = " .. tostring(labelParams) );
  if labelParams ~= nil then
    message("labelParams = " .. tostring(labelParams.text) );
    message("labelParams.YVALUE = " .. tostring(labelParams.yvalue) );
  --     labelParams.TEXT = text
  --     SetLabelParams("MySecurities", 1, labelParams)
  end



end


function FindPosition(limit_kind, currentbal)
  if limit_kind == 2 and tonumber(currentbal) ~= 0 then
    return true
  end
  return false
end

function GetPosition(securityCode)
  local countPositions = getNumberOf("depo_limits");
  local positions = SearchItems("depo_limits", 0, countPositions-1, FindPosition, "limit_kind, currentbal")
  if positions ~= nil then
    for i = 1, #positions do
      local position = getItem("depo_limits", positions[i]);
      if position.sec_code == securityCode then
        return position;
      end
    end;
  end;

  return nil;

end

function Init()

  SetClientSetting();

  local info = getDataSourceInfo();
  -- message("info " .. tostring(info));
  if info ~=  nil then
    --  PlaceLabel(info.sec_code);
    local position = GetPosition(info.sec_code);
    local buySellInfo = getBuySellInfo(FirmId, ClientCode, info.class_code, info.sec_code, 0);
    if position ~= nil then
      local valuebalance = position.currentbal * position.wa_position_price;
      local result = "Бумага \t\t" .. tostring(info.sec_code);
      result = result .. "\nПозиция \t" .. format_num(tonumber(position.currentbal), 0);
      result = result .. "\nБаланс. цена\t " .. format_num(position.wa_position_price, 2);
      result = result .. "\nБал. стоимость\t " .. format_num(tonumber(valuebalance), 2);
      result = result .. "\nСтоимость\t" .. format_num(tonumber(buySellInfo.value), 2);
      result = result .. "\nПрибыль\t" .. format_num(tonumber(buySellInfo.profit_loss), 2);
      result = result .. "\nПрибыль, %\t" .. format_num(tonumber(buySellInfo.profit_loss / valuebalance * 100), 2);
      message(tostring(result));
    --local textInfo = "class_code = " .. tostring(info.class_code) .. "   sec_code = " .. tostring(info.sec_code) .. " position.currentbal = " .. tostring(position.currentbal);
    --PlaceLabel("DDDD");
    else
      message("Бумага " .. tostring(info.sec_code) .. " не куплена ");
    end
  end

  return 1
end
function OnCalculate(index)
  return nil
end
