--- Точка входа скрипта QUIK.
--- Управляет основным циклом, обрабатывает ответы транзакций,
--- очереди ордеров и сделок с помощью событийных
--- callback-функций QUIK (OnInit, OnStop, OnOrder, OnTrade, OnTransReply).

package.path = getScriptPath() .. "\\?.lua;" .. getScriptPath() .. "\\libs\\?.lua;" .. getScriptPath() .. "\\utils\\?.lua;"

require("Assistant")
Constants = require("Constants")

log = require("log")

local Engine = {}

transId = os.time()

Engine.isRun = true

Engine.N_TransReplies = {}
Engine.N_LastTransID = 0
Engine.N_Orders = {}
Engine.N_LastOrderNum = 0
Engine.N_Trades = {}
Engine.N_LastTradeNum = 0

Engine.OnInit = function()
  if N_OnInit ~= nil then
    N_OnInit()
  end
end

Engine.OnStop = function()
  Engine.isRun = false
  if N_OnStop ~= nil then
    N_OnStop()
  end
end

Engine.OnClose = function()
  if N_OnClose ~= nil then
    N_OnClose()
    sleep(Constants.SLEEP_MAIN_LOOP_MS)
  end
end

Engine.OnTransReply = function(trans_reply)
  for i, TransReply in ipairs(Engine.N_TransReplies) do
    if Engine.N_TransReplies[i].trans_id == trans_reply.trans_id then
      if Engine.N_TransReplies[i].checked ~= nil then
        trans_reply.checked = true
      end
      table.sremove(Engine.N_TransReplies, i)
      table.sinsert(Engine.N_TransReplies, trans_reply)
      return
    end
  end
  if Engine.N_LastTransID < trans_reply.trans_id then
    table.sinsert(Engine.N_TransReplies, trans_reply)
  end
end

Engine.OnOrder = function(order)
  for i, Order in ipairs(Engine.N_Orders) do
    if Engine.N_Orders[i].trans_id == order.trans_id then
      if Engine.N_Orders[i].checked ~= nil then
        order.checked = true
      end
      if Engine.N_Orders[i].last_execution_count ~= nil then
        order.last_execution_count = Engine.N_Orders[i].last_execution_count
      end
      table.sremove(Engine.N_Orders, i)
      table.sinsert(Engine.N_Orders, order)
      return
    end
  end
  if Engine.N_LastOrderNum < order.order_num then
    table.sinsert(Engine.N_Orders, order)
  end
end

Engine.OnTrade = function(trade)
  for i, Trade in ipairs(Engine.N_Trades) do
    if Engine.N_Trades[i].trade_num == trade.trade_num then
      if Engine.N_Trades[i].checked ~= nil then
        trade.checked = true
      end
      table.sremove(Engine.N_Trades, i)
      table.sinsert(Engine.N_Trades, trade)
      return
    end
  end
  if Engine.N_LastTradeNum < trade.trade_num then
    table.sinsert(Engine.N_Trades, trade)
  end
end

function main()
  while Engine.isRun do
    local loopOk, loopErr = pcall(function()
      if N_OnMainLoop ~= nil then
        N_OnMainLoop()
      end

      ClearPositionCache()

      for i, TransReplie in ipairs(Engine.N_TransReplies) do
        if Engine.N_TransReplies[i].checked == nil then
          if Engine.N_TransReplies[i].status > 1 and Engine.N_TransReplies[i].status ~= TRANS_STATUS_COMPLETED then
            if N_OnTransExecutionError ~= nil then
              N_OnTransExecutionError(Engine.N_TransReplies[i])
            end
            Engine.N_TransReplies[i].checked = true
          elseif Engine.N_TransReplies[i].status == TRANS_STATUS_COMPLETED then
            if N_OnTransOK ~= nil then
              N_OnTransOK(Engine.N_TransReplies[i])
            end
            Engine.N_TransReplies[i].checked = true
          end
        end
      end

      for i, Order in ipairs(Engine.N_Orders) do
        if Engine.N_Orders[i].checked == nil then
          if N_OnNewOrder ~= nil then
            N_OnNewOrder(Engine.N_Orders[i])
          end
          Engine.N_Orders[i].checked = true
        end
        local ExecutionCount = Engine.N_Orders[i].qty - Engine.N_Orders[i].balance
        if
          (Engine.N_Orders[i].last_execution_count == nil or Engine.N_Orders[i].last_execution_count ~= ExecutionCount)
          and ExecutionCount > 0
        then
          if N_OnExecutionOrder ~= nil then
            N_OnExecutionOrder(Engine.N_Orders[i])
            Engine.N_Orders[i].last_execution_count = ExecutionCount
          end
        end
      end

      local tradesToRemove = {}
      local ordersToRemove = {}
      local repliesToRemove = {}

      for i, Trade in ipairs(Engine.N_Trades) do
        N_OnNewTrade(Engine.N_Trades[i])
        Engine.N_LastTradeNum = Engine.N_Trades[i].trade_num
        tradesToRemove[Engine.N_Trades[i].trade_num] = true

        log.debug(
          "N_OnNewTrade() deal #"
            .. Engine.N_Trades[i].trade_num
            .. " trans_id="
            .. tostring(Engine.N_Trades[i].trans_id)
            .. " price="
            .. Engine.N_Trades[i].price
            .. " qty="
            .. Engine.N_Trades[i].qty
        )
        log.trace(json.encode(Engine.N_Trades[i]))

        if Engine.N_Trades[i].order_num ~= nil then
          for j, Order in ipairs(Engine.N_Orders) do
            if Engine.N_Trades[i].order_num == Engine.N_Orders[j].order_num then
              if Engine.N_Orders[j].last_execution_count ~= nil and Engine.N_Orders[j].last_execution_count == Engine.N_Orders[j].qty then
                Engine.N_LastTransID = Engine.N_Orders[j].trans_id
                ordersToRemove[Engine.N_Orders[j].order_num] = true
                for k, TransReply in ipairs(Engine.N_TransReplies) do
                  if TransReply.trans_id == Engine.N_Orders[j].trans_id then
                    repliesToRemove[k] = true
                  end
                end
                Engine.N_LastOrderNum = Engine.N_Orders[j].order_num
                break
              end
            end
          end
        end
      end

      for i = #Engine.N_TransReplies, 1, -1 do
        if repliesToRemove[i] then
          table.remove(Engine.N_TransReplies, i)
        end
      end
      for i = #Engine.N_Orders, 1, -1 do
        if ordersToRemove[Engine.N_Orders[i].order_num] then
          table.remove(Engine.N_Orders, i)
        end
      end
      for i = #Engine.N_Trades, 1, -1 do
        if tradesToRemove[Engine.N_Trades[i].trade_num] then
          table.remove(Engine.N_Trades, i)
        end
      end

      sleep(Constants.SLEEP_MAIN_LOOP_MS)
    end)
    if not loopOk then
      log.error(string.format("Ошибка главного цикла: %s", tostring(loopErr)))
      sleep(Constants.SLEEP_ERROR_MS)
    end
  end
end

OnInit = Engine.OnInit
OnStop = Engine.OnStop
OnClose = Engine.OnClose
OnTransReply = Engine.OnTransReply
OnOrder = Engine.OnOrder
OnTrade = Engine.OnTrade

return Engine
