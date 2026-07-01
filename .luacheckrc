-- Luacheck configuration for QuikAssistant
-- Globals from QUIK API and project architecture

std = "lua53"

-- QUIK API globals
globals = {
    -- QUIK native functions
    "getScriptPath",
    "getSecurityInfo",
    "getParamEx",
    "getNumberOf",
    "SearchItems",
    "getItem",
    "sendTransaction",
    "isConnected",
    "getInfoParam",
    "getPortfolioInfoEx",
    "sleep",
    "message",
    "PrintDbgStr",

    -- QUIK constants
    "QTABLE_STRING_TYPE",
    "QTABLE_DOUBLE_TYPE",
    "QTABLE_INT64_TYPE",
    "QTABLE_NO_INDEX",

    -- QUIK table functions
    "AllocTable",
    "CreateWindow",
    "SetWindowPos",
    "DeleteTable",
    "GetTableSize",
    "AddLine",
    "DeleteLine",
    "SetCell",
    "GetCell",
    "SetValue",
    "GetValue",
    "SetCaption",
    "SetColor",
    "SetPosition",
    "Show",
    "CloseWindow",

    -- Project globals (event bus and state)
    "isRun",
    "transId",
    "N_TransReplies",
    "N_LastTransID",
    "N_Orders",
    "N_LastOrderNum",
    "N_Trades",
    "N_LastTradeNum",
    "N_OnInit",
    "N_OnMainLoop",
    "N_OnStop",
    "N_OnClose",
    "N_OnTransSendError",
    "N_OnTransExecutionError",
    "N_OnTransOK",
    "N_OnNewOrder",
    "N_OnExecutionOrder",
    "N_OnNewTrade",
    "N_CloseAllOrder",

    -- Config globals (set by Setting.lua)
    "Broker",
    "ClientCode",
    "AccountCode",
    "FirmId",
    "VolumeOrderMax",
    "BondVolumeOrderMax",
    "VolumeOrderLimit",
    "LimitActuationOrderEdge",
    "LimitActuationOrderBondEdge",
    "FileBuyOrder",
    "FileSellOrder",
    "FileBuyOrderEdge",
    "FileBuyOrderBondsEdge",
    "FileSellOrderEdge",
    "SessionMorningEnabled",
    "SessionMainEnabled",
    "SessionEveningEnabled",
    "BrokerEnabled",

    -- Constants (promoted by Constants.lua)
    "FLAG_ACTIVE",
    "FLAG_EXECUTED",
    "FLAG_SELL",
    "ERR_PRICE_TOO_LOW",
    "ERR_PRICE_TOO_HIGH",
    "ERR_EXECUTION_REJECTED",
    "TRANS_STATUS_COMPLETED",
    "PRICE_DEVIATION_MULTIPLIER",

    -- Session state globals
    "TimeMainStart",
    "TimeMorningStart",
    "TimeEveningStart",
    "IsSentOrders",
    "IsSendingOrders",
    "IsMorningTime",
    "IsMainTime",
    "IsEveningTime",
    "sendOrders",
    "sendOrdersSet",
    "unknownSecurities",

    -- Function globals (backward compatibility wrappers)
    "AdjustPrice",
    "CheckOrder",
    "GetPosition",
    "GetPriceLast",
    "GetPriceMin",
    "GetPriceMax",
    "GetOrderVolumeMax",
    "GetKoeffVolumeOrderMax",
    "ClearPositionCache",
    "ClearSecurityInfoCache",
    "IsOrderExists",
    "IsSendOrder",
    "GetOperation",
    "IsOrderExecuted",
    "FindOrder",
    "GetQuikOrders",
    "SetLimitOrdersWithError",
    "TradeClosePosition",
    "TradeSave",
    "LoadOrdersFromFile",
    "SubmitOrders",
    "Initialization",
    "SubmittingOrders",
    "SubmittingOrdersRun",
    "SetClientSetting",
    "RefreshTableOrdersControl",
    "ClearTableOrdersControl",
    "UpdateTableSetting",
    "RefreshDataToTableSetting",
    "getFromCSV",
    "format_num",
    "comma_value",
    "round",

    -- Table column name globals
    "nameColumnSecurityName",
    "nameColumnSecurityCode",
    "nameColumnOperation",
    "nameColumnPriceLast",
    "nameColumnOrderPrice",
    "nameColumnQuantity",
    "nameColumnVolume",
    "nameColumnActuation",
    "nameColumnLastChange",
    "nameColumnOrderNum",
    "nameSettingBroker",
    "nameSettingClientCode",
    "nameSettingAccountCode",
    "nameSettingFirmId",

    -- Table instances
    "tableOrdersControl",
    "tableSetting",

    -- Callbacks
    "OnInit",
    "OnStop",
    "OnOrder",
    "OnTrade",
    "OnTransReply",
    "OnClose",
    "main",
}

-- Read-only globals (should not be set)
read_globals = {
    "json",
    "log",
    "csv",
    "enum",
    -- QUIK table/math extensions
    "table.sinsert",
    "table.sremove",
    "math.round",
    -- Project classes (used via require)
    "Order",
    "QTable",
    "Config",
    "SettingsManager",
    "PositionService",
    "MarketData",
    "BrokerAdapter",
    "OrderValidator",
    "TransactionHandler",
    "PriceAdjuster",
    "FileFunction",
    "TradeSave",
    "SessionScheduler",
    "OrderLoader",
    "SubmittingOrders",
    "TableConstructor",
    "TableOrders",
    "TableSetting",
    "Setting",
    "Constants",
    "OrderLoader",
    -- Test/indicator globals
    "_initConstants",
    "WaitForMarketData",
    "DestroyTable",
    "IsWindowClosed",
    "unpack",
    "getDataSourceInfo",
    "AddLabel",
    "DelAllLabels",
    "GetLabelParams",
    "getBuySellInfo",
    "FindPosition",
    "chart_tag",
    "Start",
    "Init",
    "OnCalculate",
    "Settings",
    "ClassCode",
    "BrokerUserMap",
    -- QUIK table/indicator globals
    "FindSetting",
    "RGB",
    "QTABLE_DEFAULT_COLOR",
    "nameSettingFileBuyOrderBondsEdge",
    "nameSettingFileSellOrderEdge",
    "nameSettingFileBuyOrderEdge",
    "nameSettingFileSellOrder",
    "nameSettingFileBuyOrder",
    "nameSettingVolumeOrderMax",
    "nameSettingInAllAssets",
    "nameSettingAllAssets",
    "nameSettingProfitLoss",
    "nameSettingRateChange",
    "nameSettingIndexMOEX",
    "nameSettingServerTime",
    "AlignRight",
    "SetAccountSetting",
    "SetPortfolioInfo",
    "SetFileOrders",
    "GetSettingValue",
    "EventCallbackTableSetting",
    "QTABLE_LBUTTONDBLCLK",
    "SetSettingVTB",
    "SetSettingFinam",
    -- Additional QUIK globals
    "left",
    "GetSecurityInfo",
    "N_SetLimitOrder",
    "ShowTableSetting",
    "SetServerTime",
    "IMAGE_BUY",
    "IMAGE_SELL",
    "labelId",
    "charts",
    -- QUIK table events
    "QTABLE_LBUTTONUP",
    "QTABLE_MBUTTONDBLCLK",
    "QTABLE_MBUTTONDOWN",
    "QTABLE_RBUTTONUP",
    "QTABLE_CLOSE",
    "QTABLE_CONTEXTMENU",
    "QTABLE_RBUTTONDOWN",
    "QTABLE_LBUTTONDOWN",
    "QTABLE_RBUTTONDBLCLK",
    "QTABLE_VKEY",
    "QTABLE_CHAR",
    "QTABLE_SELCHANGED",
    -- QUIK table functions
    "AddColumn",
    "InsertRow",
    "Clear",
    "GetWindowRect",
    "GetWindowCaption",
    "SetWindowCaption",
    "SetTableNotificationCallback",
    -- TableSetting globals
    "CreateTableSetting",
    "CreateTableOrdersControl",
    "ShowTableOrdersControl",
    "SetDataToTableSetting",
    "UpdateTableOrdersControl",
    "FindRow",
    "GetPriceCurrent",
    "GetOrderOperation",
    "EventTable",
    "EventCallbackTableSetting",
    "top",
    "bottom",
    "left",
    "right",
    "k",
    "res",
    "countOrders",
    "cols",
    "col",
    "str_amount",
    "problem",
    -- MarketData globals
    "GetParamInfo",
    "GetPricePrev",
    -- OrderValidator globals
    "ClearVolumeWarnedTickers",
}

-- Ignore specific warnings
ignore = {
    "212", -- unused argument (common in QUIK callbacks)
    "213", -- unused loop variable
    "122", -- setting read-only global (for log/json initialization)
    "121", -- setting read-only field (for log config)
    "211", -- unused variable (common in QUIK indicators)
    "214", -- unused variable with _ prefix
    "431", -- shadowing definition (common in loops)
    "421", -- shadowing definition of variable
    "422", -- shadowing definition of argument
    "311", -- value assigned but unused (common in pcall)
    "542", -- empty if branch (legitimate pattern)
    "411", -- variable was previously defined (common in loops)
    "412", -- variable was previously defined as argument
    "431", -- variable was previously defined as upvalue
    "512", -- line is too long (style preference)
    "unused", -- unused variable warnings (often QUIK API or module-level state)
}

-- Per-file overrides
files["Tests/**/*.lua"] = {
    globals = {
        "quik_mock",
        "addTestOrder",
        "addTestPosition",
        "clearTestData",
        "tables",
    },
}

files["IntegrationTests/**/*.lua"] = {
    globals = {
        "quik_mock",
        "Config",
        "SettingsManager",
        "PositionService",
        "MarketData",
        "BrokerAdapter",
        "N_SetLimitOrder",
        "_initConstants",
        "Order",
        "WaitForMarketData",
    },
}

files["LuaIndicators/**/*.lua"] = {
    globals = {
        "OnInit",
        "OnStop",
        "OnTransReply",
        "main",
        "comma_value",
        "round",
        "format_num",
        "Start",
        "Init",
        "OnCalculate",
        "Settings",
        "chart_tag",
        "ClassCode",
        "SetSettingVTB",
        "SetSettingFinam",
        "FindPosition",
        "PlaceLabel",
        "k",
        "label_params",
    },
}
