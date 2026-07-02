--- Работа с CSV-файлами ордеров.
--- Реализует чтение CSV-файлов с описаниями ордеров
--- из папки Data проекта.

local BrokerAdapter = require("BrokerAdapter")

---------------------------------------------------------------------------
-- Функции для работы с файлами
--
--
---------------------------------------------------------------------------

local csv = require("csv")

--- Читает CSV-файл из папки Data, возвращает массив строк.
--- Чтение данных из CSV-файла в папке Data.
--- @param nameFileCSV string имя CSV-файла (относительно Data/)
--- @return table массив строк, каждая строка — массив значений
function getFromCSV(nameFileCSV)
	local result = {}
	local path = BrokerAdapter.GetScriptPath() .. "//Data//" .. nameFileCSV
	local fileCSV = csv.open(path)

	if fileCSV ~= nil then
		for r in fileCSV:lines() do
			local r2 = {}
			for i, v in ipairs(r) do
				r2[#r2 + 1] = tostring(v)
			end
			result[#result + 1] = r2
		end
	else
		log.warn(string.format("Не удалось открыть CSV файл: %s", path))
	end

	return result
end
