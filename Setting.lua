require("TableSetting")

--- ���� ������ ���������� QUIK
FLAG_ACTIVE = 0x1
FLAG_EXECUTED = 0x2
FLAG_SELL = 0x4

--- ���� ������ ���������� QUIK
ERR_PRICE_TOO_LOW = 579
ERR_PRICE_TOO_HIGH = 580
ERR_EXECUTION_REJECTED = 133

--- ���� �������� ����������
TRANS_STATUS_COMPLETED = 3

--- ��������� ��� ������������� ���
PRICE_DEVIATION_MULTIPLIER = 10

--- ��������� ����������
Broker = ""
ClientCode = ""
AccountCode = ""
AccountCodeSpb = ""
FirmId = ""
VolumeOrderMax = 0
BondVolumeOrderMax = 0
--- ��������� �� ������� ������
VolumeOrderLimit = 200000
--- ��������� �� ������� ������ � ��������
VolumeOrderLimitUSD = 100
--- ��������� �� ������� ������ ����������� ����� � ������
VolumeOrderLimitForeign = 70000

--- ��������� ���������� �� ���� �����
LimitActuationOrderEdge = 5
--- ��������� ���������� �� ���� ����� ���������
LimitActuationOrderBondEdge = 60
--- ��������� ���������� �� ���� ����� ����������� �����
LimitActuationOrderForeignEdge = 30

FileBuyOrder = ""
FileSellOrder = ""
FileBuyOrderEdge = ""
FileBuyOrderBondsEdge = ""
FileBuyOrderSpbEdge = ""
FileBuyOrderRmUsdEdge = ""
FileSellOrderEdge = ""

function SetSettingFinam()
  Broker = "FINAM"
  ClientCode = "0734A/0734A"
  AccountCode = "L01+00000F00"
  FirmId = "MC0061900000"
  VolumeOrderMax = 70000
  BondVolumeOrderMax = 100000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 50
  VolumeOrderLimit = 120000
end

function SetSettingVTB()
  Broker = "VTB"
  ClientCode = "386507"
  AccountCode = "L01-00000F00"
  FirmId = "MC0003300000"
  VolumeOrderMax = 20000
  BondVolumeOrderMax = 20000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 30
end

function SetSettingPSB()
  Broker = "PSB"
  ClientCode = "40200"
  AccountCode = "L01+00000F00"
  FirmId = "MC0038600000"
  VolumeOrderMax = 50000
  BondVolumeOrderMax = 100000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 0
  VolumeOrderLimit = 120000
end

function SetSettingRSHB()
  Broker = "RSHB"
  ClientCode = "496082"
  AccountCode = "L01+00000F00"
  FirmId = "MC0134700000"
  VolumeOrderMax = 20000
  BondVolumeOrderMax = 20000
  LimitActuationOrderEdge = 0
  LimitActuationOrderBondEdge = 60
end

function SetSettingTest()
  Broker = "TEST"
  ClientCode = "10567"
  AccountCode = "NL0011100043"
  FirmId = ""
  VolumeOrderMax = 11000
  BondVolumeOrderMax = 7000
end

--- ��������� ���������� ��� �������
function SetClientSetting()
  -- ������� ���� ���������� � ���� ��� ���� ��������
  if ClearSecurityInfoCache then
    ClearSecurityInfoCache()
  end
  local userId = getInfoParam("USERID")
  local problem = ""
  if userId == nil or userId == "" then
    problem = "ID ������������ �� ������"
  end

  if userId == "171783" then
    SetSettingFinam()
  elseif userId == "49653" then
    SetSettingVTB()
  elseif userId == "34146" then
    SetSettingPSB()
  elseif userId == "48640" then
    SetSettingRSHB()
  elseif userId == "119330" then
    SetSettingTest()
  else
    Broker = ""
    ClientCode = ""
    AccountCode = ""
    VolumeOrderMax = 0
  end

  FileBuyOrder = Broker .. "_BuyOrders.csv"
  FileSellOrder = Broker .. "_SellOrders.csv"
  FileBuyOrderEdge = Broker .. "_BuyOrders_Edge.csv"
  FileBuyOrderBondsEdge = Broker .. "_BuyOrdersBonds_Edge.csv"
  FileSellOrderEdge = Broker .. "_SellOrders_Edge.csv"
end
