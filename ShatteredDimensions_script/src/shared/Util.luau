local Util = {}

function Util.deepCopy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Util.deepCopy(value)
	end
	return copy
end

function Util.clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

function Util.round(value, decimals)
	local power = 10 ^ (decimals or 0)
	return math.floor(value * power + 0.5) / power
end

function Util.tableFind(tbl, wanted)
	for index, value in ipairs(tbl) do
		if value == wanted then
			return index
		end
	end
	return nil
end

function Util.isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e6
		and math.abs(value.Y) < 1e6
		and math.abs(value.Z) < 1e6
end

function Util.formatClock(totalSeconds)
	local seconds = math.max(0, math.floor(totalSeconds + 0.5))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainder = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, remainder)
	end
	return string.format("%02d:%02d", minutes, remainder)
end

-- Общее время игры всегда показываем вплоть до секунд.
function Util.formatPlaytime(totalSeconds)
	local seconds = math.max(0, math.floor(totalSeconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainder = seconds % 60

	if hours > 0 then
		return string.format("%d ч %02d мин %02d сек", hours, minutes, remainder)
	elseif minutes > 0 then
		return string.format("%d мин %02d сек", minutes, remainder)
	end
	return string.format("%d сек", remainder)
end

function Util.formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	formatted = formatted:gsub("^%s+", "")
	return formatted
end

function Util.choose(array, random)
	if #array == 0 then
		return nil
	end
	local rng = random or Random.new()
	return array[rng:NextInteger(1, #array)]
end

function Util.shuffle(array, random)
	local copy = table.clone(array)
	local rng = random or Random.new()
	for index = #copy, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		copy[index], copy[swapIndex] = copy[swapIndex], copy[index]
	end
	return copy
end

-- Безопасное слияние сохранённых данных с профилем по умолчанию.
function Util.mergeDefaults(defaults, saved)
	local result = Util.deepCopy(defaults)
	if type(saved) ~= "table" then
		return result
	end

	for key, default in pairs(defaults) do
		local value = saved[key]
		if type(default) == "table" and next(default) ~= nil then
			if type(value) == "table" then
				result[key] = Util.mergeDefaults(default, value)
			end
		elseif type(value) == "table" and type(default) == "table" then
			-- Пустая таблица по умолчанию означает массив (скины, эмоции).
			result[key] = Util.deepCopy(value)
		elseif type(value) == type(default) then
			result[key] = Util.deepCopy(value)
		end
	end
	return result
end

return Util
