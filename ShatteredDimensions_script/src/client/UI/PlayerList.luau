local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local UILib = require(script.Parent:WaitForChild("UILib"))

local PlayerList = {}
PlayerList.__index = PlayerList

local function roleText(role)
	local meta = Config.RoleMeta[role] or Config.RoleMeta.Lobby
	return meta.name
end

local function statusText(playerData)
	if playerData.role == Config.Roles.LostSoul then
		return if playerData.isDead then "УСТРАНЁН" else "ОХОТИТСЯ"
	elseif playerData.role == Config.Roles.Savior then
		return if playerData.isDead then "ПОГИБ" else "ВЫЖИВАЕТ"
	elseif playerData.role == Config.Roles.Spectator then
		return "НАБЛЮДАЕТ"
	end
	return "В ЛОББИ"
end

function PlayerList.new(playerGui, localPlayer, remotes)
	local self = setmetatable({}, PlayerList)
	self.localPlayer = localPlayer
	self.remotes = remotes
	self.isVisible = false
	self.data = nil
	self.players = {}
	self.rows = {}
	self.selectedUserId = nil
	self.signature = ""
	self.blur = nil

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShatteredDimensions_PlayerList"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 40
	screenGui.Parent = playerGui
	self.gui = screenGui

	local root = UILib.new("Frame", {
		Name = "Root",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
	}, screenGui)
	self.root = root

	local backdropButton = UILib.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
	}, root)
	backdropButton.MouseButton1Click:Connect(function()
		self:close()
	end)

	local panel = UILib.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.78),
		BackgroundColor3 = Theme.Colors.BackgroundSoft,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, root)
	UILib.corner(panel, Theme.Corners.Large)
	UILib.stroke(panel, Theme.Colors.Line, 1, 0.25)
	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(760, 520)
	panelConstraint.MaxSize = Vector2.new(1220, 760)
	panelConstraint.Parent = panel
	self.panel = panel

	local topStripe = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.Savior,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 4,
	}, panel)
	local stripeGradient = Instance.new("UIGradient")
	stripeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Savior),
		ColorSequenceKeypoint.new(0.5, Theme.Colors.Line),
		ColorSequenceKeypoint.new(1, Theme.Colors.LostSoul),
	})
	stripeGradient.Parent = topStripe

	local header = UILib.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 5,
	}, panel)
	UILib.label(header, {
		Text = "СПИСОК ДУШ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Savior,
		Position = UDim2.fromOffset(22, 13),
		Size = UDim2.new(0.5, 0, 0, 13),
		ZIndex = 6,
	})
	UILib.label(header, {
		Text = "УЧАСТНИКИ",
		Font = Theme.Fonts.Display,
		TextSize = 25,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(22, 26),
		Size = UDim2.new(0.5, 0, 0, 34),
		ZIndex = 6,
	})
	self.countLabel = UILib.label(header, {
		Text = "0 В СЕТИ",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(120, 20),
		ZIndex = 6,
	})

	local close = UILib.button(header, {
		Name = "Close",
		Text = "✕",
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		TextColor3 = Theme.Colors.Muted,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 7,
	})
	UILib.corner(close, Theme.Corners.Small)
	UILib.hover(close, Theme.Colors.PanelRaised, Theme.Colors.PanelHover)
	close.MouseButton1Click:Connect(function()
		self:close()
	end)

	UILib.line(panel, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 5,
	})

	local content = UILib.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 73),
		Size = UDim2.new(1, 0, 1, -73),
		ZIndex = 4,
	}, panel)

	-- Левая колонка со списком.
	local listColumn = UILib.new("Frame", {
		Name = "ListColumn",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.55, 0, 1, 0),
		ZIndex = 4,
	}, content)
	self.listColumn = listColumn
	UILib.padding(listColumn, 18, 14, 18, 20)

	local scroller = UILib.new("ScrollingFrame", {
		Name = "Players",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Colors.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 5,
	}, listColumn)
	self.scroller = scroller
	UILib.list(scroller, Enum.FillDirection.Vertical, 6)

	self.emptyLabel = UILib.label(listColumn, {
		Text = "ПОИСК ДУШ...",
		Font = Theme.Fonts.Medium,
		TextSize = 11,
		TextColor3 = Theme.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 20),
		Visible = false,
		ZIndex = 6,
	})

	local divider = UILib.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.Colors.LineSoft,
		BorderSizePixel = 0,
		Position = UDim2.new(0.55, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 5,
	}, content)

	-- Правая колонка.
	local detail = UILib.new("Frame", {
		Name = "Details",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		Position = UDim2.new(0.55, 1, 0, 0),
		Size = UDim2.new(0.45, -1, 1, 0),
		ClipsDescendants = true,
		ZIndex = 4,
	}, content)
	self.detail = detail
	UILib.padding(detail, 20)
	local detailHeader = UILib.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 5,
	}, detail)
	self.detailName = UILib.label(detailHeader, {
		Text = "ВЫБЕРИТЕ УЧАСТНИКА",
		Font = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = Theme.Colors.Text,
		Size = UDim2.new(1, -80, 0, 30),
		ZIndex = 6,
	})
	self.detailUsername = UILib.label(detailHeader, {
		Text = "нажмите на строку слева",
		Font = Theme.Fonts.Medium,
		TextSize = 11,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 6,
	})
	self.statusPill = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(102, 24),
		ZIndex = 6,
	}, detailHeader)
	UILib.corner(self.statusPill, Theme.Corners.Pill)
	self.statusLabel = UILib.label(self.statusPill, {
		Text = "В ЛОББИ",
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
	})

	local statBar = UILib.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 48),
		ZIndex = 5,
	}, detail)
	UILib.corner(statBar, Theme.Corners.Small)
	UILib.stroke(statBar, Theme.Colors.LineSoft, 1, 0.3)
	UILib.label(statBar, {
		Text = "ОБЩЕЕ ВРЕМЯ В ИГРЕ",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		Position = UDim2.fromOffset(13, 7),
		Size = UDim2.new(0.55, -16, 0, 12),
		ZIndex = 6,
	})
	self.playtimeLabel = UILib.label(statBar, {
		Text = "0 сек",
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(13, 20),
		Size = UDim2.new(0.65, -16, 0, 20),
		ZIndex = 6,
	})
	self.currentRoleLabel = UILib.label(statBar, {
		Text = "—",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.55, 0, 0, 16),
		Size = UDim2.new(0.45, -13, 0, 20),
		ZIndex = 6,
	})

	UILib.label(detail, {
		Text = "ТЕКУЩИЕ ОБРАЗЫ",
		Font = Theme.Fonts.Bold,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 5,
	})

	local cards = UILib.new("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 1, -220),
		ZIndex = 5,
	}, detail)
	self.cards = cards
	UILib.list(cards, Enum.FillDirection.Horizontal, 10)

	local function makeRenderCard(parent, layoutOrder, role, accent)
		local card = UILib.new("Frame", {
			BackgroundColor3 = Theme.Colors.BackgroundSoft,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, -5, 1, 0),
			ZIndex = 6,
		}, parent)
		card.LayoutOrder = layoutOrder
		UILib.corner(card, Theme.Corners.Medium)
		local stroke = UILib.stroke(card, Theme.Colors.Line, 1, 0.2)
		card.ClipsDescendants = true

		local roleBar = UILib.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 8,
		}, card)

		local roleLabel = UILib.label(card, {
			Text = if role == Config.Roles.LostSoul then "ПОТЕРЯННАЯ ДУША" else "ВЫЖИВШИЙ",
			Font = Theme.Fonts.Bold,
			TextSize = 8,
			TextColor3 = accent,
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.new(1, -20, 0, 12),
			ZIndex = 8,
		})

		local imageHolder = UILib.new("Frame", {
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 1, -106),
			ClipsDescendants = true,
			ZIndex = 7,
		}, card)
		UILib.corner(imageHolder, Theme.Corners.Small)
		local fallback = UILib.label(imageHolder, {
			Text = "?",
			Font = Theme.Fonts.Display,
			TextSize = 42,
			TextColor3 = Theme.Colors.Line,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
		})
		local image = UILib.new("ImageLabel", {
			Name = "Render",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = 9,
		}, imageHolder)
		local shade = UILib.new("Frame", {
			BackgroundColor3 = Theme.Colors.BackgroundSoft,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
		}, imageHolder)
		local shadeGradient = Instance.new("UIGradient")
		shadeGradient.Rotation = 90
		shadeGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		shadeGradient.Parent = shade

		local activeBadge = UILib.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 34),
			Size = UDim2.fromOffset(52, 16),
			Visible = false,
			ZIndex = 12,
		}, card)
		UILib.corner(activeBadge, Theme.Corners.Pill)
		local activeText = UILib.label(activeBadge, {
			Text = "В ИГРЕ",
			Font = Theme.Fonts.Bold,
			TextSize = 7,
			TextColor3 = Theme.Colors.Background,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 13,
		})

		local name = UILib.label(card, {
			Text = "—",
			Font = Theme.Fonts.Bold,
			TextSize = 12,
			TextColor3 = Theme.Colors.Text,
			Position = UDim2.new(0, 10, 1, -72),
			Size = UDim2.new(1, -20, 0, 17),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
		})
		local skin = UILib.label(card, {
			Text = "—",
			Font = Theme.Fonts.Medium,
			TextSize = 10,
			TextColor3 = Theme.Colors.Muted,
			Position = UDim2.new(0, 10, 1, -54),
			Size = UDim2.new(1, -20, 0, 15),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
		})
		local selected = UILib.label(card, {
			Text = "ВЫБРАНО",
			Font = Theme.Fonts.Bold,
			TextSize = 7,
			TextColor3 = Theme.Colors.Dim,
			Position = UDim2.new(0, 10, 1, -34),
			Size = UDim2.new(1, -20, 0, 12),
			ZIndex = 8,
		})

		return {
			card = card,
			stroke = stroke,
			roleLabel = roleLabel,
			image = image,
			imageColor = image,
			fallback = fallback,
			name = name,
			skin = skin,
			selected = selected,
			activeBadge = activeBadge,
			activeText = activeText,
			role = role,
			accent = accent,
		}
	end

	self.lostCard = makeRenderCard(cards, 1, Config.Roles.LostSoul, Theme.Colors.LostSoul)
	self.saviorCard = makeRenderCard(cards, 2, Config.Roles.Savior, Theme.Colors.Savior)

	self.footerLabel = UILib.label(detail, {
		Text = "TAB — ЗАКРЫТЬ",
		Font = Theme.Fonts.Bold,
		TextSize = 8,
		TextColor3 = Theme.Colors.Dim,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 5,
	})

	-- Затемнение фона.
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "SD_PlayerListBlur"
	self.blur.Size = 0
	self.blur.Enabled = false
	self.blur.Parent = Lighting

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed and input.KeyCode ~= Enum.KeyCode.Tab then
			if self.isVisible and input.KeyCode == Enum.KeyCode.Escape then
				self:close()
			end
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode == Enum.KeyCode.Tab then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isVisible then
			self:close()
		end
	end)

	self.remotes.PlayerListData.OnClientEvent:Connect(function(data)
		self:setData(data)
	end)

	return self
end

function PlayerList:isOpen()
	return self.isVisible
end

function PlayerList:open()
	if self.isVisible then
		return
	end
	self.isVisible = true
	self.root.Visible = true
	self.blur.Enabled = true
	UILib.tween(self.blur, { Size = 14 }, 0.25)
	self.root.BackgroundTransparency = 0.6
	UILib.tween(self.root, { BackgroundTransparency = 0.38 }, 0.2)
	self.remotes.RequestPlayerList:FireServer()
end

function PlayerList:close()
	if not self.isVisible then
		return
	end
	self.isVisible = false
	self.root.Visible = false
	UILib.tween(self.blur, { Size = 0 }, 0.2)
	task.delay(0.22, function()
		if not self.isVisible then
			self.blur.Enabled = false
		end
	end)
end

function PlayerList:toggle()
	if self.isVisible then
		self:close()
	else
		self:open()
	end
end

function PlayerList:setData(data)
	if type(data) ~= "table" or type(data.players) ~= "table" then
		return
	end
	self.data = data
	self.players = data.players
	self.countLabel.Text = string.format("%d В СЕТИ", #self.players)

	if #self.players == 0 then
		self.emptyLabel.Visible = true
		self.scroller.Visible = false
	else
		self.emptyLabel.Visible = false
		self.scroller.Visible = true
	end

	local selectedExists = false
	if self.selectedUserId then
		for _, playerData in ipairs(self.players) do
			if playerData.userId == self.selectedUserId then
				selectedExists = true
				break
			end
		end
	end
	if not selectedExists then
		self.selectedUserId = self.players[1] and self.players[1].userId or nil
	end

	local signatureParts = {}
	for _, playerData in ipairs(self.players) do
		table.insert(signatureParts, string.format(
			"%d:%s:%s:%s:%s",
			playerData.userId,
			playerData.role,
			tostring(playerData.isDead),
			playerData.displayName,
			tostring(playerData.inRound)
		))
	end
	local signature = table.concat(signatureParts, "|")
	if signature ~= self.signature then
		self.signature = signature
		self:renderRows()
	else
		self:applySelectionStyles()
	end
	self:updateDetails()
end

function PlayerList:renderRows()
	table.clear(self.rows)
	for _, child in ipairs(self.scroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, playerData in ipairs(self.players) do
		local roleColor = Theme.roleColor(playerData.role)
		local row = UILib.button(self.scroller, {
			Name = "Player_" .. tostring(playerData.userId),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(1, 0, 0, 62),
			LayoutOrder = index,
			ZIndex = 6,
		})
		UILib.corner(row, Theme.Corners.Small)
		local stroke = UILib.stroke(row, Theme.Colors.LineSoft, 1, 0.4)

		local avatarHolder = UILib.new("Frame", {
			BackgroundColor3 = Theme.Colors.PanelRaised,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(46, 46),
			ClipsDescendants = true,
			ZIndex = 7,
		}, row)
		UILib.corner(avatarHolder, Theme.Corners.Small)
		local initial = UILib.label(avatarHolder, {
			Text = string.upper(string.sub(playerData.displayName, 1, 1)),
			Font = Theme.Fonts.Display,
			TextSize = 18,
			TextColor3 = Theme.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
		})
		local avatar = UILib.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = UILib.avatarUrl(playerData.userId, false, 150),
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 9,
		}, avatarHolder)

		local onlineDot = UILib.makeDot(row, Theme.Colors.Success, 5)
		onlineDot.Position = UDim2.fromOffset(9, 54)
		onlineDot.ZIndex = 10

		local nameLabel = UILib.label(row, {
			Text = playerData.displayName,
			Font = Theme.Fonts.Bold,
			TextSize = 13,
			TextColor3 = Theme.Colors.Text,
			Position = UDim2.fromOffset(65, 10),
			Size = UDim2.new(1, -135, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		})
		local usernameLabel = UILib.label(row, {
			Text = "@" .. playerData.username,
			Font = Theme.Fonts.Medium,
			TextSize = 9,
			TextColor3 = Theme.Colors.Dim,
			Position = UDim2.fromOffset(65, 28),
			Size = UDim2.new(1, -135, 0, 13),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		})
		local roleLabel = UILib.label(row, {
			Text = roleText(playerData.role) .. "  //  " .. statusText(playerData),
			Font = Theme.Fonts.Bold,
			TextSize = 8,
			TextColor3 = roleColor,
			Position = UDim2.fromOffset(65, 42),
			Size = UDim2.new(1, -135, 0, 12),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		})

		local arrow = UILib.label(row, {
			Text = "›",
			Font = Theme.Fonts.Bold,
			TextSize = 22,
			TextColor3 = Theme.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(18, 28),
			ZIndex = 7,
		})

		local roleAccent = UILib.new("Frame", {
			BackgroundColor3 = roleColor,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, -16),
			Position = UDim2.fromOffset(0, 8),
			ZIndex = 10,
		}, row)
		UILib.corner(roleAccent, Theme.Corners.Pill)

		row.MouseEnter:Connect(function()
			if self.selectedUserId ~= playerData.userId then
				UILib.tween(row, { BackgroundColor3 = Theme.Colors.PanelHover }, 0.14)
			end
		end)
		row.MouseLeave:Connect(function()
			if self.selectedUserId ~= playerData.userId then
				UILib.tween(row, { BackgroundColor3 = Theme.Colors.Panel }, 0.14)
			end
		end)
		row.MouseButton1Click:Connect(function()
			self.selectedUserId = playerData.userId
			self:applySelectionStyles()
			self:updateDetails()
		end)

		self.rows[playerData.userId] = {
			row = row,
			stroke = stroke,
			roleAccent = roleAccent,
			nameLabel = nameLabel,
			usernameLabel = usernameLabel,
			roleLabel = roleLabel,
			initial = initial,
			avatar = avatar,
			onlineDot = onlineDot,
			arrow = arrow,
			roleColor = roleColor,
			data = playerData,
		}
	end

	self:applySelectionStyles()
end

function PlayerList:applySelectionStyles()
	for userId, entry in pairs(self.rows) do
		if userId == self.selectedUserId then
			entry.row.BackgroundColor3 = Theme.Colors.PanelHover
			entry.stroke.Color = entry.roleColor
			entry.stroke.Transparency = 0.25
			entry.arrow.TextColor3 = entry.roleColor
		else
			entry.row.BackgroundColor3 = Theme.Colors.Panel
			entry.stroke.Color = Theme.Colors.LineSoft
			entry.stroke.Transparency = 0.4
			entry.arrow.TextColor3 = Theme.Colors.Dim
		end
	end
end

function PlayerList:updateRenderCard(card, playerData, role)
	local isLost = role == Config.Roles.LostSoul
	local characterId = if isLost then playerData.lostSoulId else playerData.saviorId
	local skinId = if isLost then playerData.lostSoulSkinId else playerData.saviorSkinId
	local character = Config.getCharacter(characterId)
	local skin = Config.getSkin(skinId) or Config.getDefaultSkin(role)
	local accent = skin and skin.accent or Theme.roleColor(role)

	card.stroke.Color = accent
	card.stroke.Transparency = 0.55
	card.roleLabel.TextColor3 = accent
	card.activeBadge.BackgroundColor3 = accent
	card.image.Image = UILib.avatarUrl(playerData.userId, true, 420)
	card.image.ImageColor3 = skin and skin.previewTint or Color3.fromRGB(255, 255, 255)
	card.fallback.Text = string.upper(string.sub(playerData.displayName, 1, 1))
	card.name.Text = character and character.name or "НЕИЗВЕСТНО"
	card.skin.Text = skin and skin.name or "ОРИГИНАЛ"
	card.name.TextColor3 = Theme.Colors.Text
	card.skin.TextColor3 = accent

	local active = playerData.inRound and playerData.role == role and not playerData.isDead
	card.activeBadge.Visible = active
	card.activeText.Text = "В ИГРЕ"
	if playerData.isDead and playerData.role == role then
		card.activeBadge.Visible = true
		card.activeBadge.BackgroundColor3 = Theme.Colors.Dim
		card.activeText.Text = "ПОГИБ"
	end

	if active then
		card.stroke.Transparency = 0.1
	else
		card.stroke.Transparency = 0.55
	end
end

function PlayerList:updateDetails()
	if not self.data or not self.selectedUserId then
		self.detailName.Text = "ВЫБЕРИТЕ УЧАСТНИКА"
		self.detailUsername.Text = "нажмите на строку слева"
		self.playtimeLabel.Text = "0 сек"
		self.currentRoleLabel.Text = "—"
		self.statusLabel.Text = "—"
		self.statusPill.BackgroundColor3 = Theme.Colors.PanelRaised
		self.statusLabel.TextColor3 = Theme.Colors.Muted
		for _, card in ipairs({ self.lostCard, self.saviorCard }) do
			card.image.Image = ""
			card.name.Text = "—"
			card.skin.Text = "—"
			card.activeBadge.Visible = false
		end
		return
	end

	local selected = nil
	for _, playerData in ipairs(self.players) do
		if playerData.userId == self.selectedUserId then
			selected = playerData
			break
		end
	end
	if not selected then
		return
	end

	self.detailName.Text = selected.displayName
	if selected.userId == self.localPlayer.UserId then
		self.detailName.Text = selected.displayName .. "  (ВЫ)"
	end
	self.detailUsername.Text = "@" .. selected.username
	self.playtimeLabel.Text = Util.formatPlaytime(selected.totalPlaySeconds or 0)
	self.currentRoleLabel.Text = roleText(selected.role)
	self.currentRoleLabel.TextColor3 = Theme.roleColor(selected.role)

	local roleColor = Theme.roleColor(selected.role)
	self.statusPill.BackgroundColor3 = roleColor
	self.statusLabel.TextColor3 = Theme.Colors.Background
	self.statusLabel.Text = statusText(selected)

	self:updateRenderCard(self.lostCard, selected, Config.Roles.LostSoul)
	self:updateRenderCard(self.saviorCard, selected, Config.Roles.Savior)
end

return PlayerList
