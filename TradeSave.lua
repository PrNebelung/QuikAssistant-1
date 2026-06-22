--- ���������� ������ � ����.
--- ���������� ���������� � ������ ����������� ������
--- (���, ��������, ����������, ����) � ���� MyTrades.csv.


local BrokerAdapter = require("BrokerAdapter")

--���������� ������ � ��� � � ���� ������� ������
--- ���������� ������ � ���� MyTrades.csv: ����, �����, ���, ��������, ����������, ����, ������.
function TradeSave(trade)
  local Operation = ""
  if trade.buy_sell == "S" then
    Operation = "-"
  end

  local TradeLine = os.date("%Y-%m-%d")
    .. " "
    .. os.date("%X", os.time())
    .. ";"
    .. trade.sec_code
    .. ";"
    .. Operation
    .. trade.qty
    .. ";"
    .. trade.price
    .. ";"
    .. Broker
    .. "\n"

  local fp, err = io.open(BrokerAdapter.GetScriptPath() .. "//Data//MyTrades.csv", "a+")
  if not fp then
    log.error("�� ������� ������� MyTrades.csv: " .. tostring(err))
    return
  end

  local ok, werr = pcall(function()
    fp:write(TradeLine)
    fp:flush()
    fp:close()
  end)
  if not ok then
    log.error("������ ������ � MyTrades.csv: " .. werr)
  end
end
