local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local ContentService = require(script.Parent:WaitForChild("ContentService"))

local AbilityService = {}

local remotesFolder
local sprintRemote
local toggleRemote
local aimRemote
local primaryRemote
local emoteRemote
local combatRemote
local emoteRemoteOut
local notificationRemote

local sprintInput = {}
local sprinting = {}
local sprintLocked = {}
local stamina = {}
local lastDrain = {}
local lastAttributeUpdate = {}
local lastEmoteUse = {}
local flashlights = {}
local flashlightSerial = {}

local abilityDefs = {}
local currentAbility = {}
local abilityStates = {}
local abilityDeathNotified = {}
local lastAbilityUse = {}

local function getRole(player)
	return player:GetAttribute("GameRole")
end

local function isInRound(player)
	return player:GetAttribute("InRound") == true
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function setSprintState(player, state, humanoid, role)
	local userId = player.UserId
	local wasSprinting = sprinting[userId] == true
	sprinting[userId] = state

	if humanoid then
		local baseSpeed = Config.Movement.BaseWalkSpeed[role] or 16
		humanoid.WalkSpeed = if state then baseSpeed * Config.Movement.SprintMultiplier else baseSpeed
	end

	if wasSprinting ~= state then
		player:SetAttribute("Sprinting", state)
	end
end

local function stopFlashlight(player)
	local userId = player.UserId
	local state = flashlights[userId]
	if not state then
		player:SetAttribute("FlashlightOn", false)
		return
	end

	if state.part then
		state.part:Destroy()
	end
	if state.prop then
		state.prop:Destroy()
	end
	flashlights[userId] = nil
	player:SetAttribute("FlashlightOn", false)
end

local function findHand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function makeFlashlightProp(character)
	local hand = findHand(character)
	if not hand then
		return nil
	end

	local existing = character:FindFirstChild("SD_FlashlightProp")
	if existing then
		existing:Destroy()
	end

	local prop = Instance.new("Model")
	prop.Name = "SD_FlashlightProp"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.35, 0.35, 0.85)
	body.Color = Color3.fromRGB(43, 46, 53)
	body.Material = Enum.Material.Metal
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = hand.CFrame * CFrame.new(0, -0.55, -0.35)
	body.Parent = prop

	local lens = Instance.new("Part")
	lens.Name = "Lens"
	lens.Size = Vector3.new(0.31, 0.31, 0.12)
	lens.Color = Color3.fromRGB(255, 246, 214)
	lens.Material = Enum.Material.Neon
	lens.CanCollide = false
	lens.CanQuery = false
	lens.CanTouch = false
	lens.Massless = true
	lens.CFrame = body.CFrame * CFrame.new(0, 0, -0.48)
	lens.Parent = prop

	prop.PrimaryPart = body
	prop.Parent = character

	local bodyWeld = Instance.new("WeldConstraint")
	bodyWeld.Part0 = hand
	bodyWeld.Part1 = body
	bodyWeld.Parent = body

	local lensWeld = Instance.new("WeldConstraint")
	lensWeld.Part0 = body
	lensWeld.Part1 = lens
	lensWeld.Parent = lens

	return prop
end

local function startFlashlight(player)
	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		return
	end

	local userId = player.UserId
	stopFlashlight(player)

	local lightPart = Instance.new("Part")
	lightPart.Name = "SD_FlashlightBeam"
	lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lightPart.Transparency = 1
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.Parent = Workspace

	local spot = Instance.new("SpotLight")
	spot.Name = "Beam"
	spot.Face = Enum.NormalId.Front
	spot.Angle = Config.Flashlight.Angle
	spot.Brightness = Config.Flashlight.Brightness
	spot.Range = Config.Flashlight.Range
	spot.Color = Config.Flashlight.Color
	spot.Shadows = true
	spot.Parent = lightPart

	local direction = root.CFrame.LookVector
	lightPart.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.4, 0), root.Position + Vector3.new(0, 1.4, 0) + direction)

	flashlightSerial[userId] = (flashlightSerial[userId] or 0) + 1
	flashlights[userId] = {
		part = lightPart,
		spot = spot,
		direction = direction,
		prop = makeFlashlightProp(character),
		serial = flashlightSerial[userId],
	}

	player:SetAttribute("FlashlightOn", true)
end

local function updateFlashlight(player, direction)
	local state = flashlights[player.UserId]
	if not state or not state.part then
		return
	end

	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		stopFlashlight(player)
		return
	end

	if Util.isFiniteVector3(direction) and direction.Magnitude > 0.01 then
		state.direction = direction.Unit
	end

	local head = character:FindFirstChild("Head")
	local origin = (head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))) + state.direction * 0.65
	state.part.CFrame = CFrame.lookAt(origin, origin + state.direction * 20)
end

local function raycastClear(origin, targetPosition, ignoreA, ignoreB)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignoreA, ignoreB }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, targetPosition - origin, params)
	return result == nil
end

local function performKnifeAttack(player, aim)
	if Workspace:GetAttribute("GamePhase") ~= "Round" then
		return
	end
	if not isInRound(player) or player:GetAttribute("IsDead") == true then
		return
	end

	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		return
	end

	local attackerRole = getRole(player)
	local targetRole = if attackerRole == Config.Roles.LostSoul
		then Config.Roles.Savior
		else Config.Roles.LostSoul

	if not Util.isFiniteVector3(aim) or aim.Magnitude < 0.01 then
		aim = root.CFrame.LookVector
	else
		aim = aim.Unit
	end

	local origin = root.Position + Vector3.new(0, 1, 0)
	combatRemote:FireAllClients({
		type = "KnifeSwing",
		userId = player.UserId,
		origin = origin,
		direction = aim,
	})

	local coneCos = math.cos(math.rad(Config.Combat.Knife.ConeDegrees / 2))
	local bestTarget = nil
	local bestDistance = math.huge

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player
			and otherPlayer:GetAttribute("GameRole") == targetRole
			and otherPlayer:GetAttribute("InRound") == true
			and otherPlayer:GetAttribute("IsDead") ~= true
		then
			local targetCharacter, targetHumanoid, targetRoot = getCharacterParts(otherPlayer)
			if targetCharacter and targetHumanoid and targetRoot then
				local targetPosition = targetRoot.Position + Vector3.new(0, 0.6, 0)
				local offset = targetPosition - origin
				local distance = offset.Magnitude
				if distance <= Config.Combat.Knife.Range and distance > 0.001 then
					local directionToTarget = offset.Unit
					if aim:Dot(directionToTarget) >= coneCos then
						if distance < bestDistance and raycastClear(origin, targetPosition, character, targetCharacter) then
							bestTarget = otherPlayer
							bestDistance = distance
						end
					end
				end
			end
		end
	end

	if bestTarget then
		local targetCharacter, targetHumanoid, targetRoot = getCharacterParts(bestTarget)
		if targetCharacter and targetHumanoid and targetRoot then
			local wasAlive = targetHumanoid.Health > 0
			targetHumanoid:TakeDamage(Config.Combat.Knife.Damage)
			combatRemote:FireAllClients({
				type = "KnifeHit",
				attackerId = player.UserId,
				victimId = bestTarget.UserId,
				position = targetRoot.Position,
			})

			if wasAlive and targetHumanoid.Health <= 0 then
				local profile = DataService.get(player)
				if profile then
					profile.kills += 1
					DataService.markDirty(player)
				end
			end
		end
	end
end

local function getSelectedCharacterConfig(player, role)
	local profile = DataService.get(player)
	if profile then
		local characterId = if role == Config.Roles.LostSoul
			then profile.selectedLostSoul
			else profile.selectedSavior
		local character = Config.getCharacter(characterId)
		if character then
			return character
		end
	end
	return Config.getCharacterForRole(role)
end

local function getSelectedSkinConfig(player, role)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local skinId = if role == Config.Roles.LostSoul
		then profile.selectedLostSoulSkin
		else profile.selectedSaviorSkin
	return Config.getSkin(skinId)
end

local function makeAbilityContext(player, def)
	local userId = player.UserId
	local state = abilityStates[userId]
	if not state then
		state = { cleanups = {} }
		abilityStates[userId] = state
	end
	if not state.cleanups then
		state.cleanups = {}
	end

	local character, humanoid, root = getCharacterParts(player)
	local role = getRole(player)

	local function getOpponents()
		local opponents = {}
		local opposingRole = if role == Config.Roles.LostSoul
			then Config.Roles.Savior
			else Config.Roles.LostSoul
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player
				and otherPlayer:GetAttribute("GameRole") == opposingRole
				and otherPlayer:GetAttribute("InRound") == true
				and otherPlayer:GetAttribute("IsDead") ~= true
			then
				local targetCharacter, targetHumanoid, targetRoot = getCharacterParts(otherPlayer)
				if targetCharacter and targetHumanoid and targetRoot then
					table.insert(opponents, {
						player = otherPlayer,
						character = targetCharacter,
						humanoid = targetHumanoid,
						root = targetRoot,
					})
				end
			end
		end
		return opponents
	end

	return {
		player = player,
		ability = def,
		role = role,
		state = state,
		character = character,
		humanoid = humanoid,
		root = root,
		getCharacterParts = function()
			return getCharacterParts(player)
		end,
		getCharacterConfig = function()
			return getSelectedCharacterConfig(player, getRole(player))
		end,
		getSkinConfig = function()
			return getSelectedSkinConfig(player, getRole(player))
		end,
		getOpponents = getOpponents,
		fireCombat = function(payload)
			combatRemote:FireAllClients(payload)
		end,
		notify = function(text, tone)
			if notificationRemote then
				notificationRemote:FireClient(player, {
					text = text,
					tone = tone or "info",
				})
			end
		end,
		setActive = function(value)
			player:SetAttribute("AbilityActive", value == true)
		end,
		setAimActive = function(value)
			player:SetAttribute("AbilityAimActive", value == true)
		end,
		raycastClear = raycastClear,
		addCleanup = function(callback)
			if type(callback) == "function" then
				table.insert(state.cleanups, callback)
			end
		end,
	}
end

local builtinAbilities = {
	flashlight = {
		Id = "flashlight",
		Name = "Луч надежды",
		ShortName = "ФОНАРИК",
		Description = "Направленный фонарик. Повторное нажатие выключает свет.",
		Trigger = "Key",
		Key = "F",
		Cooldown = 0,
		OnActivate = function(ctx)
			if flashlights[ctx.player.UserId] then
				stopFlashlight(ctx.player)
				ctx.setActive(false)
			else
				startFlashlight(ctx.player)
				ctx.setActive(flashlights[ctx.player.UserId] ~= nil)
			end
		end,
		OnAim = function(ctx, direction)
			updateFlashlight(ctx.player, direction)
		end,
		OnDeath = function(ctx)
			stopFlashlight(ctx.player)
			ctx.setActive(false)
		end,
		OnCleanup = function(ctx)
			stopFlashlight(ctx.player)
			ctx.setActive(false)
		end,
	},
	knife = {
		Id = "knife",
		Name = "Разрез пустоты",
		ShortName = "НОЖ",
		Description = "Удар ножом в направлении камеры.",
		Trigger = "Primary",
		Key = "ЛКМ",
		Cooldown = Config.Combat.Knife.Cooldown,
		OnPrimary = function(ctx, aim)
			performKnifeAttack(ctx.player, aim)
		end,
	},
}

for abilityId, definition in pairs(builtinAbilities) do
	abilityDefs[abilityId] = definition
end

local function normalizeAbilityDefinition(definition, module)
	if type(definition) ~= "table" then
		warn("[Shattered Dimensions] Способность " .. module:GetFullName() .. " должна вернуть таблицу.")
		return nil
	end

	local id = tostring(definition.Id or module.Name)
	if id == "" then
		warn("[Shattered Dimensions] У способности " .. module:GetFullName() .. " пустой Id.")
		return nil
	end

	local trigger = definition.Trigger or "Key"
	if trigger ~= "Key" and trigger ~= "Primary" then
		warn("[Shattered Dimensions] Способность «" .. id .. "»: Trigger должен быть Key или Primary.")
		return nil
	end

	local function optionalCallback(value, name)
		if value == nil then
			return nil
		end
		if type(value) ~= "function" then
			warn("[Shattered Dimensions] Способность «" .. id .. "»: " .. name .. " должен быть функцией.")
			return nil
		end
		return value
	end

	local key = tostring(definition.Key or (trigger == "Primary" and "ЛКМ" or "F"))
	if trigger == "Key" then
		key = string.upper(key)
		if #key ~= 1 and key ~= "SPACE" then
			warn("[Shattered Dimensions] Способность «" .. id .. "»: Key должен быть одной клавишей (например, F или Q).")
		end
		if key == "SPACE" then
			key = "Space"
		end
	end

	return {
		Id = id,
		Name = tostring(definition.Name or id),
		ShortName = tostring(definition.ShortName or definition.Name or id),
		Description = tostring(definition.Description or ""),
		Trigger = trigger,
		Key = key,
		Cooldown = math.max(0, tonumber(definition.Cooldown) or 0),
		OnEquip = optionalCallback(definition.OnEquip, "OnEquip"),
		OnActivate = optionalCallback(definition.OnActivate, "OnActivate"),
		OnPrimary = optionalCallback(definition.OnPrimary, "OnPrimary"),
		OnAim = optionalCallback(definition.OnAim, "OnAim"),
		OnDeath = optionalCallback(definition.OnDeath, "OnDeath"),
		OnCleanup = optionalCallback(definition.OnCleanup, "OnCleanup"),
		Source = module:GetFullName(),
	}
end

local function loadCustomAbilityDefinitions()
	if Config.Content.UseCustomAbilities == false then
		return
	end

	for _, module in ipairs(ContentService.getAbilityModules()) do
		local ok, definition = pcall(require, module)
		if not ok then
			warn("[Shattered Dimensions] Ошибка загрузки способности " .. module:GetFullName() .. ": " .. tostring(definition))
		else
			local normalized = normalizeAbilityDefinition(definition, module)
			if normalized then
				if abilityDefs[normalized.Id] then
					warn("[Shattered Dimensions] Способность «" .. normalized.Id .. "» переопределена из " .. normalized.Source)
				end
				abilityDefs[normalized.Id] = normalized
				print("[Shattered Dimensions] Загружена способность: " .. normalized.Id)
			end
		end
	end
end

local function canUseSelectedEmote(player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local emotion = Config.getEmotion(profile.selectedEmotion)
	if not emotion then
		return nil
	end
	if emotion.price > 0 and not Util.tableFind(profile.ownedEmotions, emotion.id) then
		return nil
	end
	return emotion
end

local function useEmote(player)
	local role = getRole(player)
	if role == Config.Roles.LostSoul then
		return
	end

	if role == Config.Roles.Savior and not isInRound(player) then
		return
	end
	if player:GetAttribute("IsDead") == true then
		return
	end

	local now = os.clock()
	if now - (lastEmoteUse[player.UserId] or 0) < 3 then
		return
	end

	local emotion = canUseSelectedEmote(player)
	if not emotion then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	lastEmoteUse[player.UserId] = now
	emoteRemoteOut:FireAllClients({
		userId = player.UserId,
		emoteId = emotion.id,
	})
end

local function onSprintInput(player, wanted)
	if typeof(wanted) ~= "boolean" then
		return
	end

	local role = getRole(player)
	if not isInRound(player) or (role ~= Config.Roles.Savior and role ~= Config.Roles.LostSoul) then
		sprintInput[player.UserId] = false
		return
	end

	sprintInput[player.UserId] = wanted
	if not wanted then
		sprintLocked[player.UserId] = false
		local _, humanoid = getCharacterParts(player)
		if humanoid then
			setSprintState(player, false, humanoid, role)
		end
	end
end

local function isAbilityUsable(player)
	return Workspace:GetAttribute("GamePhase") == "Round"
		and isInRound(player)
		and player:GetAttribute("IsDead") ~= true
end

local function cooldownReady(player, def)
	local lastUse = lastAbilityUse[player.UserId] or 0
	return os.clock() - lastUse >= (def.Cooldown or 0)
end

local function markAbilityUse(player)
	lastAbilityUse[player.UserId] = os.clock()
end

local function onToggleAbility(player, requestedAbilityId)
	if type(requestedAbilityId) ~= "string" then
		return
	end

	local def = currentAbility[player.UserId]
	if not def or def.Id ~= requestedAbilityId or def.Trigger ~= "Key" then
		return
	end
	if not isAbilityUsable(player) or not cooldownReady(player, def) then
		return
	end
	if type(def.OnActivate) ~= "function" then
		return
	end

	markAbilityUse(player)
	local ok, err = pcall(def.OnActivate, makeAbilityContext(player, def))
	if not ok then
		warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnActivate): " .. tostring(err))
	end
end

local function onPrimaryAbility(player, aim)
	local def = currentAbility[player.UserId]
	if not def or def.Trigger ~= "Primary" then
		return
	end
	if not isAbilityUsable(player) or not cooldownReady(player, def) then
		return
	end
	if type(def.OnPrimary) ~= "function" then
		return
	end

	markAbilityUse(player)
	local ok, err = pcall(def.OnPrimary, makeAbilityContext(player, def), aim)
	if not ok then
		warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnPrimary): " .. tostring(err))
	end
end

local function onAimUpdate(player, direction)
	local def = currentAbility[player.UserId]
	if not isAbilityUsable(player) or not def or type(def.OnAim) ~= "function" or not Util.isFiniteVector3(direction) then
		return
	end
	local ok, err = pcall(def.OnAim, makeAbilityContext(player, def), direction)
	if not ok then
		warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnAim): " .. tostring(err))
	end
end

local function cleanupCurrentAbility(player)
	local userId = player.UserId
	local def = currentAbility[userId]
	local state = abilityStates[userId]

	if def and state then
		if type(def.OnCleanup) == "function" then
			local ok, err = pcall(def.OnCleanup, makeAbilityContext(player, def))
			if not ok then
				warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnCleanup): " .. tostring(err))
			end
		end

		if type(state.cleanups) == "table" then
			for _, callback in ipairs(state.cleanups) do
				local ok, err = pcall(callback)
				if not ok then
					warn("[Shattered Dimensions] Ошибка cleanup способности «" .. def.Id .. "»: " .. tostring(err))
				end
			end
		end
	end

	stopFlashlight(player)
	currentAbility[userId] = nil
	abilityStates[userId] = nil
	abilityDeathNotified[userId] = nil
	lastAbilityUse[userId] = 0

	player:SetAttribute("AbilityId", nil)
	player:SetAttribute("AbilityName", nil)
	player:SetAttribute("AbilityShortName", nil)
	player:SetAttribute("AbilityKey", nil)
	player:SetAttribute("AbilityTrigger", nil)
	player:SetAttribute("AbilityActive", false)
	player:SetAttribute("AbilityAimActive", false)
end

local function updateStaminaAttributes(player, immediate)
	local maxStamina = Config.Stamina.Max[getRole(player)] or 100
	local value = Util.round(stamina[player.UserId] or maxStamina, 1)
	player:SetAttribute("MaxStamina", maxStamina)
	player:SetAttribute("Stamina", value)
	player:SetAttribute("Sprinting", sprinting[player.UserId] == true)
	lastAttributeUpdate[player.UserId] = os.clock()
end

function AbilityService.init()
	remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")
	sprintRemote = remotesFolder:WaitForChild("SprintInput")
	toggleRemote = remotesFolder:WaitForChild("ToggleAbility")
	aimRemote = remotesFolder:WaitForChild("AimUpdate")
	primaryRemote = remotesFolder:WaitForChild("PrimaryAction")
	emoteRemote = remotesFolder:WaitForChild("UseEmote")
	combatRemote = remotesFolder:WaitForChild("CombatFeedback")
	emoteRemoteOut = remotesFolder:WaitForChild("EmoteEvent")
	notificationRemote = remotesFolder:WaitForChild("Notification")

	loadCustomAbilityDefinitions()

	sprintRemote.OnServerEvent:Connect(function(player, wanted)
		onSprintInput(player, wanted)
	end)

	toggleRemote.OnServerEvent:Connect(function(player, ability)
		onToggleAbility(player, ability)
	end)

	aimRemote.OnServerEvent:Connect(function(player, direction)
		onAimUpdate(player, direction)
	end)

	primaryRemote.OnServerEvent:Connect(function(player, aim)
		onPrimaryAbility(player, aim)
	end)

	emoteRemote.OnServerEvent:Connect(function(player)
		useEmote(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		AbilityService.cleanupPlayer(player)
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		local dt = math.min(deltaTime, 0.2)
		local now = os.clock()

		for _, player in ipairs(Players:GetPlayers()) do
			local userId = player.UserId
			local role = getRole(player)
			local inRound = isInRound(player)
			local state = flashlights[userId]

			if state then
				local def = currentAbility[userId]
				if not inRound or player:GetAttribute("IsDead") == true or not def or def.Id ~= "flashlight" then
					stopFlashlight(player)
					player:SetAttribute("AbilityActive", false)
				else
					updateFlashlight(player)
				end
			end

			if not inRound or (role ~= Config.Roles.Savior and role ~= Config.Roles.LostSoul) then
				if sprinting[userId] then
					sprinting[userId] = false
					player:SetAttribute("Sprinting", false)
				end
				continue
			end

			local character, humanoid, root = getCharacterParts(player)
			if not character or not humanoid or not root or player:GetAttribute("IsDead") == true then
				if sprinting[userId] then
					setSprintState(player, false, humanoid, role)
				end
				continue
			end

			if stamina[userId] == nil then
				stamina[userId] = Config.Stamina.Max[role] or 100
				lastDrain[userId] = 0
			end

			local currentStamina = stamina[userId]
			local moving = humanoid.MoveDirection.Magnitude > 0.08
			local wantsSprint = sprintInput[userId] == true and not sprintLocked[userId]

			if sprinting[userId] then
				if not wantsSprint or currentStamina <= 0 or not moving then
					setSprintState(player, false, humanoid, role)
				else
					currentStamina -= Config.Stamina.DrainPerSecond * dt
					if currentStamina <= 0 then
						currentStamina = 0
						lastDrain[userId] = now
						sprintLocked[userId] = true
						setSprintState(player, false, humanoid, role)
					else
						lastDrain[userId] = now
					end
					stamina[userId] = currentStamina
				end
			else
				if wantsSprint and moving and currentStamina >= Config.Stamina.MinToStartSprint then
					setSprintState(player, true, humanoid, role)
					lastDrain[userId] = now
				elseif now - (lastDrain[userId] or 0) >= Config.Stamina.RegenDelay then
					local maxStamina = Config.Stamina.Max[role] or 100
					currentStamina = math.min(maxStamina, currentStamina + Config.Stamina.RegenPerSecond * dt)
					stamina[userId] = currentStamina
				end
			end

			if now - (lastAttributeUpdate[userId] or 0) >= Config.Stamina.UpdateInterval then
				updateStaminaAttributes(player)
			end
		end
	end)
end

function AbilityService.setupForRound(player, role)
	cleanupCurrentAbility(player)

	local maxStamina = Config.Stamina.Max[role] or 100
	local userId = player.UserId
	stamina[userId] = maxStamina
	sprintInput[userId] = false
	sprinting[userId] = false
	sprintLocked[userId] = false
	lastDrain[userId] = 0
	lastEmoteUse[userId] = 0
	lastAbilityUse[userId] = 0
	abilityDeathNotified[userId] = false
	stopFlashlight(player)
	updateStaminaAttributes(player, true)

	local _, humanoid = getCharacterParts(player)
	if humanoid then
		humanoid.WalkSpeed = Config.Movement.BaseWalkSpeed[role] or 16
	end

	local characterConfig = getSelectedCharacterConfig(player, role)
	local fallbackId = Config.Content.AbilityFallbackByRole[role]
	local requestedId = characterConfig and characterConfig.abilityId or fallbackId
	local def = abilityDefs[requestedId] or abilityDefs[fallbackId]

	if not def then
		warn("[Shattered Dimensions] Не найдена способность «" .. tostring(requestedId) .. "» и fallback для роли " .. tostring(role) .. ".")
		player:SetAttribute("AbilityId", nil)
		player:SetAttribute("AbilityName", nil)
		player:SetAttribute("AbilityShortName", nil)
		player:SetAttribute("AbilityKey", nil)
		player:SetAttribute("AbilityTrigger", nil)
		return
	end

	if requestedId ~= def.Id then
		warn("[Shattered Dimensions] Способность «" .. tostring(requestedId) .. "» не найдена. Использую «" .. def.Id .. "».")
	end

	currentAbility[userId] = def
	abilityStates[userId] = { cleanups = {} }

	player:SetAttribute("AbilityId", def.Id)
	player:SetAttribute("AbilityName", def.Name)
	player:SetAttribute("AbilityShortName", def.ShortName)
	player:SetAttribute("AbilityKey", def.Key)
	player:SetAttribute("AbilityTrigger", def.Trigger)
	player:SetAttribute("AbilityActive", false)
	player:SetAttribute("AbilityAimActive", false)

	if type(def.OnEquip) == "function" then
		local ok, err = pcall(def.OnEquip, makeAbilityContext(player, def))
		if not ok then
			warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnEquip): " .. tostring(err))
		end
	end
end

function AbilityService.resetPlayer(player)
	local userId = player.UserId
	cleanupCurrentAbility(player)

	sprintInput[userId] = false
	sprinting[userId] = false
	sprintLocked[userId] = false
	lastEmoteUse[userId] = 0
	stamina[userId] = Config.Stamina.Max[Config.Roles.Savior] or 100
	lastDrain[userId] = 0
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("MaxStamina", 100)

	local _, humanoid = getCharacterParts(player)
	if humanoid then
		humanoid.WalkSpeed = Config.Movement.BaseWalkSpeed[Config.Roles.Savior]
	end
end

function AbilityService.onPlayerDied(player)
	sprintInput[player.UserId] = false
	sprinting[player.UserId] = false
	player:SetAttribute("Sprinting", false)
	stopFlashlight(player)
	player:SetAttribute("AbilityActive", false)

	local userId = player.UserId
	local def = currentAbility[userId]
	if def and type(def.OnDeath) == "function" and not abilityDeathNotified[userId] then
		abilityDeathNotified[userId] = true
		local ok, err = pcall(def.OnDeath, makeAbilityContext(player, def))
		if not ok then
			warn("[Shattered Dimensions] Ошибка способности «" .. def.Id .. "» (OnDeath): " .. tostring(err))
		end
	end

	-- Если раунд закончился, живой персонаж не должен оставаться
	-- на скорости бега после сброса состояния.
	local _, humanoid = getCharacterParts(player)
	if humanoid then
		local role = getRole(player)
		humanoid.WalkSpeed = Config.Movement.BaseWalkSpeed[role] or Config.Movement.BaseWalkSpeed[Config.Roles.Savior]
	end
end

function AbilityService.cleanupPlayer(player)
	cleanupCurrentAbility(player)
	sprintInput[player.UserId] = nil
	sprinting[player.UserId] = nil
	sprintLocked[player.UserId] = nil
	stamina[player.UserId] = nil
	lastDrain[player.UserId] = nil
	lastAttributeUpdate[player.UserId] = nil
	lastEmoteUse[player.UserId] = nil
	lastAbilityUse[player.UserId] = nil
	flashlightSerial[player.UserId] = nil
end

return AbilityService
