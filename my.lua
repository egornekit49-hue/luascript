-- Финальный скрипт: Speed + Fly (CFrame) + Auto-Punch (универсальный)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager") -- если есть
local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ======
local SPEED = 50
local STEP = 4
local PUNCH_DELAY = 50   -- мс
local BLOCK_SPEED_THRESHOLD = 0.5
local FLY_SPEED = 50

-- ====== GUI (зелёный) ======
local gui = Instance.new("ScreenGui")
gui.Name = "SuperGui"
gui.Parent = game:GetService("CoreGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 280)
panel.Position = UDim2.new(0, 10, 1, -290)
panel.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "Speed + Fly + Anti-Block"
title.TextColor3 = Color3.new(0.7, 1, 0.7)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

-- Speed
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromOffset(60, 26)
speedLabel.Position = UDim2.fromOffset(12, 48)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed:"
speedLabel.TextColor3 = Color3.new(0.8, 1, 0.8)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 16
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = panel

local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.fromOffset(70, 30)
valueBox.Position = UDim2.fromOffset(80, 44)
valueBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
valueBox.BorderSizePixel = 0
valueBox.Text = tostring(SPEED)
valueBox.TextColor3 = Color3.new(1, 1, 1)
valueBox.Font = Enum.Font.GothamBold
valueBox.TextSize = 18
valueBox.ClearTextOnFocus = false
valueBox.Parent = panel
Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 7)

local decrease = Instance.new("TextButton")
decrease.Size = UDim2.fromOffset(40, 30)
decrease.Position = UDim2.fromOffset(160, 44)
decrease.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
decrease.BorderSizePixel = 0
decrease.Text = "-"
decrease.TextColor3 = Color3.new(1, 1, 1)
decrease.Font = Enum.Font.GothamBold
decrease.TextSize = 24
decrease.Parent = panel
Instance.new("UICorner", decrease).CornerRadius = UDim.new(0, 7)

local increase = Instance.new("TextButton")
increase.Size = UDim2.fromOffset(40, 30)
increase.Position = UDim2.fromOffset(210, 44)
increase.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
increase.BorderSizePixel = 0
increase.Text = "+"
increase.TextColor3 = Color3.new(1, 1, 1)
increase.Font = Enum.Font.GothamBold
increase.TextSize = 24
increase.Parent = panel
Instance.new("UICorner", increase).CornerRadius = UDim.new(0, 7)

-- Fly
local flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.fromOffset(100, 32)
flyButton.Position = UDim2.fromOffset(12, 88)
flyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
flyButton.BorderSizePixel = 0
flyButton.Text = "Fly: OFF"
flyButton.TextColor3 = Color3.new(1, 1, 1)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 18
flyButton.Parent = panel
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 7)

-- Auto-Punch
local autoLabel = Instance.new("TextLabel")
autoLabel.Size = UDim2.fromOffset(100, 26)
autoLabel.Position = UDim2.fromOffset(12, 132)
autoLabel.BackgroundTransparency = 1
autoLabel.Text = "Auto-Punch: OFF"
autoLabel.TextColor3 = Color3.fromRGB(1, 0.5, 0.5)
autoLabel.Font = Enum.Font.GothamBold
autoLabel.TextSize = 16
autoLabel.TextXAlignment = Enum.TextXAlignment.Left
autoLabel.Parent = panel

local toggleAuto = Instance.new("TextButton")
toggleAuto.Size = UDim2.fromOffset(80, 32)
toggleAuto.Position = UDim2.fromOffset(120, 128)
toggleAuto.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
toggleAuto.BorderSizePixel = 0
toggleAuto.Text = "Вкл"
toggleAuto.TextColor3 = Color3.new(1, 1, 1)
toggleAuto.Font = Enum.Font.GothamBold
toggleAuto.TextSize = 18
toggleAuto.Parent = panel
Instance.new("UICorner", toggleAuto).CornerRadius = UDim.new(0, 7)

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.fromOffset(70, 26)
delayLabel.Position = UDim2.fromOffset(12, 176)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Delay (ms):"
delayLabel.TextColor3 = Color3.new(0.8, 1, 0.8)
delayLabel.Font = Enum.Font.Gotham
delayLabel.TextSize = 14
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = panel

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.fromOffset(60, 26)
delayBox.Position = UDim2.fromOffset(100, 172)
delayBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
delayBox.BorderSizePixel = 0
delayBox.Text = tostring(PUNCH_DELAY)
delayBox.TextColor3 = Color3.new(1, 1, 1)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 16
delayBox.ClearTextOnFocus = false
delayBox.Parent = panel
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 7)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 26)
hint.Position = UDim2.fromOffset(12, 212)
hint.BackgroundTransparency = 1
hint.Text = "WASD + Space/Shift (Fly)"
hint.TextColor3 = Color3.fromRGB(185, 190, 205)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.Parent = panel

-- ====== ЛОГИКА СКОРОСТИ ======
local function getHumanoid()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

local function setSpeed(newSpeed)
    local val = tonumber(newSpeed)
    if val then SPEED = val end
    valueBox.Text = tostring(SPEED)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = SPEED end
end

decrease.Activated:Connect(function() setSpeed(SPEED - STEP) end)
increase.Activated:Connect(function() setSpeed(SPEED + STEP) end)
valueBox.FocusLost:Connect(function() setSpeed(valueBox.Text) end)

RunService.Heartbeat:Connect(function()
    local hum = getHumanoid()
    if hum and hum.WalkSpeed ~= SPEED then hum.WalkSpeed = SPEED end
end)

player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = SPEED
end)
task.wait(0.5)
setSpeed(SPEED)

-- ====== ПОЛЁТ (через CFrame, обходит блокировку BodyVelocity) ======
local flying = false
local flyConnection
local function startFly()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flying = true
    flyButton.Text = "Fly: ON"
    flyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flying or not root then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local move = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + cam.CFrame.UpVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - cam.CFrame.UpVector end
        if move.Magnitude > 0 then
            root.CFrame = root.CFrame + move.Unit * SPEED * 0.1
        end
    end)
end

local function stopFly()
    flying = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    flyButton.Text = "Fly: OFF"
    flyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
end

flyButton.Activated:Connect(function()
    if flying then stopFly() else startFly() end
end)
player.CharacterAdded:Connect(function()
    if flying then stopFly() end
end)

-- ====== АВТО-УДАР (исправлен) ======
local isAutoOn = false
local lastPunchTime = 0

-- Поиск кнопки удара в GUI
local function findPunchButton()
    local gui = player.PlayerGui
    if not gui then return nil end
    for _, child in ipairs(gui:GetDescendants()) do
        if child:IsA("TextButton") then
            local name = child.Name:lower()
            if name:find("punch") or name:find("attack") or name:find("hit") or name:find("fight") then
                return child
            end
        end
    end
    return nil
end

local punchButton = findPunchButton()
if punchButton then
    print("[Auto-Punch] Найдена кнопка удара:", punchButton.Name)
else
    print("[Auto-Punch] Кнопка удара не найдена, будем использовать эмуляцию")
end

-- Функция удара
local function punch()
    -- Способ 1: кнопка в GUI
    if punchButton and punchButton:IsA("TextButton") then
        punchButton:Click()
        return
    end

    -- Способ 2: эмуляция касания через VirtualInputManager
    if VirtualInputManager then
        VirtualInputManager:SendTouchEvent(1, {UDim2.new(0.5, 0, 0.5, 0)}, false, 0, 0)
        task.wait(0.05)
        VirtualInputManager:SendTouchEvent(1, {UDim2.new(0.5, 0, 0.5, 0)}, true, 0, 0)
        return
    end

    -- Способ 3: эмуляция клавиши (попробуем Q, E, F)
    local keys = {Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.F}
    for _, key in ipairs(keys) do
        -- В Roblox нет SetKeyDown, но в некоторых эксплойтах есть функция для отправки нажатий
        -- Попробуем через UserInputService:InputBegan (это событие, но некоторые эксплойты позволяют его вызвать)
        local input = {
            UserInputType = Enum.UserInputType.Keyboard,
            KeyCode = key,
            Position = Vector2.new()
        }
        UserInputService:InputBegan(input, false)
        task.wait(0.05)
        UserInputService:InputEnded(input, false)
    end
end

local function isBlocking(char)
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    if hum.WalkSpeed <= BLOCK_SPEED_THRESHOLD then return true end
    -- анимация
    local animator = hum:FindFirstChild("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.Name:lower():find("block") then
                return true
            end
        end
    end
    return false
end

local function getNearestEnemy()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest, minDist = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local oChar = other.Character
            if oChar then
                local oRoot = oChar:FindFirstChild("HumanoidRootPart")
                if oRoot then
                    local dist = (root.Position - oRoot.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = oChar
                    end
                end
            end
        end
    end
    return nearest
end

local function autoPunchLoop()
    while isAutoOn do
        local enemy = getNearestEnemy()
        if enemy then
            local nowBlocking = isBlocking(enemy)
            if not nowBlocking then  -- УДАРЯЕМ, КОГДА НЕТ БЛОКА (без проверки перехода)
                local currentTime = tick() * 1000
                if currentTime - lastPunchTime >= PUNCH_DELAY then
                    punch()
                    lastPunchTime = currentTime
                end
            end
        end
        task.wait(0.05)
    end
end

toggleAuto.Activated:Connect(function()
    isAutoOn = not isAutoOn
    if isAutoOn then
        autoLabel.Text = "Auto-Punch: ON"
        autoLabel.TextColor3 = Color3.fromRGB(0.5, 1, 0.5)
        toggleAuto.Text = "Выкл"
        lastPunchTime = 0
        task.spawn(autoPunchLoop)
    else
        autoLabel.Text = "Auto-Punch: OFF"
        autoLabel.TextColor3 = Color3.fromRGB(1, 0.5, 0.5)
        toggleAuto.Text = "Вкл"
    end
end)

delayBox.FocusLost:Connect(function()
    local newDelay = tonumber(delayBox.Text)
    if newDelay and newDelay >= 0 then
        PUNCH_DELAY = newDelay
    else
        delayBox.Text = tostring(PUNCH_DELAY)
    end
end)

print("[SuperScript] Загружен. Теперь бьёт, если противник не блокирует (даже если блока не было).")
