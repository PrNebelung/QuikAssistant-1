--- ������-��������� �������.
--- ���������� ����� ������� QUIK (FLAG_ACTIVE, FLAG_SELL � ��.),
--- ���� ������ (ERR_PRICE_TOO_LOW � ��.), ������� ����������
--- � ��������� ������������� ���.

local Constants = {}

-- ==========================================
-- ����� ������� QUIK
-- ==========================================
Constants.FLAG_ACTIVE = 0x1
Constants.FLAG_EXECUTED = 0x2
Constants.FLAG_SELL = 0x4

-- ==========================================
-- ���� ������ QUIK
-- ==========================================
Constants.ERR_PRICE_TOO_LOW = 579
Constants.ERR_PRICE_TOO_HIGH = 580
Constants.ERR_EXECUTION_REJECTED = 133

-- ==========================================
-- ������� ����������
-- ==========================================
Constants.TRANS_STATUS_COMPLETED = 3

-- ==========================================
-- ������������� ���
-- ==========================================
Constants.PRICE_DEVIATION_MULTIPLIER = 10

--- �������� �������� Constants.* � ���������� ���������� (FLAG_ACTIVE � ��.) ��� �������� �������������.
function _initConstants()
  FLAG_ACTIVE = Constants.FLAG_ACTIVE
  FLAG_EXECUTED = Constants.FLAG_EXECUTED
  FLAG_SELL = Constants.FLAG_SELL
  ERR_PRICE_TOO_LOW = Constants.ERR_PRICE_TOO_LOW
  ERR_PRICE_TOO_HIGH = Constants.ERR_PRICE_TOO_HIGH
  ERR_EXECUTION_REJECTED = Constants.ERR_EXECUTION_REJECTED
  TRANS_STATUS_COMPLETED = Constants.TRANS_STATUS_COMPLETED
  PRICE_DEVIATION_MULTIPLIER = Constants.PRICE_DEVIATION_MULTIPLIER
end

_initConstants()

return Constants
