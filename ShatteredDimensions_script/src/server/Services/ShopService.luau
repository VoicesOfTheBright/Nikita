local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local ShopService = {}

local remotesFolder
local profileRemote
local shopActionRemote
local notificationRemote

local function notify(player, text, tone)
	notificationRemote:FireClient(player, {
		text = text,
		tone = tone or "info",
	})
end

local function isOwned(profile, kind, item)
	if not item then
		return false
	end
	if item.price == 0 then
		return true
	end

	local collection = if kind == "Skin" then profile.ownedSkins else profile.ownedEmotions
	return Util.tableFind(collection, item.id) ~= nil
end

local function pushProfile(player)
	local public = DataService.getPublicProfile(player)
	if public then
		profileRemote:FireClient(player, public)
	end
end

local function purchase(player, profile, itemType, itemId)
	if itemType == "Savior" or itemType == "LostSoul" then
		notify(player, "Персонажи открыты по умолчанию — их можно просто выбрать.", "info")
		return
	end

	local item
	local ownedCollection
	if itemType == "Skin" then
		item = Config.getSkin(itemId)
		ownedCollection = profile.ownedSkins
	elseif itemType == "Emotion" then
		item = Config.getEmotion(itemId)
		ownedCollection = profile.ownedEmotions
	else
		notify(player, "Неизвестный товар.", "warning")
		return
	end

	if not item then
		notify(player, "Товар не найден.", "warning")
		return
	end
	if isOwned(profile, itemType, item) then
		notify(player, "Этот товар уже открыт.", "info")
		return
	end
	if profile.echoes < item.price then
		notify(player, "Недостаточно эха. Нужно: " .. Util.formatNumber(item.price) .. ".", "warning")
		return
	end

	profile.echoes -= item.price
	table.insert(ownedCollection, item.id)
	DataService.markDirty(player)

	-- Купленное сразу надеваем.
	if itemType == "Skin" then
		if item.role == Config.Roles.Savior then
			profile.selectedSaviorSkin = item.id
			profile.selectedSavior = item.characterId
		else
			profile.selectedLostSoulSkin = item.id
			profile.selectedLostSoul = item.characterId
		end
		CharacterService.refreshLobbyAppearance(player)
	else
		profile.selectedEmotion = item.id
	end

	notify(player, "«" .. item.name .. "» открыто и выбрано.", "success")
	pushProfile(player)
end

local function equip(player, profile, itemType, itemId)
	if itemType == "Savior" then
		local character = Config.getCharacter(itemId)
		if not character or character.role ~= Config.Roles.Savior then
			notify(player, "Неизвестный выживший.", "warning")
			return
		end
		profile.selectedSavior = character.id
		CharacterService.refreshLobbyAppearance(player)
		notify(player, "Выживший: " .. character.name, "success")
	elseif itemType == "LostSoul" then
		local character = Config.getCharacter(itemId)
		if not character or character.role ~= Config.Roles.LostSoul then
			notify(player, "Неизвестная потерянная душа.", "warning")
			return
		end
		profile.selectedLostSoul = character.id
		notify(player, "Потерянная душа: " .. character.name, "success")
	elseif itemType == "Skin" then
		local skin = Config.getSkin(itemId)
		if not skin then
			notify(player, "Скин не найден.", "warning")
			return
		end
		if not isOwned(profile, "Skin", skin) then
			notify(player, "Сначала купите этот скин.", "warning")
			return
		end
		if skin.role == Config.Roles.Savior then
			profile.selectedSaviorSkin = skin.id
			profile.selectedSavior = skin.characterId
			CharacterService.refreshLobbyAppearance(player)
		else
			profile.selectedLostSoulSkin = skin.id
			profile.selectedLostSoul = skin.characterId
		end
		notify(player, "Скин «" .. skin.name .. "» надет.", "success")
	elseif itemType == "Emotion" then
		local emotion = Config.getEmotion(itemId)
		if not emotion then
			notify(player, "Эмоция не найдена.", "warning")
			return
		end
		if not isOwned(profile, "Emotion", emotion) then
			notify(player, "Сначала купите эту эмоцию.", "warning")
			return
		end
		profile.selectedEmotion = emotion.id
		notify(player, "Эмоция «" .. emotion.name .. "» выбрана.", "success")
	else
		notify(player, "Неизвестное действие магазина.", "warning")
		return
	end

	DataService.markDirty(player)
	pushProfile(player)
end

function ShopService.init()
	remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")
	profileRemote = remotesFolder:WaitForChild("ProfileUpdated")
	shopActionRemote = remotesFolder:WaitForChild("ShopAction")
	notificationRemote = remotesFolder:WaitForChild("Notification")

	shopActionRemote.OnServerEvent:Connect(function(player, action, itemType, itemId)
		if type(action) ~= "string" or type(itemType) ~= "string" or type(itemId) ~= "string" then
			return
		end
		if Workspace:GetAttribute("GamePhase") ~= "Lobby" then
			notify(player, "Магазин доступен только в лобби.", "warning")
			return
		end
		if #itemId > 64 then
			return
		end

		local profile = DataService.get(player)
		if not profile then
			notify(player, "Профиль ещё загружается.", "warning")
			return
		end

		if action == "Purchase" then
			purchase(player, profile, itemType, itemId)
		elseif action == "Equip" then
			equip(player, profile, itemType, itemId)
		end
	end)
end

function ShopService.sendProfile(player)
	pushProfile(player)
end

function ShopService.notify(player, text, tone)
	notify(player, text, tone)
end

return ShopService
