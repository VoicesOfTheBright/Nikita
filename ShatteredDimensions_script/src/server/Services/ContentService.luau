--[[
	ContentService — единая точка поиска пользовательского контента из Studio.

	Структура папок в ServerStorage:

		ShatteredDimensions/
			Content/
				Maps/                — модели карт (Model)
				CharacterModels/     — костюмы/модели персонажей (Model)
				Abilities/           — ModuleScript'ы способностей

	Имена моделей/модулей, начинающиеся с "_", игнорируются.
	Папки создаются автоматически, если их нет.
]]

local ServerStorage = game:GetService("ServerStorage")

local ContentService = {}

local rootFolder
local contentFolder
local mapsFolder
local characterModelsFolder
local abilitiesFolder

local function ensureFolder(parent, className, name)
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

function ContentService.init()
	rootFolder = ensureFolder(ServerStorage, "Folder", "ShatteredDimensions")
	contentFolder = ensureFolder(rootFolder, "Folder", "Content")
	mapsFolder = ensureFolder(contentFolder, "Folder", "Maps")
	characterModelsFolder = ensureFolder(contentFolder, "Folder", "CharacterModels")
	abilitiesFolder = ensureFolder(contentFolder, "Folder", "Abilities")

	local mapCount = #ContentService.getMapTemplates()
	local modelCount = #ContentService.getAllCharacterModels()
	local abilityCount = #ContentService.getAbilityModules()
	print(string.format(
		"[Shattered Dimensions] Studio-контент: карт — %d, моделей персонажей — %d, пользовательских способностей — %d.",
		mapCount,
		modelCount,
		abilityCount
	))
end

function ContentService.getContentFolder()
	return contentFolder
end

function ContentService.getMapsFolder()
	return mapsFolder
end

function ContentService.getCharacterModelsFolder()
	return characterModelsFolder
end

function ContentService.getAbilitiesFolder()
	return abilitiesFolder
end

function ContentService.getMapTemplates()
	local result = {}
	if not mapsFolder then
		return result
	end
	for _, child in ipairs(mapsFolder:GetChildren()) do
		if child:IsA("Model")
			and string.sub(child.Name, 1, 1) ~= "_"
			and child:GetAttribute("Enabled") ~= false
		then
			table.insert(result, child)
		end
	end
	return result
end

function ContentService.getAllCharacterModels()
	local result = {}
	if not characterModelsFolder then
		return result
	end
	for _, child in ipairs(characterModelsFolder:GetChildren()) do
		if child:IsA("Model") and string.sub(child.Name, 1, 1) ~= "_" then
			table.insert(result, child)
		end
	end
	return result
end

function ContentService.findCharacterModel(skinId, characterId)
	if not characterModelsFolder then
		return nil
	end

	local function isUsableModel(model)
		return model ~= nil
			and model:IsA("Model")
			and string.sub(model.Name, 1, 1) ~= "_"
	end

	-- 1. Точное имя по скину — самый приоритетный вариант.
	if skinId then
		local direct = characterModelsFolder:FindFirstChild(skinId)
		if isUsableModel(direct) then
			return direct
		end
	end

	-- 2. Точное имя по персонажу.
	if characterId then
		local direct = characterModelsFolder:FindFirstChild(characterId)
		if isUsableModel(direct) then
			return direct
		end
	end

	-- 3. Атрибут SkinId — важнее общего CharacterId.
	if skinId then
		for _, model in ipairs(characterModelsFolder:GetChildren()) do
			if isUsableModel(model) and model:GetAttribute("SkinId") == skinId then
				return model
			end
		end
	end

	-- 4. Атрибут CharacterId.
	if characterId then
		for _, model in ipairs(characterModelsFolder:GetChildren()) do
			if isUsableModel(model) and model:GetAttribute("CharacterId") == characterId then
				return model
			end
		end
	end

	return nil
end

function ContentService.getAbilityModules()
	local result = {}
	if not abilitiesFolder then
		return result
	end

	for _, descendant in ipairs(abilitiesFolder:GetDescendants()) do
		if descendant:IsA("ModuleScript") and string.sub(descendant.Name, 1, 1) ~= "_" then
			table.insert(result, descendant)
		end
	end
	return result
end

return ContentService
