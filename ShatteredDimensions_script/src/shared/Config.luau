--[[
	Shattered Dimensions — общая конфигурация.
	Модуль лежит в ReplicatedStorage.Shared и используется и сервером, и клиентом.
]]

local Config = {}

Config.Brand = {
	Name = "SHATTERED DIMENSIONS",
	NameRu = "РАЗБИТЫЕ ИЗМЕРЕНИЯ",
	Version = "0.1.0",
	Tagline = "АСИММЕТРИЧНЫЙ ХОРРОР",
}

Config.Roles = {
	Savior = "Savior",
	LostSoul = "LostSoul",
	Lobby = "Lobby",
	Spectator = "Spectator",
}

Config.RoleMeta = {
	Savior = {
		name = "ВЫЖИВШИЙ",
		nameEn = "SAVIOR",
		color = Color3.fromRGB(86, 220, 232),
		objective = "Продержитесь до конца раунда",
	},
	LostSoul = {
		name = "ПОТЕРЯННАЯ ДУША",
		nameEn = "LOST SOUL",
		color = Color3.fromRGB(235, 78, 88),
		objective = "Найдите и уничтожьте всех выживших",
	},
	Lobby = {
		name = "ЛОББИ",
		nameEn = "LOBBY",
		color = Color3.fromRGB(175, 183, 197),
		objective = "Подойдите к Хранителю, чтобы открыть магазин",
	},
	Spectator = {
		name = "НАБЛЮДАТЕЛЬ",
		nameEn = "SPECTATOR",
		color = Color3.fromRGB(238, 193, 101),
		objective = "Раунд уже идёт — дождитесь следующего",
	},
}

Config.Round = {
	IntermissionSeconds = 40,
	MinPlayers = 2,
	WaitingAfterFailedStart = 5,
	EndScreenSeconds = 8,
	LastFightingSoulSeconds = 75,
	-- Формула: 100 + 40 * (количество выживших).
	-- 1 выживший + 1 убийца — особый режим Last Fighting Soul на 75 секунд.
	-- 2 выживших + 1 убийца = 100 + 80 = 180 секунд (3 минуты), как в ТЗ.
	BaseRoundSeconds = 100,
	SecondsPerSavior = 40,
	-- Игрок может присоединиться к уже идущему раунду только наблюдателем.
	AutoRespawn = false,
}

function Config.computeRoundSeconds(playerCount, survivorCount)
	if playerCount == 2 and survivorCount == 1 then
		return Config.Round.LastFightingSoulSeconds
	end
	return Config.Round.BaseRoundSeconds + (survivorCount * Config.Round.SecondsPerSavior)
end

Config.Movement = {
	BaseWalkSpeed = {
		[Config.Roles.Savior] = 16,
		[Config.Roles.LostSoul] = 17,
	},
	SprintMultiplier = 1.55,
}

Config.Stamina = {
	Max = {
		[Config.Roles.Savior] = 100,
		[Config.Roles.LostSoul] = 110,
	},
	DrainPerSecond = 18,
	RegenPerSecond = 14,
	RegenDelay = 0.9,
	MinToStartSprint = 8,
	UpdateInterval = 0.1,
}

Config.Combat = {
	Knife = {
		Damage = 50,
		Range = 8.5,
		Cooldown = 1.15,
		ConeDegrees = 70,
	},
}

Config.Flashlight = {
	Range = 65,
	Angle = 52,
	Brightness = 3.2,
	Color = Color3.fromRGB(255, 246, 214),
	AimSendInterval = 0.08,
}

Config.Economy = {
	StartingEchoes = 500,
	ParticipationReward = 45,
	WinnerBonus = 55,
}

Config.Data = {
	StoreName = "ShatteredDimensions_Profiles_v1",
	SaveIntervalSeconds = 60,
	LoadRetries = 3,
}

Config.PlayerList = {
	RefreshSeconds = 2,
}

-- Настройки контента, который добавляется прямо в Studio.
-- Модели карт и персонажей лежат в ServerStorage.ShatteredDimensions.Content.
Config.Content = {
	UseStudioMaps = true,
	UseStudioCharacterModels = true,
	UseCustomAbilities = true,
	AbilityFallbackByRole = {
		[Config.Roles.Savior] = "flashlight",
		[Config.Roles.LostSoul] = "knife",
	},
	DefaultMapLighting = {
		ClockTime = 1.1,
		Brightness = 0.55,
		FogStart = 25,
		FogEnd = 245,
		Ambient = Color3.fromRGB(20, 23, 30),
		OutdoorAmbient = Color3.fromRGB(27, 31, 39),
		FogColor = Color3.fromRGB(11, 13, 18),
	},
}

Config.Characters = {
	Saviors = {
		{
			id = "seeker",
			role = Config.Roles.Savior,
			name = "Искатель",
			title = "THE SEEKER",
			description = "Обычный человек, который не сдался. Его лицо — ваше лицо, его страх — ваш страх.",
			lore = "Последний луч в коридоре, где давно погасли все лампы.",
			abilityId = "flashlight",
			abilityName = "Луч надежды",
			abilityKey = "F",
			abilityDescription = "Достать фонарик и посветить в направлении камеры. Повторное нажатие F выключает свет.",
			accent = Color3.fromRGB(86, 220, 232),
			price = 0,
		},
	},
	LostSouls = {
		{
			id = "hollow",
			role = Config.Roles.LostSoul,
			name = "Полый",
			title = "THE HOLLOW",
			description = "То, что осталось от человека, когда из него вынули имя. Носит чужое лицо и очень острый нож.",
			lore = "Он не гонится. Он уже знает, куда вы побежите.",
			abilityId = "knife",
			abilityName = "Разрез пустоты",
			abilityKey = "ЛКМ",
			abilityDescription = "Удар ножом в направлении камеры. Дальность — 8.5 стадов, урон — 50.",
			accent = Color3.fromRGB(235, 78, 88),
			price = 0,
		},
	},
}

Config.Skins = {
	{
		id = "seeker_original",
		characterId = "seeker",
		role = Config.Roles.Savior,
		name = "Оригинал",
		title = "DEFAULT",
		description = "Ваш собственный облик без изменений.",
		price = 0,
		accent = Color3.fromRGB(86, 220, 232),
		tint = nil,
		previewTint = Color3.fromRGB(255, 255, 255),
		rarity = "БАЗОВЫЙ",
	},
	{
		id = "seeker_nocturne",
		characterId = "seeker",
		role = Config.Roles.Savior,
		name = "Ноктюрн",
		title = "NOCTURNE",
		description = "Холодный синий оттенок. Идеально для тех, кто не хочет быть замеченным в темноте.",
		price = 250,
		accent = Color3.fromRGB(91, 161, 255),
		tint = Color3.fromRGB(66, 78, 101),
		previewTint = Color3.fromRGB(158, 186, 255),
		rarity = "РЕДКИЙ",
	},
	{
		id = "seeker_ash",
		characterId = "seeker",
		role = Config.Roles.Savior,
		name = "Пепел",
		title = "ASHEN",
		description = "Выжженная палитра старого убежища. Пыль, бетон и упрямство.",
		price = 400,
		accent = Color3.fromRGB(224, 209, 181),
		tint = Color3.fromRGB(134, 123, 108),
		previewTint = Color3.fromRGB(238, 228, 207),
		rarity = "ЭПИЧЕСКИЙ",
	},
	{
		id = "hollow_original",
		characterId = "hollow",
		role = Config.Roles.LostSoul,
		name = "Оригинал",
		title = "DEFAULT",
		description = "Ваш собственный облик без изменений.",
		price = 0,
		accent = Color3.fromRGB(235, 78, 88),
		tint = nil,
		previewTint = Color3.fromRGB(255, 255, 255),
		rarity = "БАЗОВЫЙ",
	},
	{
		id = "hollow_crimson",
		characterId = "hollow",
		role = Config.Roles.LostSoul,
		name = "Багровый свидетель",
		title = "CRIMSON WITNESS",
		description = "Багровая кожа и чужой шёпот за спиной. Он видел слишком много.",
		price = 300,
		accent = Color3.fromRGB(255, 67, 79),
		tint = Color3.fromRGB(91, 39, 43),
		previewTint = Color3.fromRGB(255, 154, 154),
		rarity = "РЕДКИЙ",
	},
	{
		id = "hollow_void",
		characterId = "hollow",
		role = Config.Roles.LostSoul,
		name = "Пустота",
		title = "THE VOID",
		description = "Не цвет. Отсутствие цвета. Тёмный силуэт с фиолетовым контуром.",
		price = 450,
		accent = Color3.fromRGB(174, 126, 255),
		tint = Color3.fromRGB(38, 38, 49),
		previewTint = Color3.fromRGB(190, 168, 255),
		rarity = "ЭПИЧЕСКИЙ",
	},
}

Config.Emotions = {
	{
		id = "wave",
		name = "Волна",
		title = "WAVE",
		symbol = "✦",
		description = "Короткий жест, который напоминает: ты ещё здесь.",
		line = "приветствует всех",
		price = 0,
		accent = Color3.fromRGB(86, 220, 232),
	},
	{
		id = "laugh",
		name = "Насмешка",
		title = "LAUGH",
		symbol = "☠",
		description = "Смеяться в лицо неизбежному — тоже стратегия.",
		line = "смеётся над темнотой",
		price = 120,
		accent = Color3.fromRGB(238, 193, 101),
	},
	{
		id = "dance",
		name = "Танец теней",
		title = "SHADOW DANCE",
		symbol = "♫",
		description = "Три секунды ритма, украденные у раунда.",
		line = "танцует перед бездной",
		price = 200,
		accent = Color3.fromRGB(174, 126, 255),
	},
	{
		id = "panic",
		name = "Паника",
		title = "PANIC",
		symbol = "!",
		description = "Иногда лучший план — честно показать, что плана нет.",
		line = "в панике оглядывается",
		price = 160,
		accent = Color3.fromRGB(235, 78, 88),
	},
}

-- Быстрые индексы для сервера и клиента.
local characterById = {}
local skinById = {}
local emotionById = {}

for _, character in ipairs(Config.Characters.Saviors) do
	characterById[character.id] = character
end
for _, character in ipairs(Config.Characters.LostSouls) do
	characterById[character.id] = character
end
for _, skin in ipairs(Config.Skins) do
	skinById[skin.id] = skin
end
for _, emotion in ipairs(Config.Emotions) do
	emotionById[emotion.id] = emotion
end

function Config.getCharacter(id)
	return characterById[id]
end

function Config.getSkin(id)
	return skinById[id]
end

function Config.getEmotion(id)
	return emotionById[id]
end

function Config.getCharacterForRole(role)
	if role == Config.Roles.Savior then
		return Config.Characters.Saviors[1]
	elseif role == Config.Roles.LostSoul then
		return Config.Characters.LostSouls[1]
	end
	return nil
end

function Config.getDefaultSkin(role)
	for _, skin in ipairs(Config.Skins) do
		if skin.role == role and skin.price == 0 then
			return skin
		end
	end
	return nil
end

function Config.getSkinsForRole(role)
	local result = {}
	for _, skin in ipairs(Config.Skins) do
		if skin.role == role then
			table.insert(result, skin)
		end
	end
	return result
end

function Config.getDefaultProfile()
	local savior = Config.getCharacterForRole(Config.Roles.Savior)
	local lostSoul = Config.getCharacterForRole(Config.Roles.LostSoul)
	local saviorSkin = Config.getDefaultSkin(Config.Roles.Savior)
	local lostSoulSkin = Config.getDefaultSkin(Config.Roles.LostSoul)
	local emotion = Config.Emotions[1]

	return {
		echoes = Config.Economy.StartingEchoes,
		ownedSkins = {},
		ownedEmotions = {},
		selectedSavior = savior and savior.id or "",
		selectedLostSoul = lostSoul and lostSoul.id or "",
		selectedSaviorSkin = saviorSkin and saviorSkin.id or "",
		selectedLostSoulSkin = lostSoulSkin and lostSoulSkin.id or "",
		selectedEmotion = emotion and emotion.id or "wave",
		totalPlaySeconds = 0,
		roundsPlayed = 0,
		roundsWon = 0,
		kills = 0,
	}
end

return Config
