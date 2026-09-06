-- Скорость + ПОЛЁТ (БЕЗ ОГРАНИЧЕНИЙ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ======
local SPEED = 50          -- скорость (и для бега, и для полёта)
local STEP = 4            -- шаг кнопок +/-

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "SpeedControlGui"
gui.Parent = game:GetService("CoreGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 200)
panel.Position = UDim2.new(0, 20, 1, -220)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "Скорость + Полет"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local function createButton(name, text, x, y)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(50, 42)
	button.Position = UDim2.fromOffset(x, y)
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

local decrease = createButton("Decrease", "-", 20, 52)
local increase = createButton("Increase", "+", 180, 52)

local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.fromOffset(90, 42)
valueBox.Position = UDim2.fromOffset(80, 52)
valueBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
valueBox.BorderSizePixel = 0
valueBox.Text = tostring(SPEED)
valueBox.TextColor3 = Color3.new(1, 1, 1)
valueBox.Font = Enum.Font.GothamBold
valueBox.TextSize = 20
valueBox.ClearTextOnFocus = false
valueBox.Parent = panel
Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 7)

-- Кнопка включения полёта
local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Size = UDim2.fromOffset(100, 36)
flyButton.Position = UDim2.fromOffset(90, 108)
flyButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
flyButton.BorderSizePixel = 0
flyButton.Text = "Fly: OFF"
flyButton.TextColor3 = Color3.new(1, 1, 1)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 18
flyButton.Parent = panel
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 7)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 26)
hint.Position = UDim2.fromOffset(12, 158)
hint.BackgroundTransparency = 1
hint.Text = "WASD - движение, Пробел - вверх, Shift - вниз"
hint.TextColor3 = Color3.fromRGB(185, 190, 205)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.Parent = panel

-- ====== ЛОГИКА СКОРОСТИ (БЕЗ ОГРАНИЧЕНИЙ) ======
local function getHumanoid()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("Humanoid")
end

local function setSpeed(newSpeed)
	local val = tonumber(newSpeed)
	if val then
		SPEED = val
	end
	valueBox.Text = tostring(SPEED)
	local hum = getHumanoid()
	if hum then
		hum.WalkSpeed = SPEED
	end
end

decrease.Activated:Connect(function() setSpeed(SPEED - STEP) end)
increase.Activated:Connect(function() setSpeed(SPEED + STEP) end)
valueBox.FocusLost:Connect(function()
	setSpeed(valueBox.Text)
end)

-- Постоянное обновление скорости (для борьбы со сбросами)
RunService.Heartbeat:Connect(function()
	local hum = getHumanoid()
	if hum and hum.WalkSpeed ~= SPEED then
		hum.WalkSpeed = SPEED
	end
end)

player.CharacterAdded:Connect(function(character)
	local hum = character:WaitForChild("Humanoid")
	hum.WalkSpeed = SPEED
end)

task.wait(0.5)
setSpeed(SPEED)

-- ====== ЛОГИКА ПОЛЁТА (использует ту же SPEED) ======
local flying = false
local flyBodyVelocity, flyBodyGyro
local flyConnection

local function startFly()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChild("Humanoid")
	if not root or not hum then return end

	hum.PlatformStand = true

	flyBodyVelocity = Instance.new("BodyVelocity")
	flyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	flyBodyVelocity.Parent = root

	flyBodyGyro = Instance.new("BodyGyro")
	flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	flyBodyGyro.Parent = root

	local function updateFly()
		if not root or not flyBodyVelocity then return end
		local camera = workspace.CurrentCamera
		if not camera then return end

		local forward = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector
		local up = camera.CFrame.UpVector

		local moveDirection = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - right end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + right end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + up end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - up end

		if moveDirection.Magnitude > 0 then
			moveDirection = moveDirection.Unit * SPEED
		else
			moveDirection = Vector3.new(0, 0, 0)
		end

		flyBodyVelocity.Velocity = moveDirection

		if moveDirection.Magnitude > 0.1 then
			local targetCFrame = CFrame.lookAt(root.Position, root.Position + moveDirection)
			flyBodyGyro.CFrame = targetCFrame
		end
	end

	flyConnection = RunService.Heartbeat:Connect(updateFly)
	flying = true
	flyButton.Text = "Fly: ON"
	flyButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
end

local function stopFly()
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
	if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end

	local hum = getHumanoid()
	if hum then
		hum.PlatformStand = false
	end
	flying = false
	flyButton.Text = "Fly: OFF"
	flyButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
end

flyButton.Activated:Connect(function()
	if flying then
		stopFly()
	else
		startFly()
	end
end)

player.CharacterAdded:Connect(function()
	if flying then
		stopFly()
	end
end)
