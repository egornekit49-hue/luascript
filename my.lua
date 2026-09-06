local Players = game:GetService("Players")

local player = Players.LocalPlayer
local panel = script.Parent:WaitForChild("Panel")
local valueBox = panel:WaitForChild("SpeedValue")
local decrease = panel:WaitForChild("Decrease")
local increase = panel:WaitForChild("Increase")

local MIN_SPEED = 4
local MAX_SPEED = 100
local STEP = 4
local speed = 16

local function getHumanoid()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("Humanoid")
end

local function setSpeed(newSpeed)
	speed = math.clamp(math.round(newSpeed), MIN_SPEED, MAX_SPEED)
	valueBox.Text = tostring(speed)
	getHumanoid().WalkSpeed = speed
end

decrease.Activated:Connect(function()
	setSpeed(speed - STEP)
end)

increase.Activated:Connect(function()
	setSpeed(speed + STEP)
end)

valueBox.FocusLost:Connect(function()
	local typedSpeed = tonumber(valueBox.Text)
	setSpeed(typedSpeed or speed)
end)

player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = speed
end)

setSpeed(speed)
