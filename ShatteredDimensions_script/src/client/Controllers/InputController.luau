local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local InputController = {}
InputController.__index = InputController

function InputController.new(player, remotes, services)
	local self = setmetatable({}, InputController)
	self.player = player
	self.remotes = remotes
	self.shop = services.shop
	self.playerList = services.playerList
	self.effects = services.effects
	self.phase = "Lobby"
	self.sprintHeld = false
	self.lastAttackSent = 0
	self.lastAimSent = 0
	self.blockedLastFrame = false

	self:bind()
	return self
end

function InputController:modalOpen()
	return (self.shop and self.shop:isOpen()) or (self.playerList and self.playerList:isOpen())
end

function InputController:getRole()
	return self.player:GetAttribute("GameRole")
end

function InputController:isDead()
	return self.player:GetAttribute("IsDead") == true
end

function InputController:sendSprint(state)
	if self.remotes and self.remotes.SprintInput then
		self.remotes.SprintInput:FireServer(state)
	end
end

function InputController:stopSprint()
	if not self.sprintHeld then
		return
	end
	self.sprintHeld = false
	self:sendSprint(false)
end

function InputController:setPhase(phase)
	self.phase = phase
	if phase ~= "Round" then
		self:stopSprint()
	end
end

function InputController:reset()
	self.sprintHeld = false
	self:sendSprint(false)
end

function InputController:getAbilityId()
	return self.player:GetAttribute("AbilityId")
end

function InputController:getAbilityTrigger()
	return self.player:GetAttribute("AbilityTrigger")
end

function InputController:getAbilityKey()
	return self.player:GetAttribute("AbilityKey")
end

function InputController:isAbilityKey(input)
	local abilityKey = self:getAbilityKey()
	if not abilityKey or self:getAbilityTrigger() ~= "Key" then
		return false
	end
	return input.KeyCode.Name == abilityKey
end

function InputController:bind()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if self.phase ~= "Round" or self:modalOpen() or self:isDead() then
				return
			end
			local role = self:getRole()
			if role == Config.Roles.Savior or role == Config.Roles.LostSoul then
				self.sprintHeld = true
				self:sendSprint(true)
			end
		elseif self:isAbilityKey(input) then
			if self.phase ~= "Round" or self:modalOpen() or self:isDead() then
				return
			end
			local abilityId = self:getAbilityId()
			if abilityId and abilityId ~= "" then
				self.remotes.ToggleAbility:FireServer(abilityId)
			end
		elseif input.KeyCode == Enum.KeyCode.One then
			if self:modalOpen() or self:isDead() then
				return
			end
			local role = self:getRole()
			if role == Config.Roles.Savior or role == Config.Roles.Lobby or role == Config.Roles.Spectator then
				if self.phase == "Round" or self.phase == "Lobby" then
					self.remotes.UseEmote:FireServer()
				end
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self.phase ~= "Round" or self:modalOpen() or self:isDead() then
				return
			end
			if self:getAbilityTrigger() ~= "Primary" then
				return
			end

			local now = os.clock()
			if now - self.lastAttackSent < 0.1 then
				return
			end
			self.lastAttackSent = now

			local camera = Workspace.CurrentCamera
			local aim = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
			self.remotes.PrimaryAction:FireServer(aim)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			self:stopSprint()
		end
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		self:stopSprint()
	end)

	RunService.RenderStepped:Connect(function()
		if self.phase ~= "Round" then
			if self.sprintHeld then
				self:stopSprint()
			end
			return
		end

		if self:modalOpen() or self:isDead() then
			if self.sprintHeld then
				self:stopSprint()
			end
			return
		end

		local abilityId = self:getAbilityId()
		if abilityId and abilityId ~= "" then
			local now = os.clock()
			if now - self.lastAimSent >= Config.Flashlight.AimSendInterval then
				self.lastAimSent = now
				local camera = Workspace.CurrentCamera
				if camera then
					self.remotes.AimUpdate:FireServer(camera.CFrame.LookVector)
				end
			end
		end
	end)
end

return InputController
