--- ”тилиты форматировани€ чисел.
--- —одержит функции comma_value, round, format_num.

local FormatUtils = {}

--- ќбработка целых чисел.
math.round = function(num, idp)
  if num == nil then
    return nil
  end
  local mult = 10 ^ (idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- ‘орматирование числа с разделителем тыс€ч (пробел).
function FormatUtils.comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1 %2")
    if k == 0 then
      break
    end
  end
  return formatted
end

--- ќкругление числа до decimal знаков. ќбЄртка над math.round.
function FormatUtils.round(val, decimal)
  return math.round(val, decimal)
end

--- ‘орматирование числа: разделитель тыс€ч, знаки, префикс, негативный префикс.
function FormatUtils.format_num(amount, decimal, prefix, neg_prefix)
  local str_amount, formatted, famount, remain

  amount = amount or 0
  decimal = decimal or 2
  neg_prefix = neg_prefix or "-"

  famount = math.abs(math.round(amount, decimal))
  famount = math.floor(famount)

  remain = math.round(math.abs(amount) - famount, decimal)

  formatted = FormatUtils.comma_value(famount)

  if decimal > 0 then
    remain = string.sub(tostring(remain), 3)
    formatted = formatted .. "." .. remain .. string.rep("0", decimal - string.len(remain))
  end

  formatted = (prefix or "") .. formatted

  if amount < 0 then
    if neg_prefix == "()" then
      formatted = "(" .. formatted .. ")"
    else
      formatted = neg_prefix .. formatted
    end
  end

  return formatted
end

-- √лобальные обЄртки дл€ обратной совместимости
comma_value = FormatUtils.comma_value
round = FormatUtils.round
format_num = FormatUtils.format_num

return FormatUtils
