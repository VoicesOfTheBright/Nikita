--[[
	ШАБЛОН СПОСОБНОСТИ SHATTERED DIMENSIONS
	=======================================

	Как добавить свою способность:

	1. Скопируйте этот ModuleScript в
	   ServerStorage → ShatteredDimensions → Content → Abilities.
	2. Уберите "_" из имени (например, назовите модуль Dash).
	3. Замените Id, Name, Key/Trigger, Cooldown и колбэки.
	4. В Config.luau у нужного персонажа укажите:
	   abilityId = "dash";

	Модуль должен вернуть таблицу. Обязателен только Id, остальное опционально.

	Trigger:
		"Key"     — способность на клавише (Key). Например, F или Q.
		"Primary" — способность на ЛКМ. Например, удар ножом.

	Колбэки (все необязательные):
		OnEquip(ctx)          — персонаж появился в раунде
		OnActivate(ctx)       — нажата Key-способность
		OnPrimary(ctx, aim)   — ЛКМ; aim — Vector3 направления камеры
		OnAim(ctx, direction) — клиент прислал направление камеры
		OnDeath(ctx)          — персонаж погиб / закончил раунд
		OnCleanup(ctx)        — раунд закончился, состояние сбрасывается

	ctx — это таблица с данными и удобными функциями:
		ctx.player, ctx.character, ctx.humanoid, ctx.root, ctx.role
		ctx.state                — личное состояние способности (таблица)
		ctx.getCharacterParts()  — актуальные character, humanoid, root
		ctx.getCharacterConfig() — конфиг текущего персонажа
		ctx.getSkinConfig()      — конфиг текущего скина
		ctx.getOpponents()       — живые противники с полями player/character/humanoid/root
		ctx.fireCombat(payload)  — отправить визуальное событие в CombatFeedback
		ctx.notify(text, tone)   — уведомление игроку
		ctx.setActive(bool)      — подсветить «ВКЛ» в HUD
		ctx.addCleanup(fn)       — добавить функцию очистки
		ctx.raycastClear(origin, targetPosition, ignoreA, ignoreB)

	Ошибки в колбэках ловятся сервером и не ломают остальной раунд.
]]

local DashAbility = {
	Id = "dash_example",
	Name = "Рывок",
	ShortName = "РЫВОК",
	Description = "Короткий рывок вперёд. Нажмите Q.",
	Trigger = "Key",
	Key = "Q",
	Cooldown = 8,

	OnEquip = function(ctx)
		ctx.state.baseWalkSpeed = ctx.humanoid and ctx.humanoid.WalkSpeed or 16
	end,

	OnActivate = function(ctx)
		local character, humanoid = ctx.getCharacterParts()
		if not humanoid then
			return
		end

		ctx.setActive(true)
		humanoid.WalkSpeed = 32

		local finished = false
		local function finish()
			if finished then
				return
			end
			finished = true
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.WalkSpeed = ctx.state.baseWalkSpeed or 16
			end
			ctx.setActive(false)
		end

		task.delay(0.65, finish)
		ctx.addCleanup(finish)
	end,
}

return DashAbility
