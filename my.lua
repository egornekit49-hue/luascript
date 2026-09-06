-- LocalScript: StarterPlayer > StarterPlayerScripts > SpeedControlClient

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local speed = 16
local MIN_SPEED, MAX_SPEED, STEP = 4, 100, 4

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedControlGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(250, 145)
panel.Position = UDim2.new(0, 20, 1, -165)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "Скорость бега"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local function createButton(name, text, x)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(50, 42)
	button.Position = UDim2.fromOffset(x, 52)
	button.BackgroundColor3 = Color3.fromRGB(65, 104, 190)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 24
	button.Parent = panel

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
	return button
end

local decrease = createButton("Decrease", "-", 20)
local increase = createButton("Increase", "+", 180)

local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.fromOffset(90, 42)
valueBox.Position = UDim2.fromOffset(80, 52)
valueBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
valueBox.BorderSizePixel = 0
valueBox.Text = tostring(speed)
valueBox.TextColor3 = Color3.new(1, 1, 1)
valueBox.Font = Enum.Font.GothamBold
valueBox.TextSize = 20
valueBox.ClearTextOnFocus = false
valueBox.Parent = panel
Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 7)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 26)
hint.Position = UDim2.fromOffset(12, 108)
hint.BackgroundTransparency = 1
hint.Text = "Допустимый диапазон: 4–100"
hint.TextColor3 = Color3.fromRGB(185, 190, 205)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.Parent = panel

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
	setSpeed(tonumber(valueBox.Text) or speed)
end)

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid").WalkSpeed = speed
end)

setSpeed(speed)
