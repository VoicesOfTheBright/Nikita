--[[
	Shattered Dimensions — серверная точка входа.
	Создаёт RemoteEvent'ы, запускает сервисы и подготавливает игроков.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local REMOTE_NAMES = {
	"ClientReady",
	"UIState",
	"RoundEvent",
	"Notification",
	"ProfileUpdated",
	"ShopAction",
	"OpenShop",
	"PlayerListData",
	"RequestPlayerList",
	"SprintInput",
	"ToggleAbility",
	"AimUpdate",
	"PrimaryAction",
	"UseEmote",
	"CombatFeedback",
	"EmoteEvent",
}

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local networkFolder = getOrCreate(ReplicatedStorage, "Folder", "ShatteredDimensions")
local remotesFolder = getOrCreate(networkFolder, "Folder", "Remotes")
for _, remoteName in ipairs(REMOTE_NAMES) do
	getOrCreate(remotesFolder, "RemoteEvent", remoteName)
end

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local ContentService = require(Services:WaitForChild("ContentService"))
local MapService = require(Services:WaitForChild("MapService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))
local AbilityService = require(Services:WaitForChild("AbilityService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local PlayerListService = require(Services:WaitForChild("PlayerListService"))
local RoundService = require(Services:WaitForChild("RoundService"))
local LobbyService = require(Services:WaitForChild("LobbyService"))

Players.CharacterAutoLoads = false

DataService.init()
ContentService.init()
MapService.init()
CharacterService.init()
AbilityService.init()
ShopService.init()
PlayerListService.init()
RoundService.init()
LobbyService.init()

local clientReady = remotesFolder:WaitForChild("ClientReady")
local setupInProgress = {}

local function setupPlayer(player)
	local userId = player.UserId
	if setupInProgress[userId] or player:GetAttribute("SDE_Ready") == true then
		return
	end
	setupInProgress[userId] = true

	task.spawn(function()
		local profile = DataService.load(player)
		if not player.Parent then
			setupInProgress[userId] = nil
			return
		end
		if not profile then
			setupInProgress[userId] = nil
			player:Kick("Не удалось загрузить профиль Shattered Dimensions.")
			return
		end

		local activePhase = RoundService.getPhase() ~= "Lobby"
		player:SetAttribute("GameRole", if activePhase then Config.Roles.Spectator else Config.Roles.Lobby)
		player:SetAttribute("InRound", false)
		player:SetAttribute("IsDead", false)
		player:SetAttribute("Sprinting", false)
		player:SetAttribute("FlashlightOn", false)
		player:SetAttribute("Stamina", 100)
		player:SetAttribute("MaxStamina", 100)

		ShopService.sendProfile(player)
		AbilityService.resetPlayer(player)
		CharacterService.spawnLobby(player)

		if not player.Parent then
			setupInProgress[userId] = nil
			return
		end

		RoundService.onPlayerReady(player)
		PlayerListService.broadcast()
		player:SetAttribute("SDE_Ready", true)
		setupInProgress[userId] = nil
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	setupInProgress[player.UserId] = nil
	CharacterService.cleanup(player)
end)

clientReady.OnServerEvent:Connect(function(player)
	if not DataService.get(player) then
		return
	end
	ShopService.sendProfile(player)
	RoundService.sendStateTo(player)
	PlayerListService.sendTo(player)
end)

-- Небольшая подсказка в выводе Studio.
print("[Shattered Dimensions] Сервер запущен. Версия " .. Config.Brand.Version)
