--[[
	Shattered Dimensions — клиентская точка входа.
	Собирает HUD, магазин, список участников и обработчики ввода.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")

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

local remotes = {}
for _, remoteName in ipairs(REMOTE_NAMES) do
	remotes[remoteName] = remotesFolder:WaitForChild(remoteName)
end

local UI = script.Parent:WaitForChild("UI")
local Controllers = script.Parent:WaitForChild("Controllers")

local HUD = require(UI:WaitForChild("HUD"))
local Shop = require(UI:WaitForChild("Shop"))
local PlayerList = require(UI:WaitForChild("PlayerList"))
local Effects = require(Controllers:WaitForChild("Effects"))
local InputController = require(Controllers:WaitForChild("InputController"))

local hud = HUD.new(playerGui, player)
local effects = Effects.new(playerGui, player)
local shop = Shop.new(playerGui, player, remotes)
local playerList = PlayerList.new(playerGui, player, remotes)
local input = InputController.new(player, remotes, {
	shop = shop,
	playerList = playerList,
	effects = effects,
})

local currentProfile = nil
local currentState = nil
local roundRole = nil

local function applyProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	currentProfile = profile
	hud:setProfile(profile)
	shop:setProfile(profile)
end

remotes.ProfileUpdated.OnClientEvent:Connect(applyProfile)

remotes.UIState.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end
	currentState = state
	hud:updateState(state)
	input:setPhase(state.phase)

	if state.phase ~= "Lobby" then
		shop:close()
	end
	if state.phase == "Starting" then
		playerList:close()
	end
end)

remotes.RoundEvent.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end

	if event.type == "Start" then
		roundRole = event.role
		playerList:close()
		shop:close()
		input:setPhase("Round")
		hud:showRoundStart(event)
	elseif event.type == "Death" then
		input:stopSprint()
		hud:showDeath(event)
	elseif event.type == "End" then
		input:setPhase("Ending")
		hud:showRoundEnd(event)
	elseif event.type == "Abort" then
		input:setPhase("Lobby")
		hud:showAbort(event.reason)
	end
end)

remotes.Notification.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local text = payload.text or ""
	local tone = payload.tone or "info"
	hud:toast(text, tone)
	if shop:isOpen() then
		shop:notify(text, tone)
	end
end)

remotes.OpenShop.OnClientEvent:Connect(function()
	if currentState and currentState.phase ~= "Lobby" then
		return
	end
	shop:open()
end)

remotes.PlayerListData.OnClientEvent:Connect(function(data)
	playerList:setData(data)
end)

remotes.CombatFeedback.OnClientEvent:Connect(function(data)
	effects:combat(data)
end)

remotes.EmoteEvent.OnClientEvent:Connect(function(data)
	effects:emote(data)
end)

player.CharacterAdded:Connect(function()
	input:reset()
end)

UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.Escape and shop:isOpen() then
		shop:close()
	elseif inputObject.KeyCode == Enum.KeyCode.Escape and playerList:isOpen() then
		playerList:close()
	end
end)

task.wait(0.1)
remotes.ClientReady:FireServer()

-- Небольшая стартовая подсказка, если профиль уже пришёл.
task.delay(1, function()
	if currentProfile then
		hud:toast("Tab — список участников. E у Хранителя — магазин.", "info")
	end
end)

print("[Shattered Dimensions] Клиент готов. " .. Config.Brand.Name .. " v" .. Config.Brand.Version)
