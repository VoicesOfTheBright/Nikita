local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local PlayerListService = {}

local remotesFolder
local listRemote
local requestRemote

local ROLE_ORDER = {
	[Config.Roles.LostSoul] = 1,
	[Config.Roles.Savior] = 2,
	[Config.Roles.Spectator] = 3,
	[Config.Roles.Lobby] = 4,
}

local function buildSnapshot()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.get(player)
		if profile then
			local role = player:GetAttribute("GameRole") or Config.Roles.Lobby
			table.insert(players, {
				userId = player.UserId,
				username = player.Name,
				displayName = player.DisplayName,
				role = role,
				inRound = player:GetAttribute("InRound") == true,
				isDead = player:GetAttribute("IsDead") == true,
				totalPlaySeconds = profile.totalPlaySeconds,
				saviorId = profile.selectedSavior,
				saviorSkinId = profile.selectedSaviorSkin,
				lostSoulId = profile.selectedLostSoul,
				lostSoulSkinId = profile.selectedLostSoulSkin,
				emotionId = profile.selectedEmotion,
			})
		end
	end

	table.sort(players, function(a, b)
		local aOrder = ROLE_ORDER[a.role] or 9
		local bOrder = ROLE_ORDER[b.role] or 9
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return string.lower(a.displayName) < string.lower(b.displayName)
	end)

	return {
		phase = Workspace:GetAttribute("GamePhase") or "Lobby",
		mapName = Workspace:GetAttribute("CurrentMapName"),
		players = players,
		serverTime = os.time(),
	}
end

function PlayerListService.init()
	remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")
	listRemote = remotesFolder:WaitForChild("PlayerListData")
	requestRemote = remotesFolder:WaitForChild("RequestPlayerList")

	requestRemote.OnServerEvent:Connect(function(player)
		listRemote:FireClient(player, buildSnapshot())
	end)

	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			listRemote:FireAllClients(buildSnapshot())
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.PlayerList.RefreshSeconds)
			if #Players:GetPlayers() > 0 then
				listRemote:FireAllClients(buildSnapshot())
			end
		end
	end)
end

function PlayerListService.sendTo(player)
	listRemote:FireClient(player, buildSnapshot())
end

function PlayerListService.broadcast()
	listRemote:FireAllClients(buildSnapshot())
end

return PlayerListService
