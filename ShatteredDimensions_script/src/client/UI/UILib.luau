local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))

local UILib = {}

function UILib.new(className, properties, parent)
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

function UILib.corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corners.Medium
	corner.Parent = parent
	return corner
end

function UILib.stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.Line
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UILib.padding(parent, all, right, bottom, left)
	local padding = Instance.new("UIPadding")
	if right or bottom or left then
		padding.PaddingTop = UDim.new(0, all)
		padding.PaddingRight = UDim.new(0, right or all)
		padding.PaddingBottom = UDim.new(0, bottom or all)
		padding.PaddingLeft = UDim.new(0, left or all)
	else
		padding.PaddingTop = UDim.new(0, all)
		padding.PaddingRight = UDim.new(0, all)
		padding.PaddingBottom = UDim.new(0, all)
		padding.PaddingLeft = UDim.new(0, all)
	end
	padding.Parent = parent
	return padding
end

function UILib.list(parent, direction, padding, horizontalAlignment, verticalAlignment)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, padding or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = verticalAlignment or Enum.VerticalAlignment.Top
	layout.Parent = parent
	return layout
end

function UILib.grid(parent, cellSize, cellPadding)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize or UDim2.fromOffset(250, 330)
	grid.CellPadding = cellPadding or UDim2.fromOffset(14, 14)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = parent
	return grid
end

function UILib.gradient(parent, colorSequence, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

function UILib.label(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for property, value in pairs(properties or {}) do
		defaults[property] = value
	end
	return UILib.new("TextLabel", defaults, parent)
end

function UILib.button(parent, properties)
	local defaults = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Text,
		TextSize = 14,
	}
	for property, value in pairs(properties or {}) do
		defaults[property] = value
	end
	return UILib.new("TextButton", defaults, parent)
end

function UILib.hover(button, restingColor, hoverColor)
	button.BackgroundColor3 = restingColor
	local active = true

	button.MouseEnter:Connect(function()
		if not active then
			return
		end
		TweenService:Create(button, TweenInfo.new(0.14), {
			BackgroundColor3 = hoverColor,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		if not active then
			return
		end
		TweenService:Create(button, TweenInfo.new(0.14), {
			BackgroundColor3 = restingColor,
		}):Play()
	end)

	button.Destroying:Connect(function()
		active = false
	end)
end

function UILib.line(parent, properties)
	local defaults = {
		BackgroundColor3 = Theme.Colors.LineSoft,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}
	for property, value in pairs(properties or {}) do
		defaults[property] = value
	end
	return UILib.new("Frame", defaults, parent)
end

function UILib.avatarUrl(userId, fullBody, size)
	local thumbnailType = if fullBody then "AvatarFullBody" else "AvatarHeadShot"
	return string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", thumbnailType, userId, size, size)
end

function UILib.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

function UILib.tween(instance, properties, duration, easingStyle, delayTime)
	local tween = TweenService:Create(instance, TweenInfo.new(
		duration or 0.2,
		easingStyle or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		-1,
		false,
		delayTime or 0
	), properties)
	tween:Play()
	return tween
end

function UILib.addScale(parent, amount)
	local scale = Instance.new("UIScale")
	scale.Scale = amount or 1
	scale.Parent = parent
	return scale
end

function UILib.makeDot(parent, color, size)
	local dot = UILib.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size or 6, size or 6),
	}, parent)
	UILib.corner(dot, UDim.new(1, 0))
	return dot
end

return UILib
