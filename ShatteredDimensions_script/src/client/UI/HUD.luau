local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local UILib = require(script.Parent:WaitForChild("UILib"))

local HUD = {}
HUD.__index = HUD

local function addVignette(parent, fromTop)
	local frame = UILib.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 155),
		Position = if fromTop then UDim2.fromOffset(0, 0) else UDim2.new(0, 0, 1, -155),
		ZIndex = 1,
	}, parent)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = if fromTop then 90 else -90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	return frame
end

local function makeKeyHint(parent, layoutOrder)
	local label = UILib.label(parent, {
		Name = "Hint",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 18),
		Font = Theme.Fonts.Medium,
		TextSize = 11,
		TextColor3 = Theme.Colors.TextSoft,
		RichText = true,
		LayoutOrder = layoutOrder,
	})
	return label
end

function HUD.new(playerGui, player)
	local self = setmetatable({}, HUD)
	self.player = player
	self.profile = nil
	self.state = nil
	self.lastPhase = nil
	self.roundRole = nil
	self.bannerToken = 0
	self.toasts = {}
	self.hintLabels = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShatteredDimensions_HUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui
	self.gui = screenGui

	local root = UILib.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, screenGui)
	self.root = root

	addVignette(root, true)
	addVignette(root, false)

	-- Брендинг.
	local brand = UILib.new("Frame", {
		Name = "Brand",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.fromOffset(290, 62),
		ZIndex = 5,
	}, root)

	UILib.label(brand, {
		Text = "SHATTERED // DIMENSIONS",
		Font = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, 0, 0, 14),
	})
	UILib.label(brand, {
		Text = "РАЗБИТЫЕ ИЗМЕРЕНИЯ",
		Font = Theme.Fonts.Display,
		TextSize = 19,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 0, 25),
	})
	UILib.label(brand, {
		Text = "АСИММЕТРИЧНЫЙ ХОРРОР  //  " .. Config.Brand.Version,
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(0, 41),
		Size = UDim2.new(1, 0, 0, 14),
	})

	-- Центральная карточка фазы и таймера.
	local phaseFrame = UILib.new("Frame", {
		Name = "PhaseCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 17),
		Size = UDim2.fromOffset(408, 76),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, root)
	self.phaseFrame = phaseFrame
	UILib.corner(phaseFrame, Theme.Corners.Medium)
	UILib.stroke(phaseFrame, Theme.Colors.Line, 1, 0.25)
	self.phaseAccent = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 42, 0, 2),
		Position = UDim2.new(0.5, -21, 0, 0),
		ZIndex = 9,
	}, phaseFrame)

	self.phaseLabel = UILib.label(phaseFrame, {
		Text = "ЛОББИ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, 0, 0, 13),
		ZIndex = 9,
	})
	self.timerLabel = UILib.label(phaseFrame, {
		Text = "00:40",
		Font = Theme.Fonts.Display,
		TextSize = 24,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 9,
	})
	self.phaseDetail = UILib.label(phaseFrame, {
		Text = "ДО НАЧАЛА РАУНДА",
		Font = Theme.Fonts.Medium,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 9,
	})

	-- Эхо.
	local currency = UILib.new("Frame", {
		Name = "Currency",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 20),
		Size = UDim2.fromOffset(174, 44),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, root)
	UILib.corner(currency, Theme.Corners.Medium)
	UILib.stroke(currency, Theme.Colors.Line, 1, 0.3)
	UILib.label(currency, {
		Text = "◈",
		Font = Theme.Fonts.Bold,
		TextSize = 19,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(13, 10),
		Size = UDim2.fromOffset(20, 22),
		ZIndex = 9,
	})
	UILib.label(currency, {
		Text = "ЭХО",
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(39, 8),
		Size = UDim2.new(1, -44, 0, 12),
		ZIndex = 9,
	})
	self.echoLabel = UILib.label(currency, {
		Text = "0",
		Font = Theme.Fonts.Bold,
		TextSize = 17,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(39, 18),
		Size = UDim2.new(1, -44, 0, 20),
		ZIndex = 9,
	})

	-- Карточка роли.
	local roleCard = UILib.new("Frame", {
		Name = "RoleCard",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -32),
		Size = UDim2.fromOffset(356, 116),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
	}, root)
	self.roleCard = roleCard
	UILib.corner(roleCard, Theme.Corners.Medium)
	UILib.stroke(roleCard, Theme.Colors.Line, 1, 0.3)
	self.roleAccent = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -24),
		Position = UDim2.fromOffset(0, 12),
		ZIndex = 9,
	}, roleCard)
	UILib.label(roleCard, {
		Text = "ТВОЯ РОЛЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(17, 12),
		Size = UDim2.new(1, -30, 0, 12),
		ZIndex = 9,
	})
	self.roleLabel = UILib.label(roleCard, {
		Text = "ВЫЖИВШИЙ",
		Font = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = Theme.Colors.Savior,
		Position = UDim2.fromOffset(17, 24),
		Size = UDim2.new(1, -30, 0, 28),
		ZIndex = 9,
	})
	self.roleCharLabel = UILib.label(roleCard, {
		Text = "ИСКАТЕЛЬ  //  ЛУЧ НАДЕЖДЫ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.TextSoft,
		Position = UDim2.fromOffset(17, 53),
		Size = UDim2.new(1, -30, 0, 14),
		ZIndex = 9,
	})
	self.roleObjective = UILib.label(roleCard, {
		Text = "Продержитесь до конца раунда",
		Font = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(17, 79),
		Size = UDim2.new(1, -32, 0, 24),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 9,
	})

	-- Выносливость.
	local staminaFrame = UILib.new("Frame", {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -32),
		Size = UDim2.fromOffset(338, 48),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 8,
	}, root)
	self.staminaFrame = staminaFrame
	UILib.corner(staminaFrame, Theme.Corners.Small)
	UILib.stroke(staminaFrame, Theme.Colors.Line, 1, 0.35)
	UILib.label(staminaFrame, {
		Text = "ВЫНОСЛИВОСТЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(0.5, -12, 0, 12),
		ZIndex = 9,
	})
	self.staminaValue = UILib.label(staminaFrame, {
		Text = "100 / 100",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.new(0.5, -12, 0, 12),
		ZIndex = 9,
	})

	local barBackground = UILib.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(31, 35, 43),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(1, -24, 0, 9),
		ZIndex = 9,
	}, staminaFrame)
	UILib.corner(barBackground, UDim.new(1, 0))
	self.staminaFill = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, barBackground)
	UILib.corner(self.staminaFill, UDim.new(1, 0))

	-- Подсказки управления.
	local hints = UILib.new("Frame", {
		Name = "Hints",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -28),
		Size = UDim2.fromOffset(690, 22),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, root)
	self.hintsContainer = hints
	local hintLayout = UILib.list(hints, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Right)
	hintLayout.Padding = UDim.new(0, 16)

	-- Подсказка лобби.
	self.lobbyHint = UILib.label(root, {
		Name = "LobbyHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(560, 28),
		Font = Theme.Fonts.Medium,
		TextSize = 13,
		TextColor3 = Theme.Colors.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Подойдите к Хранителю и нажмите [E], чтобы открыть магазин",
		ZIndex = 9,
	})
	local hintAccent = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 22, 0, 1),
		Position = UDim2.new(0.5, -11, 1, 1),
		ZIndex = 9,
	}, self.lobbyHint)

	-- Прицел.
	local crosshair = UILib.new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Colors.Text,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, root)
	UILib.corner(crosshair, UDim.new(1, 0))
	self.crosshair = crosshair
	local crosshairRing = UILib.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, root)
	UILib.corner(crosshairRing, UDim.new(1, 0))
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Theme.Colors.Text
	ringStroke.Thickness = 1
	ringStroke.Transparency = 0.65
	ringStroke.Parent = crosshairRing
	self.crosshairRing = crosshairRing

	-- Баннер событий.
	local banner = UILib.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.fromOffset(720, 190),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, root)
	self.banner = banner
	UILib.corner(banner, Theme.Corners.Large)
	UILib.stroke(banner, Theme.Colors.Line, 1, 0.25)
	self.bannerAccent = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 68, 0, 2),
		Position = UDim2.new(0.5, -34, 0, 0),
		ZIndex = 21,
	}, banner)
	self.bannerEyebrow = UILib.label(banner, {
		Text = "РАУНД НАЧАЛСЯ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 23),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 21,
	})
	self.bannerTitle = UILib.label(banner, {
		Text = "ВЫЖИВШИЙ",
		Font = Theme.Fonts.Display,
		TextSize = 40,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 39),
		Size = UDim2.new(1, 0, 0, 54),
		ZIndex = 21,
	})
	self.bannerSubtitle = UILib.label(banner, {
		Text = "",
		Font = Theme.Fonts.Medium,
		TextSize = 13,
		TextColor3 = Theme.Colors.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Position = UDim2.fromOffset(50, 96),
		Size = UDim2.new(1, -100, 0, 38),
		ZIndex = 21,
	})
	self.bannerFooter = UILib.label(banner, {
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 148),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 21,
	})

	-- Смерть.
	local death = UILib.new("Frame", {
		Name = "Death",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(7, 2, 3),
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 25,
	}, root)
	self.deathOverlay = death
	local deathVignette = UILib.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 26,
	}, death)
	local deathGradient = Instance.new("UIGradient")
	deathGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	deathGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 16, 20)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 4, 5)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(91, 16, 20)),
	})
	deathGradient.Rotation = 180
	deathGradient.Parent = deathVignette

	UILib.label(death, {
		Text = "ВЫ ПОГИБЛИ",
		Font = Theme.Fonts.Display,
		TextSize = 48,
		TextColor3 = Theme.Colors.LostSoul,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.36, 0),
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 27,
	})
	UILib.label(death, {
		Text = "Наблюдайте за раундом. После его окончания вы вернётесь в лобби.",
		Font = Theme.Fonts.Medium,
		TextSize = 14,
		TextColor3 = Theme.Colors.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.36, 72),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 27,
	})
	UILib.label(death, {
		Text = "[TAB]  СПИСОК УЧАСТНИКОВ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.36, 104),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 27,
	})

	-- Вспышка урона.
	self.damageFlash = UILib.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, root)

	-- Затемнение перехода.
	self.fade = UILib.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, root)

	-- Тосты.
	local toastHolder = UILib.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 78),
		Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, root)
	self.toastHolder = toastHolder
	UILib.list(toastHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)

	self:refreshHints()
	self:refreshRoleCard()
	self:refreshStamina()
	self:refreshVisibility()

	local function connectAttribute(name, callback)
		player:GetAttributeChangedSignal(name):Connect(callback)
	end
	connectAttribute("Stamina", function()
		self:refreshStamina()
	end)
	connectAttribute("MaxStamina", function()
		self:refreshStamina()
	end)
	connectAttribute("Sprinting", function()
		self:refreshStamina()
		self:refreshHints()
	end)
	connectAttribute("FlashlightOn", function()
		self:refreshHints()
	end)
	for _, attributeName in ipairs({
		"AbilityId",
		"AbilityName",
		"AbilityShortName",
		"AbilityKey",
		"AbilityTrigger",
		"AbilityActive",
	}) do
		connectAttribute(attributeName, function()
			self:refreshRoleCard()
			self:refreshHints()
		end)
	end
	connectAttribute("GameRole", function()
		self:refreshRoleCard()
		self:refreshHints()
		self:refreshVisibility()
	end)
	connectAttribute("IsDead", function()
		self:refreshVisibility()
	end)

	return self
end

function HUD:setProfile(profile)
	self.profile = profile
	if profile then
		self.echoLabel.Text = Util.formatNumber(profile.echoes)
	end
	self:refreshRoleCard()
end

function HUD:setEchoes(value)
	self.echoLabel.Text = Util.formatNumber(value or 0)
end

function HUD:refreshRoleCard()
	local role = self.player:GetAttribute("GameRole")
	if role ~= Config.Roles.Savior and role ~= Config.Roles.LostSoul then
		self.roleCard.Visible = false
		return
	end

	local meta = Config.RoleMeta[role]
	local character = nil
	if self.profile then
		local characterId = if role == Config.Roles.LostSoul
			then self.profile.selectedLostSoul
			else self.profile.selectedSavior
		character = Config.getCharacter(characterId)
	end
	if not character then
		character = Config.getCharacterForRole(role)
	end

	local abilityName = self.player:GetAttribute("AbilityName")
		or (character and character.abilityName)
		or meta.nameEn
	self.roleAccent.BackgroundColor3 = meta.color
	self.roleLabel.Text = meta.name
	self.roleLabel.TextColor3 = meta.color
	if character then
		self.roleCharLabel.Text = string.upper(character.name) .. "  //  " .. string.upper(abilityName)
		self.roleObjective.Text = meta.objective
	else
		self.roleCharLabel.Text = meta.nameEn
		self.roleObjective.Text = meta.objective
	end
end

function HUD:refreshHints()
	local role = self.player:GetAttribute("GameRole")
	local phase = self.state and self.state.phase or "Lobby"
	local flashlightOn = self.player:GetAttribute("FlashlightOn") == true
	local abilityId = self.player:GetAttribute("AbilityId")
	local abilityName = self.player:GetAttribute("AbilityShortName") or self.player:GetAttribute("AbilityName")
	local abilityKey = self.player:GetAttribute("AbilityKey")
	local abilityTrigger = self.player:GetAttribute("AbilityTrigger")
	local abilityActive = self.player:GetAttribute("AbilityActive") == true
	local signature = string.format(
		"%s|%s|%s|%s|%s|%s|%s|%s",
		tostring(phase),
		tostring(role),
		tostring(flashlightOn),
		tostring(abilityId),
		tostring(abilityName),
		tostring(abilityKey),
		tostring(abilityTrigger),
		tostring(abilityActive)
	)
	if signature == self.hintSignature and #self.hintLabels > 0 then
		return
	end
	self.hintSignature = signature

	if #self.hintLabels > 0 then
		for _, label in ipairs(self.hintLabels) do
			label:Destroy()
		end
		table.clear(self.hintLabels)
	end

	local hints = {}

	if phase == "Round" then
		if role == Config.Roles.Savior or role == Config.Roles.LostSoul then
			table.insert(hints, { "SHIFT", "БЕГ" })

			if abilityId and abilityKey and abilityName then
				local label = string.upper(abilityName)
				if (abilityActive or flashlightOn) and abilityTrigger == "Key" then
					label ..= " ВКЛ"
				end
				table.insert(hints, { abilityKey, label })
			end

			if role == Config.Roles.Savior then
				table.insert(hints, { "1", "ЭМОЦИЯ" })
			end
			table.insert(hints, { "TAB", "ИГРОКИ" })
		else
			table.insert(hints, { "TAB", "ИГРОКИ" })
		end
	else
		table.insert(hints, { "TAB", "ИГРОКИ" })
		if phase == "Lobby" then
			table.insert(hints, { "E", "МАГАЗИН" })
		end
	end

	for index, hint in ipairs(hints) do
		local label = makeKeyHint(self.hintsContainer, index)
		label.Text = string.format('<font color="#D9E2EC">[%s]</font>  %s', hint[1], hint[2])
		label.Visible = true
		table.insert(self.hintLabels, label)
	end
end

function HUD:refreshStamina()
	local stamina = tonumber(self.player:GetAttribute("Stamina")) or 0
	local maxStamina = tonumber(self.player:GetAttribute("MaxStamina")) or 100
	local ratio = math.clamp(stamina / math.max(maxStamina, 1), 0, 1)
	local role = self.player:GetAttribute("GameRole")
	local roleColor = Theme.roleColor(role)

	self.staminaFill.Size = UDim2.fromScale(ratio, 1)
	self.staminaFill.BackgroundColor3 = if ratio <= 0.25 then Theme.Colors.Danger else roleColor
	self.staminaValue.Text = string.format("%d / %d", math.floor(stamina + 0.5), math.floor(maxStamina + 0.5))
end

function HUD:refreshVisibility()
	local phase = self.state and self.state.phase or "Lobby"
	local role = self.player:GetAttribute("GameRole")
	local isDead = self.player:GetAttribute("IsDead") == true
	local inRound = phase == "Round"
	local hasCombatRole = role == Config.Roles.Savior or role == Config.Roles.LostSoul

	self.roleCard.Visible = inRound and hasCombatRole and not isDead
	self.staminaFrame.Visible = inRound and hasCombatRole and not isDead
	self.crosshair.Visible = inRound and hasCombatRole and not isDead
	self.crosshairRing.Visible = self.crosshair.Visible
	self.lobbyHint.Visible = phase == "Lobby" and not self.deathOverlay.Visible
end

function HUD:updateState(state)
	self.state = state
	local phase = state.phase
	local waiting = state.waitingForPlayers == true
	local isLastFighting = state.mode == "LastFightingSoul"
	local color = Theme.Colors.Savior
	local phaseText = "ЛОББИ"
	local timerText = Util.formatClock(state.timeLeft)
	local detailText = "ДО НАЧАЛА РАУНДА"

	if phase == "Lobby" then
		phaseText = "ЛОББИ"
		detailText = string.format("%d / %d ИГРОКОВ", state.playerCount or 0, state.minPlayers or 2)
		if waiting then
			timerText = "ОЖИДАНИЕ"
			detailText = "НУЖНО МИНИМУМ " .. tostring(state.minPlayers or 2) .. " ИГРОКА"
			color = Theme.Colors.Gold
		else
			detailText = string.format("ДО СТАРТА  //  %d ИГРОКОВ", state.playerCount or 0)
		end
	elseif phase == "Starting" then
		phaseText = "ПОДГОТОВКА"
		timerText = "АРЕНА"
		detailText = "СОЗДАНИЕ КАРТЫ..."
		color = Theme.Colors.Gold
	elseif phase == "Round" then
		phaseText = if isLastFighting then "LAST FIGHTING SOUL" else "РАУНД"
		detailText = string.format(
			"%s  //  ЖИВЫ: %d/%d",
			state.mapName or "НЕИЗВЕСТНАЯ ЗОНА",
			state.aliveSaviors or 0,
			state.totalSaviors or 0
		)
		color = if isLastFighting then Theme.Colors.LostSoul else Theme.Colors.Savior
	elseif phase == "Ending" then
		phaseText = "КОНЕЦ РАУНДА"
		timerText = Util.formatClock(state.timeLeft)
		detailText = "ВОЗВРАЩЕНИЕ В ЛОББИ..."
		color = Theme.Colors.Gold
	end

	self.phaseLabel.Text = phaseText
	self.timerLabel.Text = timerText
	self.timerLabel.TextSize = if timerText == "ОЖИДАНИЕ" then 17 else 24
	self.phaseDetail.Text = detailText
	self.phaseAccent.BackgroundColor3 = color

	if phase == "Lobby" and self.lastPhase ~= "Lobby" then
		self.deathOverlay.Visible = false
		self.banner.Visible = false
		self.bannerToken += 1
	elseif phase == "Ending" then
		self.deathOverlay.Visible = false
		self.crosshair.Visible = false
		self.crosshairRing.Visible = false
	end

	self.lastPhase = phase
	self:refreshHints()
	self:refreshVisibility()
end

function HUD:toast(message, tone)
	if not message or message == "" then
		return
	end

	local toast = UILib.new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 16,
	}, self.toastHolder)
	UILib.corner(toast, Theme.Corners.Small)
	UILib.stroke(toast, Theme.Colors.Line, 1, 0.35)
	local accent = UILib.new("Frame", {
		BackgroundColor3 = Theme.toneColor(tone),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		ZIndex = 17,
	}, toast)
	UILib.corner(accent, Theme.Corners.Pill)
	local label = UILib.label(toast, {
		Text = message,
		Font = Theme.Fonts.Medium,
		TextSize = 12,
		TextColor3 = Theme.Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 17,
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = label

	toast.BackgroundTransparency = 1
	label.TextTransparency = 1
	UILib.tween(toast, { BackgroundTransparency = 0.08 }, 0.16)
	UILib.tween(label, { TextTransparency = 0 }, 0.16)

	table.insert(self.toasts, toast)
	if #self.toasts > 5 then
		local oldest = table.remove(self.toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(4.2, function()
		if not toast.Parent then
			return
		end
		UILib.tween(toast, { BackgroundTransparency = 1 }, 0.25)
		UILib.tween(label, { TextTransparency = 1 }, 0.25)
		for _, child in ipairs(toast:GetChildren()) do
			if child:IsA("GuiObject") then
				UILib.tween(child, { BackgroundTransparency = 1 }, 0.25)
			end
		end
		task.wait(0.3)
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

function HUD:showBanner(eyebrow, title, subtitle, footer, accent, duration)
	self.bannerToken += 1
	local token = self.bannerToken
	self.banner.Visible = true
	self.banner.BackgroundTransparency = 1
	self.bannerAccent.BackgroundColor3 = accent
	self.bannerEyebrow.Text = eyebrow
	self.bannerEyebrow.TextColor3 = accent
	self.bannerTitle.Text = title
	self.bannerTitle.TextColor3 = Theme.Colors.Text
	self.bannerSubtitle.Text = subtitle or ""
	self.bannerFooter.Text = footer or ""
	self.bannerFooter.TextColor3 = Theme.Colors.Muted

	for _, element in ipairs({ self.bannerEyebrow, self.bannerTitle, self.bannerSubtitle, self.bannerFooter }) do
		element.TextTransparency = 1
	end

	UILib.tween(self.banner, { BackgroundTransparency = 0.18 }, 0.25)
	UILib.tween(self.bannerEyebrow, { TextTransparency = 0 }, 0.25)
	UILib.tween(self.bannerTitle, { TextTransparency = 0 }, 0.25)
	UILib.tween(self.bannerSubtitle, { TextTransparency = 0 }, 0.25)
	UILib.tween(self.bannerFooter, { TextTransparency = 0 }, 0.25)

	if duration then
		task.delay(duration, function()
			if token ~= self.bannerToken or not self.banner.Visible then
				return
			end
			UILib.tween(self.banner, { BackgroundTransparency = 1 }, 0.3)
			UILib.tween(self.bannerEyebrow, { TextTransparency = 1 }, 0.3)
			UILib.tween(self.bannerTitle, { TextTransparency = 1 }, 0.3)
			UILib.tween(self.bannerSubtitle, { TextTransparency = 1 }, 0.3)
			UILib.tween(self.bannerFooter, { TextTransparency = 1 }, 0.3)
			task.wait(0.32)
			if token == self.bannerToken then
				self.banner.Visible = false
			end
		end)
	end
end

function HUD:showRoundStart(data)
	self.roundRole = data.role
	self.deathOverlay.Visible = false
	self:refreshRoleCard()
	self:refreshHints()
	self:refreshVisibility()

	UILib.tween(self.fade, { BackgroundTransparency = 0.2 }, 0.12)
	task.delay(0.15, function()
		UILib.tween(self.fade, { BackgroundTransparency = 1 }, 0.45)
	end)

	local accent = Theme.roleColor(data.role)
	if data.mode == "LastFightingSoul" then
		self:showBanner(
			"ОСОБЫЙ РЕЖИМ  //  1 НА 1",
			"LAST FIGHTING SOUL",
			"Последний выживший против Полого. Убейте — или продержитесь до конца.",
			string.upper(data.mapName or "") .. "   //   " .. Util.formatClock(data.duration or Config.Round.LastFightingSoulSeconds),
			Theme.Colors.LostSoul,
			4.2
		)
	else
		local meta = Config.RoleMeta[data.role] or Config.RoleMeta.Savior
		self:showBanner(
			"РАУНД НАЧАЛСЯ",
			meta.name,
			meta.objective,
			string.upper(data.mapName or "") .. "   //   " .. Util.formatClock(data.duration or 0),
			accent,
			3.6
		)
	end

	self:toast(
		if data.role == Config.Roles.LostSoul
			then "Вы — Потерянная Душа. Охота началась."
			else "Вы — Выживший. Продержитесь до конца.",
		"info"
	)
end

function HUD:showDeath()
	self.deathOverlay.Visible = true
	self.lobbyHint.Visible = false
	self.crosshair.Visible = false
	self.crosshairRing.Visible = false
	self:refreshHints()
end

function HUD:showRoundEnd(data)
	self.deathOverlay.Visible = false
	self.crosshair.Visible = false
	self.crosshairRing.Visible = false
	self.staminaFrame.Visible = false
	self.roleCard.Visible = false
	self.lobbyHint.Visible = false

	local title
	local subtitle
	local accent
	if data.personalWin then
		title = "ПОБЕДА"
		accent = Theme.Colors.Savior
		subtitle = "Ваша сторона пережила это измерение."
	else
		title = "ПОРАЖЕНИЕ"
		accent = Theme.Colors.LostSoul
		subtitle = "Измерение забрало ещё одного."
	end

	if data.role == Config.Roles.Spectator then
		title = "РАУНД ОКОНЧЕН"
		accent = Theme.Colors.Gold
		subtitle = "Наблюдение завершено."
	end

	local winnerText = if data.winner == Config.Roles.Savior then "ПОБЕДА ВЫЖИВШИХ" else "ПОБЕДА ПОТЕРЯННОЙ ДУШИ"
	self:showBanner(
		winnerText,
		title,
		subtitle .. "\n" .. (data.reason or ""),
		"НАГРАДА  +" .. tostring(data.reward or 0) .. " ЭХО   //   ВОЗВРАЩЕНИЕ В ЛОББИ...",
		accent,
		Config.Round.EndScreenSeconds - 1
	)
end

function HUD:showAbort(message)
	self:showBanner("РАУНД ОТМЕНЁН", "СБОЙ СИНХРОНИЗАЦИИ", message or "Возвращение в лобби.", "", Theme.Colors.Warning, 3)
end

function HUD:flashDamage()
	self.damageFlash.BackgroundTransparency = 0.45
	UILib.tween(self.damageFlash, { BackgroundTransparency = 1 }, 0.45)
end

function HUD:flashFade()
	self.fade.BackgroundTransparency = 0.15
	task.delay(0.1, function()
		UILib.tween(self.fade, { BackgroundTransparency = 1 }, 0.5)
	end)
end

return HUD
