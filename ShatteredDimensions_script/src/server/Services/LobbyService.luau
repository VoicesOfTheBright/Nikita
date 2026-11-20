local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = require(script.Parent:WaitForChild("MapService"))

local LobbyService = {}

local remotesFolder
local openShopRemote
local notificationRemote

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(70, 73, 79)
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createNpc()
	local existing = Workspace:FindFirstChild("SD_Curator")
	if existing then
		existing:Destroy()
	end

	local root = MapService.getNpcStand()
	local model = Instance.new("Model")
	model.Name = "SD_Curator"

	local legs = makePart(model, "Legs", Vector3.new(3.6, 4, 1.8), root * CFrame.new(0, 2, 0), Color3.fromRGB(43, 45, 52), Enum.Material.Fabric)
	local torso = makePart(model, "Torso", Vector3.new(4.4, 5, 2.1), root * CFrame.new(0, 6, 0), Color3.fromRGB(57, 60, 68), Enum.Material.Fabric)
	local head = makePart(model, "Head", Vector3.new(1.9, 2.1, 1.9), root * CFrame.new(0, 9.8, 0), Color3.fromRGB(178, 174, 163), Enum.Material.SmoothPlastic)
	local hood = makePart(model, "Hood", Vector3.new(2.8, 2.7, 1.4), root * CFrame.new(0, 10, -0.65), Color3.fromRGB(39, 41, 48), Enum.Material.Fabric)
	hood.CanCollide = false

	local leftArm = makePart(model, "LeftArm", Vector3.new(1.2, 4.6, 1.2), root * CFrame.new(-3, 6.1, 0), Color3.fromRGB(55, 58, 66), Enum.Material.Fabric)
	local rightArm = makePart(model, "RightArm", Vector3.new(1.2, 4.6, 1.2), root * CFrame.new(3, 6.1, 0), Color3.fromRGB(55, 58, 66), Enum.Material.Fabric)
	leftArm.CanCollide = false
	rightArm.CanCollide = false
	legs.CanCollide = true
	torso.CanCollide = true
	head.CanCollide = false

	model.PrimaryPart = torso

	-- Лицо: два холодных огонька под капюшоном.
	for _, x in ipairs({ -0.4, 0.4 }) do
		local eye = makePart(
			model,
			"Eye",
			Vector3.new(0.18, 0.12, 0.1),
			root * CFrame.new(x, 10.1, 0.99),
			Color3.fromRGB(89, 231, 239),
			Enum.Material.Neon
		)
		eye.CanCollide = false
	end

	-- Посох.
	local staff = makePart(model, "Staff", Vector3.new(0.25, 9.4, 0.25), root * CFrame.new(4.1, 5.2, 0.6), Color3.fromRGB(88, 78, 64), Enum.Material.Wood)
	staff.CanCollide = false
	local staffTip = makePart(model, "StaffTip", Vector3.new(0.75, 0.75, 0.75), root * CFrame.new(4.1, 10.05, 0.6), Color3.fromRGB(89, 231, 239), Enum.Material.Neon)
	staffTip.Shape = Enum.PartType.Ball
	staffTip.CanCollide = false

	local orb = makePart(model, "Orb", Vector3.new(1.15, 1.15, 1.15), root * CFrame.new(-4.2, 9.1, 0.4), Color3.fromRGB(238, 193, 101), Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local orbLight = Instance.new("PointLight")
	orbLight.Brightness = 2.2
	orbLight.Range = 18
	orbLight.Color = Color3.fromRGB(238, 193, 101)
	orbLight.Shadows = true
	orbLight.Parent = orb

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Говорить"
	prompt.ObjectText = "Хранитель"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = torso

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NpcLabel"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = false
	billboard.MaxDistance = 80
	billboard.Size = UDim2.fromOffset(270, 66)
	billboard.StudsOffset = Vector3.new(0, 3.1, 0)
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = "ХРАНИТЕЛЬ"
	nameLabel.TextColor3 = Color3.fromRGB(238, 193, 101)
	nameLabel.TextSize = 20
	nameLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0, 0.5)
	subLabel.Size = UDim2.new(1, 0, 0.4, 0)
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.Text = "[E]  ОТКРЫТЬ МАГАЗИН"
	subLabel.TextColor3 = Color3.fromRGB(210, 216, 226)
	subLabel.TextSize = 13
	subLabel.Parent = billboard

	-- Вывеска над сценой.
	local sign = makePart(
		model,
		"ShopSign",
		Vector3.new(20, 4.5, 0.8),
		root * CFrame.new(0, 13.8, -3.5) * CFrame.Angles(0, math.rad(0), 0),
		Color3.fromRGB(28, 31, 38),
		Enum.Material.Metal
	)
	sign.CanCollide = false
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.LightInfluence = false
	surface.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Text = "ЛАВКА ХРАНИТЕЛЯ"
	signLabel.TextColor3 = Color3.fromRGB(89, 231, 239)
	signLabel.TextScaled = true
	signLabel.Parent = surface

	model.Parent = Workspace

	prompt.Triggered:Connect(function(player)
		if Workspace:GetAttribute("GamePhase") ~= "Lobby" then
			notificationRemote:FireClient(player, {
				text = "Хранитель закрывает лавку во время раунда.",
				tone = "warning",
			})
			return
		end
		notificationRemote:FireClient(player, {
			text = "Хранитель: «Выбери, кем станешь в следующем измерении».",
			tone = "info",
		})
		openShopRemote:FireClient(player)
	end)

	-- Лёгкая анимация парящей сферы, чтобы NPC не выглядел статуей.
	task.spawn(function()
		local base = orb.CFrame
		local startClock = os.clock()
		while orb.Parent do
			local elapsed = os.clock() - startClock
			orb.CFrame = base * CFrame.new(0, math.sin(elapsed * 1.4) * 0.22, 0) * CFrame.Angles(0, elapsed * 0.5, 0)
			task.wait(0.05)
		end
	end)

	return model
end

function LobbyService.init()
	remotesFolder = ReplicatedStorage:WaitForChild("ShatteredDimensions"):WaitForChild("Remotes")
	openShopRemote = remotesFolder:WaitForChild("OpenShop")
	notificationRemote = remotesFolder:WaitForChild("Notification")
	createNpc()
end

return LobbyService
