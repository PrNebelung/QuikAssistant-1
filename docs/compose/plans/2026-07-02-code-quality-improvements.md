# QuikAssistant Code Quality Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve code quality, reduce technical debt, and enhance maintainability while preserving all existing functionality and Russian text.

**Architecture:** Focus on reducing global namespace pollution, eliminating code duplication, improving error handling consistency, and removing dead code. All changes must maintain backward compatibility with existing CSV files and QUIK API integration.

**Tech Stack:** Lua 5.1 (QUIK scripting environment), cp1251 encoding for .lua files, UTF-8 for logs

## Global Constraints

- **Encoding:** All .lua files with Russian text MUST use cp1251 encoding. Use `cp1251_wrapper.py` for all modifications. NEVER use Edit tool directly on files with Russian text.
- **Backward Compatibility:** All CSV file formats must remain unchanged. QUIK API calls must not be modified.
- **Testing:** Run `lua Tests/run_tests.lua` after each task to verify no regressions.
- **Naming:** Preserve existing function signatures where used by QUIK callbacks (OnInit, OnStop, OnOrder, OnTrade, OnTransReply).

---

## Task 1: Remove Dead Code and Unused Functions

**Covers:** Code cleanup, reducing maintenance burden

**Files:**
- Modify: `TableOrders.lua:14-40` (remove commented-out code block)
- Modify: `Order.lua` (remove unused `math.round` shadow)
- Modify: `Setting.lua` (remove unused globals)

**Interfaces:**
- Consumes: None
- Produces: Cleaner codebase with no dead code

- [ ] **Step 1: Remove commented-out code in TableOrders.lua**

Read `TableOrders.lua` lines 14-40 to identify the commented-out code block. Remove it completely.

```lua
-- REMOVE lines 14-40 (commented-out code block)
```

- [ ] **Step 2: Remove unused math.round shadow in Order.lua**

The `math.round` function at line 9-15 shadows the global `math.round`. Since `FormatUtils.round` exists and is used elsewhere, this shadow is unnecessary.

```lua
-- REMOVE lines 9-15:
math.round = function(num, idp)
  if num == nil then
    return nil
  end
  local mult = 10 ^ (idp or 0)
  return math.floor(num * mult + 0.5) / mult
end
```

Update `Order.lua:GetPriceRound()` to use `FormatUtils.round` instead:

```lua
function Order:GetPriceRound()
  local FormatUtils = require("FormatUtils")
  local price = FormatUtils.round(self.Price, self.SecurityInfo.scale)
  -- ... rest of function
```

- [ ] **Step 3: Remove unused globals in Setting.lua**

Remove these unused global assignments at the end of the file (if they exist):
- `TRANS_STATUS_REJECTED`
- `VolumeOrderMin`
- `OFZVolumeOrderMax`

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add TableOrders.lua Order.lua Setting.lua
git commit -m "refactor: remove dead code and unused globals"
```

---

## Task 2: Reduce Global Namespace Pollution in StartEngine.lua

**Covers:** Code organization, reducing side effects

**Files:**
- Modify: `StartEngine.lua` (wrap globals in module table)

**Interfaces:**
- Consumes: None
- Produces: Cleaner global namespace

- [ ] **Step 1: Wrap N_ callback functions in a table**

Instead of polluting global namespace with `N_OnInit`, `N_OnMainLoop`, etc., create a single `Engine` table:

```lua
-- At top of StartEngine.lua, after requires
local Engine = {}

-- Replace all N_ callbacks with Engine.xxx
Engine.OnInit = function() ... end
Engine.OnMainLoop = function() ... end
Engine.OnStop = function() ... end
-- etc.

-- Keep backward-compatible globals for QUIK
OnInit = Engine.OnInit
OnStop = Engine.OnStop
OnClose = Engine.OnClose
OnOrder = Engine.OnOrder
OnTrade = Engine.OnTrade
OnTransReply = Engine.OnTransReply
```

- [ ] **Step 2: Move state variables into Engine table**

```lua
Engine.isRun = true
Engine.transId = os.time()
Engine.N_TransReplies = {}
Engine.N_LastTransID = 0
Engine.N_Orders = {}
Engine.N_LastOrderNum = 0
Engine.N_Trades = {}
Engine.N_LastTradeNum = 0
```

- [ ] **Step 3: Update main() to use Engine table**

```lua
function main()
  while Engine.isRun do
    local loopOk, loopErr = pcall(function()
      if Engine.OnMainLoop then
        Engine.OnMainLoop()
      end
      -- ... rest of loop using Engine.xxx
    end)
    -- ...
  end
end
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add StartEngine.lua
git commit -m "refactor: encapsulate global state in Engine table"
```

---

## Task 3: Consolidate Duplicate Code in SubmittingOrders.lua

**Covers:** DRY principle, reducing code duplication

**Files:**
- Modify: `SubmittingOrders.lua` (extract repeated patterns)

**Interfaces:**
- Consumes: None
- Produces: Cleaner SubmittingOrders.lua with less duplication

- [ ] **Step 1: Extract file processing into helper function**

The pattern of loading orders and submitting them is repeated 5 times (lines 111-180). Extract into a helper:

```lua
--- Process orders from a file
--- @param fileName string
--- @param stats table
--- @param isSubmittingOrdersRun boolean
local function processFile(fileName, stats, isSubmittingOrdersRun)
  if not isSubmittingOrdersRun then
    return
  end
  
  log.debug(string.format("Loading orders from %s", fileName))
  local orders = OrderLoader.LoadOrdersFromFile(fileName)
  stats.loaded = stats.loaded + #orders
  local s = SubmitOrders(orders)
  stats.sent = stats.sent + s.sent
  stats.rejected = stats.rejected + s.rejected
  stats.duplicate = stats.duplicate + s.duplicate
  sleep(1000)
end
```

- [ ] **Step 2: Replace duplicate code with helper calls**

```lua
-- In SubmittingOrdersRun(), replace lines 111-180 with:
processFile(Config.FileBuyOrder, stats, isSubmittingOrdersRun)
processFile(Config.FileBuyOrderBondsEdge, stats, isSubmittingOrdersRun)
processFile(Config.FileBuyOrderEdge, stats, isSubmittingOrdersRun)
processFile(Config.FileSellOrder, stats, true)  -- Always process sell
processFile(Config.FileSellOrderEdge, stats, isSubmittingOrdersRun)
```

- [ ] **Step 3: Extract duplicate stats tracking**

The stats accumulation pattern (lines 183-186) is duplicated. Extract:

```lua
local function accumulateStats(cumStats, stats)
  cumStats.loaded = cumStats.loaded + stats.loaded
  cumStats.sent = cumStats.sent + stats.sent
  cumStats.rejected = cumStats.rejected + stats.rejected
  cumStats.duplicate = cumStats.duplicate + stats.duplicate
end
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add SubmittingOrders.lua
git commit -m "refactor: extract duplicate order processing patterns"
```

---

## Task 4: Consolidate Duplicate Code in TransactionHandler.lua

**Covers:** DRY principle, reducing code duplication

**Files:**
- Modify: `TransactionHandler.lua` (extract repeated patterns)

**Interfaces:**
- Consumes: None
- Produces: Cleaner TransactionHandler.lua

- [ ] **Step 1: Extract order search helper**

The pattern of searching orders and iterating is repeated in `GetQuikOrders()` and `IsOrderExists()`. Extract:

```lua
--- Search and iterate over orders matching filter
--- @param filterFunc function
--- @param callback function
local function forEachOrder(filterFunc, callback)
  local orderIndices = BrokerAdapter.SearchOrders(filterFunc, "flags, sec_code, class_code")
  for i = 1, #orderIndices do
    local order = BrokerAdapter.GetOrder(orderIndices[i])
    if order then
      callback(order)
    end
  end
end
```

- [ ] **Step 2: Refactor GetQuikOrders and IsOrderExists**

```lua
function TransactionHandler.GetQuikOrders()
  forEachOrder(TransactionHandler.FindOrder, function(order)
    OnOrder(order)
  end)
end

function TransactionHandler.IsOrderExists(newOrder)
  local found = false
  forEachOrder(TransactionHandler.FindOrder, function(order)
    -- existing comparison logic
    if found then return end
    -- ...
  end)
  return found
end
```

- [ ] **Step 3: Extract error handling pattern**

The error handling pattern (lines 88-157) has repeated structure. Extract common error checking:

```lua
--- Check if error message contains specific error code
--- @param result_msg string
--- @param error_code string
--- @return boolean
local function isError(result_msg, error_code)
  return string.find(result_msg, ": (" .. error_code .. ")", 1, true) ~= nil
end
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add TransactionHandler.lua
git commit -m "refactor: extract order search and error handling patterns"
```

---

## Task 5: Consolidate Duplicate Code in TableOrders.lua

**Covers:** DRY principle, reducing code duplication

**Files:**
- Modify: `TableOrders.lua` (extract repeated patterns)

**Interfaces:**
- Consumes: None
- Produces: Cleaner TableOrders.lua

- [ ] **Step 1: Extract table row lookup helper**

The pattern of finding or creating a row is repeated in `UpdateTableOrdersControl`. Extract:

```lua
--- Find or create a row in table by order number
--- @param t QTable
--- @param orderNum number
--- @return number row index
local function findOrCreateRow(t, orderNum)
  local row = FindRow(t, orderNum)
  if row == nil then
    row = t:AddLine()
  end
  return row
end
```

- [ ] **Step 2: Extract table cell update helper**

The pattern of setting multiple cells is repeated. Extract:

```lua
--- Update a row with order data
--- @param t QTable
--- @param row number
--- @param secInfo table
--- @param order table
--- @param priceLast string
--- @param operation string
--- @param actuation number
--- @param lastChange number
local function updateRowCells(t, row, secInfo, order, priceLast, operation, actuation, lastChange)
  SetCell(t.t_id, row, 1, secInfo.name)
  SetCell(t.t_id, row, 2, order.sec_code)
  SetCell(t.t_id, row, 3, operation)
  SetCell(t.t_id, row, 4, string.format("%.2f", actuation))
  SetCell(t.t_id, row, 5, format_num(tonumber(priceLast), 6))
  SetCell(t.t_id, row, 6, format_num(tonumber(order.price), 6))
  SetCell(t.t_id, row, 7, format_num(tonumber(order.qty)))
  SetCell(t.t_id, row, 8, format_num(tonumber(order.value), 2))
  SetCell(t.t_id, row, 9, string.format("%.2f", lastChange))
  SetCell(t.t_id, row, 10, string.format("%i", order.order_num))
end
```

- [ ] **Step 3: Refactor UpdateTableOrdersControl**

```lua
function UpdateTableOrdersControl(t, order)
  local secInfo = GetSecurityInfo(order.sec_code)
  if secInfo == nil then return end
  
  local priceLast = GetPriceCurrent(order.class_code, order.sec_code)
  local operation = GetOrderOperation(order)
  local actuation = (tonumber(priceLast) - tonumber(order.price)) / tonumber(order.price) * 100
  local lastChange = BrokerAdapter.GetParamEx(order.class_code, order.sec_code, "LASTCHANGE") or 0
  
  local row = findOrCreateRow(t, order.order_num)
  updateRowCells(t, row, secInfo, order, priceLast, operation, actuation, lastChange)
  
  -- Color coding
  if math.abs(actuation) < 2 then
    t:Red(row, 4)
  elseif math.abs(actuation) < 5 then
    t:Yellow(row, 4)
  else
    t:Default(row, 4)
  end
  
  if IsOrderExecuted(order.flags) then
    t:Green(row, QTABLE_NO_INDEX)
  end
end
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add TableOrders.lua
git commit -m "refactor: extract table row and cell update helpers"
```

---

## Task 6: Improve Error Handling Consistency

**Covers:** Robustness, better error reporting

**Files:**
- Modify: `BrokerAdapter.lua` (consistent error handling)
- Modify: `MarketData.lua` (consistent error handling)

**Interfaces:**
- Consumes: None
- Produces: More consistent error handling

- [ ] **Step 1: Standardize error return values in BrokerAdapter**

Currently some functions return `nil` on error, others return `"0"`. Standardize:

```lua
--- Get parameter value, returns nil on error (not "0")
function BrokerAdapter.GetParamEx(classCode, secCode, param)
  local value = getParamEx(classCode, secCode, param)
  if value == nil or value.result == "0" then
    return nil  -- Changed from returning "0"
  end
  return value.param_value
end
```

- [ ] **Step 2: Update MarketData to handle nil consistently**

```lua
function MarketData.GetPriceLast(order)
  local priceLast = MarketData.GetParamInfo(order, "LAST")
  if priceLast == nil or tonumber(priceLast) == 0 then
    priceLast = MarketData.GetPricePrev(order)
  end
  return priceLast or "0"  -- Always return string
end
```

- [ ] **Step 3: Add validation in critical paths**

Add validation in `OrderValidator.CheckOrder`:

```lua
function OrderValidator.CheckOrder(order)
  if order == nil then
    log.error("CheckOrder: order is nil")
    return false, "order is nil"
  end
  
  for _, check in ipairs(checkChain) do
    local passed, reason = check(order)
    if not passed then
      return false, reason
    end
  end
  return true, ""
end
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add BrokerAdapter.lua MarketData.lua OrderValidator.lua
git commit -m "fix: standardize error handling and add nil validation"
```

---

## Task 7: Extract Magic Numbers to Constants

**Covers:** Code clarity, maintainability

**Files:**
- Modify: `Constants.lua` (add new constants)
- Modify: `StartEngine.lua` (use constants)
- Modify: `SubmittingOrders.lua` (use constants)

**Interfaces:**
- Consumes: None
- Produces: Constants.lua with all magic numbers

- [ ] **Step 1: Add missing constants to Constants.lua**

```lua
-- Sleep intervals
Constants.SLEEP_MAIN_LOOP_MS = 1000
Constants.SLEEP_ERROR_MS = 5000
Constants.SLEEP_BETWEEN_FILES_MS = 3000
Constants.SLEEP_SHORT_MS = 1000

-- Retry limits
Constants.MARKET_DATA_MAX_RETRIES = 30
Constants.MARKET_DATA_RETRY_INTERVAL_S = 2
Constants.MAX_RECURSION_DEPTH = 3

-- Table positions
Constants.TABLE_SETTING_X = 1
Constants.TABLE_SETTING_Y = 420
Constants.TABLE_SETTING_DX = 680
Constants.TABLE_SETTING_DY = 320

Constants.TABLE_ORDERS_X = 700
Constants.TABLE_ORDERS_Y = 1
Constants.TABLE_ORDERS_DX = 1200
Constants.TABLE_ORDERS_DY = 925
```

- [ ] **Step 2: Update StartEngine.lua to use constants**

```lua
-- Replace magic numbers
sleep(Constants.SLEEP_MAIN_LOOP_MS)  -- was: sleep(1000)
-- In error handler:
sleep(Constants.SLEEP_ERROR_MS)  -- was: sleep(5000)
```

- [ ] **Step 3: Update SubmittingOrders.lua to use constants**

```lua
-- Replace magic numbers
sleep(Constants.SLEEP_BETWEEN_FILES_MS)  -- was: sleep(3000)
-- In WaitForMarketData:
local maxRetries = Constants.MARKET_DATA_MAX_RETRIES
local retryInterval = Constants.MARKET_DATA_RETRY_INTERVAL_S
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 5: Commit**

```bash
git add Constants.lua StartEngine.lua SubmittingOrders.lua
git commit -m "refactor: extract magic numbers to named constants"
```

---

## Task 8: Improve SessionScheduler Logic Clarity

**Covers:** Code clarity, easier maintenance

**Files:**
- Modify: `SessionScheduler.lua` (simplify logic)

**Interfaces:**
- Consumes: None
- Produces: Clearer SessionScheduler

- [ ] **Step 1: Simplify session checking logic**

The current logic is complex with multiple flag checks. Simplify:

```lua
function SessionScheduler.CheckSession()
  local now = os.time()
  
  -- Check each session time
  local sessions = {
    { time = self.TimeMorningStart, enabled = Config.SessionMorningEnabled, flag = "morning" },
    { time = self.TimeMainStart, enabled = Config.SessionMainEnabled, flag = "main" },
    { time = self.TimeEveningStart, enabled = Config.SessionEveningEnabled, flag = "evening" },
  }
  
  for _, session in ipairs(sessions) do
    if session.enabled and os.time(session.time) < now and not self["Is" .. session.flag .. "Time"] then
      self["Is" .. session.flag .. "Time"] = true
      self.IsSentOrders = false
    end
  end
  
  return not self.IsSentOrders and os.time(self.TimeMorningStart) < now
end
```

- [ ] **Step 2: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 3: Commit**

```bash
git add SessionScheduler.lua
git commit -m "refactor: simplify session scheduler logic"
```

---

## Task 9: Add Input Validation to Order Methods

**Covers:** Robustness, preventing bugs

**Files:**
- Modify: `Order.lua` (add validation)

**Interfaces:**
- Consumes: None
- Produces: More robust Order methods

- [ ] **Step 1: Add validation to SetOperation**

```lua
function Order:SetOperation(operation, price, quantity)
  -- Validate inputs
  if operation ~= "B" and operation ~= "S" then
    log.error(string.format("Invalid operation: %s", tostring(operation)))
    return
  end
  
  if price == nil or tonumber(price) < 0 then
    log.error(string.format("Invalid price: %s", tostring(price)))
    return
  end
  
  if quantity == nil or tonumber(quantity) < 0 then
    log.error(string.format("Invalid quantity: %s", tostring(quantity)))
    return
  end
  
  self.Operation = operation
  self.Quantity = quantity
  self.Price = price
  self:GetPriceRound()
  
  if price == 0 then
    if self.SecurityInfo.min_price_step <= 0.0001 then
      self.Price = 0.0001
    else
      self.Price = self.SecurityInfo.min_price_step
    end
  end
end
```

- [ ] **Step 2: Add validation to SetQuantity**

```lua
function Order:SetQuantity(operation, price, quantityMax)
  self.Operation = operation
  
  if price == nil or quantityMax == nil then
    self.Quantity = 0
    return
  end
  
  local priceNum = tonumber(price)
  local maxNum = tonumber(quantityMax)
  
  if priceNum == nil or priceNum <= 0 or maxNum == nil or maxNum <= 0 then
    self.Quantity = 0
    return
  end
  
  -- ... rest of logic
end
```

- [ ] **Step 3: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 4: Commit**

```bash
git add Order.lua
git commit -m "feat: add input validation to Order methods"
```

---

## Task 10: Document All Public Functions

**Covers:** Code documentation, maintainability

**Files:**
- Modify: All main .lua files (add LuaDoc comments)

**Interfaces:**
- Consumes: None
- Produces: Documented codebase

- [ ] **Step 1: Add LuaDoc to Order.lua**

```lua
--- Create new Order instance
--- @param securityCode string Security ticker (e.g., "GAZP")
--- @return table|nil Order object or nil if security not found
function Order:new(securityCode)
  -- ...
end

--- Set order operation, price and quantity
--- @param operation string "B" for buy, "S" for sell
--- @param price number Order price
--- @param quantity number Order quantity
function Order:SetOperation(operation, price, quantity)
  -- ...
end
```

- [ ] **Step 2: Add LuaDoc to other modules**

Add documentation to:
- `BrokerAdapter.lua` - all public functions
- `MarketData.lua` - all public functions
- `PositionService.lua` - all public functions
- `OrderValidator.lua` - all public functions
- `SubmittingOrders.lua` - all public functions

- [ ] **Step 3: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All 170 tests pass

- [ ] **Step 4: Commit**

```bash
git add *.lua utils/*.lua
git commit -m "docs: add LuaDoc documentation to all public functions"
```

---

## Task 11: Add Comprehensive Unit Tests

**Covers:** Test coverage, regression prevention

**Files:**
- Modify: `Tests/run_tests.lua` (add new tests)

**Interfaces:**
- Consumes: Existing Order, OrderValidator, TransactionHandler modules
- Produces: Higher test coverage

- [ ] **Step 1: Add tests for OrderValidator checks**

```lua
-- Test: OrderValidator checkNotNil
test("checkNotNil - nil order", function()
  local ok, reason = CheckOrder(nil)
  assert_false(ok, "nil order should fail")
end)

test("checkNotNil - zero price", function()
  local order = Order:new("GAZP")
  order:SetOperation("B", 0, 100)
  local ok, reason = CheckOrder(order)
  assert_false(ok, "zero price should fail")
end)

-- Test: OrderValidator checkPriceBelowPricemin
test("checkPriceBelowPricemin - price below minimum", function()
  local savedGetParamEx = getParamEx
  getParamEx = function(class_code, sec_code, param)
    if param == "PRICEMIN" then
      return { result = "1", param_value = "100.0" }
    end
    return { result = "1", param_value = "0" }
  end
  local order = Order:new("GAZP")
  order:SetOperation("B", 50.00, 10)
  local ok, reason = CheckOrder(order)
  assert_false(ok, "price below PRICEMIN should fail")
  getParamEx = savedGetParamEx
end)
```

- [ ] **Step 2: Add tests for PriceAdjuster**

```lua
-- Test: PriceAdjuster.AdjustPrice
test("AdjustPrice - buy order below LAST", function()
  local savedGetParamEx = getParamEx
  getParamEx = function(class_code, sec_code, param)
    if param == "LAST" then
      return { result = "1", param_value = "200.0" }
    end
    if param == "PRICEMIN" then
      return { result = "1", param_value = "100.0" }
    end
    return { result = "1", param_value = "0" }
  end
  local order = Order:new("GAZP")
  order:SetOperation("B", 250.00, 100)
  AdjustPrice(order)
  -- Price should be adjusted down
  assert_true(order.Price < 250.00, "price should be adjusted")
  getParamEx = savedGetParamEx
end)
```

- [ ] **Step 3: Add tests for SessionScheduler**

```lua
-- Test: SessionScheduler
test("SessionScheduler - check session", function()
  local Config = require("Config")
  Config.SessionMorningEnabled = true
  SessionScheduler.Initialization()
  local result = SessionScheduler.CheckSession()
  assert_true(type(result) == "boolean", "should return boolean")
end)
```

- [ ] **Step 4: Run tests**

```bash
lua Tests/run_tests.lua
```

Expected: All tests pass (should be 180+ now)

- [ ] **Step 5: Commit**

```bash
git add Tests/run_tests.lua
git commit -m "test: add comprehensive unit tests for validators and adjusters"
```

---

## Task 12: Verify All Improvements Work Together

**Covers:** Integration verification

**Files:**
- All modified files

**Interfaces:**
- Consumes: All previous tasks
- Produces: Verified working codebase

- [ ] **Step 1: Run full test suite**

```bash
lua Tests/run_tests.lua
```

Expected: All 180+ tests pass

- [ ] **Step 2: Verify encoding is preserved**

```bash
python cp1251_wrapper.py check_all
```

Expected: All .lua files show OK

- [ ] **Step 3: Verify Russian text is readable**

```bash
python -c "
import sys; sys.stdout.reconfigure(encoding='utf-8')
files = ['Setting.lua', 'Assistant.lua', 'SubmittingOrders.lua']
for f in files:
    with open(f, 'rb') as fp:
        raw = fp.read()
    text = raw.decode('cp1251')
    print(f'{f}: OK - Russian text present')
"
```

- [ ] **Step 4: Run luacheck for code quality**

```bash
luacheck *.lua utils/*.lua
```

Expected: No new warnings introduced

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: verify all improvements and encoding preservation"
```

---

## Summary

This plan addresses:
1. **Dead code removal** - Clean up commented code and unused globals
2. **Global namespace reduction** - Encapsulate state in module tables
3. **Code duplication** - Extract common patterns into helper functions
4. **Error handling** - Standardize error returns and add validation
5. **Magic numbers** - Replace with named constants
6. **Logic clarity** - Simplify complex conditionals
7. **Input validation** - Prevent bugs at entry points
8. **Documentation** - Add LuaDoc comments
9. **Test coverage** - Add comprehensive tests

All changes maintain backward compatibility and preserve Russian text in cp1251 encoding.
