local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent.Parent.UI:WaitForChild("Theme"))
local UILib = require(script.Parent.Parent.UI:WaitForChild("UILib"))

local Effects = {}
Effects.__index = Effects

function Effects.new(playerGui, localPlayer)
	local self = setmetatable({}, Effects)
	self.localPlayer = localPlayer

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShatteredDimensions_Effects"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 25
	screenGui.Parent = playerGui
	self.gui = screenGui

	self.damageFlash = UILib.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, screenGui)

	self.hitMarker = UILib.label(screenGui, {
		Text = "✕",
		Font = Theme.Fonts.Bold,
		TextSize = 24,
		TextColor3 = Theme.Colors.Text,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	return self
end

local function getCharacter(player)
	if not player then
		return nil, nil
	end
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character, character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

function Effects:flashDamage()
	self.damageFlash.BackgroundTransparency = 0.48
	UILib.tween(self.damageFlash, { BackgroundTransparency = 1 }, 0.5)
end

function Effects:showHitMarker()
	self.hitMarker.TextTransparency = 0
	self.hitMarker.Position = UDim2.fromScale(0.5, 0.5)
	UILib.tween(self.hitMarker, { TextTransparency = 1 }, 0.24)
end

function Effects:makeSlash(origin, direction)
	for index = 1, 3 do
		local part = Instance.new("Part")
		part.Name = "SD_LocalSlash"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 248, 229)
		part.Transparency = 0.18
		part.Size = Vector3.new(0.08, 0.08, 2.6 + index * 0.5)
		local offset = direction * (1.8 + index * 0.25) + Vector3.new(0, (index - 2) * 0.22, 0)
		local originPoint = origin + offset
		part.CFrame = CFrame.lookAt(originPoint, originPoint + direction)
			* CFrame.Angles(0, 0, math.rad(-34 + index * 20))
		part.Parent = Workspace

		TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			Transparency = 1,
			Size = Vector3.new(0.01, 0.01, 5),
		}):Play()
		Debris:AddItem(part, 0.25)
	end
end

function Effects:makeHitBurst(position)
	for index = 1, 6 do
		local part = Instance.new("Part")
		part.Name = "SD_LocalHit"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(220, 54, 61)
		part.Size = Vector3.new(0.12, 0.12, 0.55)
		part.CFrame = CFrame.new(position) * CFrame.Angles(
			math.rad(math.random(-180, 180)),
			math.rad(math.random(-180, 180)),
			math.rad(math.random(-180, 180))
		)
		part.Parent = Workspace

		local direction = Vector3.new(
			math.random(-10, 10) / 10,
			math.random(2, 10) / 10,
			math.random(-10, 10) / 10
		).Unit
		TweenService:Create(part, TweenInfo.new(0.36, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(position + direction * 2.6),
			Transparency = 1,
		}):Play()
		Debris:AddItem(part, 0.4)
	end
end

function Effects:combat(data)
	if type(data) ~= "table" then
		return
	end

	if data.type == "KnifeSwing" then
		if typeof(data.origin) == "Vector3" and typeof(data.direction) == "Vector3" then
			self:makeSlash(data.origin, data.direction)
		end
	elseif data.type == "KnifeHit" then
		if typeof(data.position) == "Vector3" then
			self:makeHitBurst(data.position)
		end
		if data.attackerId == self.localPlayer.UserId then
			self:showHitMarker()
		end
		if data.victimId == self.localPlayer.UserId then
			self:flashDamage()
		end
	end
end

function Effects:emote(data)
	if type(data) ~= "table" or type(data.emoteId) ~= "string" then
		return
	end

	local emote = Config.getEmotion(data.emoteId)
	if not emote then
		return
	end

	local player = Players:GetPlayerByUserId(data.userId)
	local character, anchor = getCharacter(player)
	if not character or not anchor then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SD_Emote"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 55
	billboard.LightInfluence = false
	billboard.Size = UDim2.fromOffset(270, 72)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = anchor

	local frame = UILib.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 12, 17),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, billboard)
	UILib.corner(frame, Theme.Corners.Medium)
	local stroke = UILib.stroke(frame, emote.accent, 1, 0.2)

	local symbol = UILib.label(frame, {
		Text = emote.symbol,
		Font = Theme.Fonts.Display,
		TextSize = 24,
		TextColor3 = emote.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 9),
		Size = UDim2.fromOffset(38, 38),
	})
	local nameLabel = UILib.label(frame, {
		Text = player.DisplayName,
		Font = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = Theme.Colors.Text,
		Position = UDim2.fromOffset(52, 12),
		Size = UDim2.new(1, -62, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local lineLabel = UILib.label(frame, {
		Text = emote.line,
		Font = Theme.Fonts.Medium,
		TextSize = 9,
		TextColor3 = Theme.Colors.Muted,
		Position = UDim2.fromOffset(52, 30),
		Size = UDim2.new(1, -62, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local timeLabel = UILib.label(frame, {
		Text = emote.name:upper(),
		Font = Theme.Fonts.Bold,
		TextSize = 7,
		TextColor3 = emote.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -80, 0, 48),
		Size = UDim2.fromOffset(70, 12),
	})

	local startOffset = billboard.StudsOffset
	for _, element in ipairs({ frame, symbol, nameLabel, lineLabel, timeLabel }) do
		if element:IsA("TextLabel") then
			element.TextTransparency = 1
		else
			element.BackgroundTransparency = 1
		end
	end
	stroke.Transparency = 1

	TweenService:Create(billboard, TweenInfo.new(0.22), {
		StudsOffset = startOffset + Vector3.new(0, 0.45, 0),
	}):Play()
	TweenService:Create(frame, TweenInfo.new(0.22), { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(symbol, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
	TweenService:Create(nameLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
	TweenService:Create(lineLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
	TweenService:Create(timeLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0.2 }):Play()

	task.delay(2.6, function()
		if not billboard.Parent then
			return
		end
		TweenService:Create(billboard, TweenInfo.new(0.35), {
			StudsOffset = startOffset + Vector3.new(0, 1.1, 0),
		}):Play()
		TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(symbol, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(nameLabel, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(lineLabel, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(timeLabel, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(billboard, 0.45)
	end)
end

return Effects
