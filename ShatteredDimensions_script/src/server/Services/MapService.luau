local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ContentService = require(script.Parent:WaitForChild("ContentService"))

local MapService = {}

local MAP_ORIGIN = Vector3.new(0, 0, 4000)
local LOBBY_ORIGIN = Vector3.new(0, 0, 0)
local lobbyModel = nil
local roundModel = nil
local lastMapId = nil
local random = Random.new(os.clock() * 100000)

local PALETTE = {
	floor = Color3.fromRGB(80, 83, 88),
	floorDark = Color3.fromRGB(53, 56, 61),
	wall = Color3.fromRGB(68, 71, 77),
	wallLight = Color3.fromRGB(105, 108, 114),
	wallDark = Color3.fromRGB(42, 44, 49),
	metal = Color3.fromRGB(118, 122, 129),
	accent = Color3.fromRGB(91, 225, 235),
	danger = Color3.fromRGB(235, 78, 88),
	lamp = Color3.fromRGB(255, 236, 194),
}

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or PALETTE.wall
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addPointLight(parent, brightness, range, color)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color or PALETTE.lamp
	light.Shadows = true
	light.Parent = parent
	return light
end

local function addSurfaceText(part, text, color, subtitle)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Sign"
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = false
	surface.AlwaysOnTop = false
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 45
	surface.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, if subtitle then 0.62 else 0.8)
	label.Position = UDim2.fromScale(0, if subtitle then 0.08 else 0.1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(234, 240, 247)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface

	if subtitle then
		local lower = Instance.new("TextLabel")
		lower.Name = "Subtitle"
		lower.BackgroundTransparency = 1
		lower.Size = UDim2.fromScale(0.9, 0.22)
		lower.Position = UDim2.fromScale(0.05, 0.67)
		lower.Font = Enum.Font.GothamMedium
		lower.Text = subtitle
		lower.TextColor3 = Color3.fromRGB(145, 153, 166)
		lower.TextScaled = true
		lower.Parent = surface
	end

	return surface
end

local function createLamp(parent, cframe)
	local base = makePart(parent, "LampBase", Vector3.new(1.2, 0.6, 1.2), cframe, PALETTE.wallDark, Enum.Material.Metal)
	local pole = makePart(parent, "LampPole", Vector3.new(0.35, 11, 0.35), cframe * CFrame.new(0, 5.6, 0), PALETTE.metal, Enum.Material.Metal)
	local head = makePart(parent, "LampHead", Vector3.new(1.3, 0.45, 1.3), cframe * CFrame.new(0, 11.2, 0), Color3.fromRGB(255, 239, 198), Enum.Material.Neon)
	head.CanCollide = false
	addPointLight(head, 1.6, 32, PALETTE.lamp)
	return base, pole, head
end

local function createLobby()
	if lobbyModel then
		lobbyModel:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "SD_Lobby"
	lobbyModel = model

	local center = LOBBY_ORIGIN
	local floor = makePart(
		model,
		"LobbyFloor",
		Vector3.new(190, 2, 190),
		CFrame.new(center + Vector3.new(0, 0, 0)),
		PALETTE.floor,
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor

	-- Внешние стены-парапеты.
	makePart(model, "WallNorth", Vector3.new(190, 8, 2), CFrame.new(center + Vector3.new(0, 5, -95)), PALETTE.wallDark)
	makePart(model, "WallSouth", Vector3.new(190, 8, 2), CFrame.new(center + Vector3.new(0, 5, 95)), PALETTE.wallDark)
	makePart(model, "WallEast", Vector3.new(2, 8, 190), CFrame.new(center + Vector3.new(95, 5, 0)), PALETTE.wallDark)
	makePart(model, "WallWest", Vector3.new(2, 8, 190), CFrame.new(center + Vector3.new(-95, 5, 0)), PALETTE.wallDark)

	-- Световые полосы на полу.
	local stripeOne = makePart(model, "StripeOne", Vector3.new(150, 0.12, 0.4), CFrame.new(center + Vector3.new(0, 1.08, 18)), PALETTE.accent, Enum.Material.Neon)
	stripeOne.CanCollide = false
	local stripeTwo = makePart(model, "StripeTwo", Vector3.new(150, 0.12, 0.4), CFrame.new(center + Vector3.new(0, 1.08, 22)), PALETTE.accent, Enum.Material.Neon)
	stripeTwo.CanCollide = false
	stripeTwo.Transparency = 0.45

	-- Спавн лобби.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 1.6, 42))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(113, 117, 124)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model

	-- Сцена и арка Хранителя.
	makePart(model, "NpcStage", Vector3.new(34, 3, 23), CFrame.new(center + Vector3.new(0, 2.5, -16)), PALETTE.floorDark, Enum.Material.Slate)
	makePart(model, "NpcStageStep", Vector3.new(20, 1.5, 5), CFrame.new(center + Vector3.new(0, 1.75, -2.5)), PALETTE.wallLight, Enum.Material.Concrete)
	makePart(model, "NpcStageStepLower", Vector3.new(24, 0.75, 4), CFrame.new(center + Vector3.new(0, 1.38, 0.5)), PALETTE.wall, Enum.Material.Concrete)

	local accentLeft = makePart(model, "StageAccentL", Vector3.new(1, 0.25, 21), CFrame.new(center + Vector3.new(-16.5, 4.1, -16)), PALETTE.accent, Enum.Material.Neon)
	accentLeft.CanCollide = false
	local accentRight = makePart(model, "StageAccentR", Vector3.new(1, 0.25, 21), CFrame.new(center + Vector3.new(16.5, 4.1, -16)), PALETTE.accent, Enum.Material.Neon)
	accentRight.CanCollide = false

	makePart(model, "ArchLeft", Vector3.new(2, 21, 3), CFrame.new(center + Vector3.new(-30, 11.5, -35)), PALETTE.wallDark, Enum.Material.Concrete)
	makePart(model, "ArchRight", Vector3.new(2, 21, 3), CFrame.new(center + Vector3.new(30, 11.5, -35)), PALETTE.wallDark, Enum.Material.Concrete)
	makePart(model, "ArchTop", Vector3.new(62, 3, 3), CFrame.new(center + Vector3.new(0, 23, -35)), PALETTE.wallDark, Enum.Material.Concrete)

	local signPart = makePart(
		model,
		"LobbySign",
		Vector3.new(54, 14, 1),
		CFrame.new(center + Vector3.new(0, 13, -92)) * CFrame.Angles(0, math.rad(180), 0),
		PALETTE.wallDark,
		Enum.Material.Metal
	)
	signPart.CanCollide = false
	addSurfaceText(signPart, "SHATTERED DIMENSIONS", PALETTE.accent, "АСИММЕТРИЧНЫЙ ХОРРОР  //  ЛОББИ")

	-- Скамейки и укрытия по краям.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 68
		local bench = makePart(model, "Bench", Vector3.new(16, 1, 4), CFrame.new(center + Vector3.new(x, 2.5, 36)), PALETTE.wall, Enum.Material.WoodPlanks)
		bench.CanCollide = true
		makePart(model, "BenchLegA", Vector3.new(1, 2, 1), CFrame.new(center + Vector3.new(x - 6, 1.5, 36)), PALETTE.wallDark, Enum.Material.Metal)
		makePart(model, "BenchLegB", Vector3.new(1, 2, 1), CFrame.new(center + Vector3.new(x + 6, 1.5, 36)), PALETTE.wallDark, Enum.Material.Metal)

		local back = makePart(model, "BenchBack", Vector3.new(16, 4, 0.6), CFrame.new(center + Vector3.new(x, 4.5, 38)), PALETTE.wallDark, Enum.Material.WoodPlanks)
		back.CanCollide = false
	end

	for _, x in ipairs({ -78, 78 }) do
		for _, z in ipairs({ -72, 70 }) do
			createLamp(model, CFrame.new(center + Vector3.new(x, 1, z)))
		end
	end

	-- Низкие баррикады, чтобы лобби не выглядело пустым.
	local barricadeOne = makePart(model, "BarricadeA", Vector3.new(28, 4.5, 1.5), CFrame.new(center + Vector3.new(-55, 3.25, -45)), PALETTE.wallLight, Enum.Material.Concrete)
	barricadeOne.CFrame *= CFrame.Angles(0, math.rad(18), 0)
	local barricadeTwo = makePart(model, "BarricadeB", Vector3.new(28, 4.5, 1.5), CFrame.new(center + Vector3.new(55, 3.25, -45)), PALETTE.wallLight, Enum.Material.Concrete)
	barricadeTwo.CFrame *= CFrame.Angles(0, math.rad(-18), 0)

	model.Parent = Workspace
end

local function buildBoundary(model, origin, name)
	makePart(model, "BoundaryNorth", Vector3.new(280, 24, 2), CFrame.new(origin + Vector3.new(0, 12, -140)), PALETTE.wallDark)
	makePart(model, "BoundarySouth", Vector3.new(280, 24, 2), CFrame.new(origin + Vector3.new(0, 12, 140)), PALETTE.wallDark)
	makePart(model, "BoundaryEast", Vector3.new(2, 24, 280), CFrame.new(origin + Vector3.new(140, 12, 0)), PALETTE.wallDark)
	makePart(model, "BoundaryWest", Vector3.new(2, 24, 280), CFrame.new(origin + Vector3.new(-140, 12, 0)), PALETTE.wallDark)

	local sign = makePart(model, "MapSign", Vector3.new(48, 12, 1), CFrame.new(origin + Vector3.new(0, 15, 138.5)), PALETTE.wallDark, Enum.Material.Metal)
	sign.CanCollide = false
	addSurfaceText(sign, name, PALETTE.accent, "ЗОНА 04  //  НЕ ОСТАНАВЛИВАЙТЕСЬ")
end

local function addCrate(model, origin, x, z, size, rotation)
	local crate = makePart(
		model,
		"Crate",
		Vector3.new(size, size, size),
		CFrame.new(origin + Vector3.new(x, 1 + size / 2, z)) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		PALETTE.wallLight,
		Enum.Material.WoodPlanks
	)
	local trim = Instance.new("SurfaceGui")
	trim.Face = Enum.NormalId.Front
	trim.LightInfluence = false
	trim.Parent = crate
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = PALETTE.wallDark
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(0.7, 0.08)
	frame.Position = UDim2.fromScale(0.15, 0.45)
	frame.Parent = trim
	return crate
end

local function addWallSegment(model, origin, x, z, width, depth, height, rotation)
	local wall = makePart(
		model,
		"Wall",
		Vector3.new(width, height, depth),
		CFrame.new(origin + Vector3.new(x, height / 2 + 1, z)) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		PALETTE.wall,
		Enum.Material.Concrete
	)
	return wall
end

local function buildGrayPolygon(model, origin)
	-- Центральное бетонное строение с двумя выходами.
	addWallSegment(model, origin, 0, -22, 24, 2, 13, 0)
	addWallSegment(model, origin, -20, -22, 16, 2, 13, 0)
	addWallSegment(model, origin, 20, -22, 16, 2, 13, 0)
	addWallSegment(model, origin, 0, 22, 24, 2, 13, 0)
	addWallSegment(model, origin, -20, 22, 16, 2, 13, 0)
	addWallSegment(model, origin, 20, 22, 16, 2, 13, 0)
	addWallSegment(model, origin, -32, 0, 2, 24, 13, 0)
	addWallSegment(model, origin, 32, 0, 2, 24, 13, 0)

	for _, corner in ipairs({ { -26, -28 }, { 26, -28 }, { -26, 28 }, { 26, 28 } }) do
		makePart(
			model,
			"Pillar",
			Vector3.new(4, 15, 4),
			CFrame.new(origin + Vector3.new(corner[1], 8.5, corner[2])),
			PALETTE.wallLight,
			Enum.Material.Concrete
		)
	end

	-- Внутренние укрытия.
	addWallSegment(model, origin, -12, -5, 1.5, 18, 5, 0)
	addWallSegment(model, origin, 13, 9, 18, 1.5, 5, 0)
	addCrate(model, origin, 8, -7, 7, 17)
	addCrate(model, origin, 15, -3, 5, -22)
	addCrate(model, origin, -16, 12, 8, 8)
	addCrate(model, origin, -5, 11, 4, 31)

	local scatter = {
		{ -72, -65, 7, 15 }, { -88, -25, 6, -20 }, { -70, 34, 9, 8 }, { -94, 72, 5, 28 },
		{ 78, -63, 8, -13 }, { 93, -22, 5, 19 }, { 68, 39, 7, 41 }, { 91, 77, 6, -9 },
		{ -34, -78, 5, 12 }, { 28, -87, 9, 25 }, { -42, 80, 6, -26 }, { 43, 87, 7, 4 },
		{ -60, 4, 4, 33 }, { 58, -4, 5, -31 },
	}

	for _, data in ipairs(scatter) do
		addCrate(model, origin, data[1], data[2], data[3], data[4])
	end
end

local function buildLabyrinth(model, origin)
	local walls = {
		{ 0, -75, 140, 2, 12, 0 },
		{ -35, -75, 2, 55, 11, 0 },
		{ 30, -50, 2, 70, 11, 0 },
		{ 0, -20, 120, 2, 12, 0 },
		{ -50, 8, 2, 60, 11, 0 },
		{ 60, 12, 2, 90, 11, 0 },
		{ 10, 35, 120, 2, 13, 0 },
		{ -30, 60, 2, 55, 12, 0 },
		{ 35, 65, 100, 2, 10, 0 },
		{ 75, -30, 2, 45, 9, 0 },
		{ -75, 40, 2, 50, 10, 0 },
		{ -5, 92, 75, 2, 9, 0 },
	}

	for _, wall in ipairs(walls) do
		addWallSegment(model, origin, wall[1], wall[2], wall[3], wall[4], wall[5], wall[6])
	end

	for _, pillar in ipairs({
		{ -20, -42 }, { 20, -42 }, { -20, 78 }, { 20, 78 }, { 85, 82 }, { -85, 82 },
	}) do
		makePart(
			model,
			"Pillar",
			Vector3.new(5, 14, 5),
			CFrame.new(origin + Vector3.new(pillar[1], 8, pillar[2])),
			PALETTE.wallDark,
			Enum.Material.Concrete
		)
	end

	for _, crate in ipairs({
		{ -58, -45, 6, 14 }, { 55, -60, 7, -18 }, { -15, -50, 5, 28 },
		{ 48, 18, 8, 4 }, { -38, 26, 7, -26 }, { 20, 60, 5, 19 },
		{ -62, 84, 6, 37 }, { 78, 52, 5, -7 },
	}) do
		addCrate(model, origin, crate[1], crate[2], crate[3], crate[4])
	end

	createLamp(model, CFrame.new(origin + Vector3.new(-115, 1, -90)))
	createLamp(model, CFrame.new(origin + Vector3.new(110, 1, 95)))
end

local function buildAshYard(model, origin)
	local containers = {
		{ -62, -20, 26, 9, 9, 0 },
		{ -58, 28, 26, 9, 9, 0 },
		{ 62, -22, 26, 9, 9, 0 },
		{ 67, 26, 26, 9, 9, 0 },
		{ -4, 65, 32, 9, 9, 0 },
		{ -12, -58, 9, 9, 26, 0 },
		{ 25, -22, 9, 9, 26, 0 },
	}

	for index, data in ipairs(containers) do
		local containerColor = if index % 2 == 0 then Color3.fromRGB(92, 75, 70) else Color3.fromRGB(74, 82, 88)
		local container = makePart(
			model,
			"Container" .. tostring(index),
			Vector3.new(data[3], data[4], data[5]),
			CFrame.new(origin + Vector3.new(data[1], 5.5, data[2])) * CFrame.Angles(0, math.rad(data[6]), 0),
			containerColor,
			Enum.Material.CorrodedMetal
		)
		container.CanCollide = true

		local door = makePart(
			model,
			"ContainerDoor",
			Vector3.new(data[3] * 0.8, data[4] * 0.7, 0.3),
			container.CFrame * CFrame.new(0, 0, data[5] / 2 + 0.2),
			PALETTE.wallDark,
			Enum.Material.Metal
		)
		door.CanCollide = false
	end

	addWallSegment(model, origin, -20, 0, 2, 48, 8, 0)
	addWallSegment(model, origin, 30, 0, 2, 48, 8, 0)
	addWallSegment(model, origin, 0, -38, 38, 2, 6, 0)

	local towerBase = makePart(model, "TowerBase", Vector3.new(14, 4, 14), CFrame.new(origin + Vector3.new(0, 3, 100)), PALETTE.wallDark, Enum.Material.Concrete)
	makePart(model, "TowerMiddle", Vector3.new(10, 7, 10), CFrame.new(origin + Vector3.new(0, 8.5, 100)), PALETTE.wall, Enum.Material.Concrete)
	makePart(model, "TowerPlatform", Vector3.new(16, 1, 16), CFrame.new(origin + Vector3.new(0, 12.5, 100)), PALETTE.wallLight, Enum.Material.Metal)
	createLamp(model, CFrame.new(origin + Vector3.new(0, 13, 100)))

	for _, crate in ipairs({
		{ -100, -110, 6, 11 }, { 106, -104, 7, -8 }, { -110, 20, 5, 22 },
		{ 105, 62, 8, 0 }, { 72, 105, 5, 32 }, { -80, 104, 6, -12 },
	}) do
		addCrate(model, origin, crate[1], crate[2], crate[3], crate[4])
	end

	createLamp(model, CFrame.new(origin + Vector3.new(-115, 1, 115)))
	createLamp(model, CFrame.new(origin + Vector3.new(115, 1, -115)))
end

local blueprints = {
	{
		id = "gray_polygon",
		name = "СЕРЫЙ ПОЛИГОН",
		subtitle = "Бетон. Туман. Ничего лишнего.",
		build = buildGrayPolygon,
		lighting = {
			ClockTime = 1.1,
			Brightness = 0.55,
			FogEnd = 245,
			FogStart = 25,
			Ambient = Color3.fromRGB(20, 23, 30),
			OutdoorAmbient = Color3.fromRGB(27, 31, 39),
			FogColor = Color3.fromRGB(11, 13, 18),
		},
	},
	{
		id = "concrete_labyrinth",
		name = "БЕТОННЫЙ ЛАБИРИНТ",
		subtitle = "Каждый поворот пахнет пылью.",
		build = buildLabyrinth,
		lighting = {
			ClockTime = 0.3,
			Brightness = 0.42,
			FogEnd = 190,
			FogStart = 20,
			Ambient = Color3.fromRGB(17, 19, 25),
			OutdoorAmbient = Color3.fromRGB(23, 26, 33),
			FogColor = Color3.fromRGB(8, 10, 14),
		},
	},
	{
		id = "ash_yard",
		name = "ПЕПЕЛЬНЫЙ ДВОР",
		subtitle = "Здесь когда-то был свет.",
		build = buildAshYard,
		lighting = {
			ClockTime = 2.2,
			Brightness = 0.7,
			FogEnd = 280,
			FogStart = 32,
			Ambient = Color3.fromRGB(25, 23, 26),
			OutdoorAmbient = Color3.fromRGB(34, 30, 32),
			FogColor = Color3.fromRGB(16, 13, 15),
		},
	},
}

local function applyLobbyLighting()
	Lighting.ClockTime = 14.3
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(74, 75, 81)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 116, 126)
	Lighting.FogStart = 250
	Lighting.FogEnd = 1200
	Lighting.FogColor = Color3.fromRGB(143, 154, 168)
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 0.28
	Lighting.EnvironmentSpecularScale = 0.28
	Lighting.GlobalShadows = true
end

local function applyRoundLighting(config)
	Lighting.ClockTime = config.ClockTime
	Lighting.Brightness = config.Brightness
	Lighting.Ambient = config.Ambient
	Lighting.OutdoorAmbient = config.OutdoorAmbient
	Lighting.FogStart = config.FogStart
	Lighting.FogEnd = config.FogEnd
	Lighting.FogColor = config.FogColor
	Lighting.ExposureCompensation = -0.25
	Lighting.EnvironmentDiffuseScale = 0.12
	Lighting.EnvironmentSpecularScale = 0.18
	Lighting.GlobalShadows = true

	local oldAtmosphere = Lighting:FindFirstChild("__SD_RoundAtmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "__SD_RoundAtmosphere"
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(150, 154, 164)
	atmosphere.Decay = Color3.fromRGB(42, 45, 55)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	local oldColor = Lighting:FindFirstChild("__SD_RoundColor")
	if oldColor then
		oldColor:Destroy()
	end
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "__SD_RoundColor"
	colorCorrection.Brightness = -0.035
	colorCorrection.Contrast = 0.17
	colorCorrection.Saturation = -0.24
	colorCorrection.TintColor = Color3.fromRGB(221, 229, 242)
	colorCorrection.Parent = Lighting
end

local function removeRoundEffects()
	for _, name in ipairs({ "__SD_RoundAtmosphere", "__SD_RoundColor" }) do
		local effect = Lighting:FindFirstChild(name)
		if effect then
			effect:Destroy()
		end
	end
end

local function createSpawnData(origin)
	local survivorOffsets = {
		Vector3.new(-112, 0, 112),
		Vector3.new(112, 0, 112),
		Vector3.new(-120, 0, 50),
		Vector3.new(120, 0, 50),
		Vector3.new(-118, 0, -35),
		Vector3.new(118, 0, -35),
		Vector3.new(-78, 0, 118),
		Vector3.new(78, 0, 118),
		Vector3.new(-122, 0, 0),
		Vector3.new(122, 0, 0),
	}

	local lookTarget = origin + Vector3.new(0, 4, 0)
	local survivors = {}
	for _, offset in ipairs(survivorOffsets) do
		local spawnPosition = origin + offset + Vector3.new(0, 4, 0)
		table.insert(survivors, CFrame.lookAt(spawnPosition, lookTarget))
	end

	local killer = CFrame.lookAt(origin + Vector3.new(0, 4, -118), lookTarget)
	return killer, survivors
end

function MapService.init()
	applyLobbyLighting()
	removeRoundEffects()
	createLobby()
end

function MapService.getLobbySpawn()
	return CFrame.new(LOBBY_ORIGIN + Vector3.new(0, 4, 42))
end

function MapService.getNpcStand()
	return CFrame.new(LOBBY_ORIGIN + Vector3.new(0, 4, -16))
end

function MapService.applyLobbyLighting()
	removeRoundEffects()
	applyLobbyLighting()
end

function MapService.cleanupRoundMap()
	if roundModel then
		roundModel:Destroy()
		roundModel = nil
	end
	MapService.applyLobbyLighting()
end

local function numberAttribute(instance, name, fallback)
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function colorAttribute(instance, name, fallback)
	local value = instance:GetAttribute(name)
	if typeof(value) == "Color3" then
		return value
	end
	return fallback
end

local function markerRole(part)
	local value = part:GetAttribute("SpawnRole")
	if typeof(value) == "string" then
		local lower = string.lower(value)
		if lower == "killer" or lower == "lostsoul" or lower == "lost soul" then
			return "Killer"
		elseif lower == "savior" or lower == "survivor" then
			return "Savior"
		end
	end

	local lowerName = string.lower(part.Name)
	if string.find(lowerName, "killer", 1, true) or string.find(lowerName, "lostsoul", 1, true) then
		return "Killer"
	elseif string.find(lowerName, "survivor", 1, true) or string.find(lowerName, "savior", 1, true) then
		return "Savior"
	end
	return nil
end

local function extractCustomSpawns(model)
	local killer = nil
	local survivors = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local role = markerRole(descendant)
			if role then
				local offset = descendant:GetAttribute("SpawnOffset")
				if typeof(offset) ~= "Vector3" then
					offset = Vector3.new(0, 4, 0)
				end
				local spawnCFrame = descendant.CFrame + offset

				if role == "Killer" then
					if not killer then
						killer = spawnCFrame
					end
				else
					table.insert(survivors, spawnCFrame)
				end

				-- Маркеры не должны быть видимыми или участвовать в коллизиях.
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
	end

	return killer, survivors
end

local function fallbackCustomSpawns(model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local center = boxCFrame.Position
	local floorY = center.Y - boxSize.Y / 2 + 4
	local lookTarget = Vector3.new(center.X, floorY, center.Z)

	local killerPosition = Vector3.new(
		center.X,
		floorY,
		center.Z - math.max(12, boxSize.Z * 0.28)
	)
	local killer = CFrame.lookAt(killerPosition, lookTarget)

	local survivors = {}
	local radius = math.max(14, math.min(boxSize.X, boxSize.Z) * 0.32)
	for index = 1, 10 do
		local angle = ((index - 1) / 10) * math.pi * 2
		local position = Vector3.new(
			center.X + math.cos(angle) * radius,
			floorY,
			center.Z + math.sin(angle) * radius
		)
		table.insert(survivors, CFrame.lookAt(position, lookTarget))
	end
	return killer, survivors
end

local function customLightingConfig(template)
	local defaults = Config.Content.DefaultMapLighting
	return {
		ClockTime = numberAttribute(template, "ClockTime", defaults.ClockTime),
		Brightness = numberAttribute(template, "Brightness", defaults.Brightness),
		FogStart = numberAttribute(template, "FogStart", defaults.FogStart),
		FogEnd = numberAttribute(template, "FogEnd", defaults.FogEnd),
		Ambient = colorAttribute(template, "AmbientColor", defaults.Ambient),
		OutdoorAmbient = colorAttribute(template, "OutdoorAmbientColor", defaults.OutdoorAmbient),
		FogColor = colorAttribute(template, "FogColor", defaults.FogColor),
	}
end

local function chooseCustomTemplate(templates)
	local pool = {}
	for _, template in ipairs(templates) do
		local mapId = tostring(template:GetAttribute("MapId") or template.Name)
		if mapId ~= lastMapId then
			table.insert(pool, template)
		end
	end
	if #pool == 0 then
		pool = templates
	end

	local totalWeight = 0
	for _, template in ipairs(pool) do
		totalWeight += math.max(0, numberAttribute(template, "Weight", 1))
	end
	if totalWeight <= 0 then
		return pool[random:NextInteger(1, #pool)]
	end

	local roll = random:NextNumber(0, totalWeight)
	for _, template in ipairs(pool) do
		roll -= math.max(0, numberAttribute(template, "Weight", 1))
		if roll <= 0 then
			return template
		end
	end
	return pool[#pool]
end

local function buildCustomRoundMap(template)
	MapService.cleanupRoundMap()

	local mapId = tostring(template:GetAttribute("MapId") or template.Name)
	local mapName = tostring(template:GetAttribute("MapName") or template.Name)
	local subtitle = tostring(template:GetAttribute("MapSubtitle") or "КАРТА ИЗ STUDIO")

	local clone = template:Clone()
	clone.Name = "SD_RoundMap"
	clone:PivotTo(CFrame.new(MAP_ORIGIN))
	clone.Parent = Workspace
	roundModel = clone

	local killerSpawn, survivorSpawns = extractCustomSpawns(clone)
	if not killerSpawn or #survivorSpawns == 0 then
		local fallbackKiller, fallbackSurvivors = fallbackCustomSpawns(clone)
		if not killerSpawn then
			killerSpawn = fallbackKiller
			warn("[Shattered Dimensions] Карта «" .. mapName .. "»: нет KillerSpawn/LostSoulSpawn. Использую автоматическую точку.")
		end
		if #survivorSpawns == 0 then
			survivorSpawns = fallbackSurvivors
			warn("[Shattered Dimensions] Карта «" .. mapName .. "»: нет SurvivorSpawn/SaviorSpawn. Использую автоматические точки.")
		end
	end

	applyRoundLighting(customLightingConfig(template))
	lastMapId = mapId

	return {
		id = mapId,
		name = mapName,
		subtitle = subtitle,
		model = clone,
		center = MAP_ORIGIN,
		killerSpawn = killerSpawn,
		survivorSpawns = survivorSpawns,
		custom = true,
	}
end

function MapService.buildRoundMap()
	MapService.cleanupRoundMap()

	if Config.Content.UseStudioMaps ~= false then
		local templates = ContentService.getMapTemplates()
		if #templates > 0 then
			local template = chooseCustomTemplate(templates)
			local ok, result = pcall(buildCustomRoundMap, template)
			if ok and result then
				return result
			end
			warn("[Shattered Dimensions] Ошибка пользовательской карты, использую встроенную: " .. tostring(result))
			MapService.cleanupRoundMap()
		end
	end

	local available = {}
	for index, blueprint in ipairs(blueprints) do
		if blueprint.id ~= lastMapId then
			table.insert(available, { index = index, blueprint = blueprint })
		end
	end
	if #available == 0 then
		for index, blueprint in ipairs(blueprints) do
			table.insert(available, { index = index, blueprint = blueprint })
		end
	end

	local chosen = available[random:NextInteger(1, #available)]
	local blueprint = chosen.blueprint
	lastMapId = blueprint.id

	local model = Instance.new("Model")
	model.Name = "SD_RoundMap"
	roundModel = model

	local origin = MAP_ORIGIN
	local floor = makePart(
		model,
		"MapFloor",
		Vector3.new(280, 2, 280),
		CFrame.new(origin),
		PALETTE.floor,
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor

	-- Внутренняя разметка пола.
	for _, x in ipairs({ -90, -45, 45, 90 }) do
		local line = makePart(
			model,
			"FloorLine",
			Vector3.new(0.25, 0.05, 240),
			CFrame.new(origin + Vector3.new(x, 1.04, 0)),
			PALETTE.floorDark,
			Enum.Material.SmoothPlastic
		)
		line.CanCollide = false
	end

	buildBoundary(model, origin, blueprint.name)
	blueprint.build(model, origin)

	local killerSpawn, survivorSpawns = createSpawnData(origin)
	applyRoundLighting(blueprint.lighting)

	model.Parent = Workspace

	return {
		id = blueprint.id,
		name = blueprint.name,
		subtitle = blueprint.subtitle,
		model = model,
		center = origin,
		killerSpawn = killerSpawn,
		survivorSpawns = survivorSpawns,
	}
end

function MapService.getMapOrigin()
	return MAP_ORIGIN
end

return MapService
