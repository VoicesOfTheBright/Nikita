local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = {}

local profiles = {}
local dirty = {}
local loading = {}
local store = nil
local warnedSave = false

local function profileKey(userId)
	return "player_" .. tostring(userId)
end

local function sanitizeProfile(raw)
	local profile = Util.mergeDefaults(Config.getDefaultProfile(), raw)

	profile.echoes = math.max(0, math.floor(tonumber(profile.echoes) or Config.Economy.StartingEchoes))
	profile.totalPlaySeconds = math.max(0, math.floor(tonumber(profile.totalPlaySeconds) or 0))
	profile.roundsPlayed = math.max(0, math.floor(tonumber(profile.roundsPlayed) or 0))
	profile.roundsWon = math.max(0, math.floor(tonumber(profile.roundsWon) or 0))
	profile.kills = math.max(0, math.floor(tonumber(profile.kills) or 0))

	local ownedSkins = {}
	if type(profile.ownedSkins) == "table" then
		for _, skinId in ipairs(profile.ownedSkins) do
			if type(skinId) == "string" and Config.getSkin(skinId) and Config.getSkin(skinId).price > 0 then
				if not Util.tableFind(ownedSkins, skinId) then
					table.insert(ownedSkins, skinId)
				end
			end
		end
	end
	profile.ownedSkins = ownedSkins

	local ownedEmotions = {}
	if type(profile.ownedEmotions) == "table" then
		for _, emotionId in ipairs(profile.ownedEmotions) do
			if type(emotionId) == "string" and Config.getEmotion(emotionId) and Config.getEmotion(emotionId).price > 0 then
				if not Util.tableFind(ownedEmotions, emotionId) then
					table.insert(ownedEmotions, emotionId)
				end
			end
		end
	end
	profile.ownedEmotions = ownedEmotions

	local savior = Config.getCharacter(profile.selectedSavior)
	if not savior or savior.role ~= Config.Roles.Savior then
		local defaultSavior = Config.getCharacterForRole(Config.Roles.Savior)
		profile.selectedSavior = defaultSavior.id
	end

	local lostSoul = Config.getCharacter(profile.selectedLostSoul)
	if not lostSoul or lostSoul.role ~= Config.Roles.LostSoul then
		local defaultLostSoul = Config.getCharacterForRole(Config.Roles.LostSoul)
		profile.selectedLostSoul = defaultLostSoul.id
	end

	local saviorSkin = Config.getSkin(profile.selectedSaviorSkin)
	if not saviorSkin or saviorSkin.role ~= Config.Roles.Savior then
		profile.selectedSaviorSkin = Config.getDefaultSkin(Config.Roles.Savior).id
	elseif saviorSkin.price > 0 and not Util.tableFind(profile.ownedSkins, saviorSkin.id) then
		profile.selectedSaviorSkin = Config.getDefaultSkin(Config.Roles.Savior).id
	end

	local lostSoulSkin = Config.getSkin(profile.selectedLostSoulSkin)
	if not lostSoulSkin or lostSoulSkin.role ~= Config.Roles.LostSoul then
		profile.selectedLostSoulSkin = Config.getDefaultSkin(Config.Roles.LostSoul).id
	elseif lostSoulSkin.price > 0 and not Util.tableFind(profile.ownedSkins, lostSoulSkin.id) then
		profile.selectedLostSoulSkin = Config.getDefaultSkin(Config.Roles.LostSoul).id
	end

	local emotion = Config.getEmotion(profile.selectedEmotion)
	if not emotion then
		profile.selectedEmotion = Config.Emotions[1].id
	elseif emotion.price > 0 and not Util.tableFind(profile.ownedEmotions, emotion.id) then
		profile.selectedEmotion = Config.Emotions[1].id
	end

	return profile
end

local function fetchSavedProfile(userId)
	if not store then
		return nil
	end

	local lastError
	for attempt = 1, Config.Data.LoadRetries do
		local ok, result = pcall(function()
			return store:GetAsync(profileKey(userId))
		end)

		if ok then
			return result
		end

		lastError = result
		if attempt < Config.Data.LoadRetries then
			task.wait(1)
		end
	end

	warn("[Shattered Dimensions] Не удалось загрузить профиль " .. tostring(userId) .. ": " .. tostring(lastError))
	return nil
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[Shattered Dimensions] DataStore недоступен, профили будут временными: " .. tostring(result))
	end

	task.spawn(function()
		local lastSave = os.clock()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = profiles[player.UserId]
				if profile then
					profile.totalPlaySeconds += 1
					dirty[player.UserId] = true
				end
			end

			if os.clock() - lastSave >= Config.Data.SaveIntervalSeconds then
				lastSave = os.clock()
				for _, player in ipairs(Players:GetPlayers()) do
					local profile = profiles[player.UserId]
					if profile and dirty[player.UserId] then
						DataService.save(player)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local profile = profiles[userId]
		if not profile then
			return
		end

		DataService.save(player)
		-- Профиль намеренно остаётся в памяти сервера: при быстром реджойне
		-- игрок продолжит с тем же прогрессом, а данные не потеряются.
		dirty[userId] = false
		loading[userId] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.save(player)
		end
		if not store then
			return
		end
		-- Даём Roblox время завершить SetAsync.
		task.wait(2)
	end)
end

function DataService.load(player)
	local userId = player.UserId
	if profiles[userId] then
		return profiles[userId]
	end
	if loading[userId] then
		local waited = 0
		while loading[userId] and waited < 15 do
			task.wait(0.1)
			waited += 0.1
		end
		return profiles[userId]
	end

	loading[userId] = true
	local saved = fetchSavedProfile(userId)
	local profile = sanitizeProfile(saved)
	profiles[userId] = profile
	loading[userId] = nil
	dirty[userId] = false
	return profile
end

function DataService.get(player)
	if not player then
		return nil
	end
	return profiles[player.UserId]
end

function DataService.getByUserId(userId)
	return profiles[userId]
end

function DataService.markDirty(player)
	if player then
		dirty[player.UserId] = true
	end
end

function DataService.save(player)
	if not player or not store then
		return false
	end

	local userId = player.UserId
	local profile = profiles[userId]
	if not profile then
		return false
	end

	local snapshot = Util.deepCopy(profile)
	local ok, result = pcall(function()
		store:SetAsync(profileKey(userId), snapshot)
	end)

	if ok then
		dirty[userId] = false
		return true
	end

	if not warnedSave then
		warnedSave = true
		warn("[Shattered Dimensions] Не удалось сохранить профиль: " .. tostring(result))
	end
	return false
end

function DataService.addEchoes(player, amount)
	local profile = DataService.get(player)
	if not profile then
		return 0
	end

	profile.echoes = math.max(0, profile.echoes + math.floor(amount or 0))
	DataService.markDirty(player)
	return profile.echoes
end

function DataService.getPublicProfile(player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	return {
		echoes = profile.echoes,
		ownedSkins = table.clone(profile.ownedSkins),
		ownedEmotions = table.clone(profile.ownedEmotions),
		selectedSavior = profile.selectedSavior,
		selectedLostSoul = profile.selectedLostSoul,
		selectedSaviorSkin = profile.selectedSaviorSkin,
		selectedLostSoulSkin = profile.selectedLostSoulSkin,
		selectedEmotion = profile.selectedEmotion,
		totalPlaySeconds = profile.totalPlaySeconds,
		roundsPlayed = profile.roundsPlayed,
		roundsWon = profile.roundsWon,
		kills = profile.kills,
	}
end

return DataService
