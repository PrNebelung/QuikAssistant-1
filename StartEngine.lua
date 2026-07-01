--- Точка входа скрипта QUIK.
--- Управляет основным циклом, обрабатывает ответы транзакций,
--- очереди ордеров и сделок с помощью событийных
--- callback-функций QUIK (OnInit, OnStop, OnOrder, OnTrade, OnTransReply).

package.path = getScriptPath() .. "\\?.lua;" .. getScriptPath() .. "\\libs\\?.lua;" .. getScriptPath() .. "\\utils\\?.lua;"

require("Assistant")

log = require("log")

isRun = true
transId = os.time()

N_TransReplies = {}
N_LastTransID = 0
N_Orders = {}
N_LastOrderNum = 0
N_Trades = {}
N_LastTradeNum = 0

function main()
  while isRun do
    local loopOk, loopErr = pcall(function()
      if N_OnMainLoop ~= nil then
        N_OnMainLoop()
      end

      ClearPositionCache()

      for i, TransReplie in ipairs(N_TransReplies) do
        if N_TransReplies[i].checked == nil then
          if N_TransReplies[i].status > 1 and N_TransReplies[i].status ~= TRANS_STATUS_COMPLETED then
            if N_OnTransExecutionError ~= nil then
              N_OnTransExecutionError(N_TransReplies[i])
            end
            N_TransReplies[i].checked = true
          elseif N_TransReplies[i].status == TRANS_STATUS_COMPLETED then
            if N_OnTransOK ~= nil then
              N_OnTransOK(N_TransReplies[i])
            end
            N_TransReplies[i].checked = true
          end
        end
      end

      for i, Order in ipairs(N_Orders) do
        if N_Orders[i].checked == nil then
          if N_OnNewOrder ~= nil then
            N_OnNewOrder(N_Orders[i])
          end
          N_Orders[i].checked = true
        end
        local ExecutionCount = N_Orders[i].qty - N_Orders[i].balance
        if
          (N_Orders[i].last_execution_count == nil or N_Orders[i].last_execution_count ~= ExecutionCount)
          and ExecutionCount > 0
        then
          if N_OnExecutionOrder ~= nil then
            N_OnExecutionOrder(N_Orders[i])
            N_Orders[i].last_execution_count = ExecutionCount
          end
        end
      end

      local tradesToRemove = {}
      local ordersToRemove = {}
      local repliesToRemove = {}

      for i, Trade in ipairs(N_Trades) do
        N_OnNewTrade(N_Trades[i])
        N_LastTradeNum = N_Trades[i].trade_num
        tradesToRemove[N_Trades[i].trade_num] = true

        log.debug(
          "N_OnNewTrade() deal #"
            .. N_Trades[i].trade_num
            .. " trans_id="
            .. tostring(N_Trades[i].trans_id)
            .. " price="
            .. N_Trades[i].price
            .. " qty="
            .. N_Trades[i].qty
        )
        log.trace(json.encode(N_Trades[i]))

        if N_Trades[i].order_num ~= nil then
          for j, Order in ipairs(N_Orders) do
            if N_Trades[i].order_num == N_Orders[j].order_num then
              if N_Orders[j].last_execution_count ~= nil and N_Orders[j].last_execution_count == N_Orders[j].qty then
                N_LastTransID = N_Orders[j].trans_id
                ordersToRemove[N_Orders[j].order_num] = true
                for k, TransReply in ipairs(N_TransReplies) do
                  if TransReply.trans_id == N_Orders[j].trans_id then
                    repliesToRemove[k] = true
                  end
                end
                N_LastOrderNum = N_Orders[j].order_num
                break
              end
            end
          end
        end
      end

      for i = #N_TransReplies, 1, -1 do
        if repliesToRemove[i] then
          table.remove(N_TransReplies, i)
        end
      end
      for i = #N_Orders, 1, -1 do
        if ordersToRemove[N_Orders[i].order_num] then
          table.remove(N_Orders, i)
        end
      end
      for i = #N_Trades, 1, -1 do
        if tradesToRemove[N_Trades[i].trade_num] then
          table.remove(N_Trades, i)
        end
      end

      sleep(1000)
    end)
    if not loopOk then
      log.error("Main loop error: " .. tostring(loopErr))
      sleep(5000)
    end
  end
end

function OnTransReply(trans_reply)
  for i, TransReply in ipairs(N_TransReplies) do
    if N_TransReplies[i].trans_id == trans_reply.trans_id then
      if N_TransReplies[i].checked ~= nil then
        trans_reply.checked = true
      end
      table.sremove(N_TransReplies, i)
      table.sinsert(N_TransReplies, trans_reply)
      return
    end
  end
  if N_LastTransID < trans_reply.trans_id then
    table.sinsert(N_TransReplies, trans_reply)
  end
end

function OnOrder(order)
  for i, Order in ipairs(N_Orders) do
    if N_Orders[i].trans_id == order.trans_id then
      if N_Orders[i].checked ~= nil then
        order.checked = true
      end
      if N_Orders[i].last_execution_count ~= nil then
        order.last_execution_count = N_Orders[i].last_execution_count
      end
      table.sremove(N_Orders, i)
      table.sinsert(N_Orders, order)
      return
    end
  end
  if N_LastOrderNum < order.order_num then
    table.sinsert(N_Orders, order)
  end
end

function OnTrade(trade)
  for i, Trade in ipairs(N_Trades) do
    if N_Trades[i].trade_num == trade.trade_num then
      if N_Trades[i].checked ~= nil then
        trade.checked = true
      end
      table.sremove(N_Trades, i)
      table.sinsert(N_Trades, trade)
      return
    end
  end
  if N_LastTradeNum < trade.trade_num then
    table.sinsert(N_Trades, trade)
  end
end

function OnInit()
  if N_OnInit ~= nil then
    N_OnInit()
  end
end

function OnStop()
  isRun = false
  if N_OnStop ~= nil then
    N_OnStop()
  end
end

function OnClose()
  if N_OnClose ~= nil then
    N_OnClose()
    sleep(1000)
  end
end
