local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local MapService = require(script.Parent:WaitForChild("MapService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))

local RoundService = {}

local remotesFolder
local stateRemote
local roundEventRemote
local notificationRemote

local phase = "Lobby"
local phaseEndsAt = os.clock() + Config.Round.IntermissionSeconds
local endingEndsAt = 0
local roundEndsAt = 0
local currentMap = nil
local roundMode = "Standard"
local roundDuration = 0
local roundStartedAt = 0
local aliveSaviors = {}
local totalSaviors = 0
local lastKillerUserId = nil
local waitingForPlayers = false
local stateVersion = 0
local lastStateKey = nil
local random = Random.new(os.clock() * 1000000)

local buildPayload
local broadcastState
local pushState
local endRound
local returnToLobby
local abortRoundStart
local attemptStart

local function notify(player, text, tone)
	notificationRemote:FireClient(player, {
		text = text,
		tone = tone or "info",
	})
end

local function notifyAll(text, tone)
	notificationRemote:FireAllClients({
		text = text,
		tone = tone or "info",
	})
end

local function getReadyPlayers()
	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService.get(player) and player:GetAttribute("SD_Loading") ~= true then
			table.insert(ready, player)
		end
	end
	return ready
end

local function countAliveSaviors()
	local count = 0
	for _ in pairs(aliveSaviors) do
		count += 1
	end
	return count
end

local function setGamePhase(newPhase)
	phase = newPhase
	Workspace:SetAttribute("GamePhase", newPhase)
end

buildPayload = function()
	local now = os.clock()
	local timeLeft = 0

	if phase == "Lobby" then
		if waitingForPlayers then
			timeLeft = 0
		else
			timeLeft = math.max(0, math.ceil(phaseEndsAt - now))
		end
	elseif phase == "Round" then
		timeLeft = math.max(0, math.ceil(roundEndsAt - now))
	elseif phase == "Ending" then
		timeLeft = math.max(0, math.ceil(endingEndsAt - now))
	end

	return {
		phase = phase,
		timeLeft = timeLeft,
		mode = roundMode,
		mapName = currentMap and currentMap.name or nil,
		mapSubtitle = currentMap and currentMap.subtitle or nil,
		aliveSaviors = countAliveSaviors(),
		totalSaviors = totalSaviors,
		minPlayers = Config.Round.MinPlayers,
		playerCount = #Players:GetPlayers(),
		waitingForPlayers = waitingForPlayers,
	}
end

broadcastState = function()
	if stateRemote then
		stateRemote:FireAllClients(buildPayload())
	end
end

pushState = function(player)
	if stateRemote and player.Parent then
		stateRemote:FireClient(player, buildPayload())
	end
end

local function chooseKiller(players)
	local candidates = {}
	for _, player in ipairs(players) do
		if #players <= 2 or player.UserId ~= lastKillerUserId then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		candidates = players
	end

	local killer = Util.choose(candidates, random)
	lastKillerUserId = killer and killer.UserId or nil
	return killer
end

local function resetParticipantAttributes(player)
	player:SetAttribute("GameRole", Config.Roles.Lobby)
	player:SetAttribute("InRound", false)
	player:SetAttribute("IsDead", false)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("FlashlightOn", false)
end

local function spawnLobbyAsync(player)
	if not player.Parent then
		return
	end
	task.spawn(function()
		pcall(function()
			CharacterService.spawnLobby(player)
		end)
	end)
end

abortRoundStart = function(version, reason)
	if version ~= stateVersion then
		return
	end
	stateVersion += 1

	currentMap = nil
	roundMode = "Standard"
	totalSaviors = 0
	aliveSaviors = {}
	Workspace:SetAttribute("CurrentMapName", nil)
	MapService.cleanupRoundMap()

	waitingForPlayers = false
	phaseEndsAt = os.clock() + Config.Round.WaitingAfterFailedStart
	setGamePhase("Lobby")
	roundEventRemote:FireAllClients({
		type = "Abort",
		reason = reason,
	})
	notifyAll("Раунд отменён: " .. reason, "warning")

	for _, player in ipairs(Players:GetPlayers()) do
		resetParticipantAttributes(player)
		AbilityService.resetPlayer(player)
		spawnLobbyAsync(player)
	end
	broadcastState()
end

local function startRoundTask(version, players, killer, duration)
	local ok, mapData = pcall(MapService.buildRoundMap)
	if version ~= stateVersion then
		return
	end
	if not ok or not mapData then
		warn("[Shattered Dimensions] Не удалось построить карту: " .. tostring(mapData))
		abortRoundStart(version, "не удалось построить карту")
		return
	end

	currentMap = mapData
	roundDuration = duration
	Workspace:SetAttribute("CurrentMapName", mapData.name)

	local participants = {}
	local roles = {}
	local survivorIndex = 1

	for _, player in ipairs(players) do
		if player.Parent then
			local role = if player == killer then Config.Roles.LostSoul else Config.Roles.Savior
			roles[player.UserId] = role
			player:SetAttribute("GameRole", role)
			player:SetAttribute("InRound", true)
			player:SetAttribute("IsDead", false)
			table.insert(participants, player)
		end
	end

	if #participants < 2 or not roles[killer and killer.UserId] then
		abortRoundStart(version, "участники покинули лобби")
		return
	end

	local failures = 0
	local pending = 0
	for _, player in ipairs(participants) do
		local role = roles[player.UserId]
		local spawnCFrame
		if role == Config.Roles.LostSoul then
			spawnCFrame = mapData.killerSpawn
		else
			local spawns = mapData.survivorSpawns
			spawnCFrame = spawns[((survivorIndex - 1) % #spawns) + 1]
			survivorIndex += 1
		end

		pending += 1
		task.spawn(function()
			local spawnOk = pcall(function()
				CharacterService.spawnForRound(player, role, spawnCFrame)
			end)
			if not spawnOk or not CharacterService.isAlive(player) then
				failures += 1
			else
				AbilityService.setupForRound(player, role)
			end
			pending -= 1
		end)
	end

	while pending > 0 and version == stateVersion do
		task.wait(0.1)
	end
	if version ~= stateVersion then
		return
	end

	if failures > 0 then
		abortRoundStart(version, "не удалось загрузить персонажей")
		return
	end

	-- Проверяем, что обе стороны всё ещё на месте после загрузки.
	local active = {}
	totalSaviors = 0
	aliveSaviors = {}
	local hasKiller = false
	for _, player in ipairs(participants) do
		if player.Parent and player:GetAttribute("InRound") == true then
			local role = roles[player.UserId]
			if role == Config.Roles.LostSoul then
				hasKiller = true
			elseif role == Config.Roles.Savior then
				totalSaviors += 1
				if player:GetAttribute("IsDead") ~= true then
					aliveSaviors[player.UserId] = true
				end
			end
			table.insert(active, player)
		end
	end

	if not hasKiller or totalSaviors < 1 or #active < 2 then
		abortRoundStart(version, "недостаточно участников")
		return
	end

	-- Если кто-то отключился во время загрузки, пересчитываем режим и таймер.
	if #active == 2 and totalSaviors == 1 then
		roundMode = "LastFightingSoul"
		duration = Config.Round.LastFightingSoulSeconds
	else
		roundMode = "Standard"
		duration = Config.computeRoundSeconds(#active, totalSaviors)
	end
	roundDuration = duration

	roundStartedAt = os.clock()
	roundEndsAt = roundStartedAt + duration
	setGamePhase("Round")

	for _, player in ipairs(active) do
		local role = roles[player.UserId]
		roundEventRemote:FireClient(player, {
			type = "Start",
			role = role,
			mapName = mapData.name,
			mapSubtitle = mapData.subtitle,
			mode = roundMode,
			duration = duration,
			survivorCount = totalSaviors,
			playerCount = #active,
		})
	end

	notifyAll(
		if roundMode == "LastFightingSoul"
			then "LAST FIGHTING SOUL — один против одного."
			else "Раунд начался. Карта: " .. mapData.name,
		"info"
	)
	broadcastState()
end

local function beginRound(players)
	if phase ~= "Lobby" or #players < Config.Round.MinPlayers then
		return
	end

	stateVersion += 1
	local version = stateVersion
	waitingForPlayers = false

	local killer = chooseKiller(players)
	if not killer then
		return
	end

	local survivorCount = #players - 1
	local duration = Config.computeRoundSeconds(#players, survivorCount)
	roundMode = if #players == 2 and survivorCount == 1 then "LastFightingSoul" else "Standard"
	roundDuration = duration
	totalSaviors = 0
	aliveSaviors = {}
	Workspace:SetAttribute("CurrentMapName", nil)

	setGamePhase("Starting")
	notifyAll("Подготовка арены...", "info")
	broadcastState()

	task.spawn(function()
		startRoundTask(version, players, killer, duration)
	end)
end

attemptStart = function()
	if phase ~= "Lobby" then
		return
	end
	local ready = getReadyPlayers()
	if #ready < Config.Round.MinPlayers then
		waitingForPlayers = true
		phaseEndsAt = os.clock() + Config.Round.WaitingAfterFailedStart
		notifyAll("Нужно минимум " .. tostring(Config.Round.MinPlayers) .. " игрока. Ожидание...", "warning")
		broadcastState()
		return
	end
	beginRound(ready)
end

local function onPlayerDied(player)
	if phase ~= "Round" then
		return
	end

	AbilityService.onPlayerDied(player)
	local role = player:GetAttribute("GameRole")
	if role == Config.Roles.Savior then
		aliveSaviors[player.UserId] = nil
		roundEventRemote:FireClient(player, {
			type = "Death",
			aliveSaviors = countAliveSaviors(),
			totalSaviors = totalSaviors,
		})
		broadcastState()

		if countAliveSaviors() == 0 then
			endRound(Config.Roles.LostSoul, "Все выжившие потеряны.")
		end
	elseif role == Config.Roles.LostSoul then
		endRound(Config.Roles.Savior, "Потерянная душа рассеялась.")
	end
end

endRound = function(winner, reason)
	if phase ~= "Round" then
		return
	end

	stateVersion += 1
	setGamePhase("Ending")
	endingEndsAt = os.clock() + Config.Round.EndScreenSeconds

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InRound") == true then
			local role = player:GetAttribute("GameRole")
			local personalWin = (winner == Config.Roles.Savior and role == Config.Roles.Savior)
				or (winner == Config.Roles.LostSoul and role == Config.Roles.LostSoul)
			local reward = Config.Economy.ParticipationReward + (personalWin and Config.Economy.WinnerBonus or 0)

			local profile = DataService.get(player)
			if profile then
				profile.echoes += reward
				profile.roundsPlayed += 1
				if personalWin then
					profile.roundsWon += 1
				end
				DataService.markDirty(player)
				ShopService.sendProfile(player)
			end

			roundEventRemote:FireClient(player, {
				type = "End",
				winner = winner,
				reason = reason,
				reward = reward,
				personalWin = personalWin,
				role = role,
				duration = roundDuration,
			})

			player:SetAttribute("InRound", false)
			AbilityService.onPlayerDied(player)
		end
	end

	Workspace:SetAttribute("CurrentMapName", currentMap and currentMap.name or nil)
	broadcastState()
end

returnToLobby = function()
	stateVersion += 1
	phaseEndsAt = os.clock() + Config.Round.IntermissionSeconds
	waitingForPlayers = false
	roundMode = "Standard"
	roundDuration = 0
	roundStartedAt = 0
	roundEndsAt = 0
	endingEndsAt = 0
	totalSaviors = 0
	aliveSaviors = {}
	Workspace:SetAttribute("CurrentMapName", nil)
	setGamePhase("Lobby")
	MapService.applyLobbyLighting()

	for _, player in ipairs(Players:GetPlayers()) do
		resetParticipantAttributes(player)
		AbilityService.resetPlayer(player)
		spawnLobbyAsync(player)
	end

	local mapToClean = currentMap
	currentMap = nil

	task.spawn(function()
		task.wait(2)
		MapService.cleanupRoundMap()
		mapToClean = nil
	end)

	notifyAll("Вы возвращены в лобби. До следующего раунда " .. tostring(Config.Round.IntermissionSeconds) .. " сек.", "info")
	broadcastState()
end

local function handlePlayerRemoving(player)
	if phase == "Round" then
		local role = player:GetAttribute("GameRole")
		if role == Config.Roles.LostSoul then
			endRound(Config.Roles.Savior, "Потерянная душа покинула измерение.")
		elseif role == Config.Roles.Savior then
			aliveSaviors[player.UserId] = nil
			if countAliveSaviors() == 0 then
				endRound(Config.Roles.LostSoul, "Все выжившие покинули измерение.")
			end
		end
	end
end

function RoundService.init()
	remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")
	stateRemote = remotesFolder:WaitForChild("UIState")
	roundEventRemote = remotesFolder:WaitForChild("RoundEvent")
	notificationRemote = remotesFolder:WaitForChild("Notification")

	setGamePhase("Lobby")
	Workspace:SetAttribute("CurrentMapName", nil)
	waitingForPlayers = false
	phaseEndsAt = os.clock() + Config.Round.IntermissionSeconds
	CharacterService.setDeathCallback(onPlayerDied)
	Players.PlayerRemoving:Connect(handlePlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()

			if phase == "Lobby" then
				if not waitingForPlayers and now >= phaseEndsAt then
					attemptStart()
				end
			elseif phase == "Round" then
				if now >= roundEndsAt then
					endRound(Config.Roles.Savior, "Время вышло. Выжившие дожили до рассвета.")
				end
			elseif phase == "Ending" then
				if now >= endingEndsAt then
					returnToLobby()
				end
			end

			local payload = buildPayload()
			local key = table.concat({
				payload.phase,
				tostring(payload.timeLeft),
				tostring(payload.waitingForPlayers),
				payload.mapName or "",
				tostring(payload.aliveSaviors),
				tostring(payload.totalSaviors),
				tostring(payload.playerCount),
			}, "|")

			if key ~= lastStateKey then
				lastStateKey = key
				stateRemote:FireAllClients(payload)
			end
		end
	end)
end

function RoundService.onPlayerReady(player)
	if phase ~= "Lobby" then
		if player:GetAttribute("GameRole") ~= Config.Roles.Spectator then
			player:SetAttribute("GameRole", Config.Roles.Spectator)
			player:SetAttribute("InRound", false)
			CharacterService.refreshLobbyAppearance(player)
		end
		notify(player, "Раунд уже идёт. Вы присоединитесь со следующего раунда.", "warning")
		pushState(player)
		return
	end

	player:SetAttribute("GameRole", Config.Roles.Lobby)
	player:SetAttribute("InRound", false)
	CharacterService.refreshLobbyAppearance(player)
	pushState(player)

	if waitingForPlayers and #getReadyPlayers() >= Config.Round.MinPlayers then
		waitingForPlayers = false
		phaseEndsAt = os.clock() + Config.Round.WaitingAfterFailedStart
		notifyAll("Достаточно игроков. Старт через " .. tostring(Config.Round.WaitingAfterFailedStart) .. " сек.", "success")
		broadcastState()
	end
end

function RoundService.sendStateTo(player)
	pushState(player)
end

function RoundService.getPhase()
	return phase
end

function RoundService.getCurrentMapName()
	return currentMap and currentMap.name or nil
end

return RoundService
