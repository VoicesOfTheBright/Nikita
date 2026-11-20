local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local ContentService = require(script.Parent:WaitForChild("ContentService"))
local MapService = require(script.Parent:WaitForChild("MapService"))

local CharacterService = {}

local deathCallback = nil
local spawnSerial = {}
local CUSTOM_MODEL_NAME = "__SD_CustomModel"

local BODY_PART_NAMES = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local function findHand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function restoreAvatarAppearance(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and BODY_PART_NAMES[child.Name] then
			child.Transparency = 0
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 0
			end
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Decal") then
			descendant.Transparency = 0
		elseif descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 0
			end
		end
	end
end

local function clearVisuals(character)
	if character:FindFirstChild(CUSTOM_MODEL_NAME) then
		restoreAvatarAppearance(character)
	end
	for _, name in ipairs({ "__SD_SkinHighlight", "__SD_SkinAura", "__SD_RoleTag", "SD_KnifeProp", "SD_FlashlightProp", CUSTOM_MODEL_NAME }) do
		local existing = character:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

local function loadCharacter(player)
	local existing = player.Character
	local addedCharacter = nil

	local connection = player.CharacterAdded:Connect(function(character)
		addedCharacter = character
	end)

	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn("[Shattered Dimensions] LoadCharacter " .. player.Name .. ": " .. tostring(err))
	end

	if not addedCharacter and player.Character and player.Character ~= existing then
		addedCharacter = player.Character
	end

	for _ = 1, 100 do
		if addedCharacter then
			break
		end
		task.wait(0.05)
	end
	connection:Disconnect()

	if not addedCharacter then
		return nil, nil
	end

	local humanoid = addedCharacter:WaitForChild("Humanoid", 8)
	local root = addedCharacter:WaitForChild("HumanoidRootPart", 8)
	if not humanoid or not root then
		return nil, nil
	end

	return addedCharacter, humanoid
end

local function applyBodyTint(character, tint)
	if not tint then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and BODY_PART_NAMES[descendant.Name] then
			descendant.Color = tint
		end
	end
end

local function makeHighlight(character, accent, subtle)
	local highlight = Instance.new("Highlight")
	highlight.Name = "__SD_SkinHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = accent
	highlight.FillTransparency = 1
	highlight.OutlineColor = accent
	highlight.OutlineTransparency = subtle and 0.72 or 0.38
	highlight.Parent = character
	return highlight
end

local function makeAura(character, accent)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "__SD_SkinAura"
	aura.Color = ColorSequence.new(accent)
	aura.LightEmission = 0.7
	aura.LightInfluence = 0
	aura.Rate = 3.5
	aura.Lifetime = NumberRange.new(0.7, 1.2)
	aura.Speed = NumberRange.new(0.2, 0.7)
	aura.SpreadAngle = Vector2.new(25, 25)
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.Parent = root
end

local function addRoleTag(player, character, role, characterName)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local meta = Config.RoleMeta[role] or Config.RoleMeta.Lobby
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "__SD_RoleTag"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = false
	billboard.MaxDistance = 55
	billboard.Size = UDim2.fromOffset(210, 36)
	billboard.StudsOffset = Vector3.new(0, 2.3, 0)
	billboard.Parent = head

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = meta.color
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = frame

	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = meta.color
	badge.BorderSizePixel = 0
	badge.Size = UDim2.new(0, 4, 1, 0)
	badge.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 0)
	label.Size = UDim2.new(1, -18, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(meta.name) .. "  //  " .. string.upper(characterName)
	label.TextColor3 = Color3.fromRGB(236, 240, 246)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = frame

	badge.Name = "Badge"
end

local function addKnife(character)
	local hand = findHand(character)
	if not hand then
		return
	end

	local prop = Instance.new("Model")
	prop.Name = "SD_KnifeProp"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 0.7, 0.22)
	handle.Color = Color3.fromRGB(40, 35, 33)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = hand.CFrame * CFrame.new(0, -0.45, -0.25)
	handle.Parent = prop

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.08, 1.45, 0.28)
	blade.Color = Color3.fromRGB(196, 202, 212)
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, -1.0, 0)
	blade.Parent = prop

	prop.PrimaryPart = handle
	prop.Parent = character

	local handleWeld = Instance.new("WeldConstraint")
	handleWeld.Part0 = hand
	handleWeld.Part1 = handle
	handleWeld.Parent = handle

	local bladeWeld = Instance.new("WeldConstraint")
	bladeWeld.Part0 = handle
	bladeWeld.Part1 = blade
	bladeWeld.Parent = blade
end

local AVATAR_PART_ALIASES = {
	Head = { "Head" },
	Torso = { "UpperTorso", "Torso" },
	UpperTorso = { "UpperTorso", "Torso" },
	LowerTorso = { "LowerTorso", "Torso" },
	["Left Arm"] = { "LeftUpperArm", "Left Arm" },
	["Right Arm"] = { "RightUpperArm", "Right Arm" },
	["Left Leg"] = { "LeftUpperLeg", "Left Leg" },
	["Right Leg"] = { "RightUpperLeg", "Right Leg" },
	LeftUpperArm = { "LeftUpperArm", "Left Arm" },
	LeftLowerArm = { "LeftLowerArm", "Left Arm" },
	LeftHand = { "LeftHand", "Left Arm" },
	RightUpperArm = { "RightUpperArm", "Right Arm" },
	RightLowerArm = { "RightLowerArm", "Right Arm" },
	RightHand = { "RightHand", "Right Arm" },
	LeftUpperLeg = { "LeftUpperLeg", "Left Leg" },
	LeftLowerLeg = { "LeftLowerLeg", "Left Leg" },
	LeftFoot = { "LeftFoot", "Left Leg" },
	RightUpperLeg = { "RightUpperLeg", "Right Leg" },
	RightLowerLeg = { "RightLowerLeg", "Right Leg" },
	RightFoot = { "RightFoot", "Right Leg" },
}

local function findAvatarPart(character, requestedName)
	local aliases = AVATAR_PART_ALIASES[requestedName] or { requestedName }
	for _, alias in ipairs(aliases) do
		local part = character:FindFirstChild(alias)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function hideAvatarAppearance(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and BODY_PART_NAMES[child.Name] then
			child.Transparency = 1
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
			end
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Decal") then
			descendant.Transparency = 1
		elseif descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
			end
		end
	end
end

--[[
	Костюм из Studio — это Model с частями. Каждая часть крепится к
	соответствующей части аватара по имени или по атрибуту AvatarPart.
	Так сохраняются стандартные анимации, управление и Humanoid игрока.
]]
local function applyCustomCostume(character, characterConfig, skin)
	if Config.Content.UseStudioCharacterModels == false then
		return false
	end

	local template = ContentService.findCharacterModel(
		skin and skin.id or nil,
		characterConfig and characterConfig.id or nil
	)
	if not template or not template:IsA("Model") then
		return false
	end

	local clone = template:Clone()
	if not clone then
		return false
	end

	local customHumanoid = clone:FindFirstChildOfClass("Humanoid")
	if customHumanoid then
		customHumanoid:Destroy()
	end

	clone.Name = CUSTOM_MODEL_NAME
	clone:PivotTo(character:GetPivot())

	local fallbackTorso = findAvatarPart(character, "UpperTorso") or findAvatarPart(character, "Torso")
	if not fallbackTorso then
		clone:Destroy()
		return false
	end

	local mappings = {}
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if string.lower(descendant.Name) == "humanoidrootpart" then
				descendant.Transparency = 1
			else
				local requested = descendant:GetAttribute("AvatarPart")
				if typeof(requested) ~= "string" then
					requested = descendant.Name
				end
				local target = findAvatarPart(character, requested) or fallbackTorso
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				table.insert(mappings, { part = descendant, target = target })
			end
		end
	end

	if #mappings == 0 then
		clone:Destroy()
		return false
	end

	hideAvatarAppearance(character)
	clone.Parent = character

	for _, mapping in ipairs(mappings) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mapping.target
		weld.Part1 = mapping.part
		weld.Parent = mapping.part
		mapping.part.Anchored = false
	end

	return true
end

local function applyAppearance(player, character, role, tagRole)
	clearVisuals(character)
	tagRole = tagRole or role

	local profile = DataService.get(player)
	local skin = nil
	if profile then
		local skinId = if role == Config.Roles.LostSoul
			then profile.selectedLostSoulSkin
			else profile.selectedSaviorSkin
		skin = Config.getSkin(skinId)
	end

	if not skin then
		skin = Config.getDefaultSkin(role) or Config.getDefaultSkin(Config.Roles.Savior)
	end

	if skin then
		applyBodyTint(character, skin.tint)
		makeHighlight(character, skin.accent, skin.price == 0)
		if skin.price > 0 then
			makeAura(character, skin.accent)
		end
	end

	local characterConfig = nil
	if profile then
		local characterId = if role == Config.Roles.LostSoul
			then profile.selectedLostSoul
			else profile.selectedSavior
		characterConfig = Config.getCharacter(characterId)
	end
	if not characterConfig then
		characterConfig = Config.getCharacterForRole(role) or Config.getCharacterForRole(Config.Roles.Savior)
	end

	applyCustomCostume(character, characterConfig, skin)

	addRoleTag(player, character, tagRole, characterConfig and characterConfig.name or "БЕЗЫМЯННЫЙ")

	if role == Config.Roles.LostSoul then
		addKnife(character)
	end
end

local function bindDeath(player, humanoid)
	humanoid.Died:Connect(function()
		if player:GetAttribute("InRound") ~= true then
			return
		end
		if player:GetAttribute("IsDead") == true then
			return
		end

		player:SetAttribute("IsDead", true)
		player:SetAttribute("Sprinting", false)
		if deathCallback then
			task.spawn(deathCallback, player)
		end
	end)
end

function CharacterService.init()
	Players.CharacterAutoLoads = false
end

function CharacterService.setDeathCallback(callback)
	deathCallback = callback
end

function CharacterService.spawnLobby(player)
	if not player.Parent then
		return nil
	end

	spawnSerial[player.UserId] = (spawnSerial[player.UserId] or 0) + 1
	local serial = spawnSerial[player.UserId]

	player:SetAttribute("SD_Loading", true)
	local character, humanoid = loadCharacter(player)
	if serial ~= spawnSerial[player.UserId] then
		return nil
	end
	player:SetAttribute("SD_Loading", false)
	if not character or not humanoid then
		return nil
	end

	character:PivotTo(MapService.getLobbySpawn())
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = Config.Movement.BaseWalkSpeed[Config.Roles.Savior]
	humanoid.JumpPower = 50

	player:SetAttribute("InRound", false)
	player:SetAttribute("IsDead", false)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("MaxStamina", 100)
	player:SetAttribute("Stamina", 100)
	if not player:GetAttribute("GameRole") then
		player:SetAttribute("GameRole", Config.Roles.Lobby)
	end

	local tagRole = if player:GetAttribute("GameRole") == Config.Roles.Spectator
		then Config.Roles.Spectator
		else Config.Roles.Lobby
	applyAppearance(player, character, Config.Roles.Savior, tagRole)
	bindDeath(player, humanoid)
	return character
end

function CharacterService.spawnForRound(player, role, spawnCFrame)
	if not player.Parent then
		return nil
	end

	spawnSerial[player.UserId] = (spawnSerial[player.UserId] or 0) + 1
	local serial = spawnSerial[player.UserId]

	player:SetAttribute("GameRole", role)
	player:SetAttribute("InRound", true)
	player:SetAttribute("IsDead", false)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("SD_Loading", true)

	local character, humanoid = loadCharacter(player)
	if serial ~= spawnSerial[player.UserId] then
		return nil
	end
	player:SetAttribute("SD_Loading", false)
	if not character or not humanoid then
		return nil
	end

	character:PivotTo(spawnCFrame)
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = Config.Movement.BaseWalkSpeed[role] or 16
	humanoid.JumpPower = 50

	local maxStamina = Config.Stamina.Max[role] or 100
	player:SetAttribute("MaxStamina", maxStamina)
	player:SetAttribute("Stamina", maxStamina)

	applyAppearance(player, character, role)
	bindDeath(player, humanoid)
	return character
end

function CharacterService.refreshLobbyAppearance(player)
	local character = player.Character
	if not character or player:GetAttribute("InRound") == true then
		return
	end

	local tagRole = if player:GetAttribute("GameRole") == Config.Roles.Spectator
		then Config.Roles.Spectator
		else Config.Roles.Lobby
	applyAppearance(player, character, Config.Roles.Savior, tagRole)
end

function CharacterService.getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function CharacterService.getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function CharacterService.isAlive(player)
	local humanoid = CharacterService.getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0 and player:GetAttribute("IsDead") ~= true
end

function CharacterService.getSelectedAppearance(player, role)
	local profile = DataService.get(player)
	if not profile then
		return nil, nil
	end

	if role == Config.Roles.LostSoul then
		return Config.getCharacter(profile.selectedLostSoul), Config.getSkin(profile.selectedLostSoulSkin)
	end
	return Config.getCharacter(profile.selectedSavior), Config.getSkin(profile.selectedSaviorSkin)
end

function CharacterService.cleanup(player)
	if not player then
		return
	end
	spawnSerial[player.UserId] = nil
end

return CharacterService
