local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local UILib = require(script.Parent:WaitForChild("UILib"))

local Shop = {}
Shop.__index = Shop

local TABS = {
	{
		id = "Saviors",
		index = "01",
		title = "ВЫЖИВШИЕ",
		subtitle = "SAVIORS",
		description = "Те, кто ещё дышит. Выберите свой облик и способность.",
	},
	{
		id = "LostSouls",
		index = "02",
		title = "ПОТЕРЯННЫЕ ДУШИ",
		subtitle = "LOST SOULS",
		description = "Те, кто уже не дышит. Выберите того, кто будет охотиться.",
	},
	{
		id = "Skins",
		index = "03",
		title = "СКИНЫ",
		subtitle = "SKINS",
		description = "Другой оттенок того же кошмара. Косметика не влияет на силу.",
	},
	{
		id = "Emotions",
		index = "04",
		title = "ЭМОЦИИ",
		subtitle = "EMOTIONS",
		description = "Короткие жесты выживших. Иногда это единственное, что осталось.",
	},
}

local function findTab(tabId)
	for _, tab in ipairs(TABS) do
		if tab.id == tabId then
			return tab
		end
	end
	return TABS[1]
end

local function isOwned(profile, listName, item)
	if not profile or not item then
		return false
	end
	if item.price == 0 then
		return true
	end
	local list = profile[listName]
	if not list then
		return false
	end
	return Util.tableFind(list, item.id) ~= nil
end

function Shop.new(playerGui, localPlayer, remotes)
	local self = setmetatable({}, Shop)
	self.localPlayer = localPlayer
	self.remotes = remotes
	self.profile = nil
	self.isVisible = false
	self.activeTab = "Saviors"
	self.navButtons = {}
	self.messageToken = 0

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShatteredDimensions_Shop"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 30
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	self.gui = screenGui

	local root = UILib.new("Frame", {
		Name = "Root",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, screenGui)
	self.root = root

	local panel = UILib.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.82),
		BackgroundColor3 = Theme.Colors.BackgroundSoft,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, root)
	UILib.corner(panel, Theme.Corners.Large)
	UILib.stroke(panel, Theme.Colors.Line, 1, 0.22)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(860, 560)
	constraint.MaxSize = Vector2.new(1280, 800)
	constraint.Parent = panel
	self.panel = panel

	local topLine = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 4,
	}, panel)
	local topGradient = Instance.new("UIGradient")
	topGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Savior),
		ColorSequenceKeypoint.new(0.5, Theme.Colors.Gold),
		ColorSequenceKeypoint.new(1, Theme.Colors.LostSoul),
	})
	topGradient.Parent = topLine

	local header = UILib.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 86),
		ZIndex = 5,
	}, panel)

	UILib.label(header, {
		Text = "ЛАВКА ХРАНИТЕЛЯ  //  SPECTRUM MARKET",
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(22, 15),
		Size = UDim2.new(0.5, 0, 0, 12),
		ZIndex = 6,
	})
	UILib.label(header, {
		Text = "МАГАЗИН ДУШ",
		Font = Theme.Fonts.Display,
		TextSize = 28,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(22, 28),
		Size = UDim2.new(0.5, 0, 0, 40),
		ZIndex = 6,
	})
	UILib.label(header, {
		Text = "Всё, что можно купить, всё, чем можно стать.",
		Font = Theme.Fonts.Medium,
		TextSize = 10,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(22, 65),
		Size = UDim2.new(0.5, 0, 0, 12),
		ZIndex = 6,
	})

	local currency = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -68, 0, 43),
		Size = UDim2.fromOffset(166, 38),
		ZIndex = 6,
	}, header)
	UILib.corner(currency, Theme.Corners.Small)
	UILib.stroke(currency, Theme.Colors.Line, 1, 0.35)
	UILib.label(currency, {
		Text = "◈",
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(18, 20),
		ZIndex = 7,
	})
	self.currencyLabel = UILib.label(currency, {
		Text = "0",
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(36, 8),
		Size = UDim2.new(1, -44, 0, 20),
		ZIndex = 7,
	})
	UILib.label(currency, {
		Text = "ЭХО",
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -40, 0, 15),
		Size = UDim2.fromOffset(30, 10),
		ZIndex = 7,
	})

	local close = UILib.button(header, {
		Text = "✕",
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		TextColor3 = Theme.Colors.Muted,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0, 43),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 6,
	})
	UILib.corner(close, Theme.Corners.Small)
	UILib.hover(close, Theme.Colors.PanelRaised, Theme.Colors.PanelHover)
	close.MouseButton1Click:Connect(function()
		self:close()
	end)

	UILib.line(panel, {
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 5,
	})

	-- Навигация.
	local nav = UILib.new("Frame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 103),
		Size = UDim2.new(0, 204, 1, -121),
		ZIndex = 5,
	}, panel)

	local navButtonsHolder = UILib.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 260),
		ZIndex = 6,
	}, nav)
	UILib.list(navButtonsHolder, Enum.FillDirection.Vertical, 6)

	for index, tab in ipairs(TABS) do
		local button = UILib.button(navButtonsHolder, {
			Name = "Tab_" .. tab.id,
			Text = "",
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 58),
			LayoutOrder = index,
			ZIndex = 7,
		})
		UILib.corner(button, Theme.Corners.Small)
		local stroke = UILib.stroke(button, Theme.Colors.LineSoft, 1, 0.5)
		local accent = UILib.new("Frame", {
			BackgroundColor3 = Theme.Colors.Gold,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, -16),
			Position = UDim2.fromOffset(0, 8),
			Visible = false,
			ZIndex = 9,
		}, button)
		UILib.corner(accent, Theme.Corners.Pill)
		local indexLabel = UILib.label(button, {
			Text = tab.index,
			Font = Theme.Fonts.Bold,
			TextSize = 8,
			TextColor3 = Theme.Colors.Dim,
			Position = UDim2.fromOffset(13, 8),
			Size = UDim2.fromOffset(24, 10),
			ZIndex = 8,
		})
		local titleLabel = UILib.label(button, {
			Text = tab.title,
			Font = Theme.Fonts.Bold,
			TextSize = 12,
			TextColor3 = Theme.Colors.TextSoft,
			Position = UDim2.fromOffset(13, 20),
			Size = UDim2.new(1, -24, 0, 17),
			ZIndex = 8,
		})
		local subLabel = UILib.label(button, {
			Text = tab.subtitle,
			Font = Theme.Fonts.Medium,
			TextSize = 8,
			TextColor3 = Theme.Colors.Dim,
			Position = UDim2.fromOffset(13, 38),
			Size = UDim2.new(1, -24, 0, 11),
			ZIndex = 8,
		})

		button.MouseEnter:Connect(function()
			if self.activeTab ~= tab.id then
				UILib.tween(button, { BackgroundColor3 = Theme.Colors.PanelHover }, 0.14)
			end
		end)
		button.MouseLeave:Connect(function()
			if self.activeTab ~= tab.id then
				UILib.tween(button, { BackgroundColor3 = Theme.Colors.Panel }, 0.14)
			end
		end)
		button.MouseButton1Click:Connect(function()
			self.activeTab = tab.id
			self:updateNavigation()
			self:render()
		end)

		self.navButtons[tab.id] = {
			button = button,
			accent = accent,
			stroke = stroke,
			indexLabel = indexLabel,
			titleLabel = titleLabel,
			subLabel = subLabel,
		}
	end

	local loadout = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 112),
		ZIndex = 6,
	}, nav)
	UILib.corner(loadout, Theme.Corners.Small)
	UILib.stroke(loadout, Theme.Colors.LineSoft, 1, 0.5)
	UILib.label(loadout, {
		Text = "ТЕКУЩАЯ СБОРКА",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(11, 9),
		Size = UDim2.new(1, -20, 0, 10),
		ZIndex = 7,
	})
	self.currentSaviorLabel = UILib.label(loadout, {
		Text = "ВЫЖИВШИЙ: —",
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.Savior,
		Position = UDim2.fromOffset(11, 30),
		Size = UDim2.new(1, -20, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})
	self.currentLostLabel = UILib.label(loadout, {
		Text = "ДУША: —",
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.LostSoul,
		Position = UDim2.fromOffset(11, 52),
		Size = UDim2.new(1, -20, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})
	self.currentEmotionLabel = UILib.label(loadout, {
		Text = "ЭМОЦИЯ: —",
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(11, 74),
		Size = UDim2.new(1, -20, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})

	UILib.label(nav, {
		Text = "[ESC] ЗАКРЫТЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 12),
		ZIndex = 6,
	})

	-- Контент.
	local content = UILib.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 240, 0, 101),
		Size = UDim2.new(1, -258, 1, -119),
		ZIndex = 5,
	}, panel)

	self.sectionTitle = UILib.label(content, {
		Text = "ВЫЖИВШИЕ",
		Font = Theme.Fonts.Display,
		TextSize = 20,
		TextColor3 = Theme.Colors.Text,
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 6,
	})
	self.sectionDescription = UILib.label(content, {
		Text = "",
		Font = Theme.Fonts.Medium,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 6,
	})

	self.scroller = UILib.new("ScrollingFrame", {
		Name = "Catalog",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 53),
		Size = UDim2.new(1, 0, 1, -53),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Colors.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
	}, content)
	self.scrollerContent = self.scroller
	UILib.padding(self.scroller, 0, 10, 8, 1)

	self.messageLabel = UILib.label(panel, {
		Text = "",
		Font = Theme.Fonts.Medium,
		TextSize = 11,
		TextColor3 = Theme.Colors.TextSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(520, 24),
		TextTransparency = 1,
		ZIndex = 12,
	})
	self.messageLabel = self.messageLabel

	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "SD_ShopBlur"
	self.blur.Size = 0
	self.blur.Enabled = false
	self.blur.Parent = Lighting

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not self.isVisible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			self:close()
		elseif gameProcessed then
			return
		end
	end)

	self:updateNavigation()
	self:render()

	return self
end

function Shop:isOpen()
	return self.isVisible
end

function Shop:open()
	if self.isVisible then
		return
	end
	self.isVisible = true
	self.gui.Enabled = true
	self.blur.Enabled = true
	UILib.tween(self.blur, { Size = 16 }, 0.25)
	self.root.BackgroundTransparency = 0.65
	UILib.tween(self.root, { BackgroundTransparency = 0.45 }, 0.2)
	self:updateNavigation()
	self:render()
end

function Shop:close()
	if not self.isVisible then
		return
	end
	self.isVisible = false
	self.gui.Enabled = false
	UILib.tween(self.blur, { Size = 0 }, 0.2)
	task.delay(0.22, function()
		if not self.isVisible then
			self.blur.Enabled = false
		end
	end)
end

function Shop:setProfile(profile)
	self.profile = profile
	if profile then
		self.currencyLabel.Text = Util.formatNumber(profile.echoes)
	else
		self.currencyLabel.Text = "—"
	end
	self:updateNavigation()
	if self.isVisible then
		self:render()
	end
end

function Shop:updateNavigation()
	for tabId, entry in pairs(self.navButtons) do
		local selected = tabId == self.activeTab
		local accentColor = Theme.Colors.Savior
		if tabId == "LostSouls" then
			accentColor = Theme.Colors.LostSoul
		elseif tabId == "Skins" or tabId == "Emotions" then
			accentColor = Theme.Colors.Gold
		end

		entry.accent.Visible = selected
		entry.accent.BackgroundColor3 = accentColor
		entry.button.BackgroundColor3 = if selected then Theme.Colors.PanelHover else Theme.Colors.Panel
		entry.stroke.Color = if selected then entry.accent.BackgroundColor3 else Theme.Colors.LineSoft
		entry.stroke.Transparency = if selected then 0.25 else 0.5
		entry.indexLabel.TextColor3 = if selected then entry.accent.BackgroundColor3 else Theme.Colors.Dim
		entry.titleLabel.TextColor3 = if selected then Theme.Colors.Text else Theme.Colors.TextSoft
		entry.subLabel.TextColor3 = if selected then Theme.Colors.Muted else Theme.Colors.Dim
	end

	local profile = self.profile
	if not profile then
		self.currentSaviorLabel.Text = "ВЫЖИВШИЙ: —"
		self.currentLostLabel.Text = "ДУША: —"
		self.currentEmotionLabel.Text = "ЭМОЦИЯ: —"
		return
	end

	local savior = Config.getCharacter(profile.selectedSavior)
	local lostSoul = Config.getCharacter(profile.selectedLostSoul)
	local saviorSkin = Config.getSkin(profile.selectedSaviorSkin)
	local lostSkin = Config.getSkin(profile.selectedLostSoulSkin)
	local emotion = Config.getEmotion(profile.selectedEmotion)

	self.currentSaviorLabel.Text = "ВЫЖИВШИЙ: " .. tostring(savior and savior.name or "—") .. " / " .. tostring(saviorSkin and saviorSkin.name or "—")
	self.currentLostLabel.Text = "ДУША: " .. tostring(lostSoul and lostSoul.name or "—") .. " / " .. tostring(lostSkin and lostSkin.name or "—")
	self.currentEmotionLabel.Text = "ЭМОЦИЯ: " .. tostring(emotion and emotion.name or "—")
end

function Shop:notify(message, tone)
	local color = Theme.toneColor(tone)
	self.messageToken += 1
	local token = self.messageToken
	self.messageLabel.Text = message
	self.messageLabel.TextColor3 = color
	self.messageLabel.TextTransparency = 0
	self.messageLabel.Position = UDim2.new(0.5, 0, 1, -14)
	UILib.tween(self.messageLabel, { Position = UDim2.new(0.5, 0, 1, -20) }, 0.18)
	task.delay(3.4, function()
		if token ~= self.messageToken then
			return
		end
		UILib.tween(self.messageLabel, { TextTransparency = 1 }, 0.25)
	end)
end

function Shop:send(action, itemType, itemId)
	if not self.profile then
		self:notify("Профиль ещё загружается.", "warning")
		return
	end
	self.remotes.ShopAction:FireServer(action, itemType, itemId)
end

function Shop:createCard(layoutOrder)
	local card = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(286, 414),
		LayoutOrder = layoutOrder,
		ZIndex = 7,
	}, self.scroller)
	UILib.corner(card, Theme.Corners.Medium)
	local stroke = UILib.stroke(card, Theme.Colors.Line, 1, 0.4)
	card.ClipsDescendants = true
	return card, stroke
end

function Shop:makeImageArea(card, previewTint, roleAccent, badgeText)
	local holder = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 232),
		ClipsDescendants = true,
		ZIndex = 8,
	}, card)

	local fallback = UILib.label(holder, {
		Text = "?",
		Font = Theme.Fonts.Display,
		TextSize = 46,
		TextColor3 = Theme.Colors.Line,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
	})

	local image = UILib.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = UILib.avatarUrl(self.localPlayer.UserId, true, 420),
		ImageColor3 = previewTint or Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 10,
	}, holder)

	local shade = UILib.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
	}, holder)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	gradient.Parent = shade

	local badge = UILib.new("Frame", {
		BackgroundColor3 = roleAccent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(96, 18),
		ZIndex = 12,
	}, holder)
	UILib.corner(badge, Theme.Corners.Pill)
	UILib.label(badge, {
		Text = badgeText,
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
	})

	local avatarCaption = UILib.label(card, {
		Text = "ВАШ АВАТАР  //  ОСНОВА ОБРАЗА",
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(13, 239),
		Size = UDim2.new(1, -26, 0, 11),
		ZIndex = 9,
	})

	return holder, image, badge
end

function Shop:makeFooterButton(card, text, enabled, accent, callback)
	local button = UILib.button(card, {
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = if enabled then Theme.Colors.Background else Theme.Colors.Dim,
		BackgroundColor3 = if enabled then accent else Theme.Colors.PanelRaised,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 34),
		ZIndex = 12,
	})
	UILib.corner(button, Theme.Corners.Small)
	if enabled then
		UILib.hover(button, accent, accent:Lerp(Color3.fromRGB(255, 255, 255), 0.15))
		button.MouseButton1Click:Connect(callback)
	else
		button.AutoButtonColor = false
		local stroke = UILib.stroke(button, Theme.Colors.LineSoft, 1, 0.3)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	return button
end

function Shop:renderCharacterCard(character, role, order)
	local profile = self.profile
	if not profile then
		return
	end

	local role = character.role
	local accent = Theme.roleColor(role)
	local skinId = if role == Config.Roles.LostSoul then profile.selectedLostSoulSkin else profile.selectedSaviorSkin
	local skin = Config.getSkin(skinId) or Config.getDefaultSkin(role)
	local selectedId = if role == Config.Roles.LostSoul then profile.selectedLostSoul else profile.selectedSavior
	local isSelected = selectedId == character.id

	local card, stroke = self:createCard(order)
	stroke.Color = accent
	stroke.Transparency = 0.55
	self:makeImageArea(card, skin and skin.previewTint, accent, if role == Config.Roles.LostSoul then "ПОТЕРЯННАЯ ДУША" else "ВЫЖИВШИЙ")

	UILib.label(card, {
		Text = character.title,
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = accent,
		Position = UDim2.fromOffset(13, 260),
		Size = UDim2.new(1, -26, 0, 10),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = character.name,
		Font = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(13, 270),
		Size = UDim2.new(1, -26, 0, 28),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = character.description,
		Font = Theme.Fonts.Body,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(13, 301),
		Size = UDim2.new(1, -26, 0, 43),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = string.upper(character.abilityKey) .. "  //  " .. string.upper(character.abilityName),
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = accent,
		Position = UDim2.fromOffset(13, 348),
		Size = UDim2.new(1, -26, 0, 12),
		ZIndex = 9,
	})

	self:makeFooterButton(card, if isSelected then "ВЫБРАНО" else "ВЫБРАТЬ ОБРАЗ", not isSelected, accent, function()
		self:send("Equip", if role == Config.Roles.LostSoul then "LostSoul" else "Savior", character.id)
	end)
end

function Shop:renderAbilityCard(character, order)
	local buttonKind = if character.role == Config.Roles.LostSoul then "LostSoul" else "Savior"
	local accent = Theme.roleColor(character.role)
	local card, stroke = self:createCard(order)
	stroke.Color = Theme.Colors.Line
	UILib.label(card, {
		Text = "АРХИВ ХРАНИТЕЛЯ  //  " .. string.upper(buttonKind),
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -36, 0, 12),
		ZIndex = 9,
	})

	local keyBox = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 45),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = 9,
	}, card)
	UILib.corner(keyBox, Theme.Corners.Small)
	UILib.stroke(keyBox, accent, 1, 0.2)
	UILib.label(keyBox, {
		Text = character.abilityKey,
		Font = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	})

	UILib.label(card, {
		Text = "СПОСОБНОСТЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(96, 47),
		Size = UDim2.new(1, -114, 0, 12),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = character.abilityName,
		Font = Theme.Fonts.Display,
		TextSize = 18,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(96, 61),
		Size = UDim2.new(1, -114, 0, 24),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = character.abilityDescription,
		Font = Theme.Fonts.Body,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(18, 128),
		Size = UDim2.new(1, -36, 0, 92),
		ZIndex = 9,
	})

	UILib.line(card, {
		Position = UDim2.fromOffset(18, 232),
		Size = UDim2.new(1, -36, 0, 1),
		ZIndex = 8,
	})

	UILib.label(card, {
		Text = "КАК ИГРАТЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(18, 248),
		Size = UDim2.new(1, -36, 0, 12),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = if character.role == Config.Roles.LostSoul
			then "Один из игроков становится Полым. Найдите выживших, используйте укрытия и не давайте им дожить до конца таймера. Удар ножом — ЛКМ. Бег — SHIFT, но он тратит выносливость (110)."
			else "Один из игроков становится Полым. Ваша задача — продержаться до конца таймера. Фонарик — F, бег — SHIFT (100 выносливости). Эмоция — 1. Список игроков — TAB.",
		Font = Theme.Fonts.Body,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(18, 264),
		Size = UDim2.new(1, -36, 0, 92),
		ZIndex = 9,
	})

	UILib.label(card, {
		Text = "ОБРАЗ ОСНОВАН НА ВАШЕМ АВАТАРЕ",
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(18, 370),
		Size = UDim2.new(1, -36, 0, 11),
		ZIndex = 9,
	})
end

function Shop:renderSkinCard(skin, order)
	local profile = self.profile
	if not profile then
		return
	end

	local owned = isOwned(profile, "ownedSkins", skin)
	local selected = if skin.role == Config.Roles.LostSoul
		then profile.selectedLostSoulSkin == skin.id
		else profile.selectedSaviorSkin == skin.id
	local accent = skin.accent or Theme.roleColor(skin.role)

	local card, stroke = self:createCard(order)
	stroke.Color = accent
	stroke.Transparency = 0.6

	local imageHolder = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 202),
		ClipsDescendants = true,
		ZIndex = 8,
	}, card)
	local image = UILib.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = UILib.avatarUrl(self.localPlayer.UserId, true, 420),
		ImageColor3 = skin.previewTint or Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 10,
	}, imageHolder)
	local shade = UILib.new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
	}, imageHolder)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	gradient.Parent = shade

	local rarity = UILib.new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(84, 17),
		ZIndex = 12,
	}, imageHolder)
	UILib.corner(rarity, Theme.Corners.Pill)
	UILib.label(rarity, {
		Text = skin.rarity,
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = Theme.Colors.Background,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
	})

	UILib.label(card, {
		Text = if skin.role == Config.Roles.LostSoul then "ПОТЕРЯННАЯ ДУША" else "ВЫЖИВШИЙ",
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = accent,
		Position = UDim2.fromOffset(13, 213),
		Size = UDim2.new(1, -26, 0, 10),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = skin.name,
		Font = Theme.Fonts.Display,
		TextSize = 17,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(13, 224),
		Size = UDim2.new(1, -26, 0, 22),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = skin.title,
		Font = Theme.Fonts.Medium,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(13, 245),
		Size = UDim2.new(1, -26, 0, 11),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = skin.description,
		Font = Theme.Fonts.Body,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(13, 262),
		Size = UDim2.new(1, -26, 0, 30),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = if skin.price == 0 then "БАЗОВЫЙ ОБРАЗ" else "ЦЕНА  ◈ " .. Util.formatNumber(skin.price),
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = if skin.price == 0 then Theme.Colors.Dim else Theme.Colors.Gold,
		Position = UDim2.fromOffset(13, 296),
		Size = UDim2.new(1, -26, 0, 14),
		ZIndex = 9,
	})

	local buttonText
	local enabled
	local action
	if selected then
		buttonText = "НАДЕТО"
		enabled = false
		action = nil
	elseif owned then
		buttonText = "НАДЕТЬ"
		enabled = true
		action = "Equip"
	else
		buttonText = "КУПИТЬ  ·  ◈ " .. Util.formatNumber(skin.price)
		enabled = true
		action = "Purchase"
	end

	self:makeFooterButton(card, buttonText, enabled, accent, function()
		if action then
			self:send(action, "Skin", skin.id)
		end
	end)
end

function Shop:renderEmotionCard(emotion, order)
	local profile = self.profile
	if not profile then
		return
	end

	local owned = isOwned(profile, "ownedEmotions", emotion)
	local selected = profile.selectedEmotion == emotion.id
	local accent = emotion.accent or Theme.Colors.Gold

	local card = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(286, 212),
		LayoutOrder = order,
		ZIndex = 7,
	}, self.scroller)
	UILib.corner(card, Theme.Corners.Medium)
	local stroke = UILib.stroke(card, accent, 1, 0.55)
	card.ClipsDescendants = true

	local icon = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(54, 54),
		ZIndex = 8,
	}, card)
	UILib.corner(icon, Theme.Corners.Small)
	UILib.label(icon, {
		Text = emotion.symbol,
		Font = Theme.Fonts.Display,
		TextSize = 25,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
	})

	UILib.label(card, {
		Text = emotion.title,
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = accent,
		Position = UDim2.fromOffset(80, 17),
		Size = UDim2.new(1, -94, 0, 10),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = emotion.name,
		Font = Theme.Fonts.Display,
		TextSize = 16,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(80, 27),
		Size = UDim2.new(1, -94, 0, 22),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = emotion.description,
		Font = Theme.Fonts.Body,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 0, 40),
		ZIndex = 9,
	})
	UILib.label(card, {
		Text = if emotion.price == 0 then "ОТКРЫТО" else "ЦЕНА  ◈ " .. Util.formatNumber(emotion.price),
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = if emotion.price == 0 then Theme.Colors.Dim else Theme.Colors.Gold,
		Position = UDim2.fromOffset(14, 127),
		Size = UDim2.new(1, -28, 0, 12),
		ZIndex = 9,
	})

	local buttonText
	local enabled
	local action
	if selected then
		buttonText = "ВЫБРАНО"
		enabled = false
		action = nil
	elseif owned then
		buttonText = "ВЫБРАТЬ"
		enabled = true
		action = "Equip"
	else
		buttonText = "КУПИТЬ  ·  ◈ " .. Util.formatNumber(emotion.price)
		enabled = true
		action = "Purchase"
	end

	self:makeFooterButton(card, buttonText, enabled, accent, function()
		if action then
			self:send(action, "Emotion", emotion.id)
		end
	end)
end

function Shop:render()
	UILib.clear(self.scroller)
	UILib.padding(self.scroller, 0, 10, 8, 1)

	local tab = findTab(self.activeTab)
	self.sectionTitle.Text = tab.title
	self.sectionDescription.Text = tab.description

	local cellSize
	if tab.id == "Emotions" then
		cellSize = UDim2.fromOffset(286, 212)
	elseif tab.id == "Skins" then
		cellSize = UDim2.fromOffset(286, 376)
	else
		cellSize = UDim2.fromOffset(286, 414)
	end
	UILib.grid(self.scroller, cellSize, UDim2.fromOffset(14, 14))

	if not self.profile then
		UILib.label(self.scroller, {
			Text = "ЗАГРУЗКА ПРОФИЛЯ...",
			Font = Theme.Fonts.Medium,
			TextSize = 12,
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(400, 60),
			ZIndex = 8,
		})
		return
	end

	if tab.id == "Saviors" then
		local characters = Config.Characters.Saviors
		for index, character in ipairs(characters) do
			self:renderCharacterCard(character, Config.Roles.Savior, index)
		end
		if characters[1] then
			self:renderAbilityCard(characters[1], #characters + 1)
		end
	elseif tab.id == "LostSouls" then
		local characters = Config.Characters.LostSouls
		for index, character in ipairs(characters) do
			self:renderCharacterCard(character, Config.Roles.LostSoul, index)
		end
		if characters[1] then
			self:renderAbilityCard(characters[1], #characters + 1)
		end
	elseif tab.id == "Skins" then
		for index, skin in ipairs(Config.Skins) do
			self:renderSkinCard(skin, index)
		end
	elseif tab.id == "Emotions" then
		for index, emotion in ipairs(Config.Emotions) do
			self:renderEmotionCard(emotion, index)
		end
	end
end

return Shop
